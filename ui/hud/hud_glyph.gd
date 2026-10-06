class_name HudGlyph
extends Control

## Placeholder pictograms for the HUD, drawn in code to fit the control until
## there's icon art: the Asara sun (hot, rainy season), an Asotry dry leaf
## (cool, dry season) and an ariary coin. Swap for TextureRects once the
## icons exist - nothing else in the HUD depends on how these are drawn.

@export_enum("sun", "dry_leaf", "coin", "rain") var kind: String = "sun":
	set(value):
		kind = value
		queue_redraw()

const SUN := Color(1.0, 0.78, 0.2)
const SUN_RAY := Color(0.95, 0.55, 0.15)
const LEAF := Color(0.78, 0.5, 0.22)
const LEAF_DARK := Color(0.5, 0.3, 0.12)
const COIN := Color(0.95, 0.76, 0.3)
const COIN_DARK := Color(0.62, 0.43, 0.12)
const COIN_SHINE := Color(1.0, 0.95, 0.75)
const CLOUD := Color(0.62, 0.66, 0.74)
const CLOUD_LIGHT := Color(0.8, 0.83, 0.9)
const DROP := Color(0.35, 0.55, 0.85)

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	match kind:
		"sun":
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				draw_line(c + dir * s * 0.3, c + dir * s * 0.47, SUN_RAY, s * 0.09)
			draw_circle(c, s * 0.25, SUN)
		"dry_leaf":
			# Pointed leaf tilted 45 degrees, with its midrib and stem.
			var tip := c + Vector2(s * 0.34, -s * 0.34)
			var base := c + Vector2(-s * 0.3, s * 0.3)
			var side := Vector2(s * 0.2, s * 0.2)
			var points := PackedVector2Array()
			for i in 17: # one edge, base to tip...
				var t := i / 16.0
				points.append(base.lerp(tip, t) + side * sin(t * PI))
			for i in range(15, 0, -1): # ...and back along the other
				var t := i / 16.0
				points.append(base.lerp(tip, t) - side * sin(t * PI))
			draw_colored_polygon(points, LEAF)
			draw_line(base, tip, LEAF_DARK, s * 0.06)
			draw_line(base, base + Vector2(-s * 0.12, s * 0.12), LEAF_DARK, s * 0.07)
		"rain":
			# A cloud and three slanted drops under it.
			for i in 3:
				var x := c.x + (i - 1) * s * 0.24
				draw_line(Vector2(x, c.y + s * 0.12), Vector2(x - s * 0.07, c.y + s * 0.38), DROP, s * 0.08)
			draw_circle(c + Vector2(-s * 0.16, -s * 0.04), s * 0.17, CLOUD)
			draw_circle(c + Vector2(s * 0.14, -s * 0.06), s * 0.19, CLOUD)
			draw_circle(c + Vector2(-s * 0.01, -s * 0.18), s * 0.2, CLOUD_LIGHT)
			draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.06, s * 0.6, s * 0.14), CLOUD)
		"coin":
			draw_circle(c, s * 0.44, COIN_DARK)
			draw_circle(c, s * 0.37, COIN)
			draw_arc(c, s * 0.27, 0.0, TAU, 20, COIN_DARK, s * 0.06)
			draw_circle(c + Vector2(-s * 0.13, -s * 0.13), s * 0.07, COIN_SHINE)
