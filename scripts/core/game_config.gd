class_name GameConfig
extends RefCounted

# Every tunable number, read once from config/*.json at startup.
# Shared by EconomyService, the save system and tools/sim, so all three
# always agree on the numbers.

const DEFAULT_DIR: String = "res://config"

var economy: Dictionary = {}
var upgrades: Dictionary = {}
var synergies: Array = []
var locations: Array = []
## business id -> business config, in config order.
var businesses: Dictionary = {}


static func load_from_dir(dir: String = DEFAULT_DIR) -> GameConfig:
	var config := GameConfig.new()
	config.economy = _read_json(dir.path_join("economy.json"))
	config.upgrades = _read_json(dir.path_join("upgrades.json"))
	config.synergies = _read_json(dir.path_join("synergies.json")).get("synergies", [])
	config.locations = _read_json(dir.path_join("locations.json")).get("locations", [])
	for business: Dictionary in _read_json(dir.path_join("businesses.json")).get("businesses", []):
		config.businesses[str(business["id"])] = business
	return config


func get_business(business_id: String) -> Dictionary:
	return businesses.get(business_id, {})


func get_track(track: String) -> Dictionary:
	return upgrades.get("tracks", {}).get(track, {})


func get_track_names() -> Array:
	return upgrades.get("tracks", {}).keys()


func get_staff(role: String) -> Dictionary:
	return upgrades.get("staff", {}).get(role, {})


func get_economy_value(section: String, key: String) -> Variant:
	return economy.get(section, {}).get(key)


static func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameConfig: missing or empty %s" % path)
		return {}
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data
	push_error("GameConfig: %s is not a JSON object" % path)
	return {}
