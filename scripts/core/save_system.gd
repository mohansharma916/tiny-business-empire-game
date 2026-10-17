class_name SaveSystem
extends RefCounted

# Crash-safe saves (AGENTS.md section 4, PRD section 10).
# - Atomic: write <slot>.tmp, then rename over the slot. A crash leaves
#   either the old file or the new one, never half of each.
# - Two slots, used alternately, each with a SHA-256 checksum. Load picks
#   the valid slot with the highest sequence number (not the newest file
#   time, which a moved clock could fake).
# - save_version + ordered migrations. Unreadable files are set aside,
#   never deleted, so a bad load can't silently reset progress.

const DEFAULT_DIR: String = "user://saves"
const SLOT_FILE: String = "slot_%d.json"
const TEMP_SUFFIX: String = ".tmp"
const SET_ASIDE_SUFFIX: String = ".unreadable"

## MIGRATIONS[i] upgrades a payload from version i + 1 to i + 2.
## Append only; never edit a shipped step.
static var MIGRATIONS: Array[Callable] = []

var dir: String
var slot_count: int
var save_version: int
var migrations: Array[Callable]
## Files moved aside by the last load() because none of the slots was valid.
var set_aside_files: PackedStringArray = []

var _sequence: int = 0


func _init(save_dir: String = DEFAULT_DIR, slots: int = 2, version: int = 1,
		steps: Array[Callable] = MIGRATIONS) -> void:
	dir = save_dir
	slot_count = slots
	save_version = version
	migrations = steps


static func from_config(config: GameConfig, save_dir: String = DEFAULT_DIR) -> SaveSystem:
	return SaveSystem.new(save_dir, int(config.economy["save"]["slots"]),
		int(config.economy["save"]["save_version"]))


## Returns false if the file could not be written; the previous save stays intact.
func save(payload: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var sequence: int = _sequence + 1
	var body: String = JSON.stringify({
		"save_version": save_version, "sequence": sequence, "payload": payload,
	}, "", true, true)
	var text: String = JSON.stringify({"checksum": body.sha256_text(), "body": body})
	var path: String = slot_path(sequence % slot_count)
	var temp_path: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok or DirAccess.rename_absolute(temp_path, path) != OK:
		return false
	_sequence = sequence
	return true


## The newest valid payload, migrated to save_version; {} if there is none.
func load() -> Dictionary:
	set_aside_files.clear()
	var best: Dictionary = {}
	var found_files: PackedStringArray = []
	for slot in slot_count:
		var path: String = slot_path(slot)
		if not FileAccess.file_exists(path):
			continue
		found_files.append(path)
		var envelope: Dictionary = _read_envelope(path)
		if not envelope.is_empty() and int(envelope["sequence"]) > int(best.get("sequence", 0)):
			best = envelope
	if best.is_empty():
		_set_aside(found_files)
		return {}
	_sequence = int(best["sequence"])
	return best["payload"]


func slot_path(slot: int) -> String:
	return dir.path_join(SLOT_FILE % slot)


## Envelope with payload migrated, or {} if the file is damaged or unusable.
func _read_envelope(path: String) -> Dictionary:
	var outer: Variant = _parse(FileAccess.get_file_as_string(path))
	if not outer is Dictionary or not outer.get("body") is String:
		return {}
	var body: String = outer["body"]
	if body.sha256_text() != outer.get("checksum"):
		return {}
	var envelope: Variant = _parse(body)
	if not envelope is Dictionary or not envelope.get("payload") is Dictionary:
		return {}
	var payload: Variant = migrate(envelope["payload"], int(envelope.get("save_version", 0)))
	if payload == null:
		return {}
	envelope["payload"] = payload
	return envelope


## Runs the ordered steps from `from_version` up to save_version.
## Returns null for versions this build can't read (older than v1, or newer).
func migrate(payload: Dictionary, from_version: int) -> Variant:
	if from_version < 1 or from_version > save_version:
		return null
	var data: Dictionary = payload
	for version in range(from_version, save_version):
		if version - 1 >= migrations.size():
			push_error("SaveSystem: no migration from v%d" % version)
			return null
		data = migrations[version - 1].call(data)
	return data


## Damaged files are expected here; JSON.parse() reports them without logging engine errors.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


func _set_aside(paths: PackedStringArray) -> void:
	for path in paths:
		var target: String = "%s.%d%s" % [path, Time.get_unix_time_from_system(), SET_ASIDE_SUFFIX]
		if DirAccess.rename_absolute(path, target) == OK:
			set_aside_files.append(target)
			push_warning("SaveSystem: unreadable save kept at %s" % target)
