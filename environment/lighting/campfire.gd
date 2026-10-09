class_name Campfire
extends Node2D

## A campfire, always lit: a ring of stones around crossed logs and their
## embers, flames licking up, sparks drifting off, a thread of smoke, and
## the warm flickering light it pours around (a PointLight2D - it shows in
## the dark under a CanvasModulate). Its origin is the middle of the fire,
## on the ground. Drawn in code (placeholder art, like the lanterns).

const LIGHT_COLOR := Color(1.0, 0.6, 0.28)
const STONE_COLOR := Color(0.42, 0.4, 0.38)
const STONE_SHADE := Color(0.3, 0.28, 0.27)
const LOG_COLOR := Color(0.36, 0.22, 0.12)
const LOG_END := Color(0.62, 0.45, 0.28)
const EMBER_COLOR := Color(1.0, 0.45, 0.12)
## The ring of stones (an ellipse: seen from above at an angle).
const RING := Vector2(22, 9)
const STONES := 9

## How far the light reaches (px), and how strong it is.
@export var light_radius := 190.0
@export var light_energy := 1.0

var _light: PointLight2D
var _t := 0.0

func _ready() -> void:
	_t = randf() * 10.0
	_light = PointLight2D.new()
	_light.texture = NightLight._radial_texture()
	_light.texture_scale = light_radius / 64.0
	_light.color = LIGHT_COLOR
	_light.position = Vector2(0, -10)
	add_child(_light)
	add_child(_smoke())
	add_child(_flames())
	add_child(_sparks())
	# The stones in front of the flames' foot.
	var front := _FrontStones.new()
	add_child(front)

func _process(delta: float) -> void:
	_t += delta
	var flicker := 1.0 + 0.08 * sin(_t * 11.0) + 0.05 * sin(_t * 27.0) + 0.04 * sin(_t * 5.3)
	_light.energy = light_energy * flicker
	_light.texture_scale = light_radius / 64.0 * (1.0 + 0.02 * sin(_t * 7.0))
	queue_redraw()

func _draw() -> void:
	# The stones behind, then the logs and their embers.
	for i in STONES:
		var angle := PI + PI * float(i) / (STONES - 1)
		_stone(Vector2(cos(angle) * RING.x, sin(angle) * RING.y))
	var glow := 0.75 + 0.25 * sin(_t * 6.0)
	_ellipse(Vector2(0, -1), Vector2(14, 5), Color(EMBER_COLOR, 0.9 * glow))
	draw_line(Vector2(-17, 2), Vector2(15, -6), LOG_COLOR, 6.0, true)
	draw_line(Vector2(-15, -6), Vector2(17, 2), LOG_COLOR, 6.0, true)
	draw_circle(Vector2(-17, 2), 3.0, LOG_END)
	draw_circle(Vector2(17, 2), 3.0, LOG_END)
	_ellipse(Vector2(0, -3), Vector2(7, 3), Color(1.0, 0.85, 0.4, glow))

func _stone(at: Vector2) -> void:
	draw_stone(self, at)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_ellipse(self, center, radii, color)

## Drawing helpers, for this node or its front stones (from their _draw).
static func draw_stone(canvas: CanvasItem, at: Vector2) -> void:
	draw_ellipse(canvas, at, Vector2(6, 4), STONE_SHADE)
	draw_ellipse(canvas, at + Vector2(-0.5, -1), Vector2(5, 3), STONE_COLOR)

static func draw_ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, color)

# --- particles ----------------------------------------------------------------------------

func _flames() -> CPUParticles2D:
	var flames := _particles("Flames", 34, 0.75, true)
	flames.position = Vector2(0, -4)
	flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flames.emission_rect_extents = Vector2(9, 2)
	flames.direction = Vector2.UP
	flames.spread = 10.0
	flames.gravity = Vector2(0, -70)
	flames.initial_velocity_min = 18.0
	flames.initial_velocity_max = 38.0
	flames.scale_amount_min = 0.55
	flames.scale_amount_max = 0.95
	flames.scale_amount_curve = _curve([1.0, 0.8, 0.0])
	flames.color_ramp = _ramp([Color(1.0, 0.95, 0.65, 1.0), Color(1.0, 0.62, 0.18, 0.95),
		Color(0.85, 0.25, 0.06, 0.6), Color(0.5, 0.1, 0.02, 0.0)])
	return flames

func _sparks() -> CPUParticles2D:
	var sparks := _particles("Sparks", 7, 1.8, true)
	sparks.position = Vector2(0, -12)
	sparks.direction = Vector2.UP
	sparks.spread = 35.0
	sparks.gravity = Vector2(0, -15)
	sparks.initial_velocity_min = 25.0
	sparks.initial_velocity_max = 55.0
	sparks.scale_amount_min = 0.08
	sparks.scale_amount_max = 0.16
	sparks.color_ramp = _ramp([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.45, 0.1, 0.0)])
	return sparks

func _smoke() -> CPUParticles2D:
	var smoke := _particles("Smoke", 10, 3.2, false)
	smoke.position = Vector2(0, -30)
	smoke.direction = Vector2.UP
	smoke.spread = 12.0
	smoke.gravity = Vector2(8, -6)
	smoke.initial_velocity_min = 12.0
	smoke.initial_velocity_max = 20.0
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 0.9
	smoke.scale_amount_curve = _curve([0.5, 1.0, 1.6])
	smoke.color_ramp = _ramp([Color(0.6, 0.58, 0.55, 0.0), Color(0.55, 0.53, 0.5, 0.18), Color(0.5, 0.5, 0.5, 0.0)])
	return smoke

## Soft round particles. `glowing`: added light, never darkened by the night.
func _particles(node_name: String, amount: int, lifetime: float, glowing: bool) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.texture = _soft_dot()
	particles.local_coords = false
	if glowing:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		particles.material = material
	return particles

static func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 24
	texture.height = 24
	return texture

static func _ramp(colors: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	return gradient

static func _curve(values: Array) -> Curve:
	var curve := Curve.new()
	curve.max_value = 2.0
	for i in values.size():
		curve.add_point(Vector2(float(i) / (values.size() - 1), values[i]))
	return curve

## The front half of the ring, drawn over the flames' foot.
class _FrontStones extends Node2D:
	func _draw() -> void:
		for i in Campfire.STONES:
			var angle := PI * float(i) / (Campfire.STONES - 1)
			Campfire.draw_stone(self, Vector2(cos(angle) * Campfire.RING.x, sin(angle) * Campfire.RING.y))
