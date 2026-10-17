class_name ObjectivesScreen
extends Control

signal closed

var _is_open: bool = false

@onready var close_btn: Button = $SafeContainer/PanelRoot/VBox/Header/CloseButton
@onready var list_container: VBoxContainer = $SafeContainer/PanelRoot/VBox/Scroll/ListContainer

var objectives_data: Array[Dictionary] = [
	{
		"id": "obj_first_customer",
		"title": "First Brew",
		"desc": "Serve your first chai customer manually",
		"target": 1,
		"reward": 50.0,
		"claimed": false
	},
	{
		"id": "obj_first_upgrade",
		"title": "Better Equipment",
		"desc": "Upgrade the Chai Stall to total Level 5",
		"target": 5,
		"reward": 150.0,
		"claimed": false
	},
	{
		"id": "obj_hire_worker",
		"title": "Extra Hands",
		"desc": "Hire your first Worker for +20% speed",
		"target": 1,
		"reward": 300.0,
		"claimed": false
	},
	{
		"id": "obj_automate",
		"title": "Hands-Free Tycoon",
		"desc": "Hire a Manager to automate the Chai Stall",
		"target": 1,
		"reward": 1000.0,
		"claimed": false
	},
	{
		"id": "obj_offline",
		"title": "Rest & Reinvest",
		"desc": "Collect offline earnings while away",
		"target": 1,
		"reward": 500.0,
		"claimed": false
	}
]

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_screen)
	_apply_safe_area()

func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0 and vp_size.y > 0 and safe.size.x > 0:
		var margin_top: float = maxf(20.0, float(safe.position.y))
		var margin_bottom: float = maxf(20.0, vp_size.y - (safe.position.y + safe.size.y))
		var safe_margin: MarginContainer = $SafeContainer
		safe_margin.add_theme_constant_override("margin_top", int(margin_top))
		safe_margin.add_theme_constant_override("margin_bottom", int(margin_bottom))

func open_screen() -> void:
	_is_open = true
	visible = true
	refresh_objectives()

func close_screen() -> void:
	_is_open = false
	visible = false
	closed.emit()

func refresh_objectives() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var b_state: Dictionary = EconomyService.get_business_state("chai_stall")
	var levels: Dictionary = b_state.get("levels", {})
	var total_lvl: int = 0
	for l in levels.values():
		total_lvl += int(l)

	var workers: int = int(b_state.get("workers", 0))
	var is_auto: bool = b_state.get("automated", false)

	for obj in objectives_data:
		var card := _create_objective_card(obj, total_lvl, workers, is_auto)
		list_container.add_child(card)

func _create_objective_card(obj: Dictionary, total_lvl: int, workers: int, is_auto: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.24, 0.92)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = obj["title"]
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = obj["desc"]
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(desc)

	var current_val: int = 0
	match obj["id"]:
		"obj_first_customer": current_val = 1 if total_lvl >= 4 else 0
		"obj_first_upgrade": current_val = mini(obj["target"], total_lvl)
		"obj_hire_worker": current_val = mini(obj["target"], workers)
		"obj_automate": current_val = 1 if is_auto else 0
		"obj_offline": current_val = 1

	var prog_lbl := Label.new()
	prog_lbl.text = "Progress: %d / %d" % [current_val, int(obj["target"])]
	prog_lbl.add_theme_font_size_override("font_size", 12)
	prog_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
	vbox.add_child(prog_lbl)

	hbox.add_child(vbox)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110, 48)

	if obj["claimed"]:
		btn.text = "Claimed ✓"
		btn.disabled = true
	elif current_val >= int(obj["target"]):
		btn.text = "Claim ₹ %.0f" % float(obj["reward"])
		btn.pressed.connect(func(): _claim_objective(obj))
	else:
		btn.text = "In Progress"
		btn.disabled = true

	hbox.add_child(btn)
	card.add_child(hbox)
	return card

func _claim_objective(obj: Dictionary) -> void:
	obj["claimed"] = true
	var reward: BigNumber = BigNumber.from_float(float(obj["reward"]))
	EconomyService.grant_reward(reward)
	refresh_objectives()
