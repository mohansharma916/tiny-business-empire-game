class_name PacingSim
extends RefCounted

# Plays the real economy (EconomyService + IncomeModel, no copies of the
# formulas) with a greedy "best value" player and records when each pacing
# milestone happens and how long the player ever has to wait to afford anything.
#
# Value of an option = time until it is affordable + time for its extra
# income to pay back its cost. The player buys the option with the lowest.

const ECONOMY_SERVICE: GDScript = preload("res://scripts/core/economy_service.gd")
const NO_INCOME_WAIT: float = 1e18

var config: GameConfig
var settings: Dictionary
var economy: Node

var time: float = 0.0
## milestone id -> seconds
var milestones: Dictionary = {}
## [{time, label}] in order
var purchases: Array[Dictionary] = []
## Longest wait (s) to afford the cheapest option, and when it happened.
var worst_wait: float = 0.0
var worst_wait_at: float = 0.0
## Formatted cash and passive income when the run ended.
var final_cash: String = ""
var final_income: String = ""

var _retap_delay: float
var _active_fraction: float
var _attention_period: float
var _waiting_since: float = 0.0
var _businesses_owned: int = 0


func _init(game_config: GameConfig, sim_settings: Dictionary) -> void:
	config = game_config
	settings = sim_settings
	_retap_delay = float(settings["player"]["retap_delay_seconds"])
	_active_fraction = float(settings["player"]["active_fraction"])
	_attention_period = float(settings["player"]["attention_period_seconds"])
	economy = ECONOMY_SERVICE.new()
	economy.setup(config)
	for business_id: String in config.businesses:
		if economy.get_business_state(business_id)["owned"]:
			_businesses_owned += 1


func run() -> PacingSim:
	var tick: float = 1.0 / float(config.economy["tick_rate_hz"])
	var duration: float = float(settings["duration_seconds"])
	var decision_every: int = maxi(int(float(settings["decision_interval_seconds"]) / tick), 1)
	var step: int = 0
	while time < duration:
		_serve()
		economy.advance(tick)
		time += tick
		if not milestones.has("first_sale") and not economy.get_cash().is_zero():
			milestones["first_sale"] = time
		if step % decision_every == 0:
			_track_soft_lock()
			while _buy_best():
				pass
		step += 1
	final_cash = economy.get_cash().to_formatted()
	final_income = economy.get_income_per_second().to_formatted()
	economy.free()
	return self


## Hold-to-repeat on the best manual business, with a human reaction delay,
## during the active part of each attention period.
func _serve() -> void:
	if fmod(time, _attention_period) >= _attention_period * _active_fraction:
		return
	var target: String = _finger_business(_all_states())
	if target.is_empty() or economy.get_business_state(target)["cycle_running"]:
		return
	if _waiting_since < 0.0:
		_waiting_since = time
	if time - _waiting_since >= _retap_delay:
		economy.tap_business(target)
		_waiting_since = -1.0


## Buys the best option if it is affordable now. Returns true if it bought.
func _buy_best() -> bool:
	var states: Dictionary = _all_states()
	var income: float = _effective_income(states)
	var cash: float = economy.get_cash().to_float()
	var best: Dictionary = {}
	var best_score: float = INF
	for option: Dictionary in _options():
		var gain: float = _effective_income(_apply(states, option)) - income
		if gain <= 0.0:
			continue
		var wait: float = maxf(option["cost"] - cash, 0.0) / income if income > 0.0 else NO_INCOME_WAIT
		var score: float = wait + option["cost"] / gain
		if score < best_score:
			best_score = score
			best = option
	if best.is_empty() or best["cost"] > cash:
		return false
	return _execute(best)


func _execute(option: Dictionary) -> bool:
	var id: String = option["id"]
	var ok: bool = false
	match option["kind"]:
		"upgrade":
			ok = economy.buy_upgrade(id, option["track"], 1) > 0
			_mark("first_upgrade", ok)
		"worker":
			ok = economy.hire_staff(id, "worker")
			_mark("first_worker", ok)
		"manager":
			ok = economy.hire_staff(id, "manager")
			_mark("first_manager", ok)
		"business":
			ok = economy.buy_business(id)
			if ok:
				_businesses_owned += 1
				_mark("business_%d" % _businesses_owned, true)
	if ok:
		purchases.append({"time": time, "label": "%s %s %s" % [option["kind"], id, option.get("track", "")]})
	return ok


func _mark(milestone: String, happened: bool) -> void:
	if happened and not milestones.has(milestone):
		milestones[milestone] = time


## No-soft-lock rule: time to afford the cheapest option on current income.
## Idle income = passive income once anything is automated; before that the
## player's active (tapping) income, since nothing earns idle yet.
func _track_soft_lock() -> void:
	var states: Dictionary = _all_states()
	var passive: float = _passive_income(states)
	var income: float = passive if passive > 0.0 else _effective_income(states)
	var cheapest: float = INF
	for option: Dictionary in _options():
		cheapest = minf(cheapest, option["cost"])
	if cheapest == INF or income <= 0.0:
		return
	var wait: float = maxf(cheapest - economy.get_cash().to_float(), 0.0) / income
	if wait > worst_wait:
		worst_wait = wait
		worst_wait_at = time


# --- Options and income -------------------------------------------------------

func _options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for id: String in config.businesses:
		var state: Dictionary = economy.get_business_state(id)
		if not state["owned"]:
			if economy.can_unlock_business(id):
				options.append({"kind": "business", "id": id, "cost": economy.get_business_cost(id).to_float()})
			continue
		for track: String in config.get_track_names():
			options.append({"kind": "upgrade", "id": id, "track": track,
				"cost": economy.get_upgrade_cost(id, track, 1).to_float()})
		for role: String in ["worker", "manager"]:
			var cost: BigNumber = economy.get_staff_cost(id, role)
			if not cost.is_zero():
				options.append({"kind": role, "id": id, "cost": cost.to_float()})
	return options


func _all_states() -> Dictionary:
	var states: Dictionary = {}
	for id: String in config.businesses:
		states[id] = economy.get_business_state(id)
	return states


## States after buying `option`, for valuing it without touching the economy.
func _apply(states: Dictionary, option: Dictionary) -> Dictionary:
	var result: Dictionary = states.duplicate()
	var state: Dictionary = states[option["id"]].duplicate(true)
	match option["kind"]:
		"upgrade":
			state["levels"][option["track"]] += 1
		"worker":
			state["workers"] += 1
		"manager":
			state["has_manager"] = true
		"business":
			state["owned"] = true
	result[option["id"]] = state
	return result


func _passive_income(states: Dictionary) -> float:
	var total: float = 0.0
	for id: String in states:
		if states[id]["owned"] and states[id]["has_manager"]:
			total += _rate(id, states[id])
	return total


## Passive income plus the one manual business under the player's finger.
func _effective_income(states: Dictionary) -> float:
	var finger: String = _finger_business(states)
	var manual: float = _manual_rate(finger, states[finger]) if not finger.is_empty() else 0.0
	return _passive_income(states) + manual


func _finger_business(states: Dictionary) -> String:
	var best: String = ""
	var best_rate: float = 0.0
	for id: String in states:
		if states[id]["owned"] and not states[id]["has_manager"]:
			var rate: float = _manual_rate(id, states[id])
			if rate > best_rate:
				best_rate = rate
				best = id
	return best


## A manual business only earns while tapped: rate × attention × cycle / (cycle + reaction).
func _manual_rate(id: String, state: Dictionary) -> float:
	var cycle: float = IncomeModel.cycle_seconds(config, config.get_business(id), state)
	return _rate(id, state) * _active_fraction * cycle / (cycle + _retap_delay)


func _rate(id: String, state: Dictionary) -> float:
	return IncomeModel.income_per_second(config, config.get_business(id), state).to_float()
