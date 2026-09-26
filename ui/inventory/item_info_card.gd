class_name ItemInfoCard
extends VBoxContainer

## The inventory's right page: everything about one item - big icon, name
## (in the current language), tab and quantity, description and detail rows (from
## InventoryCatalog.describe()). show_empty() when nothing is selected.
## For items that can go in the Hotbar, a row of numbered slots places it
## there (show_hotbar()) - the card only reports the click, InventoryUI acts.

signal hotbar_slot_chosen(index: int)
signal hotbar_remove_requested


@onready var icon_rect: TextureRect = %Icon
@onready var placeholder: ColorRect = %Placeholder
@onready var glyph: ToolGlyph = %Glyph
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var separator: HSeparator = %Separator
@onready var description_label: Label = %DescriptionLabel
@onready var details_grid: GridContainer = %DetailsGrid
@onready var hotbar_box: HBoxContainer = %HotbarBox
@onready var slot_buttons: HBoxContainer = %SlotButtons
@onready var remove_button: Button = %RemoveButton

func _ready() -> void:
	for i in Hotbar.SIZE:
		var button := Button.new()
		button.text = str(i + 1)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(20, 20)
		button.theme_type_variation = &"BookSlotButton"
		button.pressed.connect(func(): hotbar_slot_chosen.emit(i))
		slot_buttons.add_child(button)
	remove_button.pressed.connect(func(): hotbar_remove_requested.emit())

func show_item(info: Dictionary, quantity: int) -> void:
	var icon: Texture2D = info.icon
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	var glyph_id: String = info.get("glyph", "")
	glyph.visible = icon == null and glyph_id != ""
	if glyph.visible:
		glyph.tool_id = glyph_id
	placeholder.visible = icon == null and glyph_id == ""
	placeholder.color = info.color
	name_label.text = info.name
	meta_label.text = tr("%s  ·  Quantité : %d") % [InventoryCatalog.category_name(info.category), quantity]
	meta_label.visible = true
	separator.visible = true
	description_label.text = info.description
	description_label.visible = info.description != ""
	_fill_details(info.details)

func show_empty(message: String) -> void:
	icon_rect.visible = false
	glyph.visible = false
	placeholder.visible = false
	hotbar_box.visible = false
	name_label.text = message
	meta_label.visible = false
	separator.visible = false
	description_label.visible = false
	_fill_details([])

## `current_index` = slot the item is in (-1: not in the bar). Hidden for
## items that can't go in the bar at all (`enabled` false).
func show_hotbar(enabled: bool, current_index: int) -> void:
	hotbar_box.visible = enabled
	for button: Button in slot_buttons.get_children():
		button.set_pressed_no_signal(button.get_index() == current_index)
	remove_button.visible = current_index != -1

func _fill_details(details: Array) -> void:
	for child in details_grid.get_children():
		child.queue_free()
	# Label column: exactly as wide as its longest label. Value column: all the
	# remaining width, so values only get trimmed when truly too long.
	for row in details:
		var name_label := _detail_label(row[0], &"BookTextSoft", HORIZONTAL_ALIGNMENT_LEFT)
		details_grid.add_child(name_label)
		var value_label := _detail_label(row[1], &"BookText", HORIZONTAL_ALIGNMENT_RIGHT)
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Never let a long value widen the card past the page - trim with "…".
		value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		value_label.clip_text = true
		details_grid.add_child(value_label)
	details_grid.visible = not details.is_empty()

## `style` is a Label type variation from ui/theme/main_theme.tres.
func _detail_label(text: String, style: StringName, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.theme_type_variation = style
	return label
