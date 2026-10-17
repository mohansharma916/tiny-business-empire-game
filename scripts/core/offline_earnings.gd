class_name OfflineEarnings
extends RefCounted

# Earnings while the app was closed (PRD section 5). Uses the same per-business
# rates as the online tick (IncomeModel via EconomyService), times the capped
# time away, times the offline rate. No second income formula.


## rates: business id -> BigNumber income/s of each automated business.
## Returns {seconds_away, credited_seconds, clock_rolled_back,
##          total (BigNumber), per_business {id: BigNumber}}.
static func compute(config: GameConfig, rates: Dictionary, last_seen_unix: int,
		now_unix: int, cap_seconds: int) -> Dictionary:
	var seconds_away: int = now_unix - last_seen_unix
	# Clock moved backwards: grant nothing for the gap; the caller re-anchors.
	var rolled_back: bool = seconds_away < 0
	var credited: int = 0 if rolled_back else mini(seconds_away, cap_seconds)
	var factor: float = credited * float(config.economy["offline"]["rate"])
	var total: BigNumber = BigNumber.zero()
	var per_business: Dictionary = {}
	for business_id: String in rates:
		var earned: BigNumber = rates[business_id].multiply_scalar(factor)
		if earned.is_zero():
			continue
		per_business[business_id] = earned
		total = total.add(earned)
	return {
		"seconds_away": maxi(seconds_away, 0),
		"credited_seconds": credited,
		"clock_rolled_back": rolled_back,
		"total": total,
		"per_business": per_business,
	}


static func cap_seconds(config: GameConfig) -> int:
	# TODO(P0 content): offline-cap upgrades raise this towards offline.max_cap_seconds.
	return int(config.economy["offline"]["base_cap_seconds"])
