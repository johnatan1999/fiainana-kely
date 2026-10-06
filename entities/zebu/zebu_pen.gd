class_name ZebuPen
extends Node2D

## A zebu pen (vala): a fenced enclosure the nearby GrazingZebus walk into at
## dusk and out of in the morning. Self-contained - its fence is its own
## TileMapLayer - so it's placed and moved as one piece.
##
## Markers (move them in the scene if the pen's shape changes):
## - Gate: just outside the opening, where the zebus line up to go in;
## - Entrance: just inside it;
## - Spots/*: where they lie down for the night, one each (several zebus
##   share a spot, a little apart, when there are more zebus than spots).
##
## Place it on the ground grid (its origin is a fence cell's corner), with
## the opening facing the pasture: the zebus walk in a straight line from
## the pasture to Gate - no pathfinding.

const GROUP := "zebu_pens"
## A zebu farther than this from every pen has none (it sleeps in the field).
const REACH := 700.0

@onready var _gate: Marker2D = $Gate
@onready var _entrance: Marker2D = $Entrance
@onready var _spots: Array[Node] = $Spots.get_children()

var _claimed := 0

func _ready() -> void:
	add_to_group(GROUP)

## The pen `zebu` belongs to: the nearest one of its own zone within REACH,
## or null. Same zone = same owner (both placed in the zone scene) - while a
## zone reloads, the old one's pen is still around until it's freed.
static func nearest(zebu: Node2D) -> ZebuPen:
	var best: ZebuPen = null
	var best_distance := REACH
	for pen: ZebuPen in zebu.get_tree().get_nodes_in_group(GROUP):
		if pen.owner != zebu.owner or pen.is_queued_for_deletion():
			continue
		var distance := zebu.global_position.distance_to(pen.global_position)
		if distance < best_distance:
			best = pen
			best_distance = distance
	return best

## A spot of its own for the night, in global coordinates.
func claim_spot() -> Vector2:
	var index := _claimed
	_claimed += 1
	var spot: Node2D = _spots[index % _spots.size()]
	return spot.global_position + Vector2(10, 6) * (index / _spots.size())

func route_in(spot: Vector2) -> Array[Vector2]:
	return [_gate.global_position, _entrance.global_position, spot]

func route_out(pasture: Vector2) -> Array[Vector2]:
	return [_entrance.global_position, _gate.global_position, pasture]
