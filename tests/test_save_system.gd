extends GutTest

const DIR: String = "user://test_saves"

var saves: SaveSystem


func before_each() -> void:
	EconomyFixture.remove_dir(DIR)
	saves = SaveSystem.new(DIR, 2, 1)


func after_all() -> void:
	EconomyFixture.remove_dir(DIR)


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_round_trip() -> void:
	assert_true(saves.save({"cash": {"m": 1.5, "e": 3}}))
	var loaded := SaveSystem.new(DIR, 2, 1).load()
	assert_eq(loaded["cash"]["m"], 1.5)
	assert_eq(int(loaded["cash"]["e"]), 3)


func test_full_float_precision_survives() -> void:
	var value: float = 1.2345678901234567
	saves.save({"v": value})
	assert_eq(SaveSystem.new(DIR, 2, 1).load()["v"], value)


func test_slots_alternate_and_newest_wins() -> void:
	saves.save({"n": 1})
	saves.save({"n": 2})
	saves.save({"n": 3})
	assert_true(FileAccess.file_exists(saves.slot_path(0)))
	assert_true(FileAccess.file_exists(saves.slot_path(1)))
	assert_eq(int(SaveSystem.new(DIR, 2, 1).load()["n"]), 3)


func test_no_save_loads_empty() -> void:
	assert_true(saves.load().is_empty())
	assert_true(saves.set_aside_files.is_empty())


# --- Crash mid-save ----------------------------------------------------------

func test_crash_before_rename_keeps_previous_save() -> void:
	saves.save({"n": 1})
	# The next save targets slot 0; the app dies while the temp file is half written.
	_write_raw(saves.slot_path(0) + SaveSystem.TEMP_SUFFIX, '{"checksum": "ab", "bo')
	var reloaded := SaveSystem.new(DIR, 2, 1)
	assert_eq(int(reloaded.load()["n"]), 1)
	assert_true(reloaded.save({"n": 2}), "a later save replaces the stale temp file")
	assert_eq(int(SaveSystem.new(DIR, 2, 1).load()["n"]), 2)


func test_truncated_slot_falls_back_to_other_slot() -> void:
	saves.save({"n": 1})
	saves.save({"n": 2})
	var newest: String = saves.slot_path(0)
	var text := FileAccess.get_file_as_string(newest)
	_write_raw(newest, text.substr(0, text.length() / 2))
	assert_eq(int(SaveSystem.new(DIR, 2, 1).load()["n"]), 1)


func test_save_after_fallback_overwrites_the_damaged_slot() -> void:
	saves.save({"n": 1})
	saves.save({"n": 2})
	_write_raw(saves.slot_path(0), "garbage")
	var reloaded := SaveSystem.new(DIR, 2, 1)
	reloaded.load()
	reloaded.save({"n": 3})
	assert_true(SaveSystem.new(DIR, 2, 1).load()["n"] == 3)
	assert_eq(int(JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(1)))["body"])["payload"]["n"]), 1,
		"the good backup slot was not overwritten")


# --- Corrupted slot ------------------------------------------------------------

func test_checksum_mismatch_rejects_slot() -> void:
	saves.save({"cash": 10})
	saves.save({"cash": 20})
	var path: String = saves.slot_path(0)
	_write_raw(path, FileAccess.get_file_as_string(path).replace("20", "99"))
	assert_eq(int(SaveSystem.new(DIR, 2, 1).load()["cash"]), 10)


func test_both_slots_corrupt_sets_files_aside_instead_of_deleting() -> void:
	saves.save({"n": 1})
	saves.save({"n": 2})
	_write_raw(saves.slot_path(0), "garbage")
	_write_raw(saves.slot_path(1), "{}")
	var reloaded := SaveSystem.new(DIR, 2, 1)
	assert_true(reloaded.load().is_empty())
	assert_eq(reloaded.set_aside_files.size(), 2)
	for path in reloaded.set_aside_files:
		assert_true(FileAccess.file_exists(path), path)
	assert_false(FileAccess.file_exists(saves.slot_path(0)))


func test_newer_save_version_is_not_loaded() -> void:
	SaveSystem.new(DIR, 2, 2, [func(d: Dictionary) -> Dictionary: return d]).save({"n": 1})
	assert_true(SaveSystem.new(DIR, 2, 1).load().is_empty())


# --- Migrations ------------------------------------------------------------------

func test_migrations_run_in_order() -> void:
	saves.save({"cash": 5})
	var steps: Array[Callable] = [
		func(d: Dictionary) -> Dictionary:
			d["gems"] = 0
			return d,
		func(d: Dictionary) -> Dictionary:
			d["money"] = d["cash"]
			d.erase("cash")
			d["gems_seen"] = d.has("gems")
			return d,
	]
	var loaded := SaveSystem.new(DIR, 2, 3, steps).load()
	assert_eq(int(loaded["money"]), 5)
	assert_false(loaded.has("cash"))
	assert_true(loaded["gems_seen"], "v1→v2 ran before v2→v3")


func test_missing_migration_step_refuses_to_load() -> void:
	saves.save({"n": 1})
	assert_true(SaveSystem.new(DIR, 2, 2, []).load().is_empty())
	assert_push_error("no migration from v1")


# --- Scheduler ---------------------------------------------------------------------

func test_scheduler_debounces_purchases() -> void:
	var scheduler := SaveScheduler.new(2.0, 30.0, 0.0)
	assert_false(scheduler.is_due(1.0), "nothing to save yet")
	scheduler.mark_dirty()
	assert_false(scheduler.is_due(1.9))
	assert_true(scheduler.is_due(2.0))
	scheduler.mark_saved(2.0)
	scheduler.mark_dirty()
	assert_false(scheduler.is_due(3.0), "at most once per 2 s")
	assert_true(scheduler.is_due(4.0))


func test_scheduler_autosaves_every_30_seconds() -> void:
	var scheduler := SaveScheduler.new(2.0, 30.0, 0.0)
	assert_false(scheduler.is_due(29.9))
	assert_true(scheduler.is_due(30.0))


func test_shipped_v1_to_v2_migration_adds_locations() -> void:
	saves.save({"cash": {"m": 1.0, "e": 0}})
	var loaded := SaveSystem.new(DIR, 2, 2).load()
	assert_eq(loaded["unlocked_locations"], [])
