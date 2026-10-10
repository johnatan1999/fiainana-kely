class_name DogNamePanel
extends Control

## The puppy just came home: what will it be called? A name already in the
## field (FarmSimulation's pick), to keep or to type over; "Un autre nom"
## draws another one. Enter or "C'est son nom !" names it; Escape keeps the
## one in the field. Pauses the game while open, like the QuestPanel it
## looks like. Built in code; DogManager opens it.

signal named(dog_name: String)

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.55, 0.36, 0.2)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const ACCENT_COLOR := Color(0.55, 0.3, 0.12)
const WIDTH := 420.0

var _line: LineEdit
var _intro: Label
var _ok: Button

func _ready() -> void:
	# Keeps working while the game is paused under it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `dog_name`: the one to suggest; `giver_name`: whose puppy it was.
func open(dog_name: String, giver_name: String) -> void:
	_intro.text = tr("Le chiot de %s trottine à tes pieds. Comment vas-tu l'appeler ?") % giver_name
	_line.text = dog_name
	visible = true
	get_tree().paused = true
	AudioManager.play_click_menu_sfx()
	_line.grab_focus()
	_line.select_all()

func get_typed_name() -> String:
	return _line.text

## Names it with what's in the field (the suggestion if it's empty).
func confirm() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	named.emit(_line.text)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		confirm()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
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
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := _label(box, 22, ACCENT_COLOR)
	title.text = tr("Un chiot à la ferme !")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro = _label(box, 16)
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.custom_minimum_size = Vector2(WIDTH - 36, 0)

	_line = LineEdit.new()
	_line.max_length = DogRules.DOG_NAME_MAX_LENGTH
	_line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_size_override("font_size", 20)
	_line.text_submitted.connect(func(_text: String): confirm())
	box.add_child(_line)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var other := _button(buttons, tr("Un autre nom"))
	other.pressed.connect(func():
		var names := DogRules.DOG_NAMES.filter(func(dog_name: String) -> bool: return dog_name != _line.text)
		_line.text = names[randi() % names.size()]
		_line.grab_focus())
	_ok = _button(buttons, tr("C'est son nom !"))
	_ok.pressed.connect(confirm)
	var note := _label(box, 13)
	note.text = tr("Remplis sa gamelle chaque jour : un chien qui a mangé garde la ferme la nuit.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(WIDTH - 36, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _label(parent: Node, size: int, color := TEXT_COLOR) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size = Vector2(140, 36)
	parent.add_child(button)
	return button
