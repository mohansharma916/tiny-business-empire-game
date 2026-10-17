class_name LockedHintModal
extends Control

signal closed
signal open_unlock_requested(business_id: String)

var _business_id: String = ""
var _is_unlockable_now: bool = false

@onready var title_label: Label = $SafeContainer/PanelRoot/VBox/Header/TitleLabel
@onready var close_btn: Button = $SafeContainer/PanelRoot/VBox/Header/CloseButton
@onready var desc_label: Label = $SafeContainer/PanelRoot/VBox/DescLabel
@onready var req_container: VBoxContainer = $SafeContainer/PanelRoot/VBox/ReqList
@onready var action_btn: Button = $SafeContainer/PanelRoot/VBox/ActionButton

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_hint)
	action_btn.pressed.connect(_on_action_pressed)
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

func show_business_hint(b_id: String) -> void:
	_business_id = b_id
	var b_cfg: Dictionary = EconomyService.config.get_business(b_id)
	var b_name: String = b_cfg.get("name", "Business")
	title_label.text = "🔒 %s Locked" % b_name
	desc_label.text = "This commercial plot is currently locked. Complete the requirements below to unlock:"

	for child in req_container.get_children():
		child.queue_free()

	_is_unlockable_now = EconomyService.can_unlock_business(b_id)
	var reqs: Dictionary = b_cfg.get("unlock_requires", {})

	# Location check
	var loc_id: String = b_cfg.get("location", "starter_street")
	var loc_unlocked: bool = EconomyService.is_location_unlocked(loc_id)
	var loc_item := _create_req_item("Location unlocked (%s)" % loc_id, loc_unlocked)
	req_container.add_child(loc_item)

	# Owned requirements
	if reqs.has("owned"):
		for req_b_id in reqs["owned"]:
			var req_name: String = EconomyService.config.get_business(req_b_id).get("name", req_b_id)
			var state: Dictionary = EconomyService.get_business_state(req_b_id)
			var is_owned: bool = state.get("owned", false)
			var item := _create_req_item("Own %s" % req_name, is_owned)
			req_container.add_child(item)

	# Cost requirement
	var cost: BigNumber = EconomyService.get_business_cost(b_id)
	var can_afford: bool = EconomyService.can_afford(cost)
	var cost_item := _create_req_item("Unlock Cost: %s" % UserSettings.format_cash(cost), can_afford)
	req_container.add_child(cost_item)

	if _is_unlockable_now:
		action_btn.text = "OPEN UNLOCK SCREEN"
		action_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	else:
		action_btn.text = "CLOSE"
		action_btn.remove_theme_color_override("font_color")

	visible = true

func show_location_hint(loc_id: String) -> void:
	_business_id = ""
	_is_unlockable_now = false
	var loc_progress: Dictionary = EconomyService.get_location_progress(loc_id)
	var loc_name: String = "Market Lane" if loc_id == "market_lane" else loc_id.capitalize()

	title_label.text = "🔒 %s Locked" % loc_name
	desc_label.text = "Expand your empire to access this new neighborhood:"

	for child in req_container.get_children():
		child.queue_free()

	var reqs: Dictionary = loc_progress.get("requirements", {})

	if reqs.has("businesses_owned"):
		var cur_b: int = int(reqs["businesses_owned"].get("current", 0))
		var req_b: int = int(reqs["businesses_owned"].get("required", 0))
		var met_b: bool = cur_b >= req_b
		var item := _create_req_item("Own %d businesses (Progress: %d/%d)" % [req_b, cur_b, req_b], met_b)
		req_container.add_child(item)

	if reqs.has("lifetime_earnings"):
		var cur_e: BigNumber = reqs["lifetime_earnings"].get("current", BigNumber.zero())
		var req_e: BigNumber = reqs["lifetime_earnings"].get("required", BigNumber.zero())
		var met_e: bool = cur_e.is_greater_equal(req_e)
		var item := _create_req_item("Lifetime earnings: %s (Progress: %s)" % [
			UserSettings.format_cash(req_e),
			UserSettings.format_cash(cur_e)
		], met_e)
		req_container.add_child(item)

	action_btn.text = "CLOSE"
	visible = true

func _create_req_item(text: String, is_met: bool) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	var icon := Label.new()
	icon.text = "✓ " if is_met else "✗ "
	icon.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4) if is_met else Color(1.0, 0.4, 0.4))
	icon.add_theme_font_size_override("font_size", 16)
	hbox.add_child(icon)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9) if is_met else Color(0.7, 0.7, 0.75))
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	return hbox

func close_hint() -> void:
	visible = false
	closed.emit()

func _on_action_pressed() -> void:
	if _is_unlockable_now and not _business_id.is_empty():
		var b := _business_id
		close_hint()
		open_unlock_requested.emit(b)
	else:
		close_hint()
