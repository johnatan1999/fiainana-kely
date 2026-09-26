class_name HudGlyph
extends Control

## Placeholder pictograms for the HUD, drawn in code to fit the control until
## there's icon art: the Asara sun (hot, rainy season), an Asotry dry leaf
## (cool, dry season) and an ariary coin. Swap for TextureRects once the
## icons exist - nothing else in the HUD depends on how these are drawn.

@export_enum("sun", "dry_leaf", "coin") var kind: String = "sun":
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
		"coin":
			draw_circle(c, s * 0.44, COIN_DARK)
			draw_circle(c, s * 0.37, COIN)
			draw_arc(c, s * 0.27, 0.0, TAU, 20, COIN_DARK, s * 0.06)
			draw_circle(c + Vector2(-s * 0.13, -s * 0.13), s * 0.07, COIN_SHINE)
