extends Control

# Shows the title while the first real screen loads in the background,
# so cold start never shows a blank frame. Stays on the title if the
# city scene isn't in this build yet (e.g. on main before ui/* merges).

const NEXT_SCENE: String = "res://scenes/main_city.tscn"

@onready var _title: Label = %Title

var _loading: bool = false


func _ready() -> void:
	_title.text = str(ProjectSettings.get_setting("application/config/name"))
	if ResourceLoader.exists(NEXT_SCENE):
		_loading = ResourceLoader.load_threaded_request(NEXT_SCENE) == OK
	set_process(_loading)


func _process(_delta: float) -> void:
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(NEXT_SCENE)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	set_process(false)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed: PackedScene = ResourceLoader.load_threaded_get(NEXT_SCENE) as PackedScene
		get_tree().change_scene_to_packed(packed)
