class_name Dog
extends Node2D

## The family's dog (alika), a companion: DogManager puts it in the zone and
## says what it's doing - never anything decided here:
## - FOLLOW: at the player's heels, on the path they walked (a trail of
##   their positions: it goes round what they went round, with no physics
##   and no pathfinding). Lagging behind, it runs. The player still, it sits
##   (wagging), sniffs about, then lies down;
## - GUARD: at night, at its doghouse: asleep in front of the door, it
##   lifts its head when the player comes near, and barks at the dark now and
##   then - more often when thieves are about (`restless`);
## - LEAVE: trots off and fades (off home to the farm for the night).
## Petted ("[E] Caresser Tsiky"): a happy face and a heart; `petted` tells
## DogManager. Barks through AudioManager, quieter from further away.
## Solid to nothing: it never gets in the player's way.

signal petted

enum Mode { FOLLOW, GUARD, LEAVE }

## Coat tints over the light sheet (DogRules.DOG_COATS of them): a
## tan village dog, black, brown, cream.
const COATS := [
	Color(0.88, 0.63, 0.36),
	Color(0.34, 0.29, 0.26),
	Color(0.62, 0.42, 0.27),
	Color(1.0, 0.96, 0.88),
]
## Sheet cells (assets/sprites/animals/dog.png, tools/placeholder_art/gen_dog.gd).
const FRAMES_TROT := [0, 1, 2, 3]
const FRAMES_SIT := [4, 5]
const FRAME_LIE := 6
const FRAME_SLEEP := 7
const FRAME_BARK := 8
const FRAME_SNIFF := 9
const FRAME_HAPPY := 10
const FRAME_PETTED := 11
const SPRITE_SCALE := 0.62
## A puppy's size, the day it comes (it grows over DogRules.DOG_GROWN_DAYS).
const PUPPY_SCALE := 0.65

## How far behind the player it keeps, along their path.
const FOLLOW_DISTANCE := 56.0
## A trail point every this many px the player walks.
const TRAIL_STEP := 10.0
const TRAIL_MAX := 150
const WALK_SPEED := 170.0
const RUN_SPEED := 440.0
## Further behind than that, it runs.
const RUN_BEYOND := 120.0
## Further than that (the player was moved: a door, waking up), it's put
## back at their heels.
const LOST_BEYOND := 700.0
## A trotting frame per this many px.
const STEP_DISTANCE := 7.0
## The player still: wagging, sitting, sniffing about, then lying down
## (seconds since it stopped).
const WAG_UNTIL := 2.0
const SNIFF_FROM := 4.0
const SNIFF_UNTIL := 5.5
const LIE_AFTER := 9.0
## At its doghouse, the player this close: head up.
const NOTICE_DISTANCE := 110.0
## Seconds between night barks, calm or with thieves about.
const NIGHT_BARK_CALM := Vector2(25, 60)
const NIGHT_BARK_RESTLESS := Vector2(6, 14)
const BARK_GAP := 0.32
## Barks are this much quieter per px away (dB), down to BARK_MIN_DB.
const BARK_DB_PER_PX := 0.025
const BARK_MIN_DB := -22.0
const HAPPY_TIME := 1.6
## Where "pet it" reaches, around InteractableComponent.
const PET_AREA := Vector2(64, 56)
const LEAVE_FADE := 1.2

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interactable: InteractableComponent = $InteractableComponent

var mode := Mode.FOLLOW
## Thieves about tonight (ThiefRules.is_thief_alert): it barks more.
var restless := false

var _player: PlayerController
var _trail: Array[Vector2] = []
var _bed := Vector2.ZERO
var _idle := 0.0
var _walked := 0.0
var _t := 0.0
var _happy := 0.0
var _barks_left := 0
var _bark_timer := 0.0
var _night_bark := 0.0

func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	var box := RectangleShape2D.new()
	box.size = PET_AREA
	(_interactable.get_node("InteractableCollision2D") as CollisionShape2D).shape = box
	_night_bark = randf_range(NIGHT_BARK_CALM.x, NIGHT_BARK_CALM.y) / 3.0

## Whose dog it is, its coat (index in COATS), how grown it is (0 to 1),
## its name. Before anything else.
func setup(player: PlayerController, coat: int, growth: float, dog_name: String) -> void:
	_player = player
	_sprite.self_modulate = COATS[clampi(coat, 0, COATS.size() - 1)]
	_sprite.scale = Vector2.ONE * SPRITE_SCALE * lerpf(PUPPY_SCALE, 1.0, growth)
	set_dog_name(dog_name)

func set_dog_name(dog_name: String) -> void:
	_interactable.prompt_message = tr("Caresser %s") % dog_name

## At the player's heels from now on.
func follow() -> void:
	mode = Mode.FOLLOW
	_trail.clear()
	_idle = 0.0

## Off to its doghouse for the night - or there already (`at_once`).
func guard(bed: Vector2, at_once := false) -> void:
	mode = Mode.GUARD
	_bed = bed
	if at_once:
		global_position = bed
		_sprite.frame = FRAME_SLEEP

## Trots off and fades out, then it's gone.
func leave() -> void:
	mode = Mode.LEAVE
	_interactable.set_interactable(false)

## `count` barks, a breath apart.
func bark(count := 2) -> void:
	_barks_left = count
	_bark_timer = 0.0

func is_following() -> bool:
	return mode == Mode.FOLLOW

func is_guarding() -> bool:
	return mode == Mode.GUARD

func is_barking() -> bool:
	return _barks_left > 0

func is_asleep() -> bool:
	return _sprite.frame == FRAME_SLEEP

func get_frame() -> int:
	return _sprite.frame

func _on_interacted() -> void:
	_happy = HAPPY_TIME
	_idle = 0.0
	_sprite.flip_h = _player.global_position.x < global_position.x
	petted.emit()

func _physics_process(delta: float) -> void:
	_t += delta
	if _happy > 0.0:
		_happy -= delta
		queue_redraw()
	match mode:
		Mode.FOLLOW:
			_follow(delta)
		Mode.GUARD:
			_guard(delta)
		Mode.LEAVE:
			_leave(delta)
	_bark_step(delta)

# --- following ----------------------------------------------------------------------------

func _follow(delta: float) -> void:
	var target := _player.global_position
	if global_position.distance_to(target) > LOST_BEYOND:
		put_near_player()
		return
	if _trail.is_empty() or _trail[-1].distance_to(target) >= TRAIL_STEP:
		_trail.append(target)
		if _trail.size() > TRAIL_MAX:
			_trail.pop_front()
	var behind := _path_left()
	if behind <= FOLLOW_DISTANCE:
		_rest(delta)
		return
	_idle = 0.0
	var speed := RUN_SPEED if behind > RUN_BEYOND else WALK_SPEED
	_move_along(minf(speed * delta, behind - FOLLOW_DISTANCE))

## Back at the player's heels, behind them.
func put_near_player() -> void:
	global_position = _player.global_position - _player.last_facing_direction.normalized() * FOLLOW_DISTANCE
	_trail.clear()

## How far it still is from the player, along their trail.
func _path_left() -> float:
	if _trail.is_empty():
		return 0.0
	var length := global_position.distance_to(_trail[0])
	for i in range(1, _trail.size()):
		length += _trail[i - 1].distance_to(_trail[i])
	return length

func _move_along(step: float) -> void:
	var before := global_position
	while step > 0.0 and not _trail.is_empty():
		var to_point := _trail[0] - global_position
		if to_point.length() <= step:
			global_position = _trail[0]
			step -= to_point.length()
			_trail.pop_front()
		else:
			global_position += to_point.normalized() * step
			step = 0.0
	_trot(global_position.distance_to(before), global_position.x - before.x)

func _trot(moved: float, dx: float) -> void:
	_walked += moved
	_sprite.frame = FRAMES_TROT[int(_walked / STEP_DISTANCE) % 4]
	if absf(dx) > 0.05:
		_sprite.flip_h = dx < 0.0

## The player still: it sits by them, wagging, sniffs about, lies down.
func _rest(delta: float) -> void:
	_idle += delta
	if _barks_left > 0:
		return
	if _happy > 0.0:
		_sprite.frame = FRAME_PETTED if _happy < HAPPY_TIME / 2.0 else FRAME_HAPPY
		return
	if _idle < SNIFF_FROM:
		_sprite.flip_h = _player.global_position.x < global_position.x
	if _idle < WAG_UNTIL:
		_sprite.frame = FRAMES_SIT[int(_t * 5.0) % 2]
	elif _idle >= SNIFF_FROM and _idle < SNIFF_UNTIL:
		_sprite.frame = FRAME_SNIFF
	elif _idle < LIE_AFTER:
		_sprite.frame = FRAMES_SIT[0]
	else:
		_sprite.frame = FRAME_LIE

# --- at its doghouse -----------------------------------------------------------------------

func _guard(delta: float) -> void:
	var to_bed := _bed - global_position
	if to_bed.length() > 3.0:
		var before := global_position
		global_position = global_position.move_toward(_bed, WALK_SPEED * delta)
		_trot(global_position.distance_to(before), global_position.x - before.x)
		return
	_night_bark -= delta
	if _night_bark <= 0.0:
		var gap := NIGHT_BARK_RESTLESS if restless else NIGHT_BARK_CALM
		_night_bark = randf_range(gap.x, gap.y)
		bark(randi_range(2, 3))
	if _barks_left > 0:
		return
	if _happy > 0.0:
		_sprite.frame = FRAME_PETTED
		return
	if _player.global_position.distance_to(global_position) < NOTICE_DISTANCE:
		_sprite.frame = FRAME_LIE
		_sprite.flip_h = _player.global_position.x < global_position.x
	else:
		_sprite.frame = FRAME_SLEEP

# --- leaving, barking ----------------------------------------------------------------------

func _leave(delta: float) -> void:
	var away := Vector2.RIGHT
	if _player.global_position.distance_to(global_position) > 1.0:
		away = (global_position - _player.global_position).normalized()
	var before := global_position
	global_position += away * WALK_SPEED * delta
	_trot(global_position.distance_to(before), away.x)
	modulate.a -= delta / LEAVE_FADE
	if modulate.a <= 0.0:
		queue_free()

func _bark_step(delta: float) -> void:
	if _barks_left <= 0:
		return
	_sprite.frame = FRAME_BARK
	_bark_timer -= delta
	if _bark_timer > 0.0:
		return
	var distance := _player.global_position.distance_to(global_position)
	AudioManager.play_dog_bark_sfx(maxf(-distance * BARK_DB_PER_PX, BARK_MIN_DB))
	_barks_left -= 1
	_bark_timer = BARK_GAP
	if _barks_left > 0 or not is_inside_tree():
		return
	# The last one: a "Wouf !" over its head.
	HarvestPopup.spawn(get_parent(), global_position + Vector2(0, -56), null, tr("Wouf !"))

# --- the heart, petted --------------------------------------------------------------------

func _draw() -> void:
	if _happy <= 0.0:
		return
	var rise := 1.0 - _happy / HAPPY_TIME
	var at := Vector2(0, -58 - rise * 22.0)
	var color := Color(0.9, 0.2, 0.3, minf(1.0, _happy * 2.0))
	draw_circle(at + Vector2(-3.5, -2), 4.0, color)
	draw_circle(at + Vector2(3.5, -2), 4.0, color)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-7.3, -0.5), at + Vector2(7.3, -0.5), at + Vector2(0, 7)]), color)
