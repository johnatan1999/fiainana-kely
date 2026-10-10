class_name QuestPanel
extends Control

## A side quest, offered: who asks, the story as they tell it, what to do
## first, the reward - and Accept / Later (the offer stays: no deadline,
## nothing lost). Escape is Later. Pauses the game while open, like the
## OrderPanel it looks like. Built in code; QuestManager opens it.

signal accepted
signal postponed

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.2, 0.42, 0.45)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const QUEST_COLOR := Color(0.13, 0.4, 0.43)
const WIDTH := 460.0

var _title: Label
var _giver: Label
var _line: Label
var _objective: Label
var _reward: Label
var _accept: Button

func _ready() -> void:
	# Keeps working while the game is paused under it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## Texts already translated. `reward`: what it brings ("10 000 Ar, l'amitié
## de Rakoto").
func open(title: String, giver_name: String, line: String, objective: String, reward: String) -> void:
	_title.text = title
	_giver.text = tr("Un service pour %s") % giver_name
	_line.text = "« %s »" % line
	_objective.text = tr("D'abord : %s") % objective
	_reward.text = tr("Récompense : %s") % reward
	_reward.visible = not reward.is_empty()
	visible = true
	get_tree().paused = true
	AudioManager.play_click_menu_sfx()
	_accept.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		postponed.emit()
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
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_giver = _label(box, 14, QUEST_COLOR)
	_giver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title = _label(box, 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line = _label(box, 16)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(WIDTH - 36, 0)
	box.add_child(HSeparator.new())
	_objective = _label(box, 15, QUEST_COLOR)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(WIDTH - 36, 0)
	_reward = _label(box, 16)
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := _label(box, 13)
	note.text = tr("Pas de délai : prends ton temps.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_accept = _button(buttons, tr("Accepter"))
	_accept.pressed.connect(func():
		close()
		accepted.emit())
	var later := _button(buttons, tr("Plus tard"))
	later.pressed.connect(func():
		close()
		postponed.emit())

func _label(parent: Node, size: int, color := TEXT_COLOR) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 36)
	parent.add_child(button)
	return button
