extends GutTest

const EPSILON: float = 1e-6
const CHAI: String = "chai_stall"

var svc: Node


func before_each() -> void:
	svc = EconomyFixture.service(self)


func _give_cash(amount: float) -> void:
	svc._cash = BigNumber.from_float(amount)


func _rate() -> float:
	return svc.get_business_state(CHAI)["income_per_second"].to_float()


func _set_levels(levels: Dictionary) -> void:
	for track: String in levels:
		svc._businesses[CHAI]["levels"][track] = levels[track]
	svc.recalculate_income()


# --- Income per second -------------------------------------------------------

func test_starting_state() -> void:
	var state: Dictionary = svc.get_business_state(CHAI)
	assert_true(state["owned"])
	assert_false(state["automated"])
	assert_false(svc.get_business_state("cart")["owned"])
	assert_true(svc.get_cash().is_zero())
	assert_true(svc.get_business_state("nope").is_empty())


func test_base_income_per_second() -> void:
	# min(demand 2, capacity 1) × 10 / 2 s
	assert_almost_eq(_rate(), 5.0, EPSILON)


func test_manual_business_adds_nothing_to_passive_income() -> void:
	assert_true(svc.get_income_per_second().is_zero())


func test_capacity_is_capped_by_demand() -> void:
	_set_levels({"capacity": 1})
	assert_almost_eq(_rate(), 10.0, EPSILON, "min(2, 2) × 10 / 2")
	_set_levels({"capacity": 3})
	assert_almost_eq(_rate(), 10.0, EPSILON, "demand-capped at 2")
	_set_levels({"marketing": 2})
	assert_almost_eq(_rate(), 20.0, EPSILON, "min(4, 4) × 10 / 2")


func test_quality_adds_revenue_linearly() -> void:
	_set_levels({"quality": 2})
	assert_almost_eq(_rate(), 10.0, EPSILON, "1 × 10 × (1 + 2 × 0.5) / 2")
	_set_levels({"quality": 4})
	assert_almost_eq(_rate(), 15.0, EPSILON, "1 × 10 × (1 + 4 × 0.5) / 2")


func test_equipment_shortens_cycle_down_to_minimum() -> void:
	_set_levels({"equipment": 1})
	assert_almost_eq(svc.get_business_state(CHAI)["cycle_seconds"], 1.0, EPSILON)
	assert_almost_eq(_rate(), 10.0, EPSILON)
	_set_levels({"equipment": 10})
	assert_almost_eq(svc.get_business_state(CHAI)["cycle_seconds"], 0.25, EPSILON)
	assert_almost_eq(_rate(), 40.0, EPSILON)


func test_milestone_doubles_income_every_25_levels() -> void:
	_set_levels({"marketing": 25})
	assert_almost_eq(_rate(), 10.0, EPSILON, "capacity-capped 5/s × 2")
	_set_levels({"marketing": 50, "capacity": 25})
	assert_almost_eq(_rate(), 26.0 * 10.0 / 2.0 * 8.0, EPSILON, "three milestones: ×8")


func test_milestone_signal_on_crossing() -> void:
	_set_levels({"marketing": 24})
	_give_cash(1e9)
	watch_signals(svc)
	svc.buy_upgrade(CHAI, "marketing", 1)
	assert_signal_emitted_with_parameters(svc, "milestone_reached", ["chai_stall:marketing:25"])
	svc.buy_upgrade(CHAI, "marketing", 1)
	assert_signal_emit_count(svc, "milestone_reached", 1)


func test_bulk_buy_across_two_milestones_emits_both() -> void:
	_set_levels({"equipment": 20})
	_give_cash(1e12)
	watch_signals(svc)
	assert_eq(svc.buy_upgrade(CHAI, "equipment", 40), 40)
	assert_signal_emit_count(svc, "milestone_reached", 2)
	assert_signal_emitted_with_parameters(svc, "milestone_reached", ["chai_stall:equipment:50"])


func test_workers_add_speed() -> void:
	_give_cash(150.0)
	assert_true(svc.hire_staff(CHAI, "worker"), "first worker costs 50")
	assert_almost_eq(_rate(), 7.5, EPSILON, "× (1 + 0.5)")
	assert_true(svc.hire_staff(CHAI, "worker"), "second worker costs 100")
	assert_true(svc.get_cash().is_zero())
	assert_false(svc.hire_staff(CHAI, "worker"), "can't afford the third")


func test_worker_max_level() -> void:
	_give_cash(1e9)
	for i in 3:
		assert_true(svc.hire_staff(CHAI, "worker"))
	assert_false(svc.hire_staff(CHAI, "worker"))
	assert_false(svc.hire_staff(CHAI, "chef"))


# --- Manual serving and automation ---------------------------------------------

func test_tap_runs_one_serving_cycle() -> void:
	assert_true(svc.tap_business(CHAI))
	assert_false(svc.tap_business(CHAI), "a cycle is already running")
	svc.advance(1.0)
	assert_almost_eq(svc.get_business_state(CHAI)["cycle_progress"], 0.5, EPSILON)
	assert_true(svc.get_cash().is_zero())
	svc.advance(1.0)
	assert_almost_eq(svc.get_cash().to_float(), 10.0, EPSILON, "one customer × 10")
	assert_false(svc.get_business_state(CHAI)["cycle_running"])
	svc.advance(10.0)
	assert_almost_eq(svc.get_cash().to_float(), 10.0, EPSILON, "no tap, no income")


func test_tap_on_unowned_business_does_nothing() -> void:
	assert_false(svc.tap_business("cart"))


func test_manager_automates_and_earns_rate_times_elapsed() -> void:
	_give_cash(500.0)
	watch_signals(svc)
	assert_true(svc.hire_staff(CHAI, "manager"))
	assert_signal_emitted_with_parameters(svc, "business_automated", [CHAI])
	assert_almost_eq(svc.get_income_per_second().to_float(), 5.0, EPSILON)
	for i in 8:
		svc.advance(0.25)
	assert_almost_eq(svc.get_cash().to_float(), 10.0, EPSILON)
	assert_false(svc.hire_staff(CHAI, "manager"), "only one manager")


func test_tap_boost_on_automated_business() -> void:
	_give_cash(500.0)
	svc.hire_staff(CHAI, "manager")
	watch_signals(svc)
	assert_true(svc.tap_business(CHAI))
	assert_almost_eq(svc.get_income_per_second().to_float(), 6.0, EPSILON, "+20%")
	svc.advance(12.0)
	assert_almost_eq(svc.get_cash().to_float(), 10.0 * 6.0 + 2.0 * 5.0, EPSILON, "boost ends mid-interval")
	assert_almost_eq(svc.get_income_per_second().to_float(), 5.0, EPSILON)
	assert_signal_emit_count(svc, "income_changed", 2)


# --- Upgrade costs: Cost(n) = base × r^n ---------------------------------------

func test_single_level_cost_grows_geometrically() -> void:
	assert_almost_eq(svc.get_upgrade_cost(CHAI, "equipment").to_float(), 100.0, EPSILON)
	_set_levels({"equipment": 3})
	assert_almost_eq(svc.get_upgrade_cost(CHAI, "equipment").to_float(), 100.0 * pow(1.1, 3), 1e-6)


func test_ten_level_cost_is_geometric_sum() -> void:
	var expected: float = 100.0 * (pow(1.1, 10) - 1.0) / 0.1
	assert_almost_eq(svc.get_upgrade_cost(CHAI, "equipment", 10).to_float(), expected, 1e-6)


func test_buy_upgrade_spends_and_emits() -> void:
	_give_cash(250.0)
	watch_signals(svc)
	assert_eq(svc.buy_upgrade(CHAI, "capacity"), 1)
	assert_almost_eq(svc.get_cash().to_float(), 150.0, EPSILON)
	assert_eq(svc.get_business_state(CHAI)["levels"]["capacity"], 1)
	assert_signal_emitted_with_parameters(svc, "upgrade_purchased", [CHAI, "capacity", 1])
	assert_signal_emitted(svc, "cash_changed")


func test_buy_upgrade_fails_without_cash() -> void:
	_give_cash(99.0)
	watch_signals(svc)
	assert_eq(svc.buy_upgrade(CHAI, "equipment"), 0)
	assert_signal_not_emitted(svc, "upgrade_purchased")
	assert_almost_eq(svc.get_cash().to_float(), 99.0, EPSILON)
	assert_eq(svc.buy_upgrade(CHAI, "teleporter"), 0)
	assert_eq(svc.buy_upgrade("cart", "equipment"), 0, "not owned")


# --- Bulk buy: closed form -------------------------------------------------------

func test_bulk_cost_matches_level_by_level_sum() -> void:
	for start in [0, 7, 40]:
		for count in [1, 2, 10, 33]:
			var looped := BigNumber.zero()
			for i in count:
				looped = looped.add(IncomeModel.level_cost(25.0, 1.12, start + i))
			var closed := IncomeModel.bulk_cost(25.0, 1.12, start, count)
			assert_almost_eq(closed.to_float() / looped.to_float(), 1.0, 1e-9, "n=%d k=%d" % [start, count])


func test_bulk_cost_zero_levels_is_free() -> void:
	assert_true(IncomeModel.bulk_cost(25.0, 1.12, 5, 0).is_zero())


func test_max_affordable_at_exact_boundary() -> void:
	var cost_of_five := IncomeModel.bulk_cost(100.0, 1.1, 3, 5)
	assert_eq(IncomeModel.max_affordable(100.0, 1.1, 3, cost_of_five), 5)
	assert_eq(IncomeModel.max_affordable(100.0, 1.1, 3, cost_of_five.multiply_scalar(0.9999)), 4)
	assert_eq(IncomeModel.max_affordable(100.0, 1.1, 3, BigNumber.from_float(99.0)), 0)
	assert_eq(IncomeModel.max_affordable(100.0, 1.1, 3, BigNumber.zero()), 0)


func test_max_affordable_beyond_float_range() -> void:
	var cash := BigNumber.new(1.0, 400)
	var count := IncomeModel.max_affordable(100.0, 1.15, 5000, cash)
	assert_gt(count, 0)
	assert_true(IncomeModel.bulk_cost(100.0, 1.15, 5000, count).compare(cash) <= 0)
	assert_true(IncomeModel.bulk_cost(100.0, 1.15, 5000, count + 1).is_greater_than(cash))


func test_buy_ten_buys_only_what_is_affordable() -> void:
	_give_cash(100.0 + 110.0 + 121.0 + 1.0)
	assert_eq(svc.buy_upgrade(CHAI, "equipment", 10), 3)
	assert_almost_eq(svc.get_cash().to_float(), 1.0, 1e-6)


func test_buy_max() -> void:
	_give_cash(1e6)
	var expected: int = IncomeModel.max_affordable(100.0, 1.1, 0, BigNumber.from_float(1e6))
	assert_eq(svc.buy_upgrade(CHAI, "equipment", svc.BULK_MAX), expected)
	assert_true(svc.get_cash().is_less_than(svc.get_upgrade_cost(CHAI, "equipment")))
	assert_false(svc.get_cash().is_negative())


# --- Businesses ---------------------------------------------------------------------

func test_buy_business_needs_cash_and_requirements() -> void:
	assert_true(svc.can_unlock_business("cart"), "requires chai_stall, which is owned")
	_give_cash(999.0)
	assert_false(svc.buy_business("cart"))
	_give_cash(1000.0)
	watch_signals(svc)
	assert_true(svc.buy_business("cart"))
	assert_signal_emitted_with_parameters(svc, "business_purchased", ["cart"])
	assert_true(svc.get_cash().is_zero())
	assert_true(svc.get_business_state("cart")["owned"])
	assert_false(svc.buy_business("cart"), "already owned")
	assert_false(svc.buy_business(CHAI), "already owned")


func test_buy_business_blocked_by_missing_requirement() -> void:
	svc._businesses[CHAI]["owned"] = false
	_give_cash(1e6)
	assert_false(svc.can_unlock_business("cart"))
	assert_false(svc.buy_business("cart"))


func test_staff_costs() -> void:
	assert_almost_eq(svc.get_staff_cost(CHAI, "worker").to_float(), 50.0, EPSILON)
	assert_almost_eq(svc.get_staff_cost(CHAI, "manager").to_float(), 500.0, EPSILON)
	_give_cash(500.0)
	svc.hire_staff(CHAI, "manager")
	assert_true(svc.get_staff_cost(CHAI, "manager").is_zero(), "already hired")
	assert_true(svc.get_staff_cost(CHAI, "chef").is_zero())
