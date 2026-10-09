@tool
class_name CockfightRing
extends Node2D

## The cockfight ring (kianja ady akoho) of the market town: a circle of
## trampled earth inside a cord on bamboo stakes, and its signboard. During
## the Sunday tournament (FarmSimulation.COCKFIGHT_DAY and _HOURS), two
## villagers' roosters square up in it, for the crowd. Only shows that and
## passes the player's interaction on - CockfightManager decides (the
## tournament, the ranking). Drawn in code; @tool: the ring shows in the
## editor too. Group "cockfight_rings".

signal interacted

const GROUP := "cockfight_rings"
const FRAMES := preload("res://data/rooster.tres")
const SIGNBOARD := preload("res://entities/props/signboard.tscn")
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")
## The ring's half-size (an ellipse, seen from above at an angle).
const RADII := Vector2(80, 38)
const STAKES := 14
const STAKE_HEIGHT := 14.0
const EARTH_COLOR := Color(0.55, 0.38, 0.24, 0.85)
const EARTH_EDGE := Color(0.45, 0.3, 0.18, 0.9)
const STAKE_COLOR := Color(0.62, 0.55, 0.3)
const CORD_COLOR := Color(0.85, 0.78, 0.6)
## The two roosters of the show: how far apart, and how often they lunge.
const SHOW_GAP := 26.0
const LUNGE_EVERY := Vector2(1.2, 3.0)
const ROOSTER_SCALE := 0.55
const SHOW_TINT := Color(1, 0.86, 0.62)

var _interactable: InteractableComponent
var _show: Array[AnimatedSprite2D] = []
var _weekday := GameClock.Weekday.MONDAY
var _minute := GameClock.DAY_START_MINUTE
var _lunge_in := 0.0
var _prompt_on := ""
var _prompt_off := ""

func _ready() -> void:
	y_sort_enabled = true
	# On the ground: under everything y-sorted, over the grass layers.
	var floor := _Floor.new()
	floor.name = "Floor"
	floor.z_index = -7
	add_child(floor)
	var sign_node: Node2D = SIGNBOARD.instantiate()
	sign_node.name = "Sign"
	sign_node.position = Vector2(-RADII.x - 56, RADII.y * 0.4)
	sign_node.set("text", "ADY AKOHO")
	add_child(sign_node)
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(DayNightController.CLOCK_GROUP)
	add_to_group(DayNightController.CALENDAR_GROUP)
	_interactable = INTERACTABLE.instantiate()
	_interactable.name = "InteractableComponent"
	add_child(_interactable)
	var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
	var box := RectangleShape2D.new()
	box.size = RADII * 2.0 + Vector2(30, 30)
	area.shape = box
	_interactable.interacted.connect(interacted.emit)
	for side in [-1.0, 1.0]:
		var rooster := AnimatedSprite2D.new()
		rooster.sprite_frames = FRAMES
		rooster.scale = Vector2.ONE * ROOSTER_SCALE
		rooster.offset = Vector2(0, -32)
		rooster.position = Vector2(side * SHOW_GAP, 4)
		rooster.play("idle_right" if side < 0.0 else "idle_left")
		if side > 0.0:
			rooster.modulate = SHOW_TINT
		add_child(rooster)
		_show.append(rooster)
	_refresh_show()

func set_time_of_day(minute_of_day: int) -> void:
	var was_on := is_tournament_on()
	_minute = minute_of_day
	if is_tournament_on() != was_on:
		_refresh_show()

func set_weekday(weekday: int) -> void:
	_weekday = weekday as GameClock.Weekday
	_refresh_show()

func is_tournament_on() -> bool:
	return _weekday == FarmSimulation.COCKFIGHT_DAY and _minute >= FarmSimulation.COCKFIGHT_HOURS.x \
		and _minute < FarmSimulation.COCKFIGHT_HOURS.y

## What interacting does ("[E] <prompt>", already translated): during the
## tournament, and the rest of the time.
func set_prompts(during_tournament: String, otherwise: String) -> void:
	_prompt_on = during_tournament
	_prompt_off = otherwise
	_refresh_show()

func _refresh_show() -> void:
	for rooster in _show:
		rooster.visible = is_tournament_on()
	if _interactable != null:
		_interactable.prompt_message = _prompt_on if is_tournament_on() else _prompt_off

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _show.is_empty() or not _show[0].visible:
		return
	_lunge_in -= delta
	if _lunge_in > 0.0:
		return
	_lunge_in = randf_range(LUNGE_EVERY.x, LUNGE_EVERY.y)
	# One flies at the other, wings up, and both fall back.
	var attacker: AnimatedSprite2D = _show.pick_random()
	var side := signf(attacker.position.x)
	var home := Vector2(side * SHOW_GAP, 4)
	var tween := create_tween()
	tween.tween_property(attacker, "position", home + Vector2(-side * SHOW_GAP * 0.8, -10), 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker, "position", home, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## The ring itself, flat on the ground.
class _Floor extends Node2D:
	func _draw() -> void:
		var radii := CockfightRing.RADII
		_ellipse(Vector2.ZERO, radii + Vector2(4, 2), CockfightRing.EARTH_EDGE)
		_ellipse(Vector2.ZERO, radii, CockfightRing.EARTH_COLOR)
		var tops := PackedVector2Array()
		for i in CockfightRing.STAKES + 1:
			var angle := TAU * i / CockfightRing.STAKES
			var foot := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
			var top := foot - Vector2(0, CockfightRing.STAKE_HEIGHT)
			tops.append(top)
			if i < CockfightRing.STAKES:
				draw_line(foot, top, CockfightRing.STAKE_COLOR, 3.0)
		draw_polyline(tops, CockfightRing.CORD_COLOR, 1.5, true)

	func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 40:
			var angle := TAU * i / 40.0
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		draw_colored_polygon(points, color)
