class_name GrazingZebu
extends CharacterBody2D

## A free-roaming zebu in a pasture: grazes most of the time (head down,
## chewing), takes a few slow steps now and then, sometimes lies down to
## chew the cud, and lies down for the night (DayNightController.CLOCK_GROUP).
## A calm animal: when the player comes close it raises its head and watches
## them, it doesn't run. Solid - the player walks around it.
##
## Pure ambience (no simulation state, nothing saved). Place a few in a zone
## scene - under a y-sorted node - where there's grass: each one wanders
## around where it was placed, within wander_radius.

enum Activity { GRAZE, WALK, REST }

## Coat tints over the light sheet - a mixed herd, as in Madagascar.
const COATS := [
	Color(0.66, 0.45, 0.3), # brown
	Color(0.86, 0.7, 0.52), # fawn
	Color(0.6, 0.58, 0.56), # grey
	Color(0.32, 0.25, 0.21), # near-black
	Color(1.0, 0.97, 0.92), # white
]
const SPEED := 14.0
## Walking frame per this many px walked.
const STEP_DISTANCE := 5.0
const WATCH_DISTANCE := 72.0
## Lies down for the night between these minutes of the day.
const SLEEP_FROM := 20 * 60
const WAKE_AT := 5 * 60 + 45
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

func _ready() -> void:
	add_to_group(DayNightController.CLOCK_GROUP)
	_home = global_position
	_sprite.self_modulate = COATS[coat if coat >= 0 else randi() % COATS.size()]
	_sprite.flip_h = randf() < 0.5
	_t = randf() * 10.0
	_start(Activity.GRAZE)

func set_time_of_day(minute_of_day: int) -> void:
	_minute = minute_of_day

func _is_night() -> bool:
	return _minute >= SLEEP_FROM or _minute < WAKE_AT

func _physics_process(delta: float) -> void:
	_t += delta
	velocity = Vector2.ZERO
	if _is_night():
		if _activity != Activity.REST:
			_start(Activity.REST)
		_timer = 1.0 # stays down until morning
		_sprite.frame = FRAME_REST
		return
	if _activity != Activity.REST and _player_close():
		# Head up, watching - a zebu doesn't bolt.
		_sprite.flip_h = _player.global_position.x < global_position.x
		_sprite.frame = FRAME_WATCH
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
	_walked += moved
	_sprite.flip_h = to_target.x < 0.0
	_sprite.frame = int(_walked / STEP_DISTANCE) % 4

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
