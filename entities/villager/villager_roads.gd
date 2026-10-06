class_name VillagerRoads
extends Node2D

## Where villagers can walk, for one zone: the roads are the Line2D
## children (drawn along the dirt paths in the editor, hidden in game), the
## places they go to are the Marker2Ds under Spots (house doors, the
## market, a bench, a zone exit...) - VillagerStop.spot names one.
##
## A spot named "Vers_<zone id>" is the way to that zone (where the road
## leaves the map): villagers headed there walk to it and go out, and come
## back in by it.
##
## Line points closer than MERGE_DISTANCE are one crossroads, so roads join
## by sharing a point. A spot hooks onto the nearest road point. Villagers
## walk the shortest way along the roads (AStar2D) - no navmesh: they keep
## to the paths, as people do.

const GROUP := "villager_roads"
const MERGE_DISTANCE := 12.0
const EXIT_PREFIX := "Vers_"

## The world zone these roads are in (a WorldManager zone id).
@export var zone_id := ""

var _astar := AStar2D.new()
var _spots := {}

func _ready() -> void:
	add_to_group(GROUP)
	for spot in get_node("Spots").get_children():
		if spot is Node2D:
			_spots[String(spot.name)] = spot.global_position
	for road in get_children():
		if road is Line2D:
			_add_road(road)
			road.visible = false # a guide for the editor only

## The spot leading to `zone`, or "" when there's none.
func exit_to(zone: String) -> String:
	return EXIT_PREFIX + zone if has_spot(EXIT_PREFIX + zone) else ""

func has_spot(spot_name: String) -> bool:
	return _spots.has(spot_name)

func get_spot(spot_name: String) -> Vector2:
	return _spots.get(spot_name, global_position)

## The way from `from` to the spot, along the roads: the road point
## nearest to `from`, then road point to road point, then the spot itself.
func find_path(from: Vector2, spot_name: String) -> PackedVector2Array:
	var target := get_spot(spot_name)
	if _astar.get_point_count() == 0:
		return PackedVector2Array([target])
	var start := _astar.get_closest_point(from)
	var end := _astar.get_closest_point(target)
	var path := _astar.get_point_path(start, end)
	path.append(target)
	return path

## The roads of `zone`, or null.
static func of_zone(zone: Node) -> VillagerRoads:
	for roads: VillagerRoads in zone.get_tree().get_nodes_in_group(GROUP):
		if roads.owner == zone or roads.get_parent() == zone:
			return roads
	return null

func _add_road(road: Line2D) -> void:
	var previous := -1
	for point in road.points:
		var id := _point_at(road.to_global(point))
		if previous != -1 and previous != id:
			_astar.connect_points(previous, id)
		previous = id

## The road point at `at` - an existing one within MERGE_DISTANCE (a
## crossroads), or a new one.
func _point_at(at: Vector2) -> int:
	if _astar.get_point_count() > 0:
		var closest := _astar.get_closest_point(at)
		if _astar.get_point_position(closest).distance_to(at) <= MERGE_DISTANCE:
			return closest
	var id := _astar.get_available_point_id()
	_astar.add_point(id, at)
	return id
