class_name WildAnimal
extends Node2D

## A wild animal of the forest (its Discovery: an animal page of the
## notebook), at its spot: there only in its hours and seasons (ForestManager
## says so - set_present), breathing and moving now and then between its two
## frames, and something to watch: "Observer le sifaka". Decor and
## interaction only; the rules are FarmSimulation's. Built in code; its two
## frames are its Discovery's drawing (set_discovery). Its origin is where
## it stands. Group "wild_animals".

signal observed

const GROUP := "wild_animals"
const INTERACTABLE := preload("res://components/interaction/interactable_component.tscn")
const FRAME_EVERY := Vector2(1.2, 3.5)
const FADE_TIME := 0.6

## Which animal (a Discovery id: "sifaka", "maki"...).
@export var discovery_id := ""

var _sprite: Sprite2D
var _interactable: InteractableComponent
var _frames: Array[Texture2D] = []
var _frame := 0
var _next_frame := 0.0
var _t := 0.0
var _present := false
var _fade: Tween

func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(0.5, 0.5)
	_sprite.offset = Vector2(0, -Discovery.SHEET_CELL / 2.0 + 8)
	add_child(_sprite)
	_interactable = INTERACTABLE.instantiate()
	add_child(_interactable)
	var area: CollisionShape2D = _interactable.get_node("InteractableCollision2D")
	var reach := RectangleShape2D.new()
	reach.size = Vector2(110, 90)
	area.shape = reach
	area.position = Vector2(0, -24)
	_interactable.interacted.connect(observed.emit)
	_t = randf() * 10.0
	_set_frame(0)
	visible = false
	modulate.a = 0.0
	_interactable.set_interactable(false)

## What it is: its two frames.
func set_discovery(discovery: Discovery) -> void:
	_frames = [discovery.get_drawing(0), discovery.get_drawing(1)]
	_set_frame(_frame)

## There or not (its hours, its season, the weather) - fading in or out.
func set_present(present: bool, instant := false) -> void:
	if present == _present:
		return
	_present = present
	_interactable.set_interactable(present)
	if _fade != null:
		_fade.kill()
	if instant:
		visible = present
		modulate.a = 1.0 if present else 0.0
		return
	visible = true
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0 if present else 0.0, FADE_TIME)
	if not present:
		_fade.tween_callback(func(): visible = false)

func is_present() -> bool:
	return _present

## What watching it does ("[E] Observer le sifaka", already translated).
func set_prompt(prompt: String) -> void:
	_interactable.prompt_message = prompt

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# Breathing: a hair up and down.
	_sprite.position.y = sin(_t * 2.2) * 1.2
	_next_frame -= delta
	if _next_frame <= 0.0:
		_set_frame(1 - _frame)

func _set_frame(frame: int) -> void:
	_frame = frame
	_next_frame = randf_range(FRAME_EVERY.x, FRAME_EVERY.y) * (0.5 if frame == 1 else 1.0)
	if frame < _frames.size():
		_sprite.texture = _frames[frame]
