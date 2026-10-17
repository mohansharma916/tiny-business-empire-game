class_name UserSettings
extends RefCounted

# Persistent user settings: number format, battery saver (30/60 fps), audio toggles.
# Static methods and signals so any UI script can read format preferences without circular deps.

signal settings_changed

static var _instance: UserSettings

static var use_indian_format: bool = false
static var battery_saver_30fps: bool = false
static var sfx_enabled: bool = true
static var music_enabled: bool = true
static var haptics_enabled: bool = true

const SAVE_PATH: String = "user://user_settings.json"

static func get_instance() -> UserSettings:
	if not _instance:
		_instance = UserSettings.new()
		_instance.load_settings()
	return _instance

static func format_cash(amount: BigNumber) -> String:
	get_instance()
	return "₹ %s" % amount.to_formatted(use_indian_format)

static func format_rate(amount: BigNumber) -> String:
	get_instance()
	return "+₹ %s / s" % amount.to_formatted(use_indian_format)

static func set_battery_saver(enabled: bool) -> void:
	battery_saver_30fps = enabled
	Engine.max_fps = 30 if enabled else 60
	get_instance().save_settings()
	get_instance().settings_changed.emit()

static func set_indian_format(enabled: bool) -> void:
	use_indian_format = enabled
	get_instance().save_settings()
	get_instance().settings_changed.emit()

static func set_sfx(enabled: bool) -> void:
	sfx_enabled = enabled
	get_instance().save_settings()
	get_instance().settings_changed.emit()

static func set_music(enabled: bool) -> void:
	music_enabled = enabled
	get_instance().save_settings()
	get_instance().settings_changed.emit()

static func set_haptics(enabled: bool) -> void:
	haptics_enabled = enabled
	get_instance().save_settings()
	get_instance().settings_changed.emit()

func save_settings() -> void:
	var data: Dictionary = {
		"use_indian_format": use_indian_format,
		"battery_saver_30fps": battery_saver_30fps,
		"sfx_enabled": sfx_enabled,
		"music_enabled": music_enabled,
		"haptics_enabled": haptics_enabled
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var content: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var d: Dictionary = json.data
		use_indian_format = bool(d.get("use_indian_format", false))
		battery_saver_30fps = bool(d.get("battery_saver_30fps", false))
		sfx_enabled = bool(d.get("sfx_enabled", true))
		music_enabled = bool(d.get("music_enabled", true))
		haptics_enabled = bool(d.get("haptics_enabled", true))
		Engine.max_fps = 30 if battery_saver_30fps else 60
