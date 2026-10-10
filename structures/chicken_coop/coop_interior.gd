@tool
class_name CoopInterior
extends Node2D

## The inside of the farm's coop, built from its level (FamilyProject
## "coop") - no picture: a room drawn in code (sharp at any zoom) from
## LEVELS - its floor's size, its walls (earth, broken, or bricks), its
## nest boxes - and everything placed from that size: the walls' collisions,
## the door out, the spawn, the bowls, the hens' area, the zone's camera
## limits. A bigger coop is a bigger room; a new level is a line in LEVELS.
##
## Built in _ready, before WorldManager reads the zone's camera limits -
## from `level`, kept up to date by FamilyProjectManager (the level isn't
## known to the zone scene itself). @tool: the room shows in the editor, at
## `preview_level`.
##
## The zone's nodes it places (siblings): ExitDoor, Spawns, FeedingBowl,
## WaterBowl, ChickenCoop (settling hens), ChickenArea (where hens roam).

const GROUP := "coop_interiors"
const TILE := 48
## Per level: the floor in cells, the walls, how many nest boxes.
const LEVELS := {
	0: {"cells": Vector2i(6, 4), "walls": "ruin", "nests": 0},
	1: {"cells": Vector2i(6, 4), "walls": "earth", "nests": 4},
	2: {"cells": Vector2i(8, 4), "walls": "earth", "nests": 8},
	3: {"cells": Vector2i(10, 5), "walls": "brick", "nests": 12},
}
## The back wall's face (seen from the front), the side and front walls'
## thickness, the doorway in the front wall.
const BACK_WALL := 84.0
const WALL := 20.0
const DOOR := 64.0
const BOWLS := preload("res://assets/sprites/props/coop_bowls.png")
## Cells of BOWLS (tools/placeholder_art/gen_coop.gd): feeder empty, full;
## water jar empty, full - twice the on-screen size.
const FEEDER_CELL := Vector2(128, 64)
const WATER_CELL := Vector2(64, 128)

const FLOOR := Color(0.55, 0.42, 0.28)
const FLOOR_DARK := Color(0.46, 0.34, 0.22)
const STRAW := Color(0.86, 0.74, 0.42)
const STRAW_DARK := Color(0.7, 0.58, 0.3)
const EARTH := Color(0.72, 0.36, 0.2)
const EARTH_DARK := Color(0.58, 0.27, 0.14)
const EARTH_TOP := Color(0.8, 0.45, 0.26)
const BRICK := Color(0.7, 0.32, 0.19)
const MORTAR := Color(0.84, 0.72, 0.58)
const WOOD := Color(0.5, 0.33, 0.18)
const WOOD_DARK := Color(0.33, 0.2, 0.1)
const OUTLINE := Color(0.18, 0.1, 0.05)
const EGG := Color(0.97, 0.93, 0.85)
const SKY := Color(0.62, 0.78, 0.9)

## The coop's level, set by FamilyProjectManager before the zone loads.
static var level := 1
## In the editor only: which level to show.
@export_range(0, 3) var preview_level := 1:
	set(value):
		preview_level = value
		if Engine.is_editor_hint() and is_inside_tree():
			_build(preview_level)

var _level := -1
var _walls: StaticBody2D

func _ready() -> void:
	z_index = -1
	add_to_group(GROUP)
	_build(preview_level if Engine.is_editor_hint() else level)

## Rebuilds the room for `new_level` (the coop rebuilt while the player is
## in it: a ruin becoming level 1 - the same size).
func set_level(new_level: int) -> void:
	if new_level != _level:
		_build(new_level)

## The floor, in the zone's coordinates (centered on the origin).
func get_floor() -> Rect2:
	var cells: Vector2i = LEVELS[_level]["cells"]
	var size := Vector2(cells * TILE)
	return Rect2(-size / 2.0, size)

func _build(new_level: int) -> void:
	_level = clampi(new_level, 0, LEVELS.size() - 1)
	var floor_rect := get_floor()
	_build_walls(floor_rect)
	if not Engine.is_editor_hint():
		_place_zone_nodes(floor_rect)
	queue_redraw()

## The walls' collisions: the back wall, the sides, the front either side of
## the doorway.
func _build_walls(f: Rect2) -> void:
	if _walls != null:
		_walls.queue_free()
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	var half_door := DOOR / 2.0
	for wall: Rect2 in [
		Rect2(f.position.x - WALL, f.position.y - BACK_WALL, f.size.x + WALL * 2.0, BACK_WALL),
		Rect2(f.position.x - WALL, f.position.y, WALL, f.size.y + WALL),
		Rect2(f.end.x, f.position.y, WALL, f.size.y + WALL),
		Rect2(f.position.x, f.end.y, f.size.x / 2.0 - half_door, WALL),
		Rect2(half_door, f.end.y, f.size.x / 2.0 - half_door, WALL),
	]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = wall.size
		shape.shape = box
		shape.position = wall.get_center()
		_walls.add_child(shape)
	add_child(_walls)

## Everything in the room, from its size - and the zone's camera limits.
func _place_zone_nodes(f: Rect2) -> void:
	var zone := get_parent()
	if zone is ZoneRoot:
		zone.camera_limit_left = floori(f.position.x - WALL - 16)
		zone.camera_limit_right = ceili(f.end.x + WALL + 16)
		zone.camera_limit_top = floori(f.position.y - BACK_WALL - 16)
		zone.camera_limit_bottom = ceili(f.end.y + WALL + 16)
	var door := zone.get_node_or_null("ExitDoor") as Node2D
	if door != null:
		door.position = Vector2(0, f.end.y + WALL * 0.6)
	# The player comes in just inside the doorway.
	var spawns := zone.get_node_or_null("Spawns") as Node2D
	if spawns != null:
		for spawn: Node2D in spawns.get_children():
			spawn.position = Vector2.ZERO
		spawns.position = Vector2(0, f.end.y - 24)
	var feeder := zone.get_node_or_null("FeedingBowl") as Node2D
	if feeder != null:
		feeder.position = Vector2(f.position.x + f.size.x * 0.25, f.position.y + f.size.y * 0.45)
		_dress_bowl(feeder, FEEDER_CELL, 0)
	var water := zone.get_node_or_null("WaterBowl") as Node2D
	if water != null:
		water.position = Vector2(f.end.x - f.size.x * 0.22, f.position.y + f.size.y * 0.7)
		_dress_bowl(water, WATER_CELL, 1)
	var coop := zone.get_node_or_null("ChickenCoop") as Node2D
	if coop != null:
		coop.position = Vector2(0, f.position.y + f.size.y * 0.35)
	var area := zone.get_node_or_null("ChickenArea") as Control
	if area != null:
		area.position = f.position + Vector2(24, 36)
		area.size = f.size - Vector2(48, 72)

## The bowls' sharp art (BOWLS, twice the size: shown at half).
func _dress_bowl(bowl: Node2D, cell: Vector2, row: int) -> void:
	var textures := []
	for column in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = BOWLS
		atlas.region = Rect2(Vector2(cell.x * column, row * FEEDER_CELL.y), cell)
		textures.append(atlas)
	bowl.set("empty_bowl_texture", textures[0])
	bowl.set("full_bowl_texture", textures[1])
	var visual := bowl.get_node_or_null("Visual") as Sprite2D
	if visual != null:
		visual.scale = Vector2(0.5, 0.5)
	# Shows the right one now (servings' setter redraws).
	bowl.set("servings", bowl.get("servings"))

# --- drawing -------------------------------------------------------------------------------

func _draw() -> void:
	if _level < 0:
		return
	var f := get_floor()
	var walls: String = LEVELS[_level]["walls"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + _level
	_draw_floor(f, rng, walls == "ruin")
	_draw_back_wall(f, walls, rng)
	_draw_nests(f, LEVELS[_level]["nests"], rng)
	_draw_side_walls(f, walls)
	if walls == "ruin":
		_draw_debris(f, rng)
	if walls == "brick":
		_draw_basket(Vector2(f.end.x - 40, f.end.y - 24))

func _draw_floor(f: Rect2, rng: RandomNumberGenerator, ruin: bool) -> void:
	draw_rect(f, FLOOR)
	for i in int(f.size.x * f.size.y / 260.0):
		var at := Vector2(rng.randf_range(f.position.x, f.end.x), rng.randf_range(f.position.y, f.end.y))
		draw_circle(at, rng.randf_range(2.0, 5.0), FLOOR_DARK)
	# Straw strewn on the floor - thicker along the back wall.
	for i in int(f.size.x * f.size.y / (90.0 if not ruin else 220.0)):
		var at := Vector2(rng.randf_range(f.position.x, f.end.x),
			f.position.y + pow(rng.randf(), 1.8) * f.size.y)
		var tip := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(5.0, 11.0)
		draw_line(at, tip, STRAW if rng.randf() < 0.65 else STRAW_DARK, 1.6)

func _draw_back_wall(f: Rect2, walls: String, rng: RandomNumberGenerator) -> void:
	var face := Rect2(f.position.x - WALL, f.position.y - BACK_WALL, f.size.x + WALL * 2.0, BACK_WALL)
	if walls == "brick":
		draw_rect(face, BRICK)
		var row := 0
		var y := face.position.y
		while y < face.end.y:
			draw_line(Vector2(face.position.x, y), Vector2(face.end.x, y), MORTAR, 1.5)
			var x := face.position.x + (0.0 if row % 2 == 0 else 12.0)
			while x < face.end.x:
				draw_line(Vector2(x, y), Vector2(x, minf(y + 9.0, face.end.y)), MORTAR, 1.5)
				x += 24.0
			y += 9.0
			row += 1
		# A window with sky.
		var window := Rect2(f.end.x - 96, face.position.y + 14, 56, 34)
		draw_rect(window, SKY)
		draw_rect(window, WOOD, false, 4.0)
		draw_line(Vector2(window.get_center().x, window.position.y), Vector2(window.get_center().x, window.end.y), WOOD, 3.0)
	else:
		draw_rect(face, EARTH)
		for i in int(face.size.x / 6.0):
			draw_circle(Vector2(rng.randf_range(face.position.x, face.end.x), rng.randf_range(face.position.y, face.end.y)),
				rng.randf_range(2.0, 4.0), EARTH_DARK)
		if walls == "ruin":
			# Holes in the wall, daylight through them.
			for x in [face.position.x + face.size.x * 0.22, face.position.x + face.size.x * 0.68]:
				var hole := PackedVector2Array([Vector2(x, face.position.y + 10), Vector2(x + 34, face.position.y + 18),
					Vector2(x + 28, face.position.y + 46), Vector2(x - 6, face.position.y + 40)])
				draw_colored_polygon(hole, SKY.darkened(0.15))
	draw_rect(Rect2(face.position.x, face.position.y, face.size.x, 6), EARTH_TOP if walls != "brick" else BRICK.lightened(0.15))
	draw_line(Vector2(face.position.x, face.end.y), Vector2(face.end.x, face.end.y), OUTLINE, 2.0)
	# A perch along it.
	if walls != "ruin":
		draw_line(Vector2(f.position.x + 10, f.position.y - 10), Vector2(f.end.x - 10, f.position.y - 10), WOOD_DARK, 4.0)

## Nest boxes in a row on the back wall (two rows when they don't fit).
func _draw_nests(f: Rect2, count: int, rng: RandomNumberGenerator) -> void:
	if count <= 0:
		return
	var size := Vector2(30, 24)
	var per_row := mini(count, int((f.size.x - 20.0) / (size.x + 6.0)))
	var rows := ceili(float(count) / per_row)
	for i in count:
		var row := i / per_row
		var column := i % per_row
		var width := per_row * (size.x + 6.0) - 6.0
		var at := Vector2(-width / 2.0 + column * (size.x + 6.0), f.position.y - BACK_WALL + 18 + row * (size.y + 6))
		if rows == 1:
			at.y += 16
		var box := Rect2(at, size)
		draw_rect(box, WOOD_DARK)
		draw_rect(box.grow(-3), STRAW)
		draw_rect(box, OUTLINE, false, 1.5)
		if rng.randf() < 0.35:
			draw_circle(box.get_center() + Vector2(0, 2), 4.0, EGG)

func _draw_side_walls(f: Rect2, walls: String) -> void:
	var color := BRICK if walls == "brick" else EARTH
	var top := EARTH_TOP if walls != "brick" else BRICK.lightened(0.15)
	for side: Rect2 in [Rect2(f.position.x - WALL, f.position.y, WALL, f.size.y + WALL),
			Rect2(f.end.x, f.position.y, WALL, f.size.y + WALL)]:
		draw_rect(side, color)
		draw_rect(side.grow_individual(0, 0, 0, -side.size.y + 4), top)
	var half_door := DOOR / 2.0
	for front: Rect2 in [Rect2(f.position.x - WALL, f.end.y, f.size.x / 2.0 - half_door + WALL, WALL),
			Rect2(half_door, f.end.y, f.size.x / 2.0 - half_door + WALL, WALL)]:
		draw_rect(front, color)
		draw_rect(Rect2(front.position, Vector2(front.size.x, 5)), top)
	# The doorway's threshold.
	draw_rect(Rect2(-half_door, f.end.y, DOOR, WALL), FLOOR_DARK)
	draw_line(Vector2(-half_door, f.end.y + WALL), Vector2(half_door, f.end.y + WALL), WOOD, 3.0)

func _draw_debris(f: Rect2, rng: RandomNumberGenerator) -> void:
	# Fallen planks and bits of thatch.
	for i in 6:
		var at := Vector2(rng.randf_range(f.position.x + 20, f.end.x - 20), rng.randf_range(f.position.y + 20, f.end.y - 20))
		var tip := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(24.0, 44.0)
		draw_line(at, tip, WOOD_DARK, 6.0)
		draw_line(at, tip, WOOD, 3.0)

func _draw_basket(at: Vector2) -> void:
	draw_circle(at, 13.0, WOOD_DARK)
	draw_circle(at + Vector2(0, -2), 10.0, WOOD)
	for i in 4:
		draw_circle(at + Vector2(-6 + i * 4, -6 - (i % 2) * 3), 3.5, EGG)
