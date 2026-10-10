@tool
class_name Sunbeam
extends Node2D

## Sunlight falling into a glade of the forest, where the canopy opens: the
## ground brighter than the shaded undergrowth around it (a soft, warm
## PointLight2D, over the zone's shade - ZoneRoot.shade) and a few slanted
## shafts of light, slowly breathing. By day only: DayNightController calls
## set_night(), and it fades out at dusk. Its origin is the middle of the
## glade. Placed by tools/build_forest.gd.

## The glade's half-size, in px: how far the light reaches.
@export var radius := Vector2(260, 180):
	set(value):
		radius = value
		queue_redraw()
@export var color := Color(1.0, 0.93, 0.7)
## How much brighter the glade is, in full day.
@export var energy := 0.45
## Shafts of light across the glade.
@export_range(0, 8) var shafts := 4:
	set(value):
		shafts = value
		queue_redraw()

## The shafts' slant (px sideways per px down): the sun is high, a little
## to the west.
const SLANT := 0.3
const SHAFT_ALPHA := 0.09
## DayNightController's night amount from which the sun is down for good
## (full night reads about 0.84, not 1).
const SUNSET_NIGHT := 0.75
## The shafts breathe slowly: redrawn this often (s), not every frame.
const REDRAW_EVERY := 0.1

var _light: PointLight2D
var _day := 1.0
var _t := 0.0
var _since_redraw := 0.0

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = additive
	z_index = 2
	if Engine.is_editor_hint():
		return
	add_to_group(DayNightController.LIGHT_GROUP)
	_light = PointLight2D.new()
	_light.texture = NightLight._radial_texture()
	_light.texture_scale = maxf(radius.x, radius.y) / 64.0 * 1.3
	_light.scale = Vector2(1.0, radius.y / radius.x)
	_light.color = color
	add_child(_light)
	_t = hash(name) % 100
	_update()

func set_night(amount: float) -> void:
	_day = clampf(1.0 - amount / SUNSET_NIGHT, 0.0, 1.0)
	visible = _day > 0.01
	_update()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	_t += delta
	_since_redraw += delta
	if _since_redraw >= REDRAW_EVERY:
		_since_redraw = 0.0
		queue_redraw()

func _update() -> void:
	if _light != null:
		_light.energy = energy * _day
	queue_redraw()

func _draw() -> void:
	for i in shafts:
		var f := (i + 0.5) / shafts
		var x := lerpf(-radius.x * 0.8, radius.x * 0.8, f) + sin(i * 2.3) * 30.0
		var width := 26.0 + 18.0 * absf(sin(i * 1.7))
		var breathe := 0.65 + 0.35 * sin(_t * 0.5 + i * 1.3)
		var alpha := SHAFT_ALPHA * breathe * _day
		var foot := Vector2(x, radius.y * 0.6)
		var top := Vector2(x - SLANT * radius.y * 2.8, -radius.y * 2.2)
		var dir := (foot - top).normalized()
		var side := dir.orthogonal() * width * 0.5
		var shaft := PackedVector2Array([top - side * 0.6, top + side * 0.6, foot + side, foot - side])
		var colors := PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, alpha), Color(color, alpha)])
		draw_polygon(shaft, colors)
		draw_circle(foot, width * 0.9, Color(color, alpha * 0.6))
