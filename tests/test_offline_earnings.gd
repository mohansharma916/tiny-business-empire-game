extends GutTest

# Fixture: an automated chai stall earns 5/s; offline cap 2 h, rate 50%.

const DIR: String = "user://test_offline_saves"
const CHAI: String = "chai_stall"
const HOUR: int = 3600
const EPSILON: float = 1e-6

var clock: EconomyFixture.FakeClock


func before_each() -> void:
	EconomyFixture.remove_dir(DIR)
	clock = EconomyFixture.FakeClock.new()


func after_all() -> void:
	EconomyFixture.remove_dir(DIR)


func _automated_service() -> Node:
	var svc: Node = EconomyFixture.service_with_saves(self, DIR, clock)
	svc._cash = BigNumber.from_float(500.0)
	svc.hire_staff(CHAI, "manager")
	svc.save_now()
	return svc


## Simulates the app being killed and started again `seconds` later.
func _relaunch_after(seconds: int) -> Node:
	clock.now += seconds
	return EconomyFixture.service_with_saves(self, DIR, clock)


func _pending_total(svc: Node) -> float:
	var pending: Dictionary = svc.get_pending_offline_earnings()
	return 0.0 if pending.is_empty() else pending["total"].to_float()


func test_offline_uses_online_rate_at_half_rate() -> void:
	_automated_service()
	var svc := _relaunch_after(HOUR)
	assert_almost_eq(_pending_total(svc), 5.0 * HOUR * 0.5, EPSILON)
	assert_eq(svc.get_pending_offline_earnings()["seconds_away"], HOUR)


func test_offline_is_capped_at_two_hours() -> void:
	_automated_service()
	var svc := _relaunch_after(5 * HOUR)
	assert_almost_eq(_pending_total(svc), 5.0 * 2 * HOUR * 0.5, EPSILON)
	assert_eq(svc.get_pending_offline_earnings()["credited_seconds"], 2 * HOUR)


func test_manual_business_earns_nothing_offline() -> void:
	EconomyFixture.service_with_saves(self, DIR, clock)
	var svc := _relaunch_after(HOUR)
	assert_true(svc.get_pending_offline_earnings().is_empty())


func test_offline_matches_online_integration() -> void:
	var online: Node = _automated_service()
	var cash_before: float = online.get_cash().to_float()
	online.advance(600.0)
	var online_earned: float = online.get_cash().to_float() - cash_before
	EconomyFixture.remove_dir(DIR)
	_automated_service()
	var offline := _relaunch_after(600)
	assert_almost_eq(_pending_total(offline), online_earned * 0.5, EPSILON, "same function, × offline rate")


# --- Claims ------------------------------------------------------------------------

func test_claim_grants_once() -> void:
	_automated_service()
	var svc := _relaunch_after(HOUR)
	var cash_before: float = svc.get_cash().to_float()
	assert_almost_eq(svc.claim_offline_earnings().to_float(), 9000.0, EPSILON)
	assert_almost_eq(svc.get_cash().to_float(), cash_before + 9000.0, EPSILON)
	assert_true(svc.claim_offline_earnings().is_zero(), "double claim gives nothing")
	assert_almost_eq(svc.get_cash().to_float(), cash_before + 9000.0, EPSILON)


func test_claim_is_recorded_in_the_save_before_cash_is_granted() -> void:
	_automated_service()
	var svc := _relaunch_after(HOUR)
	var cash_after_claim: float = svc.get_cash().to_float() + svc.claim_offline_earnings().to_float()
	# Killed right after the claim: the save already has the cash and no pending claim.
	var relaunched := _relaunch_after(0)
	assert_almost_eq(relaunched.get_cash().to_float(), cash_after_claim, EPSILON)
	assert_true(relaunched.get_pending_offline_earnings().is_empty())
	assert_true(relaunched.claim_offline_earnings().is_zero())


func test_unclaimed_earnings_survive_a_relaunch_without_being_counted_twice() -> void:
	_automated_service()
	_relaunch_after(HOUR)
	var svc := _relaunch_after(0)
	assert_almost_eq(_pending_total(svc), 9000.0, EPSILON)


func test_failed_save_grants_nothing_and_keeps_the_claim() -> void:
	_automated_service()
	clock.now += HOUR
	var failing := FailingSaveSystem.new(DIR, 2, 1)
	var svc: Node = EconomyFixture.service_with_saves(self, DIR, clock, failing)
	var cash_before: float = svc.get_cash().to_float()
	failing.fail = true
	assert_true(svc.claim_offline_earnings().is_zero())
	assert_almost_eq(svc.get_cash().to_float(), cash_before, EPSILON)
	failing.fail = false
	assert_almost_eq(svc.claim_offline_earnings().to_float(), 9000.0, EPSILON)


# --- Clock moved backwards -------------------------------------------------------------

func test_clock_moved_back_grants_nothing() -> void:
	_automated_service()
	var svc := _relaunch_after(-HOUR)
	assert_true(svc.get_pending_offline_earnings().is_empty())


func test_clock_moved_back_re_anchors() -> void:
	_automated_service()
	_relaunch_after(-5 * HOUR)
	# Clock is set right again: only the real 1 h since the re-anchor counts,
	# not the 4 h "gap" between the rolled-back time and the old save.
	var svc := _relaunch_after(HOUR)
	assert_almost_eq(_pending_total(svc), 9000.0, EPSILON)


# --- Lifecycle wiring ------------------------------------------------------------------

func test_pause_saves_and_resume_collects_offline() -> void:
	var svc: Node = _automated_service()
	svc.lifecycle.handle_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	clock.now += HOUR
	watch_signals(svc)
	svc.lifecycle.handle_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_signal_emitted(svc, "offline_earnings_available")
	assert_almost_eq(_pending_total(svc), 9000.0, EPSILON)


func test_purchase_triggers_debounced_save() -> void:
	var svc: Node = EconomyFixture.service_with_saves(self, DIR, clock)
	svc._cash = BigNumber.from_float(1000.0)
	clock.monotonic = 10.0
	svc.buy_upgrade(CHAI, "quality")
	svc.persistence.on_tick()
	var reloaded := _relaunch_after(0)
	assert_eq(reloaded.get_business_state(CHAI)["levels"]["quality"], 1)


class FailingSaveSystem:
	extends SaveSystem
	var fail: bool = false

	func save(payload: Dictionary) -> bool:
		return false if fail else super.save(payload)


func test_unlocked_locations_survive_a_relaunch() -> void:
	var svc: Node = EconomyFixture.service_with_saves(self, DIR, clock)
	svc._cash = BigNumber.from_float(1000.0)
	svc.buy_business("cart")
	svc._earn(BigNumber.from_float(6000.0))
	svc.save_now()
	assert_true(_relaunch_after(0).is_location_unlocked("lane"))
