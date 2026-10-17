class_name SaveScheduler
extends RefCounted

# Decides when to save (AGENTS.md section 4): after a purchase or claim,
# debounced to once per debounce_seconds, and every autosave_seconds.
# Pure timing logic on a monotonic clock passed in by the caller, so the
# economy tick can drive it and tests can step it.

var debounce_seconds: float
var autosave_seconds: float

var _dirty: bool = false
var _last_save: float = 0.0


func _init(debounce: float, autosave: float, now: float) -> void:
	debounce_seconds = debounce
	autosave_seconds = autosave
	_last_save = now


static func from_config(config: GameConfig, now: float) -> SaveScheduler:
	var save: Dictionary = config.economy["save"]
	return SaveScheduler.new(float(save["debounce_seconds"]), float(save["autosave_seconds"]), now)


func mark_dirty() -> void:
	_dirty = true


func is_due(now: float) -> bool:
	var since: float = now - _last_save
	return (_dirty and since >= debounce_seconds) or since >= autosave_seconds


func mark_saved(now: float) -> void:
	_dirty = false
	_last_save = now
