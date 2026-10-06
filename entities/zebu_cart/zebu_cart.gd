class_name ZebuCart
extends PathFollow2D

## A zebu cart (sarety) driven along a road: a pair of yoked zebus walking,
## wheels turning, a driver on the box. Pure ambience - no simulation state,
## nothing saved.
##
## Place it as the child of a Path2D drawn along a road in the zone scene.
## It comes in from the path's start (off-screen), drives to the end (e.g.
## the market) and waits there a while, then drives back and disappears at
## the start, and comes back later. Roads should be mostly horizontal: the
## art is a side view (left/right).
##
## Origin = the ground under the cart's middle, so it y-sorts with the
## player (the Path2D must be y-sorted). It stops while the player stands in
## its way instead of pushing them, and only sets off during the day
## (DayNightController.CLOCK_GROUP) - a cart still out at dusk lights its
## lantern (a NightLight child).

const SPEED := 32.0
## No departures before / after these times (minute of the day).
const FIRST_DEPARTURE := 6 * 60 + 30
const LAST_DEPARTURE := 18 * 60 + 30
## Pause off-screen before coming back, and at the destination (seconds).
@export var away_time := Vector2(25.0, 60.0)
@export var stop_time := Vector2(8.0, 16.0)
## Delay before the first trip after the zone loads.
@export var first_delay := Vector2(2.0, 10.0)
## Size of the whole cart (art, body, "in the way" check). The art is laid
## out in Visual at 1:1; this scales it to sit right next to the player.
@export var art_scale := 1.6

## The art faces right; px walked per walking frame, wheel radius (in game px).
const STEP_DISTANCE := 7.0
const WHEEL_RADIUS := 19.0
const WALK_FRAMES := 4
## Body (what blocks the player) and the "someone in the way" check, for a
## cart facing right - mirrored when it faces left.
const BODY_CENTER_X := 32.0
const AHEAD_CENTER_X := 128.0

enum Leg { OUT, STOPPED, BACK, AWAY }

@onready var _visual: Node2D = $Visual
@onready var _zebus: Array[Sprite2D] = [$Visual/FarZebu, $Visual/NearZebu]
@onready var _wheels: Array[Sprite2D] = [$Visual/FarWheel, $Visual/NearWheel]
@onready var _body_shape: CollisionShape2D = $Body/CollisionShape2D
@onready var _ahead: Area2D = $Ahead
@onready var _ahead_shape: CollisionShape2D = $Ahead/CollisionShape2D

var _leg := Leg.AWAY
var _timer := 0.0
var _minute := 12 * 60
var _walked := 0.0
var _facing := 1.0

func _ready() -> void:
	rotates = false
	loop = false
	_visual.scale = Vector2(art_scale, art_scale)
	(_body_shape.shape as RectangleShape2D).size *= art_scale
	(_ahead_shape.shape as RectangleShape2D).size *= art_scale
	_body_shape.position *= art_scale
	_ahead_shape.position *= art_scale
	add_to_group(DayNightController.CLOCK_GROUP)
	_go_away()
	_timer = randf_range(first_delay.x, first_delay.y)

func set_time_of_day(minute_of_day: int) -> void:
	_minute = minute_of_day

func is_driving() -> bool:
	return _leg == Leg.OUT or _leg == Leg.BACK

func _physics_process(delta: float) -> void:
	match _leg:
		Leg.AWAY:
			_timer -= delta
			if _timer <= 0.0:
				if _minute >= FIRST_DEPARTURE and _minute <= LAST_DEPARTURE:
					_set_off()
				else:
					_timer = 5.0 # check again later
		Leg.STOPPED:
			_timer -= delta
			if _timer <= 0.0:
				_leg = Leg.BACK
		Leg.OUT, Leg.BACK:
			_drive(delta)

func _drive(delta: float) -> void:
	if _someone_in_the_way():
		_show_walk_frame(0)
		return
	var before := global_position
	progress += SPEED * delta * (1.0 if _leg == Leg.OUT else -1.0)
	var moved := global_position - before
	if absf(moved.x) > 0.01:
		_face(signf(moved.x))
	_walked += moved.length()
	for wheel in _wheels:
		wheel.rotation += moved.length() / WHEEL_RADIUS
	_show_walk_frame(int(_walked / STEP_DISTANCE) % WALK_FRAMES)
	if _leg == Leg.OUT and progress_ratio >= 1.0:
		_leg = Leg.STOPPED
		_timer = randf_range(stop_time.x, stop_time.y)
		_show_walk_frame(0)
	elif _leg == Leg.BACK and progress_ratio <= 0.0:
		_go_away()

func _set_off() -> void:
	progress_ratio = 0.0
	_leg = Leg.OUT
	visible = true
	_body_shape.set_deferred("disabled", false)

## Off-screen, hidden, until the next trip.
func _go_away() -> void:
	_leg = Leg.AWAY
	visible = false
	_body_shape.set_deferred("disabled", true)
	_timer = randf_range(away_time.x, away_time.y)

func _someone_in_the_way() -> bool:
	for body in _ahead.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false

## The art faces right; mirrored to face left. The body and the "ahead"
## check are moved rather than mirrored (no negative scale on physics).
func _face(direction: float) -> void:
	if direction == _facing:
		return
	_facing = direction
	_visual.scale.x = direction * art_scale
	_body_shape.position.x = BODY_CENTER_X * art_scale * direction
	_ahead_shape.position.x = AHEAD_CENTER_X * art_scale * direction

func _show_walk_frame(frame: int) -> void:
	for zebu in _zebus:
		zebu.frame = frame
