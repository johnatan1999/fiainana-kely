class_name ZoneRoot
extends Node2D

## Root script for every zone scene (House/Exterior).
## Says how big the zone is - for the camera limits and the edge walls - and
## which BGM track (if any) AudioManager should crossfade to on entry.
##
## Size: a zone with a GroundLayer is exactly its painted ground - camera
## limits and invisible walls around it follow on their own, so growing a
## village is just painting more ground. Zones without one (interiors, a
## single room image) set camera_limit_* by hand instead.

enum BGM { NONE, EXTERIOR, INTERIOR }

## Thickness of the invisible walls around the painted ground.
const EDGE_WALL_THICKNESS := 32.0

## Only used by zones without a GroundLayer.
@export var camera_limit_left: int = -10000
@export var camera_limit_top: int = -10000
@export var camera_limit_right: int = 10000
@export var camera_limit_bottom: int = 10000
## Exteriors 1.05 (~23 x 13 tiles in view: room to plan fields and find
## your way), interiors ~1.4 (closer, cosier). One consistent value per kind
## of place - the player's on-screen size shouldn't jump around.
@export var camera_zoom: float = 1.05
@export var bgm: BGM = BGM.NONE
## Lit from inside (DayNightController): no sky tint, a warm dim light at
## night instead of the blue outdoors.
@export var indoor := false

func _ready() -> void:
	var ground := _ground_rect()
	if ground.has_area():
		_add_edge_walls(ground)

## Where the camera may look, in global coordinates.
func get_camera_bounds() -> Rect2:
	var ground := _ground_rect()
	if ground.has_area():
		return ground
	return Rect2(camera_limit_left, camera_limit_top,
			camera_limit_right - camera_limit_left, camera_limit_bottom - camera_limit_top)

func _ground_rect() -> Rect2:
	var ground := get_node_or_null("GroundLayer") as GroundLayer
	return ground.get_world_rect() if ground else Rect2()

## Four invisible walls hugging the painted ground from the outside.
func _add_edge_walls(rect: Rect2) -> void:
	var t := EDGE_WALL_THICKNESS
	var body := StaticBody2D.new()
	body.name = "EdgeWalls"
	for wall in [
		Rect2(rect.position.x - t, rect.position.y - t, rect.size.x + 2.0 * t, t), # top
		Rect2(rect.position.x - t, rect.end.y, rect.size.x + 2.0 * t, t), # bottom
		Rect2(rect.position.x - t, rect.position.y, t, rect.size.y), # left
		Rect2(rect.end.x, rect.position.y, t, rect.size.y), # right
	]:
		var shape := RectangleShape2D.new()
		shape.size = wall.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = to_local(wall.get_center())
		body.add_child(collision)
	add_child(body, false, Node.INTERNAL_MODE_BACK)
