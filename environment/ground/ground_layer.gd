class_name GroundLayer
extends TileMapLayer

## The zone's ground, painted by hand in the editor - and its size: the
## painted area is the zone's playable area. ZoneRoot fits the camera limits
## and the invisible edge walls to it, so growing a village is just painting
## more ground.

## Bounding box of the painted tiles, in global coordinates.
func get_world_rect() -> Rect2:
	var used := get_used_rect()
	if used.size == Vector2i.ZERO:
		return Rect2()
	var tile := Vector2(tile_set.tile_size)
	var local := Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)
	return global_transform * local
