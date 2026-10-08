class_name ZebuMarketPanel
extends Control

## The zebu market (tsena omby) of the bourg: buy a young zebu, sell the
## player's own at their worth. Only shows what ZebuManager hands it and
## says what the player asked for (signals) - the rules are FarmSimulation's.
## Pauses the game while open, like the shop. Built in code.

signal buy_requested
signal sell_requested(zebu_id: String)

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const NOTE_COLOR := Color(0.6, 0.3, 0.15)
const WIDTH := 470.0
const ICON_SIZE := Vector2(48, 36)

var _title: Label
var _offer: Label
var _buy: Button
var _note: Label
var _herd_title: Label
var _herd: VBoxContainer
var _close: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `zebus`: [{"id", "name", "growth" (text), "value" (Ar)}] - the player's
## herd. `note`: why buying isn't possible, or "".
func show_market(title: String, price: int, can_buy: bool, note: String, zebus: Array,
		capacity: int) -> void:
	_title.text = tr(title)
	_offer.text = tr("Jeune zébu (vantotr'omby) : %s") % Currency.format(price)
	_buy.disabled = not can_buy
	_note.text = note
	_note.visible = not note.is_empty()
	_herd_title.text = tr("Ton troupeau (%d/%d)") % [zebus.size(), capacity]
	for child in _herd.get_children():
		_herd.remove_child(child)
		child.queue_free()
	if zebus.is_empty():
		_label(_herd, 15).text = tr("Tu n'as pas encore de zébu.")
	for zebu: Dictionary in zebus:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_herd.add_child(row)
		var icon := TextureRect.new()
		icon.texture = InventoryCatalog.zebu_icon()
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = GrazingZebu.COATS[zebu["coat"]]
		row.add_child(icon)
		var text := _label(row, 16)
		text.text = "%s · %s" % [zebu["name"], zebu["growth"]]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sell := _button(row, tr("Vendre %s") % Currency.format(zebu["value"]))
		var zebu_id: String = zebu["id"]
		sell.pressed.connect(func(): sell_requested.emit(zebu_id))
	if not visible:
		visible = true
		get_tree().paused = true
		AudioManager.play_click_menu_sfx()
		(_close if _buy.disabled else _buy).grab_focus()

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
	var line := _label(box, 15)
	line.text = tr("« Des zébus solides, nourris à l'herbe des collines ! »")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(HSeparator.new())

	var offer_row := HBoxContainer.new()
	offer_row.add_theme_constant_override("separation", 10)
	box.add_child(offer_row)
	_offer = _label(offer_row, 17)
	_offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy = _button(offer_row, tr("Acheter"))
	_buy.pressed.connect(buy_requested.emit)
	_note = _label(box, 14)
	_note.add_theme_color_override("font_color", NOTE_COLOR)
	var hint := _label(box, 13)
	hint.text = tr("Il vit au parc de la ferme. Remplis l'abreuvoir chaque jour : il grandit et prend de la valeur.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH - 36, 0)
	box.add_child(HSeparator.new())

	_herd_title = _label(box, 17)
	_herd = VBoxContainer.new()
	_herd.add_theme_constant_override("separation", 6)
	box.add_child(_herd)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	_close = _button(buttons, tr("Fermer"))
	_close.pressed.connect(close)

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 34)
	parent.add_child(button)
	return button
