class_name GroundLayer
extends TileMapLayer

## Fills itself with the grass ground tile across a rectangular area, once, at
## scene load - the base outdoor ground beneath the farm plots, buildings and
## paths. Replaces the old flat-color "Floor" ColorRect placeholder.

const TILE_SOURCE_ID := 0
const TILE_GRASS := Vector2i(0, 3)

## Size of the area to fill, in tiles - set to cover the zone's playable rect.
@export var grid_width: int = 30
@export var grid_height: int = 34

#func _ready() -> void:
	#for y in range(grid_height):
		#for x in range(grid_width):
			#set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_GRASS)
