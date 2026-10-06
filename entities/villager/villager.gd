class_name Villager
extends CharacterBody2D

## A villager going about their day (VillagerData.routine): walks along the
## zone's roads (VillagerRoads) to each step's spot when its time comes,
## then stands, strolls around, or goes in (a house, a zone exit). Keeps the
## clock (DayNightController.CLOCK_GROUP) and the weather
## (WeatherController.WEATHER_GROUP): in the rain, only rain_proof steps
## happen - otherwise they stay home.
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
## STAND: turns every so often. WANDER: a few steps around the spot.
const TURN_EVERY := Vector2(3.0, 8.0)
const WANDER_RADIUS := 45.0
const WANDER_EVERY := Vector2(2.0, 6.0)

@export var data: VillagerData

@onready var _visual: VillagerVisual = $VillagerVisual
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _bubble: Label = $Bubble

var _roads: VillagerRoads
var _minute := 12 * 60
var _raining := false
var _clock_known := false
## The step being done (or walked to); null = at home.
var _stop: VillagerStop
var _path := PackedVector2Array()
var _inside := false
var _timer := 0.0
var _greet_cooldown := 0.0
var _bubble_time := 0.0
var _player: Node2D

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(DayNightController.CLOCK_GROUP)
	add_to_group(WeatherController.WEATHER_GROUP)
	_bubble.visible = false
	if data != null:
		_visual.look = data.look
		_visual.scale = Vector2.ONE * data.size
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

## The spot of the current step (home when there's none).
func get_spot_name() -> String:
	return _stop.spot if _stop != null else data.home

func _activity() -> VillagerStop.Activity:
	return _stop.activity if _stop != null else VillagerStop.Activity.INSIDE

## The step for now, the weather allowing; null = home.
func _wanted_stop() -> VillagerStop:
	var stop := data.get_stop(_minute)
	if stop != null and _raining and not stop.rain_proof:
		return null
	return stop

func _update_plan() -> void:
	if data == null:
		return
	if _roads == null:
		_roads = VillagerRoads.of_zone(owner)
		if _roads == null:
			push_warning("Villager %s: no VillagerRoads in the zone." % name)
			return
	var stop := _wanted_stop()
	if not _clock_known:
		# First tick after the zone loads: already there.
		_clock_known = true
		_stop = stop
		global_position = _roads.get_spot(get_spot_name())
		_arrive()
		return
	if stop == _stop:
		return
	_stop = stop
	# Comes out of where they were (a door, an exit) if they were in.
	_set_inside(false)
	_path = _roads.find_path(global_position, get_spot_name())

func _physics_process(delta: float) -> void:
	_bubble_time -= delta
	if _bubble.visible and _bubble_time <= 0.0:
		_bubble.visible = false
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
		_face_player()
		_try_greet()
		return
	_visual.play(Vector2.ZERO, false)
	_timer -= delta
	if _timer > 0.0:
		return
	match _activity():
		VillagerStop.Activity.STAND:
			# Looks around - mostly towards the camera, never long away.
			var directions := [Vector2.DOWN, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			_visual.play(directions.pick_random(), false)
			_timer = randf_range(TURN_EVERY.x, TURN_EVERY.y)
		VillagerStop.Activity.WANDER:
			var spot := _roads.get_spot(get_spot_name())
			_path = PackedVector2Array([spot + Vector2.from_angle(randf() * TAU) * randf_range(10.0, WANDER_RADIUS)])
			_timer = randf_range(WANDER_EVERY.x, WANDER_EVERY.y)

func _arrive() -> void:
	if _activity() == VillagerStop.Activity.INSIDE:
		_set_inside(true)
		return
	_set_inside(false)
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
	if _greet_cooldown > 0.0 or data.greetings.is_empty():
		return
	_greet_cooldown = GREET_COOLDOWN
	_bubble.text = tr(data.greetings[randi() % data.greetings.size()])
	_bubble.visible = true
	_bubble_time = BUBBLE_TIME
