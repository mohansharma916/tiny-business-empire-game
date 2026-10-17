class_name SettingsScreen
extends Control

signal closed

@onready var close_btn: Button = $SafeContainer/PanelRoot/VBox/Header/CloseButton
@onready var fps_toggle: CheckButton = $SafeContainer/PanelRoot/VBox/Scroll/ContentVBox/PerformanceCard/HBox/FPSToggle
@onready var format_short_btn: Button = $SafeContainer/PanelRoot/VBox/Scroll/ContentVBox/FormatCard/ButtonRow/FormatShortBtn
@onready var format_indian_btn: Button = $SafeContainer/PanelRoot/VBox/Scroll/ContentVBox/FormatCard/ButtonRow/FormatIndianBtn
@onready var preview_format_label: Label = $SafeContainer/PanelRoot/VBox/Scroll/ContentVBox/FormatCard/PreviewLabel

@onready var sfx_toggle: CheckButton = $SafeContainer/PanelRoot/VBox/Scroll/ContentVBox/AudioCard/SFXRow/SFXToggle
@onready var music_toggle: CheckButton = $SafeContainer/PanelRoot/VBox/Scroll/ContentVBox/AudioCard/MusicRow/MusicToggle
@onready var haptics_toggle: CheckButton = $SafeContainer/PanelRoot/VBox/Scroll/ContentVBox/AudioCard/HapticsRow/HapticsToggle

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_screen)

	fps_toggle.toggled.connect(func(enabled: bool):
		UserSettings.set_battery_saver(enabled)
	)

	format_short_btn.pressed.connect(func():
		UserSettings.set_indian_format(false)
		_refresh_format_buttons()
	)

	format_indian_btn.pressed.connect(func():
		UserSettings.set_indian_format(true)
		_refresh_format_buttons()
	)

	sfx_toggle.toggled.connect(func(enabled: bool):
		UserSettings.set_sfx(enabled)
	)

	music_toggle.toggled.connect(func(enabled: bool):
		UserSettings.set_music(enabled)
	)

	haptics_toggle.toggled.connect(func(enabled: bool):
		UserSettings.set_haptics(enabled)
	)

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
	visible = true
	_load_current_values()

func close_screen() -> void:
	visible = false
	closed.emit()

func _load_current_values() -> void:
	UserSettings.get_instance()
	fps_toggle.set_pressed_no_signal(UserSettings.battery_saver_30fps)
	sfx_toggle.set_pressed_no_signal(UserSettings.sfx_enabled)
	music_toggle.set_pressed_no_signal(UserSettings.music_enabled)
	haptics_toggle.set_pressed_no_signal(UserSettings.haptics_enabled)
	_refresh_format_buttons()

func _refresh_format_buttons() -> void:
	var is_indian: bool = UserSettings.use_indian_format
	format_short_btn.flat = is_indian
	format_indian_btn.flat = not is_indian

	var sample: BigNumber = BigNumber.from_float(12500000.0)
	preview_format_label.text = "Sample: ₹ %s" % sample.to_formatted(is_indian)
