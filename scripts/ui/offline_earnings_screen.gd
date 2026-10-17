class_name OfflineEarningsScreen
extends Control

signal closed(claimed_amount: BigNumber)

var _is_open: bool = false
var _current_earned: BigNumber = BigNumber.zero()

@onready var time_away_label: Label = $SafeContainer/PanelRoot/VBox/TimeAwayLabel
@onready var total_cash_label: Label = $SafeContainer/PanelRoot/VBox/EarningsCard/VBox/TotalCashLabel
@onready var breakdown_list: VBoxContainer = $SafeContainer/PanelRoot/VBox/BreakdownCard/Scroll/ListContainer
@onready var collect_btn: Button = $SafeContainer/PanelRoot/VBox/ButtonContainer/CollectButton
@onready var double_ad_btn: Button = $SafeContainer/PanelRoot/VBox/ButtonContainer/DoubleAdButton

func _ready() -> void:
	visible = false
	collect_btn.pressed.connect(_on_collect)
	double_ad_btn.pressed.connect(_on_double_ad)
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

func show_offline_earnings(simulated_seconds: float = 3600.0) -> void:
	if not EconomyService:
		return

	var calculation: Dictionary = EconomyService.calculate_offline_earnings(simulated_seconds)
	_current_earned = calculation.get("earned", BigNumber.zero())
	var elapsed_sec: float = float(calculation.get("elapsed_seconds", 0.0))
	var is_capped: bool = calculation.get("capped", false)

	var hours: int = int(elapsed_sec / 3600.0)
	var minutes: int = int(fmod(elapsed_sec, 3600.0) / 60.0)

	var time_text: String = "You were away for "
	if hours > 0:
		time_text += "%dh %dm" % [hours, minutes]
	else:
		time_text += "%d minutes" % maxi(1, minutes)
	if is_capped:
		time_text += " (Max 2 hr cap reached)"

	time_away_label.text = time_text
	total_cash_label.text = "₹ %s" % _current_earned.to_formatted(false)

	# Populate breakdown list
	for child in breakdown_list.get_children():
		child.queue_free()

	var breakdown: Dictionary = calculation.get("breakdown", {})
	for b_name in breakdown:
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = b_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 15)

		var val: BigNumber = breakdown[b_name]
		var val_lbl := Label.new()
		val_lbl.text = "+ ₹ %s" % val.to_formatted(false)
		val_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		val_lbl.add_theme_font_size_override("font_size", 15)

		row.add_child(name_lbl)
		row.add_child(val_lbl)
		breakdown_list.add_child(row)

	collect_btn.text = "COLLECT ₹ %s" % _current_earned.to_formatted(false)
	var double_val := _current_earned.mul(2.0)
	double_ad_btn.text = "🎬 DOUBLE REWARD (2× ₹ %s)" % double_val.to_formatted(false)

	_is_open = true
	visible = true

func _on_collect() -> void:
	if not _is_open:
		return
	var claimed := EconomyService.claim_offline_earnings(false)
	_is_open = false
	visible = false
	closed.emit(claimed)

func _on_double_ad() -> void:
	if not _is_open:
		return
	var claimed := EconomyService.claim_offline_earnings(true)
	_is_open = false
	visible = false
	closed.emit(claimed)

func close_screen() -> void:
	_on_collect()
