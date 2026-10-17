class_name EconomyFixture
extends RefCounted

# A config with round numbers so expected values can be worked out by hand.
# Tests use it instead of config/*.json, so balancing never breaks tests.

const ECONOMY_SERVICE: GDScript = preload("res://scripts/core/economy_service.gd")


static func config() -> GameConfig:
	var c := GameConfig.new()
	c.economy = {
		"config_version": 1,
		"tick_rate_hz": 4,
		"starting_cash": 0,
		"milestones": {"every_n_levels": 25, "multiplier": 2.0},
		"tap": {"boost_multiplier": 1.2, "boost_duration_seconds": 10},
		"offline": {"base_cap_seconds": 7200, "max_cap_seconds": 28800, "rate": 0.5, "ad_multiplier": 2.0},
		"save": {"autosave_seconds": 30, "debounce_seconds": 2, "slots": 2, "save_version": 1},
	}
	c.upgrades = {
		"tracks": {
			"equipment": {"growth": 1.1, "effect": {"cycle_time_multiplier_per_level": 0.5, "min_cycle_seconds": 0.25}},
			"capacity": {"growth": 1.2, "effect": {"capacity_added_per_level": 1.0}},
			"quality": {"growth": 1.15, "effect": {"revenue_bonus_per_level": 0.5}},
			"marketing": {"growth": 1.1, "effect": {"demand_added_per_level": 1.0}},
		},
		"staff": {
			"worker": {"speed_bonus_per_level": 0.5, "level_cost_growth": 2.0, "max_level": 3},
			"manager": {"automates": true},
		},
	}
	c.locations = [
		{"id": "street", "unlock_requires": {}},
		{"id": "lane", "unlock_requires": {"businesses_owned": 2, "lifetime_earnings": 5000}},
	]
	c.synergies = [
		{"id": "combo", "requires": ["chai_stall", "cart"], "min_level_each": 3,
			"income_multiplier": 1.5, "applies_to": ["chai_stall", "cart"]},
	]
	c.businesses = {
		"chai_stall": _business(0, {}, "street"),
		"cart": _business(1000, {"owned": ["chai_stall"]}, "street"),
		"bakery": _business(2000, {"location": "lane"}, "lane"),
		"cafe": _business(3000, {"owned": ["bakery"]}, "lane"),
	}
	return c


## A fresh EconomyService outside the scene tree (no timer): drive it with advance().
static func service(test: GutTest) -> Node:
	var svc: Node = test.autofree(ECONOMY_SERVICE.new())
	svc.setup(config())
	return svc


## A service with saves in `save_dir` and a controllable clock: set clock.now (unix seconds).
## Mirrors EconomyService._ready() without the scene tree or timer.
static func service_with_saves(test: GutTest, save_dir: String, clock: FakeClock,
		saves: SaveSystem = null) -> Node:
	var svc: Node = service(test)
	var save_system: SaveSystem = saves if saves else SaveSystem.from_config(svc.config, save_dir)
	svc.persistence = EconomyPersistence.new(svc, save_system)
	svc.persistence.wall_clock = func() -> int: return clock.now
	svc.persistence.monotonic_clock = func() -> float: return clock.monotonic
	svc.persistence.load_game()
	return svc


static func remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


class FakeClock:
	var now: int = 1_000_000
	var monotonic: float = 0.0


## Income 5/s at level 0: min(demand 2, capacity 1) × 10 / 2 s.
static func _business(unlock_cost: float, requires: Dictionary, location: String) -> Dictionary:
	return {
		"location": location,
		"unlock_cost": unlock_cost,
		"unlock_requires": requires,
		"base_revenue_per_customer": 10,
		"base_cycle_seconds": 2.0,
		"base_capacity": 1,
		"base_demand": 2,
		"upgrade_base_costs": {"equipment": 100, "capacity": 100, "quality": 100, "marketing": 100},
		"staff": {"worker_cost": 50, "manager_cost": 500},
	}
