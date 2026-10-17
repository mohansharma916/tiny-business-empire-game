class_name EmpireOverviewScreen
extends Control

signal closed

var _is_open: bool = false

@onready var close_btn: Button = $SafeContainer/PanelRoot/VBox/Header/CloseButton
@onready var businesses_owned_label: Label = $SafeContainer/PanelRoot/VBox/StatsGrid/BusinessesCard/ValLabel
@onready var income_rate_label: Label = $SafeContainer/PanelRoot/VBox/StatsGrid/IncomeCard/ValLabel
@onready var lifetime_label: Label = $SafeContainer/PanelRoot/VBox/StatsGrid/LifetimeCard/ValLabel
@onready var city_level_label: Label = $SafeContainer/PanelRoot/VBox/StatsGrid/CityLevelCard/ValLabel
@onready var expansion_desc: Label = $SafeContainer/PanelRoot/VBox/ExpansionCard/VBox/DescLabel

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
	refresh_stats()

func close_screen() -> void:
	_is_open = false
	visible = false
	closed.emit()

func refresh_stats() -> void:
	if not EconomyService:
		return

	var owned_count: int = EconomyService.owned_businesses.size()
	businesses_owned_label.text = "%d / 5" % owned_count

	var inc := EconomyService.get_income_per_second()
	income_rate_label.text = "₹ %s / s" % inc.to_formatted(false)

	# Cash + spent estimate for lifetime
	var cash := EconomyService.get_cash()
	lifetime_label.text = "₹ %s" % cash.to_formatted(false)

	city_level_label.text = "Starter Street (Lv. 1)"

	expansion_desc.text = "Own 3 businesses and earn ₹ 50K lifetime cash to expand into Market Lane."
