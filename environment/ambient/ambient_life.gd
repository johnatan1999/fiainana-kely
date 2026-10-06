class_name AmbientLife
extends Node2D

## A zone's ambient wildlife: butterflies over the grass, birds pecking on
## the ground that fly off when the player comes close (and land again
## elsewhere later), and now and then a flock crossing the sky with its
## shadows sliding over the ground. Purely cosmetic: no collision, no
## gameplay state, nothing saved - everything is spawned fresh when the zone
## loads. Drop one in a zone; use several for different species or areas
## (e.g. egrets kept to the paddies).
##
## Y-sorted, so birds on the ground sort with the player and the props;
## butterflies and flocks fly above everything (their own z_index).
##
## Follows the light (DayNightController.LIGHT_GROUP - it's all looks): at
## night butterflies are gone, birds fly off to roost and no flock passes -
## fireflies come out instead.

## Butterflies spawn over the zone's GrassLayer, inside `area`.
@export var butterfly_count := 8
@export var ground_bird_count := 6
## Species picked from for the ground birds - see AmbientBird.SPECIES.
@export var bird_species: PackedStringArray = ["fody", "myna"]
## Where everything spawns, in zone coordinates. Empty = the whole zone.
@export var area := Rect2()
@export var flocks := true
## Seconds between two flocks, picked in [x, y].
@export var flock_interval := Vector2(25.0, 60.0)
## Night only, over the grass like the butterflies.
@export var firefly_count := 10

## Spawn spots are re-rolled this many times until they're clear of solid
## things (walls, trunks, fences, deep water).
const SPAWN_TRIES := 20
## Kept clear along the zone's edges when spawning over the whole zone.
const EDGE_MARGIN := 64.0

var _rng := RandomNumberGenerator.new()
var _rect: Rect2
var _grass: TileMapLayer
## 0 by day, 1 at full night - see set_night().
var _night := 0.0
var _butterflies: Array[Butterfly] = []
var _fireflies: Array[Firefly] = []

func _ready() -> void:
	add_to_group(DayNightController.LIGHT_GROUP)
	y_sort_enabled = true
	_rng.randomize()
	var zone := get_parent()
	if area.has_area():
		_rect = area
	elif zone.has_method("get_camera_bounds"):
		# Not right against the zone's edges.
		_rect = zone.get_camera_bounds().grow(-EDGE_MARGIN)
	else:
		_rect = Rect2(0, 0, 1000, 1000)
	_grass = zone.get_node_or_null("GrassLayer") as TileMapLayer
	# Solid shapes are only queryable once the physics server has them.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	for i in butterfly_count:
		var butterfly := Butterfly.new()
		add_child(butterfly)
		butterfly.setup(_butterfly_spot(), _rng)
		_butterflies.append(butterfly)
	for i in firefly_count:
		var firefly := Firefly.new()
		add_child(firefly)
		firefly.setup(_butterfly_spot(), _rng)
		_fireflies.append(firefly)
	set_night(_night)
	for i in ground_bird_count:
		var bird := AmbientBird.new()
		add_child(bird)
		bird.setup_ground(bird_species[_rng.randi() % bird_species.size()], self, _rng)
	if flocks:
		_schedule_flock()

## Called by DayNightController as the light changes.
func set_night(amount: float) -> void:
	_night = amount
	for butterfly in _butterflies:
		butterfly.visible = not is_night()
	for firefly in _fireflies:
		firefly.visible = is_night()
	if is_night():
		for child in get_children():
			if child is AmbientBird:
				child.go_to_roost()

## Too dark for butterflies and birds, time for fireflies.
func is_night() -> bool:
	return _night > 0.6

## A clear spot on the ground for a bird to land, at least `min_distance`
## from `away_from` (the player, so birds never land right on them).
func pick_landing_spot(away_from: Vector2 = Vector2.INF, min_distance := 0.0) -> Vector2:
	var best := _random_point()
	for i in SPAWN_TRIES:
		var p := _random_point()
		if _is_clear(p) and (away_from == Vector2.INF or p.distance_to(away_from) >= min_distance):
			return p
		best = p
	return best

func _butterfly_spot() -> Vector2:
	if _grass:
		var cells := _grass.get_used_cells()
		for i in SPAWN_TRIES:
			if cells.is_empty():
				break
			var p := to_local(_grass.to_global(_grass.map_to_local(cells[_rng.randi() % cells.size()])))
			if _rect.has_point(p):
				return p
	return _random_point()

func _random_point() -> Vector2:
	return _rect.position + Vector2(_rng.randf(), _rng.randf()) * _rect.size

func _is_clear(p: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = to_global(p)
	query.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()

func _schedule_flock() -> void:
	get_tree().create_timer(_rng.randf_range(flock_interval.x, flock_interval.y), false).timeout.connect(_send_flock)

## 4 to 7 birds crossing the whole area in a loose V, high in the sky.
func _send_flock() -> void:
	if not is_inside_tree():
		return
	if is_night():
		_schedule_flock()
		return
	var going_right := _rng.randf() < 0.5
	var y := _rng.randf_range(_rect.position.y, _rect.end.y)
	var start_x := _rect.position.x - 80.0 if going_right else _rect.end.x + 80.0
	var direction := Vector2(1.0 if going_right else -1.0, _rng.randf_range(-0.25, 0.25)).normalized()
	var species := bird_species[_rng.randi() % bird_species.size()]
	var count := _rng.randi_range(4, 7)
	for i in count:
		var rank := (i + 1) / 2
		var side := 1.0 if i % 2 == 0 else -1.0
		var offset := -direction * rank * 22.0 + direction.orthogonal() * side * rank * 16.0
		var bird := AmbientBird.new()
		add_child(bird)
		bird.setup_flock(species, Vector2(start_x, y) + offset, direction, _rect.grow(160.0), _rng)
	_schedule_flock()
