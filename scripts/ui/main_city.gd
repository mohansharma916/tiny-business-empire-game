class_name MainCity
extends Control

# City scene with Chai Stall, customer pooling, HUD, tutorial, and panel management

@onready var city_world: Node2D = $CityWorld
@onready var stall_sprite: Sprite2D = $CityWorld/StallPlot/StallSprite
@onready var tap_ring: TextureProgressBar = $CityWorld/StallPlot/TapRing
@onready var tap_hitbox: Button = $CityWorld/StallPlot/TapHitbox
@onready var cash_float_anchor: Marker2D = $CityWorld/StallPlot/CashFloatAnchor

# HUD Nodes
@onready var cash_label: Label = $SafeContainer/TopHUD/VBox/StatsRow/CashCard/CashLabel
@onready var income_label: Label = $SafeContainer/TopHUD/VBox/StatsRow/IncomeCard/IncomeLabel

@onready var goals_btn: Button = $SafeContainer/TopHUD/VBox/NavRow/GoalsButton
@onready var empire_btn: Button = $SafeContainer/TopHUD/VBox/NavRow/EmpireButton
@onready var offline_btn: Button = $SafeContainer/TopHUD/VBox/NavRow/OfflineTestButton
@onready var details_btn: Button = $SafeContainer/BottomHUD/DetailsButton

# Panel references (instantiated once and reused)
@onready var details_panel: BusinessDetailsPanel = $Panels/BusinessDetailsPanel
@onready var offline_screen: OfflineEarningsScreen = $Panels/OfflineEarningsScreen
@onready var objectives_screen: ObjectivesScreen = $Panels/ObjectivesScreen
@onready var empire_screen: EmpireOverviewScreen = $Panels/EmpireOverviewScreen
@onready var tutorial_overlay: TutorialOverlay = $Panels/TutorialOverlay

# Customer pool
@onready var customer_container: Node2D = $CityWorld/Customers
var customer_pool: Array[Node2D] = []
const MAX_CUSTOMERS: int = 8
var _customer_spawn_timer: float = 0.0

# Tap-to-serve state
var _is_pressing_stall: bool = false
var _serving_progress: float = 0.0

# Textures for visual levels
var tex_lvl1: Texture2D = preload("res://assets/placeholder/chai_stall_level1.png")
var tex_lvl2: Texture2D = preload("res://assets/placeholder/chai_stall_level2.png")
var tex_lvl3: Texture2D = preload("res://assets/placeholder/chai_stall_level3.png")
var tex_customer: Texture2D = preload("res://assets/placeholder/customer_pedestrian.png")

# 4 Hz HUD update limiter
var _hud_update_accumulator: float = 0.0
const HUD_UPDATE_INTERVAL: float = 0.25 # Max 4 updates/sec

func _ready() -> void:
	_setup_customer_pool()
	_setup_tap_and_hold()
	_setup_panel_events()
	_apply_safe_area()

	EconomyService.cash_changed.connect(func(_c): _request_hud_refresh())
	EconomyService.income_changed.connect(func(_i): _request_hud_refresh())
	EconomyService.upgrade_purchased.connect(func(_b, _t, _l): _update_stall_visuals())
	EconomyService.business_automated.connect(func(_b): _update_stall_visuals())

	_update_stall_visuals()
	_refresh_hud_now()

	# Start onboarding tutorial on first session
	tutorial_overlay.start_tutorial()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back_button()

func _handle_android_back_button() -> void:
	# Close the topmost open panel first
	if objectives_screen.visible:
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

func _setup_panel_events() -> void:
	details_btn.pressed.connect(open_business_details)
	offline_btn.pressed.connect(open_offline_earnings)
	goals_btn.pressed.connect(open_objectives)
	empire_btn.pressed.connect(open_empire_overview)

	details_panel.closed.connect(_on_panel_closed)
	offline_screen.closed.connect(func(_a): _on_panel_closed())
	objectives_screen.closed.connect(_on_panel_closed)
	empire_screen.closed.connect(_on_panel_closed)

func open_business_details() -> void:
	_pause_city(true)
	details_panel.open_business("chai_stall")
	if tutorial_overlay.is_active and tutorial_overlay.current_step == 2:
		tutorial_overlay.advance_to_step(3)

func open_offline_earnings() -> void:
	_pause_city(true)
	offline_screen.show_offline_earnings(3600.0)

func open_objectives() -> void:
	_pause_city(true)
	objectives_screen.open_screen()

func open_empire_overview() -> void:
	_pause_city(true)
	empire_screen.open_screen()

func _on_panel_closed() -> void:
	_pause_city(false)
	_update_stall_visuals()
	_refresh_hud_now()

func _pause_city(paused: bool) -> void:
	# Pauses animations and updates of the city world behind the panel
	city_world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

func _setup_tap_and_hold() -> void:
	tap_hitbox.button_down.connect(func(): _is_pressing_stall = true)
	tap_hitbox.button_up.connect(func(): _is_pressing_stall = false)

func _process(delta: float) -> void:
	# Limit HUD updates to at most 4 times per second (PRD rule)
	_hud_update_accumulator += delta
	if _hud_update_accumulator >= HUD_UPDATE_INTERVAL:
		_hud_update_accumulator = 0.0
		_refresh_hud_now()

	# Process manual tap-and-hold serving or automated cycle
	_process_serving_cycle(delta)
	_process_customer_movement(delta)

func _process_serving_cycle(delta: float) -> void:
	var b_state := EconomyService.get_business_state("chai_stall")
	var is_auto: bool = b_state.get("is_automated", false)
	var cycle_time := EconomyService.calculate_cycle_time("chai_stall")

	if is_auto:
		# Auto-running: continuous progress loop
		_serving_progress += delta / cycle_time
		if _serving_progress >= 1.0:
			_serving_progress = 0.0
			_spawn_customer_purchase_effect()
		tap_ring.value = _serving_progress * 100.0
	else:
		# Manual: requires player pressing or holding
		if _is_pressing_stall:
			_serving_progress += delta / cycle_time
			if _serving_progress >= 1.0:
				_serving_progress = 0.0
				var result: Dictionary = EconomyService.tap_business("chai_stall")
				var earned: BigNumber = result.get("revenue", BigNumber.zero())
				_pop_cash_number(earned)
				_spawn_customer_purchase_effect()
				if tutorial_overlay.is_active and tutorial_overlay.current_step == 1:
					tutorial_overlay.advance_to_step(2)
			tap_ring.value = _serving_progress * 100.0
		else:
			# Decay slowly if released
			_serving_progress = maxf(0.0, _serving_progress - delta * 0.5)
			tap_ring.value = _serving_progress * 100.0

func _update_stall_visuals() -> void:
	var tier: int = EconomyService.get_visual_tier("chai_stall")
	match tier:
		1: stall_sprite.texture = tex_lvl1
		2: stall_sprite.texture = tex_lvl2
		3: stall_sprite.texture = tex_lvl3
		_: stall_sprite.texture = tex_lvl1

func _request_hud_refresh() -> void:
	pass

func _refresh_hud_now() -> void:
	if not EconomyService:
		return
	var c := EconomyService.get_cash()
	cash_label.text = "₹ %s" % c.to_formatted(false)
	var inc := EconomyService.get_income_per_second()
	income_label.text = "+₹ %s / s" % inc.to_formatted(false)

func _pop_cash_number(earned: BigNumber) -> void:
	var float_label := Label.new()
	float_label.text = "+₹ %s" % earned.to_formatted(false)
	float_label.add_theme_font_size_override("font_size", 20)
	float_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	float_label.position = cash_float_anchor.position + Vector2(randf_range(-20, 20), randf_range(-10, 10))
	city_world.add_child(float_label)

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
	var start_pos := Vector2(80, 720)
	var stall_pos := Vector2(280, 580)
	var end_pos := Vector2(580, 760)

	cust.position = start_pos
	var tween := create_tween()
	tween.tween_property(cust, "position", stall_pos, 1.2)
	tween.tween_interval(0.4)
	tween.tween_property(cust, "position", end_pos, 1.2)
	tween.tween_callback(func(): cust.visible = false)

func _process_customer_movement(delta: float) -> void:
	_customer_spawn_timer += delta
	if _customer_spawn_timer >= 2.5:
		_customer_spawn_timer = 0.0
		_spawn_customer_purchase_effect()
