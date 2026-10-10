class_name SchoolPanel
extends Control

## Paying Fara's school fees, at the school: what's owed, by when (or that
## it's late), and how to pay - in Ariary (as much as the player has, up to
## what's owed) or in rice. Only shows what SchoolManager hands it and says
## what the player asked for (signals) - the rules are FarmSimulation's.
## Pauses the game while open, like the shop. Built in code.

signal pay_money_requested
signal pay_rice_requested

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const NOTE_COLOR := Color(0.6, 0.3, 0.15)
const LATE_COLOR := Color(0.7, 0.2, 0.1)
const WIDTH := 430.0

var _title: Label
var _line: Label
var _debt: Label
var _when: Label
var _pay_money: Button
var _pay_rice: Button
var _note: Label
var _close: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `days_left`: as SchoolRules.get_school_days_left() (0 or less = late).
## `money_payment`: what the Ariary button pays (0 = greyed). `rice_count`
## and `rice_price`: the rice the rice button gives and what each is worth
## (count 0 = greyed). Opens the panel, or refreshes it if already open.
func show_fees(teacher_name: String, line: String, debt: int, days_left: int, money_payment: int,
		rice_count: int, rice_price: int, note: String) -> void:
	_title.text = tr("Écolage de Fara")
	_line.text = "%s : « %s »" % [teacher_name, line]
	_debt.text = tr("Reste à payer : %s") % Currency.format(debt) if debt > 0 else tr("Tout est payé. Merci !")
	if debt <= 0:
		_when.text = ""
	elif days_left <= 0:
		_when.text = tr("En retard : Fara reste à la maison.")
	elif days_left == 1:
		_when.text = tr("Dernier jour pour payer.")
	else:
		_when.text = tr("À payer d'ici %d jours.") % days_left
	_when.add_theme_color_override("font_color", LATE_COLOR if days_left <= 1 else TEXT_COLOR)
	_when.visible = not _when.text.is_empty()
	_pay_money.text = tr("Payer %s") % Currency.format(money_payment) if money_payment > 0 else tr("Payer en ariary")
	_pay_money.disabled = money_payment <= 0 or debt <= 0
	_pay_rice.text = tr("Donner %d riz (%s pièce)") % [rice_count, Currency.format(rice_price)] if rice_count > 0 \
		else tr("Payer en riz (%s pièce)") % Currency.format(rice_price)
	_pay_rice.disabled = rice_count <= 0 or debt <= 0
	_note.text = note
	_note.visible = not note.is_empty()
	if not visible:
		visible = true
		get_tree().paused = true
		AudioManager.play_click_menu_sfx()
	if _pay_money.disabled and _pay_rice.disabled:
		_close.grab_focus()
	else:
		(_pay_money if not _pay_money.disabled else _pay_rice).grab_focus()

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
	_debt = _label(box, 19)
	_debt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_when = _label(box, 15)
	_when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_pay_money = _button(buttons)
	_pay_money.pressed.connect(func(): pay_money_requested.emit())
	_pay_rice = _button(buttons)
	_pay_rice.pressed.connect(func(): pay_rice_requested.emit())
	_note = _label(box, 14)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH - 36, 0)
	_note.add_theme_color_override("font_color", NOTE_COLOR)
	_close = _button(box)
	_close.text = tr("Fermer")
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	parent.add_child(label)
	return label

func _button(parent: Node) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	return button
