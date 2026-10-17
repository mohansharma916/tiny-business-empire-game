class_name EconomyPersistence
extends RefCounted

# Connects EconomyService to the save system and offline earnings, so the
# service itself stays about economy rules.
#
# Offline flow: on launch/resume, compute earnings since last_seen, add them
# to `pending`, re-anchor last_seen to now, and save at once, so a kill
# before the claim neither loses nor repeats them. claim() writes a save
# that already contains the granted cash and no pending claim, and only
# then changes cash in memory: the claim is recorded before it is granted.

var save_system: SaveSystem
var scheduler: SaveScheduler
## Wall clock in unix seconds; replaced in tests.
var wall_clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
## Monotonic seconds for save timing; replaced in tests.
var monotonic_clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _economy: Node
var _last_seen_unix: int = 0
## {total, seconds_away, credited_seconds, per_business} with BigNumbers as dicts; {} if none.
var _pending: Dictionary = {}


func _init(economy: Node, saves: SaveSystem) -> void:
	_economy = economy
	save_system = saves
	scheduler = SaveScheduler.from_config(economy.config, monotonic_clock.call())


## Loads the newest valid save into the economy (if any), then checks offline earnings.
func load_game() -> void:
	var data: Dictionary = save_system.load()
	_last_seen_unix = wall_clock.call()
	if data.is_empty():
		save_now()
		return
	_restore(data)
	_last_seen_unix = int(data.get("last_seen_unix", _last_seen_unix))
	_pending = data.get("pending_offline", {})
	check_offline_earnings()


func on_tick() -> void:
	var now: float = monotonic_clock.call()
	if scheduler.is_due(now):
		save_now()


func mark_dirty() -> void:
	scheduler.mark_dirty()


## Saves with last_seen = now. Called on pause, autosave and debounced purchases.
func save_now() -> bool:
	_last_seen_unix = wall_clock.call()
	return _write(_snapshot())


## Adds earnings since last_seen to the pending claim. Returns the pending summary.
func check_offline_earnings() -> Dictionary:
	var now: int = wall_clock.call()
	var report: Dictionary = OfflineEarnings.compute(_economy.config, _economy.get_offline_rates(),
		_last_seen_unix, now, OfflineEarnings.cap_seconds(_economy.config))
	if not report["total"].is_zero():
		_add_to_pending(report)
	# Always re-anchor, including after a clock rollback, so the gap is never credited.
	save_now()
	return get_pending()


## Pending summary with BigNumbers: {total, seconds_away, credited_seconds, per_business}; {} if none.
func get_pending() -> Dictionary:
	if _pending.is_empty():
		return {}
	var per_business: Dictionary = {}
	for business_id: String in _pending["per_business"]:
		per_business[business_id] = BigNumber.from_dict(_pending["per_business"][business_id])
	return {
		"total": BigNumber.from_dict(_pending["total"]),
		"seconds_away": int(_pending["seconds_away"]),
		"credited_seconds": int(_pending["credited_seconds"]),
		"per_business": per_business,
	}


## Returns the amount granted; zero if nothing is pending or the save failed.
func claim() -> BigNumber:
	if _pending.is_empty():
		return BigNumber.zero()
	var amount: BigNumber = BigNumber.from_dict(_pending["total"])
	var claimed: Dictionary = _pending
	_pending = {}
	var data: Dictionary = _snapshot()
	data["cash"] = BigNumber.from_dict(data["cash"]).add(amount).to_dict()
	data["lifetime_earnings"] = BigNumber.from_dict(data["lifetime_earnings"]).add(amount).to_dict()
	if not _write(data):
		_pending = claimed
		return BigNumber.zero()
	_economy.grant_claimed(amount)
	return amount


## Save payload v1: config_version, cash, lifetime_earnings, businesses
## {id: {owned, levels, workers, has_manager}}, last_seen_unix, pending_offline.
## Cycle progress and tap boosts are moment-to-moment and not saved.
func _snapshot() -> Dictionary:
	var businesses: Dictionary = {}
	for business_id: String in _economy.config.businesses:
		var state: Dictionary = _economy.get_business_state(business_id)
		businesses[business_id] = {
			"owned": state["owned"], "levels": state["levels"],
			"workers": state["workers"], "has_manager": state["has_manager"],
		}
	return {
		"config_version": int(_economy.config.economy["config_version"]),
		"cash": _economy.get_cash().to_dict(),
		"lifetime_earnings": _economy.get_lifetime_earnings().to_dict(),
		"businesses": businesses,
	}


## JSON turns ints into floats; convert back and skip anything config no longer has.
func _restore(data: Dictionary) -> void:
	var config: GameConfig = _economy.config
	var businesses: Dictionary = {}
	for business_id: String in data.get("businesses", {}):
		if config.get_business(business_id).is_empty():
			push_warning("EconomyPersistence: saved business %s is not in config" % business_id)
			continue
		var saved: Dictionary = data["businesses"][business_id]
		var levels: Dictionary = {}
		for track: String in saved.get("levels", {}):
			if not config.get_track(track).is_empty():
				levels[track] = int(saved["levels"][track])
		businesses[business_id] = {
			"owned": bool(saved.get("owned", false)), "levels": levels,
			"workers": int(saved.get("workers", 0)), "has_manager": bool(saved.get("has_manager", false)),
		}
	_economy.restore_state(BigNumber.from_dict(data.get("cash", {})),
		BigNumber.from_dict(data.get("lifetime_earnings", {})), businesses)


func _write(data: Dictionary) -> bool:
	data["last_seen_unix"] = _last_seen_unix
	data["pending_offline"] = _pending
	var ok: bool = save_system.save(data)
	if ok:
		scheduler.mark_saved(monotonic_clock.call())
	return ok


func _add_to_pending(report: Dictionary) -> void:
	var previous: Dictionary = get_pending()
	var total: BigNumber = report["total"]
	var per_business: Dictionary = {}
	for business_id: String in report["per_business"]:
		var earned: BigNumber = report["per_business"][business_id]
		if previous.get("per_business", {}).has(business_id):
			earned = earned.add(previous["per_business"][business_id])
		per_business[business_id] = earned.to_dict()
	for business_id: String in previous.get("per_business", {}):
		if not per_business.has(business_id):
			per_business[business_id] = previous["per_business"][business_id].to_dict()
	if not previous.is_empty():
		total = total.add(previous["total"])
	_pending = {
		"total": total.to_dict(),
		"seconds_away": int(report["seconds_away"]) + int(previous.get("seconds_away", 0)),
		"credited_seconds": int(report["credited_seconds"]) + int(previous.get("credited_seconds", 0)),
		"per_business": per_business,
	}
