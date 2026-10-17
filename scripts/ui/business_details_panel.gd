class_name BusinessDetailsPanel
extends Control

signal closed

@export var business_id: String = "chai_stall"

var current_bulk: int = 1 # 1, 10 or EconomyService.BULK_MAX (-1)
var _is_open: bool = false

# UI Nodes
@onready var title_label: Label = $SafeContainer/PanelRoot/VBox/Header/TitleLabel
@onready var level_label: Label = $SafeContainer/PanelRoot/VBox/Header/LevelBadge/Label
@onready var status_badge: Label = $SafeContainer/PanelRoot/VBox/Header/StatusBadge
@onready var close_btn: Button = $SafeContainer/PanelRoot/VBox/Header/CloseButton

@onready var income_rate_label: Label = $SafeContainer/PanelRoot/VBox/StatsCard/HBox/IncomeRateLabel
@onready var cycle_time_label: Label = $SafeContainer/PanelRoot/VBox/StatsCard/HBox/CycleTimeLabel

# Synergy Card
@onready var synergy_card: PanelContainer = $SafeContainer/PanelRoot/VBox/SynergyCard
@onready var synergy_title: Label = $SafeContainer/PanelRoot/VBox/SynergyCard/VBox/SynergyTitle
@onready var synergy_desc: Label = $SafeContainer/PanelRoot/VBox/SynergyCard/VBox/SynergyDesc

# Bulk buy buttons
@onready var bulk_1_btn: Button = $SafeContainer/PanelRoot/VBox/BulkSection/HBox/Bulk1
@onready var bulk_10_btn: Button = $SafeContainer/PanelRoot/VBox/BulkSection/HBox/Bulk10
@onready var bulk_max_btn: Button = $SafeContainer/PanelRoot/VBox/BulkSection/HBox/BulkMax

# Upgrade track containers
@onready var tracks_container: VBoxContainer = $SafeContainer/PanelRoot/VBox/Scroll/TracksContainer

# Staff buttons
@onready var hire_manager_btn: Button = $SafeContainer/PanelRoot/VBox/StaffCard/HBox/ManagerBtn
@onready var hire_worker_btn: Button = $SafeContainer/PanelRoot/VBox/StaffCard/HBox/WorkerBtn

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_panel)
	bulk_1_btn.pressed.connect(func(): _set_bulk(1))
	bulk_10_btn.pressed.connect(func(): _set_bulk(10))
	bulk_max_btn.pressed.connect(func(): _set_bulk(EconomyService.BULK_MAX))

	hire_manager_btn.pressed.connect(_on_hire_manager)
	hire_worker_btn.pressed.connect(_on_hire_worker)

	EconomyService.cash_changed.connect(func(_c): if _is_open: refresh())
	EconomyService.upgrade_purchased.connect(func(_b, _t, _l): if _is_open: refresh())
	EconomyService.business_automated.connect(func(_b): if _is_open: refresh())
	EconomyService.synergy_activated.connect(func(_s): if _is_open: refresh())

	UserSettings.get_instance().settings_changed.connect(func(): if _is_open: refresh())

	_apply_safe_area()

func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0 and vp_size.y > 0 and safe.size.x > 0:
		var margin_top: float = maxf(16.0, float(safe.position.y))
		var margin_bottom: float = maxf(16.0, vp_size.y - (safe.position.y + safe.size.y))
		var safe_margin: MarginContainer = $SafeContainer
		safe_margin.add_theme_constant_override("margin_top", int(margin_top))
		safe_margin.add_theme_constant_override("margin_bottom", int(margin_bottom))

func open_business(b_id: String) -> void:
	business_id = b_id
	_is_open = true
	visible = true
	_set_bulk(1)
	refresh()

func close_panel() -> void:
	_is_open = false
	visible = false
	closed.emit()

func _set_bulk(b: int) -> void:
	current_bulk = b
	bulk_1_btn.flat = (current_bulk != 1)
	bulk_10_btn.flat = (current_bulk != 10)
	bulk_max_btn.flat = (current_bulk != EconomyService.BULK_MAX)
	refresh()

func refresh() -> void:
	if not _is_open or not EconomyService:
		return

	var b_state: Dictionary = EconomyService.get_business_state(business_id)
	if b_state.is_empty():
		return

	var b_cfg: Dictionary = EconomyService.config.get_business(business_id)
	title_label.text = b_cfg.get("name", "Business")

	var total_lvl: int = EconomyService.get_business_level(business_id)
	level_label.text = "Lv. %d" % total_lvl

	var is_auto: bool = b_state.get("automated", false)
	if is_auto:
		status_badge.text = "AUTOMATED"
		status_badge.modulate = Color(0.2, 0.9, 0.4)
	else:
		status_badge.text = "MANUAL (TAP)"
		status_badge.modulate = Color(1.0, 0.7, 0.2)

	var cycle_sec: float = float(b_state.get("cycle_seconds", 2.0))
	cycle_time_label.text = "Cycle: %.1fs" % cycle_sec

	var income_rate: BigNumber = b_state.get("income_per_second", BigNumber.zero())
	income_rate_label.text = UserSettings.format_rate(income_rate)

	_refresh_synergy()

	# Staff: Manager
	if is_auto or b_state.get("has_manager", false):
		hire_manager_btn.text = "Manager Hired ✓"
		hire_manager_btn.disabled = true
	else:
		var mgr_cost: BigNumber = EconomyService.get_staff_cost(business_id, "manager")
		hire_manager_btn.text = "Hire Manager (%s)" % UserSettings.format_cash(mgr_cost)
		hire_manager_btn.disabled = not EconomyService.can_afford(mgr_cost)

	# Staff: Worker
	var worker_cost: BigNumber = EconomyService.get_staff_cost(business_id, "worker")
	var workers_count: int = int(b_state.get("workers", 0))
	if worker_cost.is_zero():
		hire_worker_btn.text = "Worker (Max) ✓"
		hire_worker_btn.disabled = true
	else:
		hire_worker_btn.text = "Worker (%d) +20%% (%s)" % [workers_count, UserSettings.format_cash(worker_cost)]
		hire_worker_btn.disabled = not EconomyService.can_afford(worker_cost)

	_refresh_tracks(b_state)

func _refresh_synergy() -> void:
	if not EconomyService.config:
		synergy_card.visible = false
		return

	var found_synergy: Dictionary = {}
	for syn: Dictionary in EconomyService.config.synergies:
		if business_id in syn.get("applies_to", []) or business_id in syn.get("requires", []):
			found_synergy = syn
			break

	if found_synergy.is_empty():
		synergy_card.visible = false
		return

	synergy_card.visible = true
	var active_synergies: Array[String] = EconomyService.get_active_synergies()
	var is_active: bool = active_synergies.has(str(found_synergy.get("id", "")))
	var bonus_pct: int = int((float(found_synergy.get("income_multiplier", 1.0)) - 1.0) * 100.0)

	if is_active:
		synergy_title.text = "⚡ Synergy Active: %s (+%d%%)" % [found_synergy.get("name", "Synergy"), bonus_pct]
		synergy_title.add_theme_color_override("font_color", Color(0.2, 0.95, 0.8))
		synergy_desc.text = "Both businesses are Lv. %d+! +%d%% income boost active." % [
			int(found_synergy.get("min_level_each", 10)),
			bonus_pct
		]
	else:
		synergy_title.text = "⚡ Synergy: %s (Inactive)" % found_synergy.get("name", "Synergy")
		synergy_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		var req_names: Array[String] = []
		for req_id: String in found_synergy.get("requires", []):
			var b_name: String = EconomyService.config.get_business(req_id).get("name", req_id)
			var cur_lvl: int = EconomyService.get_business_level(req_id)
			req_names.append("%s (Lv. %d/%d)" % [b_name, cur_lvl, int(found_synergy.get("min_level_each", 10))])
		synergy_desc.text = "Needs: %s for +%d%% income" % [" & ".join(req_names), bonus_pct]

func _refresh_tracks(b_state: Dictionary) -> void:
	var track_keys: Array = ["equipment", "capacity", "quality", "marketing"]
	var levels_dict: Dictionary = b_state.get("levels", {})

	for i in range(track_keys.size()):
		var t_key: String = track_keys[i]
		var track_node: PanelContainer = tracks_container.get_node_or_null("Track_%s" % t_key)
		if not track_node:
			continue

		var lvl: int = int(levels_dict.get(t_key, 1))
		var lvl_lbl: Label = track_node.get_node("HBox/InfoVBox/LevelLabel")
		lvl_lbl.text = "Level %d" % lvl

		var cost: BigNumber = EconomyService.get_upgrade_cost(business_id, t_key, current_bulk)
		var buy_btn: Button = track_node.get_node("HBox/BuyButton")
		var bulk_label_str: String = "UPGRADE"
		if current_bulk == 10:
			bulk_label_str = "+ 10"
		elif current_bulk == EconomyService.BULK_MAX:
			bulk_label_str = "+ Max"

		buy_btn.text = "%s\n%s" % [bulk_label_str, UserSettings.format_cash(cost)]
		buy_btn.disabled = not EconomyService.can_afford(cost)

		for c in buy_btn.pressed.get_connections():
			buy_btn.pressed.disconnect(c.callable)
		buy_btn.pressed.connect(func():
			if EconomyService.buy_upgrade(business_id, t_key, current_bulk) > 0:
				refresh()
		)

func _on_hire_manager() -> void:
	if EconomyService.hire_staff(business_id, "manager"):
		refresh()

func _on_hire_worker() -> void:
	if EconomyService.hire_staff(business_id, "worker"):
		refresh()
