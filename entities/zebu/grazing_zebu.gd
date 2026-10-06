class_name GrazingZebu
extends CharacterBody2D

## A free-roaming zebu in a pasture: grazes most of the time (head down,
## chewing), takes a few slow steps now and then, sometimes lies down to
## chew the cud. A calm animal: when the player comes close it raises its
## head and watches them, it doesn't run. Solid - the player walks around it.
##
## Keeps the hours (DayNightController.CLOCK_GROUP): with a ZebuPen nearby
## (ZebuPen.nearest), it walks into the pen from PEN_FROM, lies down there
## for the night and walks back to its pasture from PEN_UNTIL. Without one it
## just lies down where it is for the night (SLEEP_FROM .. WAKE_AT).
##
## Pure ambience (no simulation state, nothing saved). Herds are placed in
## the zone scenes by tools/place_zebu_herds.gd: each zebu wanders around
## where it was placed, within wander_radius. On the Animals physics layer,
## which it doesn't mask: zebus walk past each other, the player and the
## fences still stop them.

enum Activity { GRAZE, WALK, REST, GO_IN, PENNED, GO_OUT }

## Coat tints over the light sheet - a mixed herd, as in Madagascar.
const COATS := [
	Color(0.66, 0.45, 0.3), # brown
	Color(0.86, 0.7, 0.52), # fawn
	Color(0.6, 0.58, 0.56), # grey
	Color(0.32, 0.25, 0.21), # near-black
	Color(1.0, 0.97, 0.92), # white
]
const SPEED := 14.0
## Walking to and from the pen - a little brisker.
const COMMUTE_SPEED := 24.0
## Walking frame per this many px walked.
const STEP_DISTANCE := 5.0
const WATCH_DISTANCE := 72.0
## Without a pen: lies down for the night between these minutes of the day.
const SLEEP_FROM := 20 * 60
const WAKE_AT := 5 * 60 + 45
## With a pen: in the pen between these minutes (about the chickens' hours:
## the player sees the herd come home at dusk).
const PEN_FROM := 18 * 60
const PEN_UNTIL := 6 * 60 + 30
## Setting off one by one, not as a block.
const SET_OFF_DELAY_MAX := 8.0
## No pathfinding: one stuck on a tree or a corner for this long squeezes
## past it. The player isn't squeezed past - the zebu waits (_commute).
const STUCK_TIME := 1.5
const CHEW_PERIOD := 0.55
const FRAME_STAND := 0
const FRAME_GRAZE := [4, 5]
const FRAME_REST := 6
const FRAME_WATCH := 7

## How far from where it was placed it wanders.
@export var wander_radius := 110.0
## Index into COATS; -1 = picked at random.
@export var coat := -1

@onready var _sprite: Sprite2D = $Sprite2D

var _home: Vector2
var _activity := Activity.GRAZE
var _timer := 0.0
var _target := Vector2.ZERO
var _walked := 0.0
var _t := 0.0
var _minute := 12 * 60
var _player: Node2D
var _clock_known := false
var _pen: ZebuPen
var _spot := Vector2.ZERO
var _route: Array[Vector2] = []
var _stuck := 0.0

func _ready() -> void:
	add_to_group(DayNightController.CLOCK_GROUP)
	_home = global_position
	_sprite.self_modulate = COATS[coat if coat >= 0 else randi() % COATS.size()]
	_sprite.flip_h = randf() < 0.5
	_t = randf() * 10.0
	_start(Activity.GRAZE)

func set_time_of_day(minute_of_day: int) -> void:
	_minute = minute_of_day
	if not _clock_known:
		# First tick after the zone loads: find the pen, and be where the
		# hour says (already in the pen when arriving at night).
		_clock_known = true
		_pen = ZebuPen.nearest(self)
		if _pen != null:
			_spot = _pen.claim_spot()
			if _in_pen_hours():
				global_position = _spot
				_activity = Activity.PENNED
		return
	if _pen == null:
		return
	if _in_pen_hours() and _activity not in [Activity.GO_IN, Activity.PENNED]:
		_set_off(Activity.GO_IN, _pen.route_in(_spot))
	elif not _in_pen_hours() and _activity in [Activity.GO_IN, Activity.PENNED]:
		_set_off(Activity.GO_OUT, _pen.route_out(_home))

func has_pen() -> bool:
	return _pen != null

func is_penned() -> bool:
	return _activity == Activity.PENNED

func _in_pen_hours() -> bool:
	return _minute >= PEN_FROM or _minute < PEN_UNTIL

func _is_night() -> bool:
	return _minute >= SLEEP_FROM or _minute < WAKE_AT

func _physics_process(delta: float) -> void:
	_t += delta
	velocity = Vector2.ZERO
	match _activity:
		Activity.GO_IN, Activity.GO_OUT:
			_commute(delta)
			return
		Activity.PENNED:
			_sprite.frame = FRAME_REST
			return
	if _pen == null and _is_night():
		if _activity != Activity.REST:
			_start(Activity.REST)
		_timer = 1.0 # stays down until morning
		_sprite.frame = FRAME_REST
		return
	if _activity != Activity.REST and _player_close():
		# Head up, watching - a zebu doesn't bolt.
		_watch_player()
		return
	_timer -= delta
	match _activity:
		Activity.GRAZE:
			_sprite.frame = FRAME_GRAZE[int(_t / CHEW_PERIOD) % 2]
			if _timer <= 0.0:
				_next()
		Activity.REST:
			_sprite.frame = FRAME_REST
			if _timer <= 0.0:
				_start(Activity.GRAZE)
		Activity.WALK:
			_walk()

func _walk() -> void:
	var to_target := _target - global_position
	if to_target.length() < 4.0 or _timer <= 0.0:
		_start(Activity.GRAZE)
		return
	velocity = to_target.normalized() * SPEED
	var before := global_position
	move_and_slide()
	var moved := global_position.distance_to(before)
	if moved < SPEED * get_physics_process_delta_time() * 0.2:
		_start(Activity.GRAZE) # blocked: graze here instead
		return
	_step(moved, to_target.x)

## Into the pen / back out to the pasture, waypoint by waypoint.
func _set_off(activity: Activity, route: Array[Vector2]) -> void:
	_activity = activity
	_route = route
	_stuck = 0.0
	_timer = randf() * SET_OFF_DELAY_MAX

func _commute(delta: float) -> void:
	if _timer > 0.0:
		# Not off yet: still lying in the pen, or still grazing.
		_timer -= delta
		_sprite.frame = FRAME_REST if _activity == Activity.GO_OUT else FRAME_GRAZE[int(_t / CHEW_PERIOD) % 2]
		return
	if _route.is_empty():
		if _activity == Activity.GO_IN:
			_activity = Activity.PENNED
		else:
			_start(Activity.GRAZE)
		return
	var to_target := _route[0] - global_position
	if to_target.length() < 4.0:
		_route.pop_front()
		_stuck = 0.0
		return
	var before := global_position
	if _stuck > STUCK_TIME:
		global_position = global_position.move_toward(_route[0], COMMUTE_SPEED * delta)
	else:
		velocity = to_target.normalized() * COMMUTE_SPEED
		move_and_slide()
	var moved := global_position.distance_to(before)
	if moved < COMMUTE_SPEED * delta * 0.3:
		if _blocked_by_player():
			_watch_player() # waits for them to step aside
			return
		_stuck += delta
	_step(moved, to_target.x)

func _blocked_by_player() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and (collider as Node).is_in_group("player"):
			return true
	return false

func _step(moved: float, direction_x: float) -> void:
	_walked += moved
	if absf(direction_x) > 0.5:
		_sprite.flip_h = direction_x < 0.0
	_sprite.frame = int(_walked / STEP_DISTANCE) % 4

func _watch_player() -> void:
	_player_close() # makes sure _player is set
	_sprite.flip_h = _player.global_position.x < global_position.x
	_sprite.frame = FRAME_WATCH

## What to do after grazing a while.
func _next() -> void:
	var roll := randf()
	if roll < 0.55:
		_start(Activity.WALK)
	elif roll < 0.85:
		_start(Activity.GRAZE)
	else:
		_start(Activity.REST)

func _start(activity: Activity) -> void:
	_activity = activity
	match activity:
		Activity.GRAZE:
			_timer = randf_range(4.0, 10.0)
		Activity.REST:
			_timer = randf_range(15.0, 30.0)
		Activity.WALK:
			var offset := Vector2.from_angle(randf() * TAU) * randf_range(20.0, wander_radius)
			_target = _home + offset
			# A few slow steps: give up if it takes too long (something's in the way).
			_timer = global_position.distance_to(_target) / SPEED + 2.0

func _player_close() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player != null and global_position.distance_to(_player.global_position) < WATCH_DISTANCE
