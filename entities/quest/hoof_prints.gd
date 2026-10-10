@tool
class_name HoofPrints
extends Node2D

## A zebu's hoof prints in the mud, drawn in code: `count` cloven prints
## (two halves each) along `direction`, in a walking zig-zag. Decor (a
## QuestTarget's look).

const MUD := Color(0.24, 0.16, 0.09, 0.75)
const RIM := Color(0.45, 0.33, 0.2, 0.55)

@export var count := 6:
	set(value):
		count = value
		queue_redraw()
@export var direction := Vector2(1, 0.4):
	set(value):
		direction = value
		queue_redraw()
@export var spacing := 26.0:
	set(value):
		spacing = value
		queue_redraw()

func _draw() -> void:
	var forward := direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	var side := forward.orthogonal()
	var start := -forward * spacing * (count - 1) / 2.0
	for i in count:
		var center := start + forward * spacing * i + side * (7.0 if i % 2 == 0 else -7.0)
		_print(center, forward, side)

## One cloven print: two half-ovals side by side, pointing `forward`.
func _print(center: Vector2, forward: Vector2, side: Vector2) -> void:
	for half in [-1.0, 1.0]:
		var points := PackedVector2Array()
		var middle: Vector2 = center + side * 2.6 * half
		for k in 12:
			var angle := TAU * k / 12.0
			points.append(middle + forward * cos(angle) * 5.5 + side * sin(angle) * 2.4)
		draw_colored_polygon(points, MUD)
		draw_polyline(points + PackedVector2Array([points[0]]), RIM, 1.0)
