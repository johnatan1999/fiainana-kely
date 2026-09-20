class_name FarmZoneData
extends Resource

## Static definition of one predefined, buy-in-one-shot land zone (macro
## progression). Authored as a rectangle (origin + size) for convenience -
## get_tile_coordinates() expands it into the explicit tile list ZoneManager
## actually unlocks.

@export var id: String
@export var display_name: String
@export var malagasy_name: String = ""
@export var description: String = ""
@export var price: int = 0

## Rectangle in farm-grid coordinates (same space as FarmSimulation plot
## positions), relative to FarmView's own origin.
@export var origin: Vector2i = Vector2i.ZERO
@export var size: Vector2i = Vector2i.ONE

func get_tile_coordinates() -> Array:
	var coordinates: Array = []
	for y in range(size.y):
		for x in range(size.x):
			coordinates.append(origin + Vector2i(x, y))
	return coordinates

func get_tile_count() -> int:
	return size.x * size.y
