class_name OrderPanel
extends Control

## A villager's order, offered: who asks, what they say, the item and how
## many, the reward, the time to deliver - and Accept / Decline. Escape
## closes it without deciding (the offer stays open). Pauses the game while
## open, like the shop. Built in code; OrderManager opens it.

signal accepted
signal declined

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const NOTE_COLOR := Color(0.6, 0.3, 0.15)
const WIDTH := 400.0
const ICON_SIZE := 40.0

var _title: Label
var _line: Label
var _icon: TextureRect
var _item: Label
var _reward: Label
var _days: Label
var _note: Label
var _accept: Button
var _decline: Button

func _ready() -> void:
	# Keeps working while the game is paused under it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `can_accept` false: shown, but Accept is greyed with `note` saying why.
## `bonus_percent`: the friendship bonus included in `reward`.
func open(villager_name: String, line: String, icon: Texture2D, item_name: String, quantity: int,
		reward: int, days: int, can_accept: bool, note := "", bonus_percent := 0) -> void:
	_title.text = tr("Commande de %s") % villager_name
	_line.text = "« %s »" % line
	_icon.texture = icon
	_icon.visible = icon != null
	_item.text = "%d × %s" % [quantity, item_name]
	_reward.text = tr("Récompense : %s") % Currency.format(reward)
	if bonus_percent > 0:
		_reward.text += "  " + tr("(+%d %% d'amitié)") % bonus_percent
	_days.text = tr("À livrer en %d jours") % days if days > 1 else tr("À livrer aujourd'hui")
	_note.text = note
	_note.visible = not note.is_empty()
	_accept.disabled = not can_accept
	visible = true
	get_tree().paused = true
	AudioManager.play_click_menu_sfx()
	(_decline if not can_accept else _accept).grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
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
	_title = _label(box, 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line = _label(box, 16)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(WIDTH - 36, 0)
	box.add_child(HSeparator.new())

	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 10)
	box.add_child(item_row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_row.add_child(_icon)
	_item = _label(item_row, 20)
	_reward = _label(box, 17)
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_days = _label(box, 15)
	_days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note = _label(box, 14)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", NOTE_COLOR)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_accept = _button(buttons, tr("Accepter"))
	_accept.pressed.connect(func():
		close()
		accepted.emit())
	_decline = _button(buttons, tr("Refuser"))
	_decline.pressed.connect(func():
		close()
		declined.emit())

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 36)
	parent.add_child(button)
	return button
