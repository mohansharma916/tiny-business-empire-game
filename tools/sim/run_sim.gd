extends SceneTree

# Usage:
#   godot --headless -s res://tools/sim/run_sim.gd
#   godot --headless -s res://tools/sim/run_sim.gd -- --config=/abs/path/to/config --log
# Exits with 1 if an economy-driven milestone misses its target or the
# no-soft-lock rule is broken, so it can gate CI later.

const SETTINGS_PATH: String = "res://tools/sim/sim_settings.json"


func _initialize() -> void:
	var args: Dictionary = _parse_args()
	var config := GameConfig.load_from_dir(args.get("config", GameConfig.DEFAULT_DIR))
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	var started: int = Time.get_ticks_msec()
	var sim := PacingSim.new(config, settings).run()
	var passed: bool = _report(sim, config, settings)
	if args.has("log"):
		print("\nPurchases:")
		for purchase: Dictionary in sim.purchases:
			print("  %s  %s" % [_clock(purchase["time"]), purchase["label"]])
	print("\n(simulated %s in %d ms)" % [_clock(sim.time), Time.get_ticks_msec() - started])
	quit(0 if passed else 1)


func _report(sim: PacingSim, config: GameConfig, settings: Dictionary) -> bool:
	var tolerance: float = float(settings["tolerance"])
	var passed: bool = true
	print("Pacing vs docs/PRD.md section 4 (tolerance ±%d%%)\n" % int(tolerance * 100))
	print("%-34s %8s %8s  %s" % ["Milestone", "Target", "Sim", "Result"])
	for target: Dictionary in settings["targets"]:
		var goal: float = float(target["seconds"])
		var result: String
		var reached: String = "never"
		if sim.milestones.has(target["id"]):
			var actual: float = sim.milestones[target["id"]]
			reached = _clock(actual)
			var off: float = (actual - goal) / goal
			result = "%+d%%" % roundi(off * 100.0)
			if not target["economy_driven"]:
				result += "  (tutorial-driven, informational)"
			elif absf(off) > tolerance:
				result += "  MISS"
				passed = false
			else:
				result += "  ok"
		else:
			result = "MISS" if target["economy_driven"] else "(informational)"
			passed = passed and not target["economy_driven"]
		print("%-34s %8s %8s  %s" % [target["label"], _clock(goal), reached, result])
	print("\nFull progression (no PRD targets):")
	for row: Dictionary in settings.get("timeline", []):
		var reached: String = _clock(sim.milestones[row["id"]]) if sim.milestones.has(row["id"]) else "never"
		print("%-34s %8s %8s" % [row["label"], "", reached])
	print("%-34s %8s %8s" % ["Run ended", "", _clock(sim.time)])
	var limit: float = float(config.economy[settings["soft_lock_max_seconds_key"]])
	var soft_lock_ok: bool = sim.worst_wait <= limit
	passed = passed and soft_lock_ok
	print("\nNo-soft-lock: longest wait to afford anything %s at %s (limit %s)  %s" % [
		_clock(sim.worst_wait), _clock(sim.worst_wait_at), _clock(limit), "ok" if soft_lock_ok else "FAIL"])
	print("Cash at end: %s, income %s/s" % [sim.final_cash, sim.final_income])
	return passed


static func _clock(seconds: float) -> String:
	var total: int = roundi(seconds)
	return "%d:%02d" % [total / 60, total % 60]


static func _parse_args() -> Dictionary:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true
	return args
