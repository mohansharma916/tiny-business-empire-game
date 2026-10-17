class_name AppLifecycle
extends RefCounted

# Reacts to OS lifecycle events (docs/MOBILE.md section 5).
# Not a Node, so scripts/core keeps a single autoload: EconomyService
# forwards its _notification() here. SceneTree propagates these
# notifications to every node, so an autoload always receives them.

## The UI closes its top panel, or asks before exiting on the city screen.
## project.godot has quit_on_go_back=false, so nothing quits on its own.
signal back_requested
## The UI frees cached panels and textures that are not on screen.
signal memory_warning
## The UI pauses animations and audio (call, notification shade).
signal focus_lost
signal focus_gained

## EconomyService (untyped: autoload scripts have no class_name). Null in tests of this class alone.
var _economy: Node


func _init(economy: Node = null) -> void:
	_economy = economy


func handle_notification(what: int) -> void:
	match what:
		Node.NOTIFICATION_APPLICATION_PAUSED:
			_on_paused()
		Node.NOTIFICATION_APPLICATION_RESUMED:
			_on_resumed()
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT:
			focus_lost.emit()
		Node.NOTIFICATION_APPLICATION_FOCUS_IN:
			focus_gained.emit()
		Node.NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()
		Node.NOTIFICATION_OS_MEMORY_WARNING:
			_on_memory_warning()


## Stop earning, then save at once: the OS may kill a backgrounded app
## without warning. Time away is credited by offline earnings on resume.
func _on_paused() -> void:
	if _economy:
		_economy.stop_tick()
		_economy.save_now()
	# TODO(P1): submit the leaderboard score through backend_client.gd.


func _on_resumed() -> void:
	if _economy:
		_economy.check_offline_earnings()
		_economy.start_tick()


func _on_memory_warning() -> void:
	memory_warning.emit()
