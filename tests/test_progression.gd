extends GutTest

# Fixture: chai_stall (owned) and cart (1,000, needs chai) on "street";
# "lane" unlocks at 2 businesses owned + 5,000 lifetime earnings and holds
# bakery (2,000) and cafe (3,000, needs bakery). Synergy "combo": chai + cart,
# each level 3+, ×1.5 on both. Each business earns 5/s at level 0.

const EPSILON: float = 1e-6

var svc: Node


func before_each() -> void:
	svc = EconomyFixture.service(self)


func _give_cash(amount: float) -> void:
	svc._cash = BigNumber.from_float(amount)


## Earned cash counts towards lifetime earnings, unlike _give_cash().
func _earn(amount: float) -> void:
	svc._earn(BigNumber.from_float(amount))


func _set_level(business_id: String, track: String, level: int) -> void:
	svc._businesses[business_id]["levels"][track] = level
	svc.recalculate_income()


func _rate(business_id: String) -> float:
	return svc.get_business_state(business_id)["income_per_second"].to_float()


# --- Synergies ---------------------------------------------------------------------

func test_synergy_inactive_until_both_owned() -> void:
	_set_level("chai_stall", "quality", 5)
	assert_true(svc.get_active_synergies().is_empty())


func test_synergy_activates_when_every_business_reaches_min_level() -> void:
	_give_cash(1000.0)
	svc.buy_business("cart")
	_set_level("chai_stall", "marketing", 3)
	watch_signals(svc)
	_set_level("cart", "marketing", 2)
	assert_true(svc.get_active_synergies().is_empty(), "cart is level 2 of 3")
	_set_level("cart", "marketing", 3)
	assert_eq(svc.get_active_synergies(), ["combo"] as Array[String])
	assert_signal_emitted_with_parameters(svc, "synergy_activated", ["combo"])
	_set_level("cart", "marketing", 4)
	assert_signal_emit_count(svc, "synergy_activated", 1, "announced once")


func test_business_level_sums_tracks() -> void:
	_set_level("chai_stall", "quality", 2)
	_set_level("chai_stall", "equipment", 1)
	assert_eq(svc.get_business_level("chai_stall"), 3)
	assert_eq(svc.get_business_state("chai_stall")["level"], 3)


func test_synergy_multiplies_income_of_its_businesses_only() -> void:
	_give_cash(1000.0)
	svc.buy_business("cart")
	# Marketing raises demand, but capacity 1 caps customers, so the rate stays 5/s.
	_set_level("chai_stall", "marketing", 3)
	_set_level("cart", "marketing", 3)
	assert_almost_eq(_rate("chai_stall"), 7.5, EPSILON, "5 × 1.5")
	assert_almost_eq(_rate("cart"), 7.5, EPSILON)


func test_synergy_counts_in_offline_rates() -> void:
	_give_cash(1000.0 + 500.0)
	svc.buy_business("cart")
	svc.hire_staff("chai_stall", "manager")
	_set_level("chai_stall", "marketing", 3)
	_set_level("cart", "marketing", 3)
	assert_almost_eq(svc.get_offline_rates()["chai_stall"].to_float(), 7.5, EPSILON)


# --- Managers on any business --------------------------------------------------------

func test_manager_automates_any_owned_business() -> void:
	_give_cash(1000.0 + 500.0)
	svc.buy_business("cart")
	watch_signals(svc)
	assert_true(svc.hire_staff("cart", "manager"))
	assert_signal_emitted_with_parameters(svc, "business_automated", ["cart"])
	assert_true(svc.get_business_state("cart")["automated"])
	assert_false(svc.get_business_state("chai_stall")["automated"])
	assert_almost_eq(svc.get_income_per_second().to_float(), 5.0, EPSILON, "only the cart earns passively")
	svc.advance(4.0)
	assert_almost_eq(svc.get_cash().to_float(), 20.0, EPSILON)


func test_staff_needs_an_owned_business() -> void:
	_give_cash(1e6)
	assert_false(svc.hire_staff("cart", "manager"))
	assert_false(svc.hire_staff("cart", "worker"))


func test_manual_cycles_run_per_business() -> void:
	_give_cash(1000.0)
	svc.buy_business("cart")
	assert_true(svc.tap_business("chai_stall"))
	assert_true(svc.tap_business("cart"), "each business has its own cycle")
	svc.advance(2.0)
	assert_almost_eq(svc.get_cash().to_float(), 20.0, EPSILON)


# --- Location unlock rules --------------------------------------------------------------

func test_second_location_starts_locked() -> void:
	assert_true(svc.is_location_unlocked("street"))
	assert_false(svc.is_location_unlocked("lane"))
	assert_false(svc.can_unlock_business("bakery"))
	_give_cash(1e6)
	assert_false(svc.buy_business("bakery"))


func test_location_needs_both_conditions() -> void:
	_earn(10000.0)
	assert_false(svc.is_location_unlocked("lane"), "earnings met, but only 1 business owned")
	svc = EconomyFixture.service(self)
	_give_cash(1000.0)
	svc.buy_business("cart")
	assert_false(svc.is_location_unlocked("lane"), "2 owned, but no lifetime earnings yet")


func test_location_unlocks_on_earning_and_emits_once() -> void:
	_give_cash(1000.0)
	svc.buy_business("cart")
	watch_signals(svc)
	_earn(4999.0)
	assert_false(svc.is_location_unlocked("lane"))
	_earn(1.0)
	assert_true(svc.is_location_unlocked("lane"))
	assert_signal_emitted_with_parameters(svc, "location_unlocked", ["lane"])
	_earn(1000.0)
	assert_signal_emit_count(svc, "location_unlocked", 1)


func test_location_unlocks_on_purchase_when_earnings_came_first() -> void:
	_earn(6000.0)
	watch_signals(svc)
	svc.buy_business("cart")
	assert_true(svc.is_location_unlocked("lane"))
	assert_signal_emitted_with_parameters(svc, "location_unlocked", ["lane"])


func test_spending_does_not_relock() -> void:
	_earn(6000.0)
	svc.buy_business("cart")
	_give_cash(0.0)
	assert_true(svc.is_location_unlocked("lane"), "lifetime earnings, not cash")


func test_unlocked_location_opens_its_businesses_in_order() -> void:
	_earn(6000.0)
	svc.buy_business("cart")
	assert_true(svc.can_unlock_business("bakery"))
	assert_false(svc.can_unlock_business("cafe"), "needs bakery")
	_give_cash(5000.0)
	assert_true(svc.buy_business("bakery"))
	assert_true(svc.buy_business("cafe"))


func test_location_progress_for_hints() -> void:
	_earn(1234.0)
	var progress: Dictionary = svc.get_location_progress("lane")
	assert_false(progress["unlocked"])
	assert_eq(progress["requirements"]["businesses_owned"], {"current": 1, "required": 2})
	assert_almost_eq(progress["requirements"]["lifetime_earnings"]["current"].to_float(), 1234.0, EPSILON)
	assert_almost_eq(progress["requirements"]["lifetime_earnings"]["required"].to_float(), 5000.0, EPSILON)
	assert_true(svc.get_location_progress("nowhere").is_empty())


func test_unknown_requirement_never_passes() -> void:
	var location := {"id": "x", "unlock_requires": {"vip_pass": 1}}
	assert_false(ProgressionRules.location_requirements_met(location, 99, BigNumber.new(1.0, 99)))
	assert_push_warning("unknown location requirement 'vip_pass'")
