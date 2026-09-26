class_name ToolGlyph
extends Control

## Placeholder pictogram for a tool that has no icon art yet (hoe, watering
## can), drawn in code to fit the control. Replace with real textures by
## giving the tool an icon - HotbarSlot only falls back to this without one.

@export_enum("hoe", "watering_can") var tool_id: String = "hoe":
	set(value):
		tool_id = value
		queue_redraw()

const WOOD := Color(0.62, 0.4, 0.22)
const WOOD_DARK := Color(0.4, 0.24, 0.12)
const METAL := Color(0.72, 0.74, 0.78)
const METAL_DARK := Color(0.45, 0.47, 0.52)
const CAN := Color(0.42, 0.58, 0.72)
const CAN_DARK := Color(0.28, 0.4, 0.52)
const WATER := Color(0.55, 0.8, 1.0)

func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match tool_id:
		"hoe":
			# Diagonal wooden handle, metal blade across its top end.
			draw_line(p.call(0.22, 0.86), p.call(0.66, 0.26), WOOD_DARK, s * 0.12)
			draw_line(p.call(0.22, 0.86), p.call(0.66, 0.26), WOOD, s * 0.07)
			draw_colored_polygon(PackedVector2Array([
				p.call(0.5, 0.14), p.call(0.86, 0.3), p.call(0.8, 0.44), p.call(0.56, 0.3)]), METAL_DARK)
			draw_colored_polygon(PackedVector2Array([
				p.call(0.54, 0.18), p.call(0.82, 0.31), p.call(0.78, 0.39), p.call(0.58, 0.28)]), METAL)
		"watering_can":
			# Body, spout, handle, and a drop falling from the rose.
			draw_rect(Rect2(p.call(0.18, 0.42), Vector2(0.46, 0.4) * s), CAN_DARK)
			draw_rect(Rect2(p.call(0.21, 0.45), Vector2(0.4, 0.34) * s), CAN)
			draw_line(p.call(0.6, 0.62), p.call(0.86, 0.36), CAN_DARK, s * 0.08)
			draw_arc(p.call(0.41, 0.42), s * 0.17, PI, TAU, 12, CAN_DARK, s * 0.06)
			draw_circle(p.call(0.9, 0.52), s * 0.05, WATER)
