@tool
class_name CoopPadlock
extends Node2D

## The padlock on the coop's door (FarmSimulation.PADLOCK_ITEM), drawn in
## code: an iron body and its shackle, a keyhole. Decor - ChickenThiefManager
## puts it on the farm's coop once bought.

const IRON := Color(0.36, 0.36, 0.38)
const LIGHT := Color(0.62, 0.62, 0.64)
const DARK := Color(0.12, 0.12, 0.13)

func _draw() -> void:
	draw_arc(Vector2(0, -7), 4.5, PI, TAU, 12, IRON, 2.2)
	draw_line(Vector2(-4.5, -7), Vector2(-4.5, -4), IRON, 2.2)
	draw_line(Vector2(4.5, -7), Vector2(4.5, -4), IRON, 2.2)
	draw_rect(Rect2(-6.5, -4, 13, 10), DARK)
	draw_rect(Rect2(-5.5, -3, 11, 8), IRON)
	draw_line(Vector2(-5, -2.5), Vector2(5, -2.5), LIGHT, 1.0)
	draw_circle(Vector2(0, 0), 1.3, DARK)
	draw_line(Vector2(0, 0), Vector2(0, 3), DARK, 1.0)
