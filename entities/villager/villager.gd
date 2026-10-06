class_name Villager
extends CharacterBody2D

## A villager going about their day (VillagerData.routine): walks along the
## zone's roads (VillagerRoads) to each step's spot when its time comes,
## then stands, strolls around, works bent over, or goes in (a house).
## Keeps the clock (DayNightController.CLOCK_GROUP) and the weather
## (WeatherController.WEATHER_GROUP): in the rain, only rain_proof steps
## happen - otherwise they stay home.
##
## Across zones: a villager who appears in several zones (the farmers, in
## the village and the rice fields) has one Villager node in each, with the
## same VillagerData. In a zone, a step elsewhere means walking out by the
## road to that zone ("Vers_<zone>") and disappearing; a step here after one
## elsewhere means coming in by that road, after ARRIVAL_DELAY (the trip).
##
## When the zone loads they're already where the hour says (no one walks
## from home at 15:00). Pure ambience: nothing saved.
##
## With the player: solid (the player walks around them); waits when the
## player is in the way; turns to the player who comes close and greets
## them now and then (a speech bubble).

const GROUP := "villagers"
const SPEED := 55.0
const ARRIVE_DISTANCE := 3.0
## The player this close ahead stops a walking villager.
const BLOCK_DISTANCE := 30.0
const GREET_DISTANCE := 60.0
const GREET_COOLDOWN := 45.0
const BUBBLE_TIME := 3.0
## STAND: turns every so often. WANDER: a few steps around the spot. WORK:
## a step along the row every so often, staying around the spot.
const TURN_EVERY := Vector2(3.0, 8.0)
const WANDER_RADIUS := 45.0
const WANDER_EVERY := Vector2(2.0, 6.0)
const WORK_STEP := 18.0
const WORK_EVERY := Vector2(5.0, 10.0)
## Coming in from another zone: the time the trip takes (seconds).
const ARRIVAL_DELAY := 12.0
## Several villagers at one spot (the hut at noon) stand apart: each has
## its own place around it, up to this far.
const SPOT_SPREAD := Vector2(20.0, 8.0)

@export var data: VillagerData

@onready var _visual: VillagerVisual = $VillagerVisual
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _bubble: Label = $Bubble

var _roads: VillagerRoads
var _minute := 12 * 60
var _raining := false
var _clock_known := false
## Where the villager is (or is going): the world zone, the spot there, what
## they do there. Not this zone = gone out by the road to it.
var _zone := ""
var _spot := ""
var _activity := VillagerStop.Activity.INSIDE
var _path := PackedVector2Array()
var _inside := false
var _arrival_delay := 0.0
var _timer := 0.0
var _work_direction := 1.0
var _greet_cooldown := 0.0
var _bubble_time := 0.0
var _player: Node2D
var _spot_offset := Vector2.ZERO
## Said instead of a greeting while set (e.g. NeighbourPaddyManager: "help
## us with the harvest?").
var call_out := ""

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(DayNightController.CLOCK_GROUP)
	add_to_group(WeatherController.WEATHER_GROUP)
	_bubble.visible = false
	if data != null:
		_visual.look = data.look
		_visual.scale = Vector2.ONE * data.size
		# The same place every day for one villager, a different one for each.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(data.display_name)
		_spot_offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * SPOT_SPREAD
	_set_inside(true) # until the clock says where they are

func set_time_of_day(minute_of_day: int) -> void:
	_minute = minute_of_day
	_update_plan()

func set_raining(raining: bool) -> void:
	_raining = raining
	if _clock_known:
		_update_plan()

func is_inside() -> bool:
	return _inside

func is_walking() -> bool:
	return not _path.is_empty()

func is_working() -> bool:
	return not _inside and _path.is_empty() and _activity == VillagerStop.Activity.WORK

## The spot they're at or going to, in this zone ("" = none).
func get_spot_name() -> String:
	return _spot

## [zone, spot, activity] for now, the weather allowing - in this zone's
## terms: a step in another zone is the road there, going out.
func _plan() -> Array:
	var stop := data.get_stop(_minute)
	if stop != null and _raining and not stop.rain_proof:
		stop = null
	var zone := data.home_zone
	var spot := data.home
	var activity := VillagerStop.Activity.INSIDE
	if stop != null:
		zone = stop.zone if not stop.zone.is_empty() else data.home_zone
		spot = stop.spot
		activity = stop.activity
	if zone != _roads.zone_id:
		spot = _road_to(zone)
		activity = VillagerStop.Activity.INSIDE
	return [zone, spot, activity]

## The exit towards `zone` - or, with no road there, the one towards home.
func _road_to(zone: String) -> String:
	var exit := _roads.exit_to(zone)
	return exit if not exit.is_empty() else _roads.exit_to(data.home_zone)

func _update_plan() -> void:
	if data == null:
		return
	if _roads == null:
		_roads = VillagerRoads.of_zone(owner)
		if _roads == null:
			push_warning("Villager %s: no VillagerRoads in the zone." % name)
			return
	var plan := _plan()
	if not _clock_known:
		# First tick after the zone loads: already there.
		_clock_known = true
		_set_plan(plan)
		if not _spot.is_empty():
			global_position = _spot_position()
		_arrive()
		return
	if plan == [_zone, _spot, _activity]:
		return
	var coming_from := _zone
	_set_plan(plan)
	var here := _roads.zone_id
	if _inside and coming_from != here:
		if _zone != here:
			return # from one elsewhere to another: never passes by
		# Back from another zone: comes in by the road from there, after the trip.
		var entry := _road_to(coming_from)
		if not entry.is_empty():
			global_position = _roads.get_spot(entry)
		_arrival_delay = ARRIVAL_DELAY
	elif _inside:
		_set_inside(false) # out of the door
	if _spot.is_empty():
		_set_inside(true)
		return
	_path = _roads.find_path(global_position, _spot)
	_path[_path.size() - 1] = _spot_position()

## This villager's own place at the spot.
func _spot_position() -> Vector2:
	return _roads.get_spot(_spot) + _spot_offset

## Where they are or are going (global), their position when nowhere.
func get_spot_position() -> Vector2:
	return _spot_position() if _roads != null and not _spot.is_empty() else global_position

func _set_plan(plan: Array) -> void:
	_zone = plan[0]
	_spot = plan[1]
	_activity = plan[2]
	_path.clear()

func _physics_process(delta: float) -> void:
	_bubble_time -= delta
	if _bubble.visible and _bubble_time <= 0.0:
		_bubble.visible = false
	if _arrival_delay > 0.0:
		_arrival_delay -= delta
		if _arrival_delay <= 0.0:
			_set_inside(false)
		return
	if _inside:
		return
	_greet_cooldown -= delta
	if not _path.is_empty():
		_walk(delta)
	else:
		_linger(delta)

func _walk(delta: float) -> void:
	var to_target := _path[0] - global_position
	if to_target.length() <= ARRIVE_DISTANCE:
		_path.remove_at(0)
		if _path.is_empty():
			_arrive()
		return
	var direction := to_target.normalized()
	if _player_in_way(direction):
		# Waits for them to step aside - and says hello.
		_face_player()
		_try_greet()
		return
	global_position += direction * minf(SPEED * delta, to_target.length())
	_visual.play(direction, true)

func _linger(delta: float) -> void:
	if _player_close():
		# Straightens up, turns to the player.
		_face_player()
		_try_greet()
		return
	_visual.play(Vector2.ZERO, false, _activity == VillagerStop.Activity.WORK)
	_timer -= delta
	if _timer > 0.0:
		return
	var spot := _roads.get_spot(_spot)
	match _activity:
		VillagerStop.Activity.STAND:
			# Looks around - mostly towards the camera.
			var directions := [Vector2.DOWN, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			_visual.play(directions.pick_random(), false)
			_timer = randf_range(TURN_EVERY.x, TURN_EVERY.y)
		VillagerStop.Activity.WANDER:
			_path = PackedVector2Array([spot + Vector2.from_angle(randf() * TAU) * randf_range(10.0, WANDER_RADIUS)])
			_timer = randf_range(WANDER_EVERY.x, WANDER_EVERY.y)
		VillagerStop.Activity.WORK:
			# Along the row, turning back at its end.
			var next := global_position + Vector2(_work_direction * WORK_STEP, 0.0)
			if absf(next.x - spot.x) > WANDER_RADIUS:
				_work_direction = -_work_direction
				next = global_position + Vector2(_work_direction * WORK_STEP, 0.0)
			_path = PackedVector2Array([next])
			_timer = randf_range(WORK_EVERY.x, WORK_EVERY.y)

func _arrive() -> void:
	if _activity == VillagerStop.Activity.INSIDE or _spot.is_empty():
		_set_inside(true)
		return
	_set_inside(false)
	if _activity == VillagerStop.Activity.WORK:
		# Facing along the row (the work art reads best from the side).
		_visual.play(Vector2(_work_direction, 0.0), false, true)
	else:
		_visual.play(Vector2.DOWN, false)
	_timer = randf_range(TURN_EVERY.x, TURN_EVERY.y)

func _set_inside(inside: bool) -> void:
	_inside = inside
	visible = not inside
	_shape.set_deferred("disabled", inside)
	if inside:
		_bubble.visible = false

# --- the player -----------------------------------------------------------------

func _find_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player

func _player_close() -> bool:
	var player := _find_player()
	return player != null and global_position.distance_to(player.global_position) < GREET_DISTANCE

func _player_in_way(direction: Vector2) -> bool:
	var player := _find_player()
	if player == null:
		return false
	var to_player := player.global_position - global_position
	return to_player.length() < BLOCK_DISTANCE and to_player.dot(direction) > 0.0

func _face_player() -> void:
	_visual.play(_find_player().global_position - global_position, false)

func _try_greet() -> void:
	if _greet_cooldown > 0.0 or (data.greetings.is_empty() and call_out.is_empty()):
		return
	_greet_cooldown = GREET_COOLDOWN
	say(call_out if not call_out.is_empty() else tr(data.greetings[randi() % data.greetings.size()]))

## Shows `text` (already translated) in the speech bubble for a moment.
func say(text: String) -> void:
	if _inside:
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_time = BUBBLE_TIME
