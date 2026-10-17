class_name ProgressionState
extends RefCounted

# Which locations are unlocked and which synergies are active. Owned by
# EconomyService, which emits the public signals from what these return.

var _config: GameConfig
## location id -> true
var _unlocked_locations: Dictionary = {}
var _active_synergies: Array[String] = []


func _init(config: GameConfig) -> void:
	_config = config
	for location: Dictionary in config.locations:
		if location.get("unlock_requires", {}).is_empty():
			_unlocked_locations[str(location["id"])] = true


func is_location_unlocked(location_id: String) -> bool:
	return _unlocked_locations.has(location_id)


func get_unlocked_locations() -> Array:
	return _unlocked_locations.keys()


## Restores saved unlocks; ids no longer in config are dropped.
func restore_locations(location_ids: Array) -> void:
	for location_id: String in location_ids:
		if not location_config(location_id).is_empty():
			_unlocked_locations[location_id] = true


func business_requirements_met(business_id: String, states: Dictionary) -> bool:
	return ProgressionRules.business_requirements_met(_config.get_business(business_id), states, _unlocked_locations)


## Unlocks every location whose conditions now hold. Returns the new ids.
func unlock_due_locations(businesses_owned: int, lifetime_earnings: BigNumber) -> Array[String]:
	var unlocked: Array[String] = []
	if _unlocked_locations.size() == _config.locations.size():
		return unlocked
	for location: Dictionary in _config.locations:
		var location_id: String = location["id"]
		if not _unlocked_locations.has(location_id) \
				and ProgressionRules.location_requirements_met(location, businesses_owned, lifetime_earnings):
			_unlocked_locations[location_id] = true
			unlocked.append(location_id)
	return unlocked


func get_active_synergies() -> Array[String]:
	return _active_synergies.duplicate()


## Recomputes active synergies. Returns the ones that just became active,
## or none when `announce` is false (e.g. right after loading a save).
func refresh_synergies(states: Dictionary, announce: bool = true) -> Array[String]:
	var active: Array[String] = ProgressionRules.active_synergies(_config, states)
	var newly_active: Array[String] = []
	if announce:
		newly_active = active.filter(func(id: String) -> bool: return not _active_synergies.has(id))
	_active_synergies = active
	return newly_active


func synergy_multiplier(business_id: String) -> float:
	return ProgressionRules.synergy_multiplier(_config, business_id, _active_synergies)


## {unlocked, requirements: {businesses_owned: {current, required},
## lifetime_earnings: {current, required (BigNumber)}}}; {} if unknown.
func location_progress(location_id: String, businesses_owned: int, lifetime_earnings: BigNumber) -> Dictionary:
	var location: Dictionary = location_config(location_id)
	if location.is_empty():
		return {}
	var progress: Dictionary = {}
	var requires: Dictionary = location.get("unlock_requires", {})
	if requires.has("businesses_owned"):
		progress["businesses_owned"] = {"current": businesses_owned, "required": int(requires["businesses_owned"])}
	if requires.has("lifetime_earnings"):
		progress["lifetime_earnings"] = {"current": lifetime_earnings,
			"required": BigNumber.from_float(float(requires["lifetime_earnings"]))}
	return {"unlocked": is_location_unlocked(location_id), "requirements": progress}


func location_config(location_id: String) -> Dictionary:
	for location: Dictionary in _config.locations:
		if location["id"] == location_id:
			return location
	return {}
