@tool
class_name ScatteredFeathers
extends Node2D

## Hen feathers strewn on the ground, drawn in code: what's left in front of
## the coop the morning after a thief took a hen (ChickenThiefManager).
## Decor; `count` feathers, the same layout every time (seeded).

const COLORS := [Color(0.62, 0.36, 0.18), Color(0.85, 0.75, 0.6), Color(0.35, 0.2, 0.12)]

@export var count := 9:
	set(value):
		count = value
		queue_redraw()
@export var spread := Vector2(46, 16):
	set(value):
		spread = value
		queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var at := Vector2(rng.randf_range(-1, 1) * spread.x, rng.randf_range(-1, 1) * spread.y)
		var angle := rng.randf_range(-PI, PI)
		var color: Color = COLORS[i % COLORS.size()]
		var along := Vector2.from_angle(angle)
		var side := along.orthogonal()
		var points := PackedVector2Array()
		for k in 10:
			var t := TAU * k / 10.0
			points.append(at + along * cos(t) * 6.0 + side * sin(t) * 1.8)
		draw_colored_polygon(points, color)
		draw_line(at - along * 7.0, at + along * 5.0, color.darkened(0.4), 0.8)
