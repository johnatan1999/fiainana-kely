@tool
class_name VillagePaddy
extends Node2D

## The neighbours' paddy: decor, not farmable - flooded soil under shallow
## water and a tuft of rice per cell. The village farmers work in it
## (VillagerStop WORK on spots placed in it - see tools/place_villagers.gd)
## and harvest it at the end of each season; the player can help.
##
## Display only: NeighbourPaddyManager drives it from FarmSimulation (the
## rice's stage, which tufts are cut) through show_state(), and handles
## `interacted` (the player cutting a tuft - tuft_near() picks which).
##
## Origin = the top-left corner of its first cell: place it on the ground
## grid, y-sorted (its tufts y-sort with the farmers). Everything is built
## in code from `size` (nothing saved in the scene); @tool, so it shows in
## the editor too.

signal interacted

const TILE := 48
const FARM_TILESET := preload("res://assets/tileset/farm_tileset.tres")
const WATER_TILESET := preload("res://assets/tileset/water_tileset.tres")
const PADDY_WATER_MATERIAL := preload("res://environment/water/paddy_water_material.tres")
const RICE_VISUAL := preload("res://entities/crops/rice/rice_visual.tscn")
const SHEAF := preload("res://entities/props/hay_sheaf.tscn")
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")
## Same soil as a flooded FarmField: tilled earth, darkened by the water.
const SOIL_TERRAIN := "Tilled"
const WET_TINT := Color(0.62, 0.5, 0.42)
const WATER_TILE := Vector2i(0, 0)
## A cut tuft: the stubble left in the water (the smallest stage, straw-
## colored).
const STUBBLE_STAGE := 0
const STUBBLE_TINT := Color(0.9, 0.78, 0.45)
## The sheaves stand in a row along the bottom edge, one per this many cut
## tufts.
const TUFTS_PER_SHEAF := 3
const SHEAF_SPACING := 26.0
const SHEAF_SCALE := 0.55

@export var size := Vector2i(6, 4):
	set(value):
		size = value
		_rebuild()

var _tufts: Dictionary = {} # cell: Vector2i -> CropVisual
var _sheaves: Array[Node2D] = []
var _built: Array[Node] = []
var _interactable: InteractableComponent
var _stage := 2
var _cut: Dictionary = {}

func _ready() -> void:
	_rebuild()

## `stage`: the CropVisual stage of the standing rice; `cut`: the cut tufts
## (cell -> true), shown as stubble, with a sheaf on the edge for every few.
func show_state(stage: int, cut: Dictionary) -> void:
	_stage = stage
	_cut = cut
	_show()

## What pressing interact here does ("" = nothing: no prompt).
func set_prompt(prompt: String) -> void:
	if _interactable == null:
		return
	_interactable.prompt_message = prompt
	_interactable.set_interactable(not prompt.is_empty())

## The standing tuft nearest to `point` (global), or (-1, -1) if all are cut.
func tuft_near(point: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for cell: Vector2i in _tufts:
		if _cut.has(cell):
			continue
		var distance := point.distance_to(get_tuft_position(cell))
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best

func get_tuft_position(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE - 4.0))

func get_rect() -> Rect2:
	return Rect2(global_position, Vector2(size * TILE))

func get_sheaf_count() -> int:
	return _sheaves.filter(func(sheaf): return sheaf.visible).size()

func _show() -> void:
	for cell: Vector2i in _tufts:
		var tuft: CropVisual = _tufts[cell]
		var cut := _cut.has(cell)
		tuft.show_stage(STUBBLE_STAGE if cut else _stage)
		tuft.modulate = STUBBLE_TINT if cut else Color.WHITE
	var sheaves := ceili(float(_cut.size()) / TUFTS_PER_SHEAF)
	for i in _sheaves.size():
		_sheaves[i].visible = i < sheaves

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for node in _built:
		node.queue_free()
	_built.clear()
	_tufts.clear()
	_sheaves.clear()
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

	# A tuft per cell, at the cell's bottom-center (CropVisual's foot).
	for cell in cells:
		var tuft: CropVisual = RICE_VISUAL.instantiate()
		tuft.position = to_local(get_tuft_position(cell))
		_own(tuft)
		_tufts[cell] = tuft

	# The sheaves' places, along the bottom edge (shown as tufts are cut).
	var count := int((size.x * TILE - 8.0) / SHEAF_SPACING)
	for i in count:
		var sheaf: Node2D = SHEAF.instantiate()
		sheaf.position = Vector2(16.0 + i * SHEAF_SPACING, size.y * TILE + 10.0 + (i % 2) * 3.0)
		sheaf.scale = Vector2.ONE * SHEAF_SCALE
		sheaf.visible = false
		# Drying on the dike, out of the way: no collision (the prop has one,
		# and it would stay on while the sheaf is hidden).
		sheaf.get_node("Base").free()
		_own(sheaf)
		_sheaves.append(sheaf)

	# Interact anywhere over the paddy - the nearest standing tuft is cut.
	if not Engine.is_editor_hint():
		_interactable = INTERACTABLE.instantiate()
		_own(_interactable)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(size * TILE)
		var collision: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
		collision.shape = shape
		collision.position = shape.size / 2.0
		_interactable.interacted.connect(interacted.emit)
		set_prompt("")
	_show()

func _own(node: Node) -> void:
	add_child(node)
	_built.append(node)

func _layer(layer_name: String, tiles: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tiles
	layer.z_index = z
	_own(layer)
	return layer

func _find_terrain(terrain_name: String) -> Vector2i:
	for terrain_set in FARM_TILESET.get_terrain_sets_count():
		for terrain in FARM_TILESET.get_terrains_count(terrain_set):
			if FARM_TILESET.get_terrain_name(terrain_set, terrain) == terrain_name:
				return Vector2i(terrain_set, terrain)
	return Vector2i(-1, -1)
