class_name MainCity
extends Control

# Main City controller supporting Starter Street & Market Lane,
# visual levels for all 5 businesses, locked plot hints, and panel management.

@onready var starter_street: Node2D = $CityWorld/StarterStreet
@onready var market_lane: Node2D = $CityWorld/MarketLane
@onready var city_world: Node2D = $CityWorld

# HUD Nodes
@onready var cash_label: Label = $SafeContainer/TopHUD/VBox/StatsRow/CashCard/CashLabel
@onready var income_label: Label = $SafeContainer/TopHUD/VBox/StatsRow/IncomeCard/IncomeLabel

@onready var nav_goals_btn: Button = $SafeContainer/TopHUD/VBox/NavRow/GoalsButton
@onready var nav_empire_btn: Button = $SafeContainer/TopHUD/VBox/NavRow/EmpireButton
@onready var nav_offline_btn: Button = $SafeContainer/TopHUD/VBox/NavRow/OfflineTestButton
@onready var nav_settings_btn: Button = $SafeContainer/TopHUD/VBox/NavRow/SettingsButton

@onready var loc_starter_btn: Button = $SafeContainer/TopHUD/VBox/LocationRow/StarterStreetBtn
@onready var loc_market_btn: Button = $SafeContainer/TopHUD/VBox/LocationRow/MarketLaneBtn

@onready var details_btn: Button = $SafeContainer/BottomHUD/DetailsButton

# Panel references (instantiated once and reused)
@onready var details_panel: BusinessDetailsPanel = $Panels/BusinessDetailsPanel
@onready var offline_screen: OfflineEarningsScreen = $Panels/OfflineEarningsScreen
@onready var objectives_screen: ObjectivesScreen = $Panels/ObjectivesScreen
@onready var empire_screen: EmpireOverviewScreen = $Panels/EmpireOverviewScreen
@onready var unlock_screen: BusinessUnlockScreen = $Panels/BusinessUnlockScreen
@onready var settings_screen: SettingsScreen = $Panels/SettingsScreen
@onready var locked_hint_modal: LockedHintModal = $Panels/LockedHintModal
@onready var tutorial_overlay: TutorialOverlay = $Panels/TutorialOverlay

# Customer pool
@onready var customer_container: Node2D = $CityWorld/Customers
var customer_pool: Array[Node2D] = []
const MAX_CUSTOMERS: int = 8
var _customer_spawn_timer: float = 0.0

# Active state
var current_location: String = "starter_street"
var selected_business_id: String = "chai_stall"
var _pressing_business_id: String = ""
var _last_progress_by_business: Dictionary = {}

# Textures
var textures: Dictionary = {
	"chai_stall": {
		"1": preload("res://assets/placeholder/chai_stall_level1.png"),
		"2": preload("res://assets/placeholder/chai_stall_level2.png"),
		"3": preload("res://assets/placeholder/chai_stall_level3.png")
	},
	"pani_puri_cart": {
		"1": preload("res://assets/placeholder/pani_puri_cart_level1.png"),
		"2": preload("res://assets/placeholder/pani_puri_cart_level2.png"),
		"3": preload("res://assets/placeholder/pani_puri_cart_level3.png")
	},
	"fruit_stand": {
		"1": preload("res://assets/placeholder/fruit_stand_level1.png"),
		"2": preload("res://assets/placeholder/fruit_stand_level2.png"),
		"3": preload("res://assets/placeholder/fruit_stand_level3.png")
	},
	"bakery": {
		"1": preload("res://assets/placeholder/bakery_level1.png"),
		"2": preload("res://assets/placeholder/bakery_level2.png"),
		"3": preload("res://assets/placeholder/bakery_level3.png")
	},
	"cafe": {
		"1": preload("res://assets/placeholder/cafe_level1.png"),
		"2": preload("res://assets/placeholder/cafe_level2.png"),
		"3": preload("res://assets/placeholder/cafe_level3.png")
	}
}
var tex_customer: Texture2D = preload("res://assets/placeholder/customer_pedestrian.png")

# 4 Hz HUD update limiter
var _hud_update_accumulator: float = 0.0
const HUD_UPDATE_INTERVAL: float = 0.25

func _ready() -> void:
	_setup_customer_pool()
	_setup_panel_events()
	_setup_location_buttons()
	_setup_plot_interactions()
	_apply_safe_area()
	_scale_backgrounds_to_viewport()

	EconomyService.cash_changed.connect(func(_c): _request_hud_refresh())
	EconomyService.income_changed.connect(func(_i): _request_hud_refresh())
	EconomyService.upgrade_purchased.connect(func(_b, _t, _l): _refresh_all_plots())
	EconomyService.business_purchased.connect(func(_b): _refresh_all_plots())
	EconomyService.business_automated.connect(func(_b): _refresh_all_plots())
	EconomyService.location_unlocked.connect(func(_l): _update_location_tabs())

	UserSettings.get_instance().settings_changed.connect(_refresh_hud_now)

	_switch_location("starter_street")
	_refresh_all_plots()
	_refresh_hud_now()

	# Start onboarding tutorial on first session
	tutorial_overlay.start_tutorial()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back_button()

func _handle_android_back_button() -> void:
	if locked_hint_modal.visible:
		locked_hint_modal.close_hint()
	elif unlock_screen.visible:
		unlock_screen.close_screen()
	elif settings_screen.visible:
		settings_screen.close_screen()
	elif objectives_screen.visible:
		objectives_screen.close_screen()
	elif empire_screen.visible:
		empire_screen.close_screen()
	elif offline_screen.visible:
		offline_screen.close_screen()
	elif details_panel.visible:
		details_panel.close_panel()
	elif tutorial_overlay.visible:
		tutorial_overlay.skip_tutorial()

func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0 and vp_size.y > 0 and safe.size.x > 0:
		var margin_top: float = maxf(16.0, float(safe.position.y))
		var margin_bottom: float = maxf(16.0, vp_size.y - (safe.position.y + safe.size.y))
		var safe_margin: MarginContainer = $SafeContainer
		safe_margin.add_theme_constant_override("margin_top", int(margin_top))
		safe_margin.add_theme_constant_override("margin_bottom", int(margin_bottom))

func _scale_backgrounds_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var s: float = maxf(vp_size.x / 768.0, vp_size.y / 1376.0)
	var bg_starter := starter_street.get_node_or_null("Background") as Sprite2D
	var bg_market := market_lane.get_node_or_null("Background") as Sprite2D
	if bg_starter:
		bg_starter.scale = Vector2(s, s)
		bg_starter.position = vp_size / 2.0
	if bg_market:
		bg_market.scale = Vector2(s, s)
		bg_market.position = vp_size / 2.0

func _setup_panel_events() -> void:
	details_btn.pressed.connect(open_selected_business_details)
	nav_goals_btn.pressed.connect(open_objectives)
	nav_empire_btn.pressed.connect(open_empire_overview)
	nav_offline_btn.pressed.connect(open_offline_earnings)
	nav_settings_btn.pressed.connect(open_settings)

	details_panel.closed.connect(_on_panel_closed)
	offline_screen.closed.connect(func(_a): _on_panel_closed())
	objectives_screen.closed.connect(_on_panel_closed)
	empire_screen.closed.connect(_on_panel_closed)
	unlock_screen.closed.connect(_on_panel_closed)
	settings_screen.closed.connect(_on_panel_closed)
	locked_hint_modal.closed.connect(_on_panel_closed)

	unlock_screen.unlocked.connect(func(b_id: String):
		_refresh_all_plots()
		_select_business(b_id)
	)
	locked_hint_modal.open_unlock_requested.connect(func(b_id: String):
		open_business_unlock(b_id)
	)

func _setup_location_buttons() -> void:
	loc_starter_btn.pressed.connect(func(): _switch_location("starter_street"))
	loc_market_btn.pressed.connect(func():
		if EconomyService.is_location_unlocked("market_lane"):
			_switch_location("market_lane")
		else:
			_pause_city(true)
			locked_hint_modal.show_location_hint("market_lane")
	)
	_update_location_tabs()

func _update_location_tabs() -> void:
	var market_unlocked: bool = EconomyService.is_location_unlocked("market_lane")
	loc_starter_btn.flat = (current_location != "starter_street")
	loc_market_btn.flat = (current_location != "market_lane")
	loc_market_btn.text = "📍 Market Lane" if market_unlocked else "📍 Market Lane 🔒"

func _switch_location(loc_id: String) -> void:
	current_location = loc_id
	starter_street.visible = (loc_id == "starter_street")
	market_lane.visible = (loc_id == "market_lane")
	_update_location_tabs()

	# Select first owned business in this location
	var target_b_id: String = "chai_stall" if loc_id == "starter_street" else "bakery"
	var state: Dictionary = EconomyService.get_business_state(target_b_id)
	if state.get("owned", false):
		_select_business(target_b_id)

func _setup_plot_interactions() -> void:
	var plot_ids: Array[String] = ["chai_stall", "pani_puri_cart", "fruit_stand", "bakery", "cafe"]
	for b_id in plot_ids:
		var plot_node := _find_plot_node(b_id)
		if not plot_node:
			continue
		var btn: Button = plot_node.get_node("TapHitbox")
		btn.button_down.connect(func(): _on_plot_button_down(b_id))
		btn.button_up.connect(func(): _on_plot_button_up(b_id))

func _find_plot_node(b_id: String) -> Node2D:
	if b_id in ["chai_stall", "pani_puri_cart", "fruit_stand"]:
		return starter_street.get_node_or_null("Plot_" + b_id) as Node2D
	else:
		return market_lane.get_node_or_null("Plot_" + b_id) as Node2D

func _on_plot_button_down(b_id: String) -> void:
	var state: Dictionary = EconomyService.get_business_state(b_id)
	if not state.get("owned", false):
		# Locked plot tapped
		_pause_city(true)
		if EconomyService.can_unlock_business(b_id):
			unlock_screen.open_for_business(b_id)
		else:
			locked_hint_modal.show_business_hint(b_id)
		return

	_select_business(b_id)
	_pressing_business_id = b_id
	EconomyService.tap_business(b_id)
	if tutorial_overlay.is_active and tutorial_overlay.current_step == 1 and b_id == "chai_stall":
		tutorial_overlay.advance_to_step(2)

func _on_plot_button_up(b_id: String) -> void:
	if _pressing_business_id == b_id:
		_pressing_business_id = ""

func _select_business(b_id: String) -> void:
	selected_business_id = b_id
	var b_cfg: Dictionary = EconomyService.config.get_business(b_id)
	var b_name: String = b_cfg.get("name", "Business").to_upper()
	details_btn.text = "⚙️ UPGRADE %s" % b_name

func open_selected_business_details() -> void:
	_pause_city(true)
	details_panel.open_business(selected_business_id)
	if tutorial_overlay.is_active and tutorial_overlay.current_step == 2 and selected_business_id == "chai_stall":
		tutorial_overlay.advance_to_step(3)

func open_business_unlock(b_id: String) -> void:
	_pause_city(true)
	unlock_screen.open_for_business(b_id)

func open_offline_earnings() -> void:
	_pause_city(true)
	offline_screen.show_offline_earnings(3600.0)

func open_objectives() -> void:
	_pause_city(true)
	objectives_screen.open_screen()

func open_empire_overview() -> void:
	_pause_city(true)
	empire_screen.open_screen()

func open_settings() -> void:
	_pause_city(true)
	settings_screen.open_screen()

func _on_panel_closed() -> void:
	_pause_city(false)
	_refresh_all_plots()
	_refresh_hud_now()

func _pause_city(paused: bool) -> void:
	city_world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

func _process(delta: float) -> void:
	_hud_update_accumulator += delta
	if _hud_update_accumulator >= HUD_UPDATE_INTERVAL:
		_hud_update_accumulator = 0.0
		_refresh_hud_now()

	_process_serving_cycles()
	_process_customer_movement(delta)

func _process_serving_cycles() -> void:
	var plot_ids: Array[String] = ["chai_stall", "pani_puri_cart", "fruit_stand"] if current_location == "starter_street" else ["bakery", "cafe"]
	for b_id in plot_ids:
		var b_state: Dictionary = EconomyService.get_business_state(b_id)
		if not b_state.get("owned", false):
			continue

		var plot_node := _find_plot_node(b_id)
		if not plot_node:
			continue

		var tap_ring: TextureProgressBar = plot_node.get_node("TapRing")
		var is_auto: bool = b_state.get("automated", false)
		var is_running: bool = b_state.get("cycle_running", false)
		var progress: float = float(b_state.get("cycle_progress", 0.0))

		if is_auto:
			tap_ring.value = progress * 100.0
			if _pressing_business_id == b_id:
				EconomyService.tap_business(b_id)
		else:
			if _pressing_business_id == b_id and not is_running:
				EconomyService.tap_business(b_id)
			tap_ring.value = progress * 100.0

		var last_p: float = float(_last_progress_by_business.get(b_id, 0.0))
		if last_p > 0.8 and progress < 0.2:
			_spawn_customer_purchase_effect()
			var b_cfg: Dictionary = EconomyService.config.get_business(b_id)
			var cycle_rev: BigNumber = IncomeModel.cycle_revenue(EconomyService.config, b_cfg, b_state)
			_pop_cash_number(cycle_rev, plot_node.get_node("CashFloatAnchor").global_position)

		_last_progress_by_business[b_id] = progress

func _refresh_all_plots() -> void:
	var plot_ids: Array[String] = ["chai_stall", "pani_puri_cart", "fruit_stand", "bakery", "cafe"]
	for b_id in plot_ids:
		_refresh_plot_visuals(b_id)

func _refresh_plot_visuals(b_id: String) -> void:
	var plot_node := _find_plot_node(b_id)
	if not plot_node:
		return

	var b_state: Dictionary = EconomyService.get_business_state(b_id)
	var is_owned: bool = b_state.get("owned", false)

	var b_sprite: Sprite2D = plot_node.get_node("BusinessSprite")
	var locked_card: Control = plot_node.get_node("LockedCard")
	var tap_ring: TextureProgressBar = plot_node.get_node("TapRing")
	var prompt_label: Label = plot_node.get_node("HoldPrompt")

	if is_owned:
		b_sprite.visible = true
		locked_card.visible = false
		tap_ring.visible = true
		prompt_label.visible = true

		var total_lvl: int = EconomyService.get_business_level(b_id)
		var tier_key := "1"
		if total_lvl >= 50:
			tier_key = "3"
		elif total_lvl >= 25:
			tier_key = "2"

		if textures.has(b_id) and textures[b_id].has(tier_key):
			b_sprite.texture = textures[b_id][tier_key]

		if b_state.get("automated", false):
			prompt_label.text = "AUTOMATED ✓"
			prompt_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			prompt_label.text = "HOLD TO SERVE"
			prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		b_sprite.visible = false
		locked_card.visible = true
		tap_ring.visible = false
		prompt_label.visible = false

		var b_cfg: Dictionary = EconomyService.config.get_business(b_id)
		var b_name: String = b_cfg.get("name", "Business")
		var card_lbl: Label = locked_card.get_node("VBox/TitleLabel")
		card_lbl.text = "🔒 %s" % b_name

func _request_hud_refresh() -> void:
	pass

func _refresh_hud_now() -> void:
	if not EconomyService:
		return
	var c: BigNumber = EconomyService.get_cash()
	cash_label.text = UserSettings.format_cash(c)
	var inc: BigNumber = EconomyService.get_income_per_second()
	income_label.text = UserSettings.format_rate(inc)

func _pop_cash_number(earned: BigNumber, anchor_pos: Vector2) -> void:
	var float_label := Label.new()
	float_label.text = "+%s" % UserSettings.format_cash(earned)
	float_label.add_theme_font_size_override("font_size", 20)
	float_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	float_label.global_position = anchor_pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))
	add_child(float_label)

	var tween := create_tween()
	tween.tween_property(float_label, "position", float_label.position + Vector2(0, -50), 0.7)
	tween.parallel().tween_property(float_label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(float_label.queue_free)

# --- Customer Pooling (max 8 visible) ---

func _setup_customer_pool() -> void:
	for i in range(MAX_CUSTOMERS):
		var cust := Node2D.new()
		cust.name = "Customer_%d" % i
		cust.visible = false

		var spr := Sprite2D.new()
		spr.texture = tex_customer
		spr.scale = Vector2(0.18, 0.18)
		cust.add_child(spr)

		customer_container.add_child(cust)
		customer_pool.append(cust)

func _spawn_customer_purchase_effect() -> void:
	for cust in customer_pool:
		if not cust.visible:
			_launch_customer(cust)
			break

func _launch_customer(cust: Node2D) -> void:
	cust.visible = true
	var start_pos := Vector2(80, 1150) if current_location == "starter_street" else Vector2(180, 1100)
	var stall_pos := Vector2(250, 800) if current_location == "starter_street" else Vector2(480, 780)
	var end_pos := Vector2(580, 520) if current_location == "starter_street" else Vector2(650, 480)

	cust.position = start_pos
	var tween := create_tween()
	tween.tween_property(cust, "position", stall_pos, 1.4)
	tween.tween_interval(0.4)
	tween.tween_property(cust, "position", end_pos, 1.4)
	tween.tween_callback(func(): cust.visible = false)

func _process_customer_movement(delta: float) -> void:
	_customer_spawn_timer += delta
	if _customer_spawn_timer >= 2.5:
		_customer_spawn_timer = 0.0
		_spawn_customer_purchase_effect()
