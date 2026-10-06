@tool
class_name FarmField
extends TileMapLayer

## One predefined group of farmable plots, designed in the editor: select the
## field and paint its cells (TileMap panel, "Arable" terrain) - the painted
## cells ARE the field's plots. When its zone loads, FarmLandManager
## registers them (owned from the start, bought in one go, or bought a few
## at a time depending on `kind`), and FarmView hands back each cell's soil
## state to draw.
##
## Place it as a child of FarmView: its position snaps to the plot grid, and
## its cells live in FarmView's grid space - the same (x, y) space as
## FarmSimulation's plot positions. Moving a field after saves exist moves
## its cells too: plots saved at the old cells lose their soil.
##
## At runtime the field repaints itself with only its owned cells; the rest
## is drawn as locked fallow, and tilled/wet soil is autotiled on top - so
## neighbouring plots merge into one field with rounded borders.

enum Kind {
	STARTER, ## Owned from the start of the game.
	ZONE, ## Bought in one go from a FarmZoneSign - see zone_data.
	PROGRESSIVE, ## Bought a few cells at a time from the ModularFarmZoneSign, row by row.
}

## Same as PlotView.CELL_SIZE - duplicated rather than referenced so this
## @tool script never drags gameplay scripts into the editor.
const CELL_SIZE := 48.0
const LOCKED_TINT := Color(0.55, 0.55, 0.55, 0.75)
## Used when the tileset has no wet terrain: tilled soil, darkened.
const WET_TINT := Color(0.62, 0.5, 0.42)
const EDITOR_OUTLINE_COLOR := Color(1.0, 0.85, 0.3, 0.9)
const EDITOR_WATER_COLOR := Color(0.3, 0.55, 0.75, 0.35)
## Paddy water drawn over the soil of a flooded field: tile (0, 0) of the
## water tileset is shallow and walkable.
const WATER_TILESET := preload("res://assets/tileset/water_tileset.tres")
const PADDY_WATER_MATERIAL := preload("res://environment/water/paddy_water_material.tres")
const PADDY_WATER_TILE := Vector2i(0, 0)

@export var kind: Kind = Kind.ZONE:
	set(value):
		kind = value
		_editor_changed()
## Name, description and price of the field - required for Kind.ZONE,
## ignored otherwise.
@export var zone_data: FarmZoneData:
	set(value):
		zone_data = value
		_editor_changed()
## Rice paddy: its plots are always irrigated and only take paddy crops
## (CropData.grows_in_paddy) - see PlotState.flooded. Drawn under shallow
## water, walkable like any field.
@export var flooded := false:
	set(value):
		flooded = value
		_editor_changed()

@export_group("Terrains")
## Terrain names in the tileset's terrain set (TileSet > Terrains), looked up
## by name so reordering terrains there is safe.
@export var arable_terrain_name := "Arable"
@export var tilled_terrain_name := "Tilled"
## Optional: missing or empty, wet soil reuses the tilled terrain tinted by WET_TINT.
@export var wet_terrain_name := "Wet"

var _cells: Array[Vector2i] = []
var _cells_read := false
var _locked_layer: TileMapLayer
var _tilled_layer: TileMapLayer
var _wet_layer: TileMapLayer
var _water_layer: TileMapLayer # flooded only: water over the owned cells
var _locked_water_layer: TileMapLayer # ...and over the locked ones, tinted
var _arable_terrain := Vector2i(-1, -1) # (terrain_set, terrain)
var _tilled_terrain := Vector2i(-1, -1)
var _wet_terrain := Vector2i(-1, -1)

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		changed.connect(_editor_changed)
		return
	# Below the y-sorted crops and the player, like any ground.
	z_index = -1
	get_cells() # cached before the field gets repainted with owned cells only
	_create_runtime_layers()

## This field's cells in FarmView's grid space (FarmSimulation plot positions).
func get_cells() -> Array[Vector2i]:
	if _cells_read and not Engine.is_editor_hint():
		return _cells
	_cells.clear()
	var origin := get_grid_origin()
	for cell in get_used_cells():
		_cells.append(origin + cell)
	_cells_read = true
	return _cells

## Where the field's cell (0, 0) is in its zone's plot grid (FarmView's).
func get_grid_origin() -> Vector2i:
	return Vector2i((position / CELL_SIZE).round())

## Redraws the soil. `owned`: set (Vector2i -> true) of the cells that have a
## plot, i.e. were bought; every other cell of the field is locked fallow.
## `tilled` and `wet` are subsets of the owned cells. All in grid space.
func show_soil(owned: Dictionary, tilled: Array[Vector2i], wet: Array[Vector2i]) -> void:
	var origin := get_grid_origin()
	var owned_local: Array[Vector2i] = []
	var locked_local: Array[Vector2i] = []
	for cell in get_cells():
		if owned.has(cell):
			owned_local.append(cell - origin)
		else:
			locked_local.append(cell - origin)
	if _arable_terrain.x != -1:
		_paint(self, owned_local, _arable_terrain)
		_paint(_locked_layer, locked_local, _arable_terrain)
	_paint(_tilled_layer, _to_local(tilled, origin), _tilled_terrain)
	_paint(_wet_layer, _to_local(wet, origin), _wet_terrain)
	if flooded:
		_flood(_water_layer, owned_local)
		_flood(_locked_water_layer, locked_local)

func _create_runtime_layers() -> void:
	_arable_terrain = _find_terrain(arable_terrain_name)
	_tilled_terrain = _find_terrain(tilled_terrain_name)
	_wet_terrain = _find_terrain(wet_terrain_name)
	if _arable_terrain.x == -1:
		push_warning("FarmField %s: no terrain named '%s' - the painted tiles are kept as-is, locked cells won't show" % [name, arable_terrain_name])
	if _tilled_terrain.x == -1:
		push_error("FarmField %s: no terrain named '%s' - tilled soil won't be drawn" % [name, tilled_terrain_name])
	_locked_layer = _add_layer("LockedLayer")
	_locked_layer.modulate = LOCKED_TINT
	_locked_layer.show_behind_parent = true
	# Children draw over the field itself, in tree order: tilled, then wet.
	_tilled_layer = _add_layer("TilledLayer")
	_wet_layer = _add_layer("WetLayer")
	if _wet_terrain.x == -1:
		_wet_terrain = _tilled_terrain
		_wet_layer.modulate = WET_TINT
	if flooded:
		# Over all the soil above (children draw in tree order); crops are
		# PlotViews, above the whole field.
		_water_layer = _add_layer("WaterLayer")
		_locked_water_layer = _add_layer("LockedWaterLayer")
		_locked_water_layer.modulate = LOCKED_TINT
		for layer in [_water_layer, _locked_water_layer]:
			layer.tile_set = WATER_TILESET
			layer.material = PADDY_WATER_MATERIAL

func _add_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	add_child(layer)
	return layer

## Repaints the whole layer at once: a cell's autotile depends on its 8
## neighbours, so painting cell by cell would leave stale borders.
func _paint(layer: TileMapLayer, cells: Array[Vector2i], terrain: Vector2i) -> void:
	layer.clear()
	if terrain.x != -1 and not cells.is_empty():
		layer.set_cells_terrain_connect(cells, terrain.x, terrain.y)

func _flood(layer: TileMapLayer, cells: Array[Vector2i]) -> void:
	layer.clear()
	for cell in cells:
		layer.set_cell(cell, 0, PADDY_WATER_TILE)

func _to_local(cells: Array[Vector2i], origin: Vector2i) -> Array[Vector2i]:
	var local: Array[Vector2i] = []
	for cell in cells:
		local.append(cell - origin)
	return local

## (terrain_set, terrain) of the terrain called `terrain_name`, or (-1, -1).
func _find_terrain(terrain_name: String) -> Vector2i:
	if terrain_name.is_empty() or tile_set == null:
		return Vector2i(-1, -1)
	for terrain_set in tile_set.get_terrain_sets_count():
		for terrain in tile_set.get_terrains_count(terrain_set):
			if tile_set.get_terrain_name(terrain_set, terrain) == terrain_name:
				return Vector2i(terrain_set, terrain)
	return Vector2i(-1, -1)

# --- Editor ------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		# Snap to the plot grid, or the field's cells wouldn't line up with
		# the plots FarmView targets.
		var snapped_position := (position / CELL_SIZE).round() * CELL_SIZE
		if snapped_position != position:
			position = snapped_position

func _editor_changed() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		queue_redraw()
		update_configuration_warnings()

## Outline of the painted area plus what the field is, so a field's role is
## readable in the editor without opening the inspector.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var used := get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var rect := Rect2(Vector2(used.position) * CELL_SIZE, Vector2(used.size) * CELL_SIZE)
	if flooded:
		for cell in get_used_cells():
			draw_rect(Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE), EDITOR_WATER_COLOR)
	draw_rect(rect, EDITOR_OUTLINE_COLOR, false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(4, 16), _editor_title(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, EDITOR_OUTLINE_COLOR)

func _editor_title() -> String:
	var cell_count := get_used_cells().size()
	match kind:
		Kind.STARTER:
			return "Champ de départ (%d)" % cell_count
		Kind.PROGRESSIVE:
			return "Zone progressive (%d)" % cell_count
	var zone_id := zone_data.id if zone_data else "?"
	return "%s %s (%d)" % ["Rizière" if flooded else "Zone", zone_id, cell_count]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_used_cells().is_empty():
		warnings.append("Peins les cellules cultivables (terrain « Arable »).")
	if kind == Kind.ZONE and zone_data == null:
		warnings.append("Une zone achetable a besoin d'un FarmZoneData (nom, prix...).")
	if get_parent() != null and not get_parent() is FarmView:
		warnings.append("Un FarmField doit être enfant de FarmView pour être dans la grille des parcelles.")
	return warnings
