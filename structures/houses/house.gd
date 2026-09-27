class_name House
extends Node2D

## Behaviour shared by every house. Each house model is its own scene,
## assembled by hand in the editor (see models/trano_gasy_01.tscn) - to make
## a new one, duplicate a model scene and swap its art and shapes:
##
##   House (this script, y_sort_enabled)
##   ├── Visual (Node2D)       its y is the depth line: the player is drawn in
##   │   │                     front of the house below it, behind it above
##   │   │                     it - put it on the door's threshold
##   │   ├── Body (Sprite2D)   the building
##   │   └── DoorOpen (Sprite2D) drawn over the door when the player is at it
##   ├── Walls (StaticBody2D)  collision shapes, any number and shape
##   ├── EnterHouse (ZoneTransition) + shape: the threshold that leads inside
##   ├── DoorReach (Area2D) + shape: where the door swings open
##   └── ExitSpawn (Marker2D)  where the player reappears coming out
##
## Art scale: the door should be about the player's height. Art is exported
## at 2x its in-game size and Body/DoorOpen scaled to 0.5, so it stays sharp
## on 1080p/1440p screens (see tools/bake_house.gd).
##
## Enterable or decorative: a model scene sets the interior all its houses
## share (interior_zone), a placed house can name its own instead or be
## locked; with no interior the door stays shut. Coming back out, the player
## reappears at ExitSpawn - see ZoneTransition.back_to_entrance.

const DOOR_FADE_TIME := 0.08
const BEHIND_FADE_TIME := 0.25

@export_group("Inside")
## Door stays shut even with an interior set (a neighbour's house).
@export var locked: bool = false:
	set(value):
		locked = value
		_apply_destination()
## The interior this house opens onto (zone id) - empty: decorative house.
@export var interior_zone: String = "":
	set(value):
		interior_zone = value
		_apply_destination()
## Entry marker in that interior.
@export var interior_spawn: String = "":
	set(value):
		interior_spawn = value
		_apply_destination()

@export_group("Feel")
## House opacity while the player walks behind it, so they're never lost.
@export_range(0.0, 1.0, 0.05) var behind_alpha: float = 0.45

@onready var _visual: Node2D = $Visual
@onready var _door_open: CanvasItem = $Visual/DoorOpen

var _behind_tween: Tween
var _door_tween: Tween

func _ready() -> void:
	_door_open.modulate.a = 0.0
	$DoorReach.body_entered.connect(_on_door_reach_changed.bind(true))
	$DoorReach.body_exited.connect(_on_door_reach_changed.bind(false))
	_add_behind_zone()
	# set(), not a direct assignment: under the test runner (--script) the
	# ZoneTransition script is a placeholder holding only its exports.
	$EnterHouse.set(&"return_point", $ExitSpawn)
	_apply_destination()

## Right after the scene is instantiated, before it enters the tree: a house
## whose settings were all left at their defaults (a decorative house) gets
## its door locked too - the setters above only run for values that are set.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_apply_destination()

func is_enterable() -> bool:
	return not locked and interior_zone != ""

## Also runs while instancing, before _ready(): a scene just instantiated
## (not in the tree yet, e.g. by the door checks) already reports the right
## destination.
func _apply_destination() -> void:
	var door := get_node_or_null("EnterHouse") as ZoneTransition
	if door == null:
		return
	door.locked = not is_enterable()
	door.target_zone = interior_zone if is_enterable() else ""
	door.target_spawn = interior_spawn if is_enterable() else ""

## Everything the art can hide the player behind: Body's area above the
## depth line. Derived from the art, so there's nothing to keep in sync.
func _add_behind_zone() -> void:
	var body := $Visual/Body as Sprite2D
	var art := body.get_global_transform() * body.get_rect()
	var depth_y := _visual.global_position.y
	var zone := Rect2(art.position, Vector2(art.size.x, depth_y - art.position.y))
	var shape := RectangleShape2D.new()
	shape.size = zone.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = to_local(zone.get_center())
	var area := Area2D.new()
	area.name = "BehindZone"
	area.monitorable = false
	area.add_child(collision)
	area.body_entered.connect(_on_behind_changed.bind(true))
	area.body_exited.connect(_on_behind_changed.bind(false))
	add_child(area)

func _on_behind_changed(body: Node2D, inside: bool) -> void:
	if not body.is_in_group("player"):
		return
	if _behind_tween:
		_behind_tween.kill()
	_behind_tween = create_tween()
	_behind_tween.tween_property(_visual, "modulate:a", behind_alpha if inside else 1.0, BEHIND_FADE_TIME)

func _on_door_reach_changed(body: Node2D, inside: bool) -> void:
	if not body.is_in_group("player") or not is_enterable():
		return
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(_door_open, "modulate:a", 1.0 if inside else 0.0, DOOR_FADE_TIME)
