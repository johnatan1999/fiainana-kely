class_name CookingPanel
extends Control

## The farm's kitchen: each recipe - its name (in Malagasy too), what goes
## in (and how much of it is in the bag), what the dish sells for - to cook
## once or as many times as the bag allows. Only shows what KitchenManager
## hands it and says what the player asked for (`cook_requested`). Pauses
## the game. Built in code.

signal cook_requested(recipe_id: String, times: int)

const PANEL_COLOR := Color(0.96, 0.9, 0.76, 0.97)
const CARD_COLOR := Color(0.99, 0.95, 0.85)
const BORDER_COLOR := Color(0.45, 0.28, 0.15)
const TEXT_COLOR := Color(0.27, 0.17, 0.09)
const MUTED_COLOR := Color(0.5, 0.38, 0.26)
const MISSING_COLOR := Color(0.65, 0.25, 0.12)
const WIDTH := 580.0
const ICON_SIZE := 40.0

var _note: Label
var _recipes: VBoxContainer
var _close: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func is_open() -> bool:
	return visible

## `recipes`: [{"id", "name", "malagasy", "icon", "ingredients" (text),
## "missing" (bool: not enough), "price" (what the dish sells for),
## "count" (times it can be cooked)}]. `note`: a word under the title.
## Opens the panel, or refreshes it if already open.
func show_recipes(recipes: Array, note: String) -> void:
	_note.text = note
	_note.visible = not note.is_empty()
	for child in _recipes.get_children():
		_recipes.remove_child(child)
		child.queue_free()
	var first: Button = null
	for recipe: Dictionary in recipes:
		var button := _add_card(recipe)
		if first == null and not button.disabled:
			first = button
	if not visible:
		visible = true
		get_tree().paused = true
		AudioManager.play_click_menu_sfx()
	(first if first != null else _close).grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _add_card(recipe: Dictionary) -> Button:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	_recipes.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture = recipe["icon"]
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	_label(texts, "%s · %s" % [recipe["name"], recipe["malagasy"]], 16, TEXT_COLOR)
	_label(texts, recipe["ingredients"], 13, MISSING_COLOR if recipe["missing"] else MUTED_COLOR)
	_label(texts, tr("Se vend %s") % Currency.format(recipe["price"]), 13, TEXT_COLOR)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	var once := _button(buttons, tr("Cuisiner"))
	once.disabled = recipe["count"] <= 0
	var recipe_id: String = recipe["id"]
	once.pressed.connect(func(): cook_requested.emit(recipe_id, 1))
	if recipe["count"] > 1:
		var all := _button(buttons, tr("Tout cuisiner (%d)") % recipe["count"])
		var times: int = recipe["count"]
		all.pressed.connect(func(): cook_requested.emit(recipe_id, times))
	return once

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
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := _label(box, tr("La cuisine · Lakozia"), 22, TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note = _label(box, "", 14, MUTED_COLOR)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WIDTH - 36, 0)
	box.add_child(HSeparator.new())
	_recipes = VBoxContainer.new()
	_recipes.add_theme_constant_override("separation", 6)
	box.add_child(_recipes)
	_close = _button(box, tr("Fermer"))
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 32)
	parent.add_child(button)
	return button
