class_name NeedBubble
extends Node2D

## Speech bubble floating above an animal's head, showing what it currently
## wants: a grain icon when hungry, a water drop when thirsty (both side by
## side if needed). The border turns red once a need is critical. Hidden when
## the animal wants nothing.
##
## Purely visual and drawn in code (no icon art in the project yet) - the
## owning animal decides what it needs and calls set_needs(); swapping the
## drawn icons for textures later only touches _draw_grain()/_draw_drop().

const ICON_SIZE := 8.0
const PADDING := 3.0
const GAP := 3.0
const TAIL_SIZE := 3.0
const CORNER_RADIUS := 4
const BORDER_WIDTH := 1
const BOB_AMPLITUDE := 1.0
const BOB_SPEED := 3.0

const BUBBLE_COLOR := Color(1.0, 1.0, 1.0, 0.92)
const BORDER_COLOR := Color(0.25, 0.2, 0.15)
const CRITICAL_BORDER_COLOR := Color(0.9, 0.15, 0.1)
const GRAIN_COLOR := Color(0.93, 0.72, 0.2)
const GRAIN_SHADE := Color(0.7, 0.5, 0.1)
const DROP_COLOR := Color(0.25, 0.55, 0.95)
const DROP_SHINE := Color(0.75, 0.88, 1.0)

var _hungry := false
var _thirsty := false
var _critical := false
var _bob_time := 0.0
var _style := StyleBoxFlat.new()

func _ready() -> void:
	z_index = 20 # above every y-sorted sprite, like the plot highlight
	_style.bg_color = BUBBLE_COLOR
	_style.set_corner_radius_all(CORNER_RADIUS)
	_style.set_border_width_all(BORDER_WIDTH)
	visible = false

## Only redraws when something actually changed - the animal calls this
## every physics tick.
func set_needs(hungry: bool, thirsty: bool, critical: bool) -> void:
	if hungry == _hungry and thirsty == _thirsty and critical == _critical:
		return
	_hungry = hungry
	_thirsty = thirsty
	_critical = critical
	visible = hungry or thirsty
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_bob_time += delta
	queue_redraw()

## Bubble is drawn with its tail tip at this node's origin - the owner places
## the node just above the animal's head.
func _draw() -> void:
	var icons: Array[Callable] = []
	if _hungry:
		icons.append(_draw_grain)
	if _thirsty:
		icons.append(_draw_drop)
	if icons.is_empty():
		return

	var bob := sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE
	var width := PADDING * 2.0 + ICON_SIZE * icons.size() + GAP * (icons.size() - 1)
	var height := PADDING * 2.0 + ICON_SIZE
	var rect := Rect2(-width / 2.0, -TAIL_SIZE - height + bob, width, height)
	var border := CRITICAL_BORDER_COLOR if _critical else BORDER_COLOR

	_style.border_color = border
	draw_style_box(_style, rect)
	var tail := PackedVector2Array([
		Vector2(-TAIL_SIZE, rect.end.y - 0.5), Vector2(TAIL_SIZE, rect.end.y - 0.5), Vector2(0, bob)])
	draw_colored_polygon(tail, BUBBLE_COLOR)
	draw_line(tail[0], tail[2], border, BORDER_WIDTH)
	draw_line(tail[1], tail[2], border, BORDER_WIDTH)

	var x := rect.position.x + PADDING
	for draw_icon in icons:
		draw_icon.call(Vector2(x, rect.position.y + PADDING))
		x += ICON_SIZE + GAP

## Three grains in a small pile, drawn inside the ICON_SIZE square at `at`.
func _draw_grain(at: Vector2) -> void:
	var c := at + Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	for offset in [Vector2(-2.2, 1.5), Vector2(2.2, 1.5), Vector2(0, -1.5)]:
		_draw_ellipse(c + offset, Vector2(2.0, 2.6), GRAIN_COLOR)
		draw_circle(c + offset + Vector2(0.6, 0.8), 0.7, GRAIN_SHADE)

## Teardrop: round bottom, pointed top, with a small shine.
func _draw_drop(at: Vector2) -> void:
	var c := at + Vector2(ICON_SIZE / 2.0, ICON_SIZE * 0.62)
	var r := ICON_SIZE * 0.34
	draw_circle(c, r, DROP_COLOR)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.95, -r * 0.3), c + Vector2(r * 0.95, -r * 0.3), Vector2(c.x, at.y)]), DROP_COLOR)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.28, DROP_SHINE)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
