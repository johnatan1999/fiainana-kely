class_name SettingsPanel
extends Control

## The home screen's settings: language, music and sound effects volumes,
## full screen - all kept by GameSettings (user://settings.cfg), applied at
## once. Built in code.

signal closed

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const WIDTH := 420.0

var _language: Button
var _music: HSlider
var _sfx: HSlider
var _fullscreen: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_language()

func open() -> void:
	_music.set_value_no_signal(GameSettings.get_volume(AudioManager.BUS_MUSIC))
	_sfx.set_value_no_signal(GameSettings.get_volume(AudioManager.BUS_SFX))
	_fullscreen.set_pressed_no_signal(GameSettings.is_fullscreen())
	_refresh_language()
	visible = true
	_language.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _refresh_language() -> void:
	if _language != null:
		_language.text = tr("Langue : %s") % GameSettings.get_locale_name()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := _label(box, tr("Paramètres"), 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_language = Button.new()
	_language.custom_minimum_size = Vector2(0, 36)
	_language.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		GameSettings.cycle_locale())
	box.add_child(_language)

	_music = _slider(box, tr("Musique"))
	_music.value_changed.connect(func(value: float): GameSettings.set_volume(AudioManager.BUS_MUSIC, value))
	_sfx = _slider(box, tr("Effets sonores"))
	_sfx.value_changed.connect(func(value: float): GameSettings.set_volume(AudioManager.BUS_SFX, value))
	# A click at the new volume, once the slider is let go.
	_sfx.drag_ended.connect(func(_changed: bool): AudioManager.play_click_menu_sfx())

	_fullscreen = CheckButton.new()
	_fullscreen.text = tr("Plein écran")
	_fullscreen.add_theme_color_override("font_color", TEXT_COLOR)
	_fullscreen.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	_fullscreen.add_theme_color_override("font_hover_color", TEXT_COLOR)
	_fullscreen.toggled.connect(func(on: bool): GameSettings.set_fullscreen(on))
	box.add_child(_fullscreen)

	var back := Button.new()
	back.text = tr("Retour")
	back.custom_minimum_size = Vector2(160, 36)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		AudioManager.play_click_menu_sfx()
		close())
	box.add_child(back)

func _slider(parent: Node, text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _label(row, text, 16)
	label.custom_minimum_size = Vector2(140, 0)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	return slider

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	parent.add_child(label)
	return label
