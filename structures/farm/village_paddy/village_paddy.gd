@tool
class_name VillagePaddy
extends Node2D

## The neighbours' paddy: decor, not farmable - flooded soil under shallow
## water, and a plant of rice per cell whose stage follows the season (just
## planted out at its start, ripe at its end: two crops a year, as on the
## highlands). The village farmers work in it (VillagerStop WORK on spots
## placed in it - see tools/place_villagers.gd).
##
## Origin = the top-left corner of its first cell: place it on the ground
## grid, y-sorted (its plants y-sort with the farmers). Everything is built in code from `size` (nothing saved in the
## scene); @tool, so it shows in the editor too.
##
## The date comes from DayNightController.CALENDAR_GROUP.

const TILE := 48
const FARM_TILESET := preload("res://assets/tileset/farm_tileset.tres")
const WATER_TILESET := preload("res://assets/tileset/water_tileset.tres")
const PADDY_WATER_MATERIAL := preload("res://environment/water/paddy_water_material.tres")
const RICE_VISUAL := preload("res://entities/crops/rice/rice_visual.tscn")
## Same soil as a flooded FarmField: tilled earth, darkened by the water.
const SOIL_TERRAIN := "Tilled"
const WET_TINT := Color(0.62, 0.5, 0.42)
const WATER_TILE := Vector2i(0, 0)
## Rice stage (CropVisual stage index) by day of the season: Sprout from
## the 1st, Growing from the 9th, Mature from the 22nd.
const STAGE_FROM_DAY := {1: 1, 9: 2, 22: 3}

@export var size := Vector2i(6, 4):
	set(value):
		size = value
		_rebuild()

var _stage := 2
var _plants: Array[CropVisual] = []
var _built: Array[Node] = []

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(DayNightController.CALENDAR_GROUP)
	_rebuild()

func set_date(day_of_season: int, _season: GameClock.Season) -> void:
	var stage := 1
	for day: int in STAGE_FROM_DAY:
		if day_of_season >= day:
			stage = STAGE_FROM_DAY[day]
	if stage != _stage:
		_stage = stage
		_show_stage()

func get_stage() -> int:
	return _stage

func get_rect() -> Rect2:
	return Rect2(global_position, Vector2(size * TILE))

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for node in _built:
		node.queue_free()
	_built.clear()
	_plants.clear()
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(Vector2i(x, y))

	var soil := _layer("Soil", FARM_TILESET, -2)
	soil.modulate = WET_TINT
	var terrain := _find_terrain(SOIL_TERRAIN)
	if terrain.x != -1:
		soil.set_cells_terrain_connect(cells, terrain.x, terrain.y)
	var water := _layer("Water", WATER_TILESET, -1)
	water.material = PADDY_WATER_MATERIAL
	for cell in cells:
		water.set_cell(cell, 0, WATER_TILE)

	# A plant per cell, at the cell's bottom-center (CropVisual's foot).
	for cell in cells:
		var plant: CropVisual = RICE_VISUAL.instantiate()
		plant.position = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE - 4.0)
		add_child(plant)
		_built.append(plant)
		_plants.append(plant)
	_show_stage()

func _show_stage() -> void:
	for plant in _plants:
		plant.show_stage(_stage)

func _layer(layer_name: String, tiles: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tiles
	layer.z_index = z
	add_child(layer)
	_built.append(layer)
	return layer

func _find_terrain(terrain_name: String) -> Vector2i:
	for terrain_set in FARM_TILESET.get_terrain_sets_count():
		for terrain in FARM_TILESET.get_terrains_count(terrain_set):
			if FARM_TILESET.get_terrain_name(terrain_set, terrain) == terrain_name:
				return Vector2i(terrain_set, terrain)
	return Vector2i(-1, -1)
