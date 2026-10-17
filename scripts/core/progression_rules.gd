class_name ProgressionRules
extends RefCounted

# Data-driven unlock and synergy rules (PRD section 6). Pure functions over
# config and business states (id -> {owned, levels, ...}), shared by
# EconomyService and tools/sim. Unknown requirement keys never pass, so a
# config typo can't unlock content by accident.


## A business's level is the sum of its upgrade-track levels.
static func business_level(state: Dictionary) -> int:
	var total: int = 0
	for level: int in state.get("levels", {}).values():
		total += level
	return total


## Ids of synergies whose businesses are all owned at min_level_each or more.
static func active_synergies(config: GameConfig, states: Dictionary) -> Array[String]:
	var active: Array[String] = []
	for synergy: Dictionary in config.synergies:
		var met: bool = true
		for business_id: String in synergy["requires"]:
			var state: Dictionary = states.get(business_id, {})
			if not state.get("owned", false) or business_level(state) < int(synergy["min_level_each"]):
				met = false
				break
		if met:
			active.append(str(synergy["id"]))
	return active


## Product of the income multipliers of active synergies that apply to the business.
static func synergy_multiplier(config: GameConfig, business_id: String, active: Array[String]) -> float:
	var multiplier: float = 1.0
	for synergy: Dictionary in config.synergies:
		if active.has(str(synergy["id"])) and business_id in synergy["applies_to"]:
			multiplier *= float(synergy["income_multiplier"])
	return multiplier


static func location_requirements_met(location: Dictionary, businesses_owned: int,
		lifetime_earnings: BigNumber) -> bool:
	var requires: Dictionary = location.get("unlock_requires", {})
	for key: String in requires:
		match key:
			"businesses_owned":
				if businesses_owned < int(requires[key]):
					return false
			"lifetime_earnings":
				if lifetime_earnings.is_less_than(BigNumber.from_float(float(requires[key]))):
					return false
			_:
				push_warning("ProgressionRules: unknown location requirement '%s'" % key)
				return false
	return true


## Everything except cash: the business's own location is unlocked and
## its unlock_requires ("owned" businesses, "location") are met.
static func business_requirements_met(business: Dictionary, states: Dictionary,
		unlocked_locations: Dictionary) -> bool:
	if business.has("location") and not unlocked_locations.has(business["location"]):
		return false
	var requires: Dictionary = business.get("unlock_requires", {})
	for key: String in requires:
		match key:
			"owned":
				for owned_id: String in requires[key]:
					if not states.get(owned_id, {}).get("owned", false):
						return false
			"location":
				if not unlocked_locations.has(requires[key]):
					return false
			_:
				push_warning("ProgressionRules: unknown business requirement '%s'" % key)
				return false
	return true
