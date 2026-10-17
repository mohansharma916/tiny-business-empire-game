extends Node

# Autoload singleton: EconomyService
# Source of truth for game economy, rates, upgrades, staff, and offline earnings.

signal cash_changed(new_cash: BigNumber)
signal income_changed(new_income: BigNumber)
signal business_purchased(business_id: String)
signal upgrade_purchased(business_id: String, track: String, new_level: int)
signal business_automated(business_id: String)
signal location_unlocked(location_id: String)
signal milestone_reached(milestone_name: String)

var cash: BigNumber = BigNumber.from_float(50.0)
var income_per_second: BigNumber = BigNumber.zero()

var businesses_config: Dictionary = {}
var upgrades_config: Dictionary = {}
var economy_config: Dictionary = {}

var owned_businesses: Dictionary = {}
var last_offline_calculation: Dictionary = {}

var _tick_timer: Timer
const TICK_RATE_HZ: float = 4.0
const TICK_INTERVAL: float = 1.0 / TICK_RATE_HZ

func _ready() -> void:
	_load_configs()
	_init_starter_state()
	_setup_tick_timer()
	recalculate_income()

func _setup_tick_timer() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.autostart = true
	_tick_timer.one_shot = false
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)

func _load_configs() -> void:
	businesses_config = _load_json("res://config/businesses.json")
	upgrades_config = _load_json("res://config/upgrades.json")
	economy_config = _load_json("res://config/economy.json")

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return json.data
	return {}

func _init_starter_state() -> void:
	# Unlock the Chai Stall by default (tier 1 starter)
	var chai_cfg: Dictionary = get_business_config("chai_stall")
	owned_businesses["chai_stall"] = {
		"id": "chai_stall",
		"name": chai_cfg.get("name", "Chai Stall"),
		"unlocked": true,
		"tracks": {
			"equipment": 1,
			"capacity": 1,
			"quality": 1,
			"marketing": 1
		},
		"workers": 0,
		"has_manager": false,
		"is_automated": false,
		"serving_progress": 0.0,
		"tap_boost_timer": 0.0
	}

func _on_tick() -> void:
	# Update active tap boosts
	for b_id in owned_businesses:
		var b: Dictionary = owned_businesses[b_id]
		if b.get("tap_boost_timer", 0.0) > 0.0:
			b["tap_boost_timer"] = maxf(0.0, b["tap_boost_timer"] - TICK_INTERVAL)
			if b["tap_boost_timer"] == 0.0:
				recalculate_income()

	# Add continuous income from automated businesses
	if not income_per_second.is_zero():
		var earned_this_tick := income_per_second.mul(TICK_INTERVAL)
		cash = cash.add(earned_this_tick)
		cash_changed.emit(cash)

func get_cash() -> BigNumber:
	return cash

func get_income_per_second() -> BigNumber:
	return income_per_second

func can_afford(cost: BigNumber) -> bool:
	return cash.is_greater_equal(cost)

func get_business_config(b_id: String) -> Dictionary:
	var list: Array = businesses_config.get("businesses", [])
	for b in list:
		if b is Dictionary and b.get("id") == b_id:
			return b
	return {}

func get_business_state(b_id: String) -> Dictionary:
	if owned_businesses.has(b_id):
		return owned_businesses[b_id]
	return {}

func is_business_owned(b_id: String) -> bool:
	return owned_businesses.has(b_id)

func get_total_business_level(b_id: String) -> int:
	var b: Dictionary = get_business_state(b_id)
	if b.is_empty():
		return 0
	var tracks: Dictionary = b.get("tracks", {})
	var total: int = 0
	for t in tracks:
		total += int(tracks[t])
	return total

func get_visual_tier(b_id: String) -> int:
	# Visual milestones at level 1, 25, 50 (PRD section 6)
	var lvl: int = get_total_business_level(b_id)
	if lvl >= 50:
		return 3
	elif lvl >= 25:
		return 2
	else:
		return 1

func get_upgrade_track_config(track_name: String) -> Dictionary:
	var tracks: Dictionary = upgrades_config.get("tracks", {})
	return tracks.get(track_name, {})

func get_upgrade_cost(b_id: String, track: String, bulk: Variant = 1) -> BigNumber:
	var b_cfg := get_business_config(b_id)
	var b_state := get_business_state(b_id)
	if b_cfg.is_empty() or b_state.is_empty():
		return BigNumber.zero()

	var base_costs: Dictionary = b_cfg.get("upgrade_base_costs", {})
	var base_cost: float = float(base_costs.get(track, 10.0))
	var track_cfg := get_upgrade_track_config(track)
	var growth: float = float(track_cfg.get("growth", 1.12))

	var current_level: int = int(b_state.get("tracks", {}).get(track, 1))
	var count: int = get_upgrade_levels_to_buy(b_id, track, bulk)
	if count <= 0:
		return BigNumber.zero()

	# Geometric sum: base * growth^(current-1) * (growth^count - 1) / (growth - 1)
	var cost_first: float = base_cost * pow(growth, float(current_level - 1))
	if count == 1:
		return BigNumber.from_float(cost_first)
	var total: float = cost_first * (pow(growth, float(count)) - 1.0) / (growth - 1.0)
	return BigNumber.from_float(total)

func get_upgrade_levels_to_buy(b_id: String, track: String, bulk: Variant = 1) -> int:
	if str(bulk).to_lower() == "max":
		var b_cfg := get_business_config(b_id)
		var b_state := get_business_state(b_id)
		var base_costs: Dictionary = b_cfg.get("upgrade_base_costs", {})
		var base_cost: float = float(base_costs.get(track, 10.0))
		var track_cfg := get_upgrade_track_config(track)
		var growth: float = float(track_cfg.get("growth", 1.12))
		var current_level: int = int(b_state.get("tracks", {}).get(track, 1))

		var cost_first: float = base_cost * pow(growth, float(current_level - 1))
		var cash_f: float = cash.to_float()
		if cash_f < cost_first:
			return 1 # Show cost for next 1 level even if cannot afford
		# cash = cost_first * (growth^k - 1) / (growth - 1)
		var k: float = log(1.0 + cash_f * (growth - 1.0) / cost_first) / log(growth)
		return maxi(1, int(floor(k)))
	else:
		return maxi(1, int(bulk))

func buy_upgrade(b_id: String, track: String, bulk: Variant = 1) -> bool:
	var cost := get_upgrade_cost(b_id, track, bulk)
	if not can_afford(cost):
		return false

	var count := get_upgrade_levels_to_buy(b_id, track, bulk)
	cash = cash.sub(cost)
	var b_state: Dictionary = owned_businesses[b_id]
	var old_total: int = get_total_business_level(b_id)
	b_state["tracks"][track] = int(b_state["tracks"][track]) + count
	var new_total: int = get_total_business_level(b_id)

	cash_changed.emit(cash)
	upgrade_purchased.emit(b_id, track, int(b_state["tracks"][track]))

	# Check milestone (every 25 total levels)
	if int(new_total / 25) > int(old_total / 25):
		milestone_reached.emit("Level %d milestone reached on %s!" % [new_total, b_state.get("name", b_id)])

	recalculate_income()
	return true

func hire_staff(b_id: String, role: String) -> bool:
	var b_state := get_business_state(b_id)
	var b_cfg := get_business_config(b_id)
	if b_state.is_empty() or b_cfg.is_empty():
		return false

	var staff_cfg: Dictionary = b_cfg.get("staff", {})
	if role == "manager":
		if b_state.get("has_manager", false):
			return false
		var cost := BigNumber.from_float(float(staff_cfg.get("manager_cost", 500.0)))
		if not can_afford(cost):
			return false
		cash = cash.sub(cost)
		b_state["has_manager"] = true
		b_state["is_automated"] = true
		cash_changed.emit(cash)
		business_automated.emit(b_id)
		recalculate_income()
		return true
	elif role == "worker":
		var cost := BigNumber.from_float(float(staff_cfg.get("worker_cost", 100.0)))
		if not can_afford(cost):
			return false
		cash = cash.sub(cost)
		b_state["workers"] = int(b_state.get("workers", 0)) + 1
		cash_changed.emit(cash)
		recalculate_income()
		return true

	return false

func tap_business(b_id: String) -> Dictionary:
	var b_state := get_business_state(b_id)
	var b_cfg := get_business_config(b_id)
	if b_state.is_empty():
		return {}

	var cycle_rev := calculate_cycle_revenue(b_id)

	if b_state.get("is_automated", false):
		# Boost speed temporarily
		b_state["tap_boost_timer"] = float(economy_config.get("tap", {}).get("boost_duration_seconds", 10.0))
		recalculate_income()
		return {"boosted": true, "duration": b_state["tap_boost_timer"], "revenue": BigNumber.zero()}
	else:
		# Manual cycle completed: grant revenue
		cash = cash.add(cycle_rev)
		cash_changed.emit(cash)
		return {"boosted": false, "revenue": cycle_rev}

func calculate_cycle_revenue(b_id: String) -> BigNumber:
	var b_cfg := get_business_config(b_id)
	var b_state := get_business_state(b_id)
	if b_cfg.is_empty() or b_state.is_empty():
		return BigNumber.zero()

	var tracks: Dictionary = b_state.get("tracks", {})
	var cap_lvl: int = int(tracks.get("capacity", 1))
	var qual_lvl: int = int(tracks.get("quality", 1))
	var mkt_lvl: int = int(tracks.get("marketing", 1))

	var base_rev: float = float(b_cfg.get("base_revenue_per_customer", 1.0))
	var base_cap: float = float(b_cfg.get("base_capacity", 1.0))
	var base_dem: float = float(b_cfg.get("base_demand", 1.5))

	var capacity: float = base_cap + float(cap_lvl - 1) * 0.2
	var demand: float = base_dem + float(mkt_lvl - 1) * 0.25
	var customers_served: float = minf(capacity, demand)

	var rev_per_cust: float = base_rev * pow(1.08, float(qual_lvl - 1))

	# Milestone multiplier (2x every 25 total levels)
	var total_lvl: int = get_total_business_level(b_id)
	var milestone_mult: float = pow(2.0, float(int(total_lvl / 25)))

	var total_rev: float = customers_served * rev_per_cust * milestone_mult
	return BigNumber.from_float(total_rev)

func calculate_cycle_time(b_id: String) -> float:
	var b_cfg := get_business_config(b_id)
	var b_state := get_business_state(b_id)
	var base_sec: float = float(b_cfg.get("base_cycle_seconds", 2.0))
	var eq_lvl: int = int(b_state.get("tracks", {}).get("equipment", 1))

	var cycle_time: float = base_sec * pow(0.97, float(eq_lvl - 1))
	cycle_time = maxf(0.25, cycle_time)

	var worker_count: int = int(b_state.get("workers", 0))
	var speed_bonus: float = 1.0 + float(worker_count) * 0.2
	if b_state.get("tap_boost_timer", 0.0) > 0.0:
		speed_bonus *= float(economy_config.get("tap", {}).get("boost_multiplier", 1.2))

	return cycle_time / speed_bonus

func recalculate_income() -> void:
	var total_income: BigNumber = BigNumber.zero()
	for b_id in owned_businesses:
		var b_state: Dictionary = owned_businesses[b_id]
		if b_state.get("is_automated", false):
			var rev := calculate_cycle_revenue(b_id)
			var cycle_time := calculate_cycle_time(b_id)
			if cycle_time > 0.0:
				var rate: BigNumber = rev.div(cycle_time)
				total_income = total_income.add(rate)

	income_per_second = total_income
	income_changed.emit(income_per_second)

func calculate_offline_earnings(simulated_seconds: float = 3600.0) -> Dictionary:
	var offline_cfg: Dictionary = economy_config.get("offline", {})
	var cap_sec: float = float(offline_cfg.get("base_cap_seconds", 7200.0))
	var rate: float = float(offline_cfg.get("rate", 0.5))

	var elapsed: float = minf(simulated_seconds, cap_sec)
	# Earned = income_per_second * elapsed * rate
	# If manual or zero rate, give a friendly baseline so offline screen is satisfying to test
	var effective_rate := income_per_second
	if effective_rate.is_zero():
		# Baseline from Chai Stall cycle
		effective_rate = calculate_cycle_revenue("chai_stall").div(calculate_cycle_time("chai_stall"))

	var earned := effective_rate.mul(elapsed * rate)
	last_offline_calculation = {
		"elapsed_seconds": elapsed,
		"capped": simulated_seconds > cap_sec,
		"earned": earned,
		"breakdown": {
			"Chai Stall": earned
		}
	}
	return last_offline_calculation

func claim_offline_earnings(double_with_ad: bool = false) -> BigNumber:
	if last_offline_calculation.is_empty():
		calculate_offline_earnings()

	var earned: BigNumber = last_offline_calculation.get("earned", BigNumber.zero())
	if double_with_ad:
		earned = earned.mul(2.0)

	cash = cash.add(earned)
	cash_changed.emit(cash)
	last_offline_calculation.clear()
	return earned
