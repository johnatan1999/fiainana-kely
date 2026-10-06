class_name WeatherController
extends Node

## Shows the day's weather (FarmSimulation.weather_changed). Rain: streaks
## falling over the whole view, splashes on the ground, an overcast sky
## (DayNightController.set_overcast), the rain's sound, and a word on waking
## up - "it's raining: the crops are watered" - so the player learns why
## they needn't water today. Indoors: no streaks, a muffled sound, the sky
## only a little greyer.
##
## The rain lives in the world, not on a CanvasLayer, so it darkens at night
## with everything else; it follows the camera's real view (its screen
## center, which differs from the camera node near the map's edges).
## Nodes in WEATHER_GROUP get set_raining(raining) - AmbientLife keeps its
## butterflies and flocks in when it rains.

const WEATHER_GROUP := "weather_listeners"
const RAIN_COLOR := Color(0.78, 0.84, 0.95, 0.55)
const SPLASH_COLOR := Color(0.85, 0.9, 1.0, 0.6)
## How slanted the rain falls (x per unit of y).
const SLANT := 0.22
## Time to cloud over / clear up.
const OVERCAST_FADE := 2.0

var simulation: FarmSimulation
var _day_night: DayNightController
var _player: PlayerController
var _rain_root: Node2D
var _streaks: CPUParticles2D
var _splashes: CPUParticles2D
var _indoor := false
var _raining := false
## Off while a save is being loaded: its weather is old news, not a morning.
var _announce := false
var _overcast_tween: Tween

func setup(p_simulation: FarmSimulation, world_manager: WorldManager, day_night: DayNightController, player: PlayerController) -> void:
	simulation = p_simulation
	_day_night = day_night
	_player = player
	_build_rain()
	simulation.weather_changed.connect(_on_weather_changed)
	simulation.state_loaded.connect(func(): _announce = false; set.call_deferred("_announce", true))
	world_manager.zone_loaded.connect(_on_zone_loaded)
	set.call_deferred("_announce", true)
	_on_weather_changed(simulation.state.weather)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_indoor = zone.indoor
	_apply(true)
	get_tree().call_group.call_deferred(WEATHER_GROUP, "set_raining", _raining)

func _on_weather_changed(weather: FarmState.Weather) -> void:
	var was_raining := _raining
	_raining = weather == FarmState.Weather.RAIN
	_apply(false)
	get_tree().call_group(WEATHER_GROUP, "set_raining", _raining)
	if _raining and not was_raining and _announce:
		UIEvents.notify(tr("Il pleut : les cultures sont arrosées."))

## Shows or hides the rain for the current weather and zone. `instantly`:
## a zone change, no fade.
func _apply(instantly: bool) -> void:
	var outdoors_rain := _raining and not _indoor
	_streaks.emitting = outdoors_rain
	_splashes.emitting = outdoors_rain
	_rain_root.visible = outdoors_rain
	var overcast := 0.0
	if _raining:
		overcast = 0.35 if _indoor else 1.0
	if _overcast_tween:
		_overcast_tween.kill()
	if instantly:
		_day_night.set_overcast(overcast)
	else:
		_overcast_tween = create_tween()
		_overcast_tween.tween_method(_day_night.set_overcast, _day_night.get_overcast(), overcast, OVERCAST_FADE)
	AudioManager.set_rain_ambience(_raining, _indoor)

func _process(_delta: float) -> void:
	if not _rain_root.visible:
		return
	var camera := _player.camera
	var view := get_viewport().get_visible_rect().size / camera.zoom
	_rain_root.global_position = camera.get_screen_center_position()
	var half := view / 2.0 + Vector2(60, 60)
	_streaks.emission_rect_extents = half
	_splashes.emission_rect_extents = half

func _build_rain() -> void:
	_rain_root = Node2D.new()
	_rain_root.name = "Rain"
	_rain_root.visible = false
	add_child(_rain_root)

	# Streaks: spawn anywhere in the view and fall a short way - an even
	# curtain that doesn't need to "fill in" from the top. Move with the view.
	_streaks = CPUParticles2D.new()
	_streaks.emitting = false
	_streaks.amount = 560 # sized for the exterior view (ZoneRoot.camera_zoom 0.9)
	_streaks.lifetime = 0.55
	_streaks.preprocess = 0.6
	_streaks.local_coords = true
	_streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_streaks.direction = Vector2(SLANT, 1.0)
	_streaks.spread = 2.0
	_streaks.gravity = Vector2.ZERO
	_streaks.initial_velocity_min = 620.0
	_streaks.initial_velocity_max = 780.0
	_streaks.particle_flag_align_y = true
	_streaks.texture = _streak_texture()
	_streaks.color = RAIN_COLOR
	_streaks.z_as_relative = false
	_streaks.z_index = 60 # over everything in the world
	_rain_root.add_child(_streaks)

	# Splashes: little rings on the ground, left where they land (world
	# space), under the trees and the player.
	_splashes = CPUParticles2D.new()
	_splashes.emitting = false
	_splashes.amount = 150
	_splashes.lifetime = 0.32
	_splashes.preprocess = 0.4
	_splashes.local_coords = false
	_splashes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splashes.gravity = Vector2.ZERO
	_splashes.initial_velocity_min = 0.0
	_splashes.initial_velocity_max = 0.0
	_splashes.scale_amount_min = 0.6
	_splashes.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.3))
	_splashes.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.colors = PackedColorArray([SPLASH_COLOR, Color(SPLASH_COLOR, 0.0)])
	_splashes.color_ramp = fade
	_splashes.texture = _splash_texture()
	_splashes.z_as_relative = false
	_splashes.z_index = -5 # on the ground: over the soil, under everything standing
	_rain_root.add_child(_splashes)

## A thin streak fading at its tail (aligned with the fall by align_y).
static func _streak_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 2
	texture.height = 14
	return texture

## A flattened ring: a drop hitting the ground, seen from above.
static func _splash_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.1), Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 10
	texture.height = 5
	return texture
