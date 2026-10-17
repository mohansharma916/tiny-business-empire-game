class_name BusinessUnlockScreen
extends Control

signal closed
signal unlocked(business_id: String)

var current_business_id: String = ""
var _is_open: bool = false

@onready var close_btn: Button = $SafeContainer/PanelRoot/VBox/Header/CloseButton
@onready var title_label: Label = $SafeContainer/PanelRoot/VBox/Header/TitleLabel
@onready var preview_sprite: TextureRect = $SafeContainer/PanelRoot/VBox/PreviewCard/PreviewTexture
@onready var tier_label: Label = $SafeContainer/PanelRoot/VBox/PreviewCard/TierBadge/Label
@onready var cost_label: Label = $SafeContainer/PanelRoot/VBox/StatsCard/HBox/CostLabel
@onready var expected_income_label: Label = $SafeContainer/PanelRoot/VBox/StatsCard/HBox/IncomeLabel
@onready var req_container: VBoxContainer = $SafeContainer/PanelRoot/VBox/ReqCard/ReqContainer
@onready var unlock_btn: Button = $SafeContainer/PanelRoot/VBox/UnlockButton

var textures: Dictionary = {
	"chai_stall": preload("res://assets/placeholder/chai_stall_level1.png"),
	"pani_puri_cart": preload("res://assets/placeholder/pani_puri_cart.png"),
	"fruit_stand": preload("res://assets/placeholder/fruit_stand.png"),
	"bakery": preload("res://assets/placeholder/bakery.png"),
	"cafe": preload("res://assets/placeholder/cafe.png")
}

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_screen)
	unlock_btn.pressed.connect(_on_unlock_pressed)
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

func open_for_business(b_id: String) -> void:
	current_business_id = b_id
	_is_open = true
	visible = true
	refresh()

func close_screen() -> void:
	_is_open = false
	visible = false
	closed.emit()

func refresh() -> void:
	if not _is_open or not EconomyService.config:
		return

	var b_cfg: Dictionary = EconomyService.config.get_business(current_business_id)
	if b_cfg.is_empty():
		return

	title_label.text = "UNLOCK %s" % str(b_cfg.get("name", "BUSINESS")).to_upper()
	tier_label.text = "Tier %d" % int(b_cfg.get("tier", 1))

	if textures.has(current_business_id):
		preview_sprite.texture = textures[current_business_id]

	var cost: BigNumber = EconomyService.get_business_cost(current_business_id)
	cost_label.text = UserSettings.format_cash(cost)

	var base_rev: float = float(b_cfg.get("base_revenue_per_customer", 1.0))
	var base_cycle: float = float(b_cfg.get("base_cycle_seconds", 2.0))
	var base_rate: float = base_rev / maxf(0.1, base_cycle)
	expected_income_label.text = "Expected: ~₹ %.1f / s" % base_rate

	# Requirements
	for child in req_container.get_children():
		child.queue_free()

	var reqs_met: bool = EconomyService.can_unlock_business(current_business_id)
	var can_afford: bool = EconomyService.can_afford(cost)

	var req_label := Label.new()
	req_label.add_theme_font_size_override("font_size", 14)
	if reqs_met:
		req_label.text = "✓ Location and prerequisites met"
		req_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	else:
		var reqs: Dictionary = b_cfg.get("unlock_requires", {})
		var missing: String = "Requires: "
		if reqs.has("owned"):
			var names: Array[String] = []
			for o_id: String in reqs["owned"]:
				names.append(EconomyService.config.get_business(o_id).get("name", o_id))
			missing += "Own " + ", ".join(names)
		if reqs.has("location"):
			missing += "Location: " + reqs["location"]
		req_label.text = "✗ " + missing
		req_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	req_container.add_child(req_label)

	unlock_btn.text = "UNLOCK FOR %s" % UserSettings.format_cash(cost)
	unlock_btn.disabled = not (reqs_met and can_afford)

func _on_unlock_pressed() -> void:
	if EconomyService.buy_business(current_business_id):
		var b_id := current_business_id
		close_screen()
		unlocked.emit(b_id)
