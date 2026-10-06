class_name OrdersTracker
extends Control

## The accepted orders, top right: for each, who, the item, how many the
## player already has out of how many, and the days left - in green once
## it can be delivered, in red on its last day. Hidden with no order.
## Built in code; OrderManager fills it (show_orders()).

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.92)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const READY_COLOR := Color(0.2, 0.5, 0.15)
const URGENT_COLOR := Color(0.7, 0.2, 0.1)
const ICON_SIZE := 22.0
const MARGIN := 16.0

var _panel: PanelContainer
var _rows: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var title := Label.new()
	title.text = tr("Commandes")
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	box.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	box.add_child(_rows)
	visible = false

## `orders`: [{"villager", "icon", "item", "have", "need", "days_left"}].
func show_orders(orders: Array) -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for order: Dictionary in orders:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = order["icon"]
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		var days: int = order["days_left"]
		var when := tr("dernier jour") if days <= 1 else tr("%d j") % days
		label.text = "%s : %d/%d %s — %s" % [order["villager"], mini(order["have"], order["need"]), order["need"], order["item"], when]
		label.add_theme_font_size_override("font_size", 14)
		var color := TEXT_COLOR
		if order["have"] >= order["need"]:
			color = READY_COLOR
		elif days <= 1:
			color = URGENT_COLOR
		label.add_theme_color_override("font_color", color)
		row.add_child(label)
		_rows.add_child(row)
	visible = not orders.is_empty()
	# Hug the top-right corner, whatever the width.
	await get_tree().process_frame
	_panel.reset_size()
	_panel.position = Vector2(-_panel.size.x - MARGIN, MARGIN)
