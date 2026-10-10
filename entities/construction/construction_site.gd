class_name ConstructionSite
extends Node2D

## Work under way on a building (a family project): wooden scaffolding
## poles lashed together in front of it, a pile of planks and bricks, and a
## small sign. Covers `area` (local, from its own origin, the building's
## foot at y = 0). Decor only, drawn in code (placeholder art) - added and
## removed by FamilyProjectManager.

const POLE := Color(0.55, 0.4, 0.22)
const POLE_DARK := Color(0.38, 0.26, 0.14)
const ROPE := Color(0.85, 0.75, 0.5)
const PLANK := Color(0.68, 0.52, 0.3)
const BRICK := Color(0.72, 0.34, 0.2)
const SIGN := Color(0.85, 0.7, 0.45)

## The building's outline to dress, from this node: x from area.position.x
## to its end, poles from the ground (y = 0) up to area.position.y.
var area := Rect2(0, -150, 220, 150)

func _ready() -> void:
	# In front of what it dresses, whatever their y.
	z_index = 1
	var label := Label.new()
	label.text = tr("Chantier")
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.25, 0.12, 0.05))
	label.position = Vector2(area.end.x - 2, -40)
	label.size = Vector2(56, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

func _draw() -> void:
	var left := area.position.x
	var right := area.end.x
	var top := area.position.y
	# Upright poles, and the lashed crossbars.
	var poles := 5
	for i in poles:
		var x := lerpf(left + 6, right - 6, float(i) / (poles - 1))
		draw_line(Vector2(x, 2), Vector2(x, top - 6), POLE_DARK, 5.0)
		draw_line(Vector2(x - 1, 2), Vector2(x - 1, top - 6), POLE, 3.0)
	for y in [top * 0.35, top * 0.7]:
		draw_line(Vector2(left, y), Vector2(right, y), POLE, 4.0)
		for i in poles:
			var x := lerpf(left + 6, right - 6, float(i) / (poles - 1))
			draw_circle(Vector2(x, y), 3.0, ROPE)
	# A diagonal brace.
	draw_line(Vector2(left + 6, 0), Vector2(right - 6, top * 0.7), POLE_DARK, 3.0)
	# Planks and bricks piled at the foot.
	for i in 3:
		draw_rect(Rect2(left - 50, -6 - i * 5, 46, 4), PLANK)
	for row in 2:
		for col in 3 - row:
			draw_rect(Rect2(right + 8 + col * 12 + row * 6, -8 - row * 7, 10, 6), BRICK)
	# The sign.
	draw_line(Vector2(right + 28, 0), Vector2(right + 28, -26), POLE_DARK, 3.0)
	draw_rect(Rect2(right - 2, -42, 60, 18), SIGN)
	draw_rect(Rect2(right - 2, -42, 60, 18), POLE_DARK, false, 1.5)
