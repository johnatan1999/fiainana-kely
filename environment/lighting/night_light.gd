class_name NightLight
extends Node2D

## A lantern (doorway, market stall...): lights up at dusk, dies out at dawn
## - DayNightController calls set_night(). Its origin is the flame: a small
## bright dot that stays vivid in the dark (unshaded), plus a warm
## PointLight2D pooling on the ground around it, flickering a little.

@export var color := Color(1.0, 0.72, 0.42)
@export var energy := 1.1
## Radius of the pool of light, in px.
@export var radius := 110.0
@export var show_flame := true

var _light: PointLight2D
var _night := 0.0
var _t := 0.0

func _ready() -> void:
	add_to_group(DayNightController.LIGHT_GROUP)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	_light = PointLight2D.new()
	_light.texture = _radial_texture()
	_light.texture_scale = radius / 64.0
	_light.color = color
	_light.energy = 0.0
	add_child(_light)
	_t = randf() * 10.0

func set_night(amount: float) -> void:
	_night = amount
	visible = amount > 0.01
	# Lit right away, not on the next _process: the light must match the
	# moment it's told, whatever the frame timing.
	_update_light()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_update_light()

func _update_light() -> void:
	var flicker := 1.0 + 0.06 * sin(_t * 9.0) + 0.04 * sin(_t * 23.0)
	_light.energy = energy * _night * flicker if visible else 0.0
	queue_redraw()

func _draw() -> void:
	if not show_flame:
		return
	draw_circle(Vector2.ZERO, 5.0, Color(color, 0.25 * _night))
	draw_circle(Vector2.ZERO, 2.5, Color(color.lightened(0.4), 0.9 * _night))

static func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
