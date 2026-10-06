class_name HarvestPopup
extends Node2D

## "+3 Corn" with the item's icon, popping up over what was just harvested,
## rising and fading out - the yield is felt where it happened, and a row of
## harvests doesn't pile up in a corner of the screen. An optional smaller
## line under it says why a harvest came out small ("peu arrosé"...).
##
## Unshaded: stays readable at night (DayNightController darkens the world).
## Above everything else (z_index). Frees itself.

const RISE := 30.0
const DURATION := 1.3
const FADE_DELAY := 0.75
const ICON_SIZE := 18.0
const TEXT_COLOR := Color(1.0, 0.97, 0.85)
const NOTE_COLOR := Color(1.0, 0.75, 0.45)

## Spawns a popup at `global_pos` (where the text's bottom sits) under
## `parent` - any node of the current zone.
static func spawn(parent: Node, global_pos: Vector2, icon: Texture2D, text: String, note := "") -> HarvestPopup:
	var popup := HarvestPopup.new()
	parent.add_child(popup)
	popup.global_position = global_pos
	popup._build(icon, text, note)
	return popup

func _build(icon: Texture2D, text: String, note: String) -> void:
	z_index = 50
	z_as_relative = false
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.use_parent_material = true
	if icon:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		picture.use_parent_material = true
		row.add_child(picture)
	row.add_child(_label(text, 15, TEXT_COLOR))
	add_child(row)
	# Centered on the spot: the main line just above it, the note just under.
	var size := row.get_combined_minimum_size()
	row.position = Vector2(-size.x / 2.0, -size.y)
	if note != "":
		var note_label := _label(note, 11, NOTE_COLOR)
		add_child(note_label)
		note_label.position = Vector2(-note_label.get_minimum_size().x / 2.0, 0)

	scale = Vector2(0.6, 0.6)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - RISE, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION - FADE_DELAY).set_delay(FADE_DELAY)
	tween.chain().tween_callback(queue_free)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.04))
	label.add_theme_constant_override("outline_size", 4)
	label.use_parent_material = true
	return label
