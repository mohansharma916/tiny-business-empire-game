class_name IncomeModel
extends RefCounted

# Pure economy math (PRD section 5). No state: callers pass config and a
# business state dictionary. EconomyService, offline earnings and tools/sim
# all use these functions, so online and offline income can never diverge.
#
# Income/s = min(Demand, Capacity) × Revenue per customer / Cycle time × Multipliers

## Above this, powers are computed in log space to stay clear of float overflow.
const FLOAT_SAFE_LIMIT: float = 1e300


## Seconds per serving cycle after equipment upgrades and worker speed.
static func cycle_seconds(config: GameConfig, business: Dictionary, state: Dictionary) -> float:
	var effect: Dictionary = config.get_track("equipment").get("effect", {})
	var level: int = _level(state, "equipment")
	var cycle: float = float(business["base_cycle_seconds"]) * pow(float(effect["cycle_time_multiplier_per_level"]), level)
	cycle = maxf(cycle, float(effect["min_cycle_seconds"]))
	return cycle / worker_speed_multiplier(config, state)


static func customers_per_cycle(config: GameConfig, business: Dictionary, state: Dictionary) -> float:
	var capacity: float = float(business["base_capacity"]) \
		+ _level(state, "capacity") * float(config.get_track("capacity")["effect"]["capacity_added_per_level"])
	var demand: float = float(business["base_demand"]) \
		+ _level(state, "marketing") * float(config.get_track("marketing")["effect"]["demand_added_per_level"])
	return minf(demand, capacity)


static func revenue_per_customer(config: GameConfig, business: Dictionary, state: Dictionary) -> BigNumber:
	var per_level: float = float(config.get_track("quality")["effect"]["revenue_multiplier_per_level"])
	return power_product(float(business["base_revenue_per_customer"]), per_level, _level(state, "quality"))


## ×2 (config) for every 25 levels (config) on each track, stacking across tracks.
static func milestone_multiplier(config: GameConfig, state: Dictionary) -> BigNumber:
	var every: int = int(config.get_economy_value("milestones", "every_n_levels"))
	var factor: float = float(config.get_economy_value("milestones", "multiplier"))
	var milestones: int = 0
	for track: String in config.get_track_names():
		milestones += _level(state, track) / every
	return power_product(1.0, factor, milestones)


static func worker_speed_multiplier(config: GameConfig, state: Dictionary) -> float:
	return 1.0 + int(state.get("workers", 0)) * float(config.get_staff("worker")["speed_bonus_per_level"])


## Revenue of one completed cycle; a manual tap pays exactly this.
static func cycle_revenue(config: GameConfig, business: Dictionary, state: Dictionary) -> BigNumber:
	return revenue_per_customer(config, business, state) \
		.multiply_scalar(customers_per_cycle(config, business, state)) \
		.multiply(milestone_multiplier(config, state))


## Steady-state income of one business, without temporary boosts.
static func income_per_second(config: GameConfig, business: Dictionary, state: Dictionary) -> BigNumber:
	return cycle_revenue(config, business, state).multiply_scalar(1.0 / cycle_seconds(config, business, state))


# --- Pricing: Cost(n) = base × r^n -------------------------------------------

## Price of the single level after `level` levels are owned.
static func level_cost(base_cost: float, growth: float, level: int) -> BigNumber:
	return power_product(base_cost, growth, level)


## Total for `count` levels starting at `level`, closed form:
## base × r^n × (r^k − 1) / (r − 1). No loop, so ×Max stays O(1).
static func bulk_cost(base_cost: float, growth: float, level: int, count: int) -> BigNumber:
	if count <= 0:
		return BigNumber.zero()
	var r_to_k: float = pow(growth, count)
	if r_to_k < FLOAT_SAFE_LIMIT:
		return level_cost(base_cost, growth, level).multiply_scalar((r_to_k - 1.0) / (growth - 1.0))
	# r^k − 1 = r^k × (1 − r^−k), in log space so huge k can't overflow.
	var log_geometric: float = count * _log10(growth) + _log10(1.0 - pow(growth, -count)) - _log10(growth - 1.0)
	return level_cost(base_cost, growth, level).multiply(BigNumber.from_log10(log_geometric))


## Largest k with bulk_cost(k) <= cash: k = floor(log_r(cash × (r − 1) / Cost(n) + 1)).
static func max_affordable(base_cost: float, growth: float, level: int, cash: BigNumber) -> int:
	if cash.is_negative() or cash.is_zero():
		return 0
	var ratio: BigNumber = cash.divide(level_cost(base_cost, growth, level)).multiply_scalar(growth - 1.0)
	var log_ratio_plus_one: float = ratio.log10() if ratio.exponent > 15 else _log10(ratio.to_float() + 1.0)
	var count: int = maxi(int(floorf(log_ratio_plus_one / _log10(growth))), 0)
	# The float estimate can be one off at exact boundaries; settle it exactly.
	if bulk_cost(base_cost, growth, level, count).is_less_than(cash) \
			and bulk_cost(base_cost, growth, level, count + 1).compare(cash) <= 0:
		count += 1
	while count > 0 and bulk_cost(base_cost, growth, level, count).is_greater_than(cash):
		count -= 1
	return count


static func upgrade_base_cost(business: Dictionary, track: String) -> float:
	return float(business.get("upgrade_base_costs", {}).get(track, 0.0))


static func upgrade_growth(config: GameConfig, track: String) -> float:
	return float(config.get_track(track).get("growth", 1.0))


static func worker_cost(config: GameConfig, business: Dictionary, workers_owned: int) -> BigNumber:
	var growth: float = float(config.get_staff("worker")["level_cost_growth"])
	return level_cost(float(business["staff"]["worker_cost"]), growth, workers_owned)


## base × factor^n. Plain float math while it fits (exact for small costs
## like 100, so labels don't floor 99.999… to 99); log space beyond that.
static func power_product(base: float, factor: float, n: int) -> BigNumber:
	var value: float = base * pow(factor, n)
	if is_finite(value) and absf(value) < FLOAT_SAFE_LIMIT:
		return BigNumber.from_float(value)
	return BigNumber.from_log10(_log10(base) + n * _log10(factor))


static func _level(state: Dictionary, track: String) -> int:
	return int(state.get("levels", {}).get(track, 0))


static func _log10(value: float) -> float:
	return log(value) / log(10.0)
