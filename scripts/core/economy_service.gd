extends Node

# Autoload "EconomyService": the only economy API the UI may use
# (AGENTS.md section 2). The UI reads state and calls these methods;
# it never computes or stores money itself.
#
# Income is a cached rate, rebuilt only when something changes. The tick
# integrates rate × elapsed; manual (non-automated) businesses earn one
# cycle's revenue per completed tap instead.

signal cash_changed(cash: BigNumber)
signal income_changed(income_per_second: BigNumber)
signal business_purchased(business_id: String)
signal upgrade_purchased(business_id: String, track: String, new_level: int)
signal business_automated(business_id: String)
signal location_unlocked(location_id: String)
## milestone_id is "<business_id>:<track>:<level>", e.g. "chai_stall:quality:25".
signal milestone_reached(milestone_id: String)

## Pass as `amount` to buy_upgrade() / get_upgrade_cost() for the ×Max button.
const BULK_MAX: int = -1
const USEC_PER_SECOND: float = 1_000_000.0

var config: GameConfig
var lifecycle: AppLifecycle = AppLifecycle.new()

var _cash: BigNumber = BigNumber.zero()
var _lifetime_earnings: BigNumber = BigNumber.zero()
var _income_per_second: BigNumber = BigNumber.zero()
## business id -> {owned, levels {track: int}, workers, has_manager,
## cycle_running, cycle_elapsed, boost_seconds_left}
var _businesses: Dictionary = {}
## business id -> BigNumber, steady-state rate without boosts.
var _base_income: Dictionary = {}

var _tick_timer: Timer
var _last_tick_usec: int = 0


func _ready() -> void:
	setup(GameConfig.load_from_dir())
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0 / float(config.economy["tick_rate_hz"])
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	start_tick()


func _notification(what: int) -> void:
	lifecycle.handle_notification(what)


## Resets to a new game. Tests and tools/sim call this on an instance that
## is never added to the tree, then drive time with advance().
func setup(game_config: GameConfig) -> void:
	config = game_config
	_cash = BigNumber.from_float(float(config.economy["starting_cash"]))
	_lifetime_earnings = BigNumber.zero()
	_businesses.clear()
	for business_id: String in config.businesses:
		var business: Dictionary = config.businesses[business_id]
		var starts_owned: bool = float(business["unlock_cost"]) == 0.0 and business["unlock_requires"].is_empty()
		_businesses[business_id] = _new_business_state(starts_owned)
	recalculate_income()


func start_tick() -> void:
	_last_tick_usec = Time.get_ticks_usec()
	if _tick_timer:
		_tick_timer.start()


func stop_tick() -> void:
	if _tick_timer:
		_tick_timer.stop()


# --- Public API (final signatures) ------------------------------------------

func get_cash() -> BigNumber:
	return _cash


## Sum of every business that earns without tapping (automated), boosts included.
func get_income_per_second() -> BigNumber:
	return _income_per_second


## Snapshot copy; changing it does nothing. Keys:
## id, owned, levels {track: int}, workers, has_manager, automated,
## cycle_running, cycle_progress (0..1), cycle_seconds, boost_seconds_left,
## income_per_second (BigNumber). Empty if the id is unknown.
func get_business_state(business_id: String) -> Dictionary:
	if not _businesses.has(business_id):
		return {}
	var state: Dictionary = _businesses[business_id]
	var cycle: float = _cycle_seconds(business_id)
	var snapshot: Dictionary = state.duplicate(true)
	snapshot.erase("cycle_elapsed")
	snapshot["id"] = business_id
	snapshot["automated"] = state["has_manager"]
	snapshot["cycle_seconds"] = cycle
	snapshot["cycle_progress"] = clampf(state["cycle_elapsed"] / cycle, 0.0, 1.0) if state["cycle_running"] else 0.0
	snapshot["income_per_second"] = _boosted_income(business_id)
	return snapshot


func can_afford(cost: BigNumber) -> bool:
	return _cash.is_greater_equal(cost)


## Returns true if the business was bought (emits business_purchased).
func buy_business(business_id: String) -> bool:
	# TODO(core/content): unlock costs, unlock_requires and Market Lane.
	return false


## amount: 1, 10 or BULK_MAX. Returns how many levels were bought (0 = none).
## Buys as many as affordable up to `amount`; emits upgrade_purchased once.
func buy_upgrade(business_id: String, track: String, amount: int = 1) -> int:
	if not _is_owned(business_id) or config.get_track(track).is_empty():
		return 0
	var count: int = _affordable_count(business_id, track, amount)
	if count == 0:
		return 0
	var old_level: int = _businesses[business_id]["levels"][track]
	_spend(_bulk_cost(business_id, track, count))
	var new_level: int = old_level + count
	_businesses[business_id]["levels"][track] = new_level
	recalculate_income()
	upgrade_purchased.emit(business_id, track, new_level)
	_emit_milestones(business_id, track, old_level, new_level)
	return count


## Total cost of the next `amount` levels (BULK_MAX: as many as affordable now).
func get_upgrade_cost(business_id: String, track: String, amount: int = 1) -> BigNumber:
	if not _businesses.has(business_id) or config.get_track(track).is_empty():
		return BigNumber.zero()
	var count: int = amount
	if amount == BULK_MAX:
		count = maxi(_affordable_count(business_id, track, BULK_MAX), 1)
	return _bulk_cost(business_id, track, count)


## role: "worker" or "manager". Returns true if hired.
func hire_staff(business_id: String, role: String) -> bool:
	if not _is_owned(business_id):
		return false
	var state: Dictionary = _businesses[business_id]
	var business: Dictionary = config.get_business(business_id)
	match role:
		"worker":
			if state["workers"] >= int(config.get_staff("worker")["max_level"]):
				return false
			var cost: BigNumber = IncomeModel.worker_cost(config, business, state["workers"])
			if not can_afford(cost):
				return false
			_spend(cost)
			state["workers"] += 1
			recalculate_income()
		"manager":
			var cost: BigNumber = BigNumber.from_float(float(business["staff"]["manager_cost"]))
			if state["has_manager"] or not can_afford(cost):
				return false
			_spend(cost)
			state["has_manager"] = true
			state["cycle_running"] = false
			recalculate_income()
			business_automated.emit(business_id)
		_:
			return false
	return true


## Manual business: starts a serving cycle if none is running.
## Automated business: starts or refreshes the temporary speed boost.
## Returns true if the tap did something. Hold-to-repeat = call it every tick.
func tap_business(business_id: String) -> bool:
	if not _is_owned(business_id):
		return false
	var state: Dictionary = _businesses[business_id]
	if state["has_manager"]:
		var was_boosted: bool = state["boost_seconds_left"] > 0.0
		state["boost_seconds_left"] = float(config.get_economy_value("tap", "boost_duration_seconds"))
		if not was_boosted:
			recalculate_income()
		return true
	if state["cycle_running"]:
		return false
	state["cycle_running"] = true
	state["cycle_elapsed"] = 0.0
	return true


# --- Rate engine -------------------------------------------------------------

## Rebuilds the cached rates. Call only when something changed.
func recalculate_income() -> void:
	var total: BigNumber = BigNumber.zero()
	for business_id: String in _businesses:
		var state: Dictionary = _businesses[business_id]
		if not state["owned"]:
			_base_income[business_id] = BigNumber.zero()
			continue
		_base_income[business_id] = IncomeModel.income_per_second(config, config.get_business(business_id), state)
		if state["has_manager"]:
			total = total.add(_boosted_income(business_id))
	if not total.is_equal(_income_per_second):
		_income_per_second = total
		income_changed.emit(_income_per_second)


## Integrates `seconds` of play. The tick calls this; offline earnings use
## the same rates through IncomeModel.
func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var earned: BigNumber = BigNumber.zero()
	var boost_ended: bool = false
	var boost_bonus: float = float(config.get_economy_value("tap", "boost_multiplier")) - 1.0
	for business_id: String in _businesses:
		var state: Dictionary = _businesses[business_id]
		if not state["owned"]:
			continue
		if state["has_manager"]:
			var boosted_seconds: float = minf(seconds, state["boost_seconds_left"])
			earned = earned.add(_base_income[business_id].multiply_scalar(seconds + boost_bonus * boosted_seconds))
			if boosted_seconds > 0.0:
				state["boost_seconds_left"] -= boosted_seconds
				boost_ended = boost_ended or state["boost_seconds_left"] <= 0.0
		elif state["cycle_running"]:
			state["cycle_elapsed"] += seconds
			if state["cycle_elapsed"] >= _cycle_seconds(business_id):
				state["cycle_running"] = false
				earned = earned.add(IncomeModel.cycle_revenue(config, config.get_business(business_id), state))
	if boost_ended:
		recalculate_income()
	if not earned.is_zero():
		_earn(earned)


func _on_tick() -> void:
	var now: int = Time.get_ticks_usec()
	# Measured, not assumed: a timer can fire late on a slow frame.
	advance((now - _last_tick_usec) / USEC_PER_SECOND)
	_last_tick_usec = now


# --- Helpers -----------------------------------------------------------------

func _new_business_state(owned: bool) -> Dictionary:
	var levels: Dictionary = {}
	for track: String in config.get_track_names():
		levels[track] = 0
	return {
		"owned": owned, "levels": levels, "workers": 0, "has_manager": false,
		"cycle_running": false, "cycle_elapsed": 0.0, "boost_seconds_left": 0.0,
	}


func _is_owned(business_id: String) -> bool:
	return _businesses.has(business_id) and _businesses[business_id]["owned"]


func _cycle_seconds(business_id: String) -> float:
	return IncomeModel.cycle_seconds(config, config.get_business(business_id), _businesses[business_id])


func _boosted_income(business_id: String) -> BigNumber:
	var base: BigNumber = _base_income.get(business_id, BigNumber.zero())
	if _businesses[business_id]["boost_seconds_left"] > 0.0:
		return base.multiply_scalar(float(config.get_economy_value("tap", "boost_multiplier")))
	return base


func _affordable_count(business_id: String, track: String, amount: int) -> int:
	var business: Dictionary = config.get_business(business_id)
	var affordable: int = IncomeModel.max_affordable(IncomeModel.upgrade_base_cost(business, track),
		IncomeModel.upgrade_growth(config, track), _businesses[business_id]["levels"][track], _cash)
	return affordable if amount == BULK_MAX else mini(affordable, amount)


func _bulk_cost(business_id: String, track: String, count: int) -> BigNumber:
	return IncomeModel.bulk_cost(IncomeModel.upgrade_base_cost(config.get_business(business_id), track),
		IncomeModel.upgrade_growth(config, track), _businesses[business_id]["levels"][track], count)


func _emit_milestones(business_id: String, track: String, old_level: int, new_level: int) -> void:
	var every: int = int(config.get_economy_value("milestones", "every_n_levels"))
	for milestone in range(old_level / every + 1, new_level / every + 1):
		milestone_reached.emit("%s:%s:%d" % [business_id, track, milestone * every])


func _spend(cost: BigNumber) -> void:
	_cash = _cash.subtract(cost)
	cash_changed.emit(_cash)


func _earn(amount: BigNumber) -> void:
	_cash = _cash.add(amount)
	_lifetime_earnings = _lifetime_earnings.add(amount)
	cash_changed.emit(_cash)
