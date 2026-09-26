@tool
class_name House
extends Node2D

## A house placed in a village, built from a HouseData model: art, solid
## base, porch, a door that opens as the player walks up (if the house can be
## entered), and the whole house fading while the player is behind it. @tool:
## shows at its real size in the editor, with its layout drawn over it.
##
## The node's position is the bottom-left corner of the art (put it on the
## 48 px grid). The house is drawn at its door's threshold depth, so the
## player is in front of it on the porch and behind it past its base.
##
## Enterable or decorative: it opens onto `interior_zone` if set here, else
## onto its model's shared interior, else it's decorative (locked door). The
## way back out is its own ExitSpawn marker in front of the door - nothing to
## place by hand, see ZoneTransition.back_to_entrance.
##
## Built in code as internal children (never saved in the scene), all from
## `data` - except EnterHouse, a real ZoneTransition node so door checks
## (tests/zone_wiring_test.gd) and WorldManager find it like any other door.

const DOOR_FADE_TIME := 0.08
const BEHIND_FADE_TIME := 0.25
## How far in front of the porch the door starts opening.
const DOOR_REACH := 40.0
## Where the player reappears coming out, in front of the footprint's edge.
const EXIT_DISTANCE := 28.0

const GIZMO_FOOTPRINT := Color(0.9, 0.2, 0.2)
const GIZMO_ENTRANCE := Color(0.2, 0.85, 0.3)
const GIZMO_DOOR := Color(0.25, 0.5, 1.0)
const GIZMO_DEPTH := Color(1.0, 0.85, 0.1)

@export var data: HouseData:
	set(value):
		data = value
		_apply_destination()
		if is_node_ready():
			_build()

@export_group("Inside")
## Door stays shut even if the model has an interior (a neighbour's house).
@export var locked: bool = false:
	set(value):
		locked = value
		_apply_destination()
## This house's own interior (zone id), instead of its model's shared one -
## the player's home, a shop...
@export var interior_zone: String = "":
	set(value):
		interior_zone = value
		_apply_destination()
@export var interior_spawn: String = "":
	set(value):
		interior_spawn = value
		_apply_destination()

@export_group("Level design")
## Walls off the ground hidden behind the house (from its footprint to the
## top of its art), when nothing back there is worth reaching: the player
## can never get lost behind it.
@export var seal_back: bool = false:
	set(value):
		seal_back = value
		if is_node_ready():
			_build()
## Editor only: draws footprint (red), porch (green), door (blue) and depth
## line (yellow) over the art, to check a model's layout at a glance.
@export var show_layout: bool = true:
	set(value):
		show_layout = value
		if _gizmo:
			_gizmo.queue_redraw()

var _visual: Node2D
var _door_open: Sprite2D
var _exit: Marker2D
var _gizmo: Node2D
var _generated: Array[Node] = []
var _behind_tween: Tween
var _door_tween: Tween

func _ready() -> void:
	_apply_destination()
	_build()

func is_enterable() -> bool:
	return not locked and _resolved_zone() != ""

func _resolved_zone() -> String:
	if interior_zone != "":
		return interior_zone
	return data.interior_zone if data else ""

func _resolved_spawn() -> String:
	if interior_spawn != "":
		return interior_spawn
	return data.interior_spawn if data else ""

## Also runs while instancing, before _ready(): the house's settings reach
## EnterHouse as soon as it exists, so a scene just instantiated (not in the
## tree yet, e.g. by the door checks) already reports the right destination.
func _apply_destination() -> void:
	var door := get_node_or_null("EnterHouse") as ZoneTransition
	if door == null:
		return
	door.locked = not is_enterable()
	door.target_zone = _resolved_zone() if door.locked == false else ""
	door.target_spawn = _resolved_spawn() if door.locked == false else ""

func _build() -> void:
	for node in _generated:
		node.queue_free()
	_generated.clear()
	_gizmo = null
	if data == null or data.body_texture == null:
		return
	var size := Vector2(data.body_texture.get_size())
	var footprint := _local(data.footprint)
	var entrance := _local(data.entrance)
	var door := _local(data.door)
	var depth_y := door.end.y

	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.position.y = depth_y
	var body := Sprite2D.new()
	body.texture = data.body_texture
	body.centered = false
	body.offset = Vector2(0, -size.y - depth_y)
	_visual.add_child(body)
	_door_open = Sprite2D.new()
	_door_open.texture = data.door_open_texture
	_door_open.centered = false
	_door_open.offset = data.door_open_position + body.offset
	_door_open.modulate.a = 0.0
	_visual.add_child(_door_open)
	_add_generated(_visual)

	var solid := StaticBody2D.new()
	solid.name = "Walls"
	for rect in _solid_rects(footprint, entrance):
		_add_rect_shape(solid, rect)
	if seal_back:
		_add_rect_shape(solid, Rect2(footprint.position.x, -size.y, footprint.size.x, footprint.position.y + size.y))
	_add_generated(solid)

	var behind := _make_area("BehindZone", Rect2(0, -size.y, size.x, size.y + depth_y))
	behind.body_entered.connect(_on_behind_changed.bind(true))
	behind.body_exited.connect(_on_behind_changed.bind(false))

	var porch := entrance if entrance.has_area() else door
	var reach := Rect2(porch.position.x - DOOR_REACH / 2.0, depth_y,
			porch.size.x + DOOR_REACH, footprint.end.y - depth_y + DOOR_REACH)
	var door_zone := _make_area("DoorReach", reach)
	door_zone.body_entered.connect(_on_door_reach_changed.bind(true))
	door_zone.body_exited.connect(_on_door_reach_changed.bind(false))

	_exit = Marker2D.new()
	_exit.name = "ExitSpawn"
	_exit.position = Vector2(door.get_center().x, footprint.end.y + EXIT_DISTANCE)
	_add_generated(_exit)

	# The threshold itself: a thin strip across the doorway's bottom edge.
	var enter := get_node_or_null("EnterHouse/CollisionShape2D") as CollisionShape2D
	if enter:
		var threshold := Rect2(door.position.x + 4.0, depth_y - 12.0, door.size.x - 8.0, 20.0)
		var shape := RectangleShape2D.new()
		shape.size = threshold.size
		enter.shape = shape
		enter.position = threshold.get_center()
	# set(), not a direct assignment: under the test runner (--script) the
	# ZoneTransition script is a placeholder holding only its exports.
	var entry := get_node_or_null("EnterHouse")
	if entry:
		entry.set(&"return_point", _exit)
	_apply_destination()

	if Engine.is_editor_hint():
		_gizmo = Node2D.new()
		_gizmo.z_index = 100
		_gizmo.draw.connect(_draw_layout.bind(footprint, entrance, door))
		_add_generated(_gizmo)

## Body-texture pixels -> local: the texture's bottom-left corner is our origin.
func _local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - Vector2(0, data.body_texture.get_height()), rect.size)

## The footprint minus the porch: left of it, right of it, and the wall
## behind it.
func _solid_rects(footprint: Rect2, entrance: Rect2) -> Array[Rect2]:
	if not entrance.has_area():
		return [footprint]
	var rects: Array[Rect2] = []
	for r in [
		Rect2(footprint.position.x, footprint.position.y, entrance.position.x - footprint.position.x, footprint.size.y),
		Rect2(entrance.end.x, footprint.position.y, footprint.end.x - entrance.end.x, footprint.size.y),
		Rect2(entrance.position.x, footprint.position.y, entrance.size.x, entrance.position.y - footprint.position.y),
	]:
		if r.has_area():
			rects.append(r)
	return rects

func _add_rect_shape(parent: CollisionObject2D, rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var node := CollisionShape2D.new()
	node.shape = shape
	node.position = rect.get_center()
	parent.add_child(node)

func _make_area(area_name: String, rect: Rect2) -> Area2D:
	var area := Area2D.new()
	area.name = area_name
	area.monitorable = false
	_add_rect_shape(area, rect)
	_add_generated(area)
	return area

## Internal: never saved into the scene, rebuilt from `data` on load.
func _add_generated(node: Node) -> void:
	add_child(node, false, Node.INTERNAL_MODE_FRONT)
	_generated.append(node)

func _draw_layout(footprint: Rect2, entrance: Rect2, door: Rect2) -> void:
	if not show_layout:
		return
	_gizmo.draw_rect(footprint, Color(GIZMO_FOOTPRINT, 0.25))
	_gizmo.draw_rect(footprint, GIZMO_FOOTPRINT, false, 2.0)
	if seal_back:
		var sealed := Rect2(footprint.position.x, -data.body_texture.get_height(), footprint.size.x,
				footprint.position.y + data.body_texture.get_height())
		_gizmo.draw_rect(sealed, Color(GIZMO_FOOTPRINT, 0.1))
	if entrance.has_area():
		_gizmo.draw_rect(entrance, Color(GIZMO_ENTRANCE, 0.35))
		_gizmo.draw_rect(entrance, GIZMO_ENTRANCE, false, 2.0)
	_gizmo.draw_rect(door, GIZMO_DOOR, false, 2.0)
	_gizmo.draw_line(Vector2(0, door.end.y), Vector2(data.body_texture.get_width(), door.end.y), GIZMO_DEPTH, 1.0)
	if _exit:
		_gizmo.draw_circle(_exit.position, 6.0, GIZMO_ENTRANCE if is_enterable() else GIZMO_FOOTPRINT)

func _on_behind_changed(body: Node2D, inside: bool) -> void:
	if Engine.is_editor_hint() or not body.is_in_group("player"):
		return
	if _behind_tween:
		_behind_tween.kill()
	_behind_tween = create_tween()
	_behind_tween.tween_property(_visual, "modulate:a", data.behind_alpha if inside else 1.0, BEHIND_FADE_TIME)

func _on_door_reach_changed(body: Node2D, inside: bool) -> void:
	if Engine.is_editor_hint() or not body.is_in_group("player") or not is_enterable():
		return
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(_door_open, "modulate:a", 1.0 if inside else 0.0, DOOR_FADE_TIME)
