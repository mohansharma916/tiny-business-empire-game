class_name TutorialOverlay
extends Control

signal tutorial_step_changed(step: int)
signal tutorial_completed

var current_step: int = 1
var is_active: bool = false
var strings: Dictionary = {}

@onready var prompt_box: PanelContainer = $SafeContainer/PromptBox
@onready var title_label: Label = $SafeContainer/PromptBox/VBox/Header/TitleLabel
@onready var desc_label: Label = $SafeContainer/PromptBox/VBox/DescLabel
@onready var skip_btn: Button = $SafeContainer/PromptBox/VBox/Header/SkipButton
@onready var next_btn: Button = $SafeContainer/PromptBox/VBox/NextButton
@onready var highlight_pointer: Control = $HighlightPointer

func _ready() -> void:
	visible = false
	_load_strings()
	skip_btn.pressed.connect(skip_tutorial)
	next_btn.pressed.connect(_on_next_pressed)

func _load_strings() -> void:
	var path := "res://config/strings_onboarding.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			strings = json.data.get("tutorial", {})

func start_tutorial() -> void:
	current_step = 1
	is_active = true
	visible = true
	_apply_step(current_step)

func skip_tutorial() -> void:
	is_active = false
	visible = false
	tutorial_completed.emit()

func advance_to_step(step: int) -> void:
	if not is_active:
		return
	if step > 3:
		complete_tutorial()
		return
	current_step = step
	_apply_step(current_step)

func _apply_step(step: int) -> void:
	match step:
		1:
			title_label.text = strings.get("step_1_title", "Welcome to Starter Street!")
			desc_label.text = strings.get("step_1_desc", "Press and hold the Chai Stall to brew fresh tea for your first customer.")
			next_btn.visible = false # Advances automatically on serve!
			highlight_pointer.position = Vector2(250, 610)
			highlight_pointer.visible = true
		2:
			title_label.text = strings.get("step_2_title", "First Sale!")
			desc_label.text = strings.get("step_2_desc", "You earned cash! Tap 'UPGRADE CHAI STALL' at the bottom to improve equipment.")
			next_btn.visible = false # Advances on opening panel!
			highlight_pointer.position = Vector2(360, 1180)
			highlight_pointer.visible = true
		3:
			title_label.text = strings.get("step_3_title", "Grow Your Empire")
			desc_label.text = strings.get("step_3_desc", "Level up your stall tracks or hire a manager to automate tea production!")
			next_btn.text = "Got It! ✓"
			next_btn.visible = true
			highlight_pointer.visible = false

	tutorial_step_changed.emit(step)

func _on_next_pressed() -> void:
	if current_step == 3:
		complete_tutorial()
	else:
		advance_to_step(current_step + 1)

func complete_tutorial() -> void:
	is_active = false
	visible = false
	tutorial_completed.emit()
