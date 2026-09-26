class_name ItemInfoCard
extends VBoxContainer

## The inventory's right page: everything about one item - big icon, French
## and Malagasy names, tab and quantity, description and detail rows (from
## InventoryCatalog.describe()). show_empty() when nothing is selected.

const INK := Color(0.29, 0.18, 0.1)
const INK_SOFT := Color(0.45, 0.32, 0.2)
const DETAIL_FONT_SIZE := 13

@onready var icon_rect: TextureRect = %Icon
@onready var placeholder: ColorRect = %Placeholder
@onready var name_label: Label = %NameLabel
@onready var malagasy_label: Label = %MalagasyLabel
@onready var meta_label: Label = %MetaLabel
@onready var separator: HSeparator = %Separator
@onready var description_label: Label = %DescriptionLabel
@onready var details_grid: GridContainer = %DetailsGrid

func show_item(info: Dictionary, quantity: int) -> void:
	var icon: Texture2D = info.icon
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	placeholder.visible = icon == null
	placeholder.color = info.color
	name_label.text = info.name
	malagasy_label.text = info.malagasy_name
	malagasy_label.visible = info.malagasy_name != "" and info.malagasy_name != info.name
	meta_label.text = "%s  ·  Quantité : %d" % [InventoryCatalog.CATEGORY_NAMES[info.category], quantity]
	meta_label.visible = true
	separator.visible = true
	description_label.text = info.description
	description_label.visible = info.description != ""
	_fill_details(info.details)

func show_empty(message: String) -> void:
	icon_rect.visible = false
	placeholder.visible = false
	name_label.text = message
	malagasy_label.visible = false
	meta_label.visible = false
	separator.visible = false
	description_label.visible = false
	_fill_details([])

func _fill_details(details: Array) -> void:
	for child in details_grid.get_children():
		child.queue_free()
	for row in details:
		details_grid.add_child(_detail_label(row[0], INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT))
		details_grid.add_child(_detail_label(row[1], INK, HORIZONTAL_ALIGNMENT_RIGHT))
	details_grid.visible = not details.is_empty()

func _detail_label(text: String, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Never let a long value widen the card past the page - trim with "…".
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", DETAIL_FONT_SIZE)
	return label
