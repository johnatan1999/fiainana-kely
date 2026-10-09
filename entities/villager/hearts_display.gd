class_name HeartsDisplay
extends Node2D

## A row of hearts - the player's friendship with a villager: full ones,
## the next one partly filled (progress), then empty ones. Drawn in code (no
## font or art needed). Villager.show_hearts() shows it for a moment.

const SIZE := 11.0
const GAP := 3.0
const FULL := Color(0.86, 0.2, 0.25)
const EMPTY := Color(0.3, 0.2, 0.18, 0.55)
const OUTLINE := Color(0.22, 0.1, 0.08)

var hearts := 0
var max_hearts := 5
## 0..1: how far into the next heart.
var progress := 0.0

func set_hearts(count: int, maximum: int, next_progress: float) -> void:
	hearts = count
	max_hearts = maximum
	progress = next_progress
	queue_redraw()

func _draw() -> void:
	var width := max_hearts * SIZE + (max_hearts - 1) * GAP
	for i in max_hearts:
		var center := Vector2(-width / 2.0 + SIZE / 2.0 + i * (SIZE + GAP), 0)
		var fill := 1.0 if i < hearts else (progress if i == hearts else 0.0)
		_heart(center, EMPTY)
		if fill > 0.0:
			# Partly filled: the bottom of the heart up to `fill`.
			_heart(center, FULL, fill)
		_heart_outline(center)

## A heart around `center`; `fill` < 1 draws only its lower part.
func _heart(center: Vector2, color: Color, fill := 1.0) -> void:
	var points := _shape(center)
	if fill < 1.0:
		var cut := center.y + SIZE / 2.0 - SIZE * fill
		var below := PackedVector2Array([Vector2(center.x - SIZE, cut), Vector2(center.x + SIZE, cut),
			Vector2(center.x + SIZE, center.y + SIZE), Vector2(center.x - SIZE, center.y + SIZE)])
		var parts := Geometry2D.intersect_polygons(points, below)
		if parts.is_empty():
			return
		points = parts[0]
	if points.size() >= 3:
		draw_colored_polygon(points, color)

func _heart_outline(center: Vector2) -> void:
	var points := _shape(center)
	points.append(points[0])
	draw_polyline(points, OUTLINE, 1.0, true)

## The heart's outline: two round lobes and a point at the bottom.
func _shape(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		# The classic heart curve, scaled to SIZE.
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(center + Vector2(x, y) * (SIZE / 34.0))
	return points
