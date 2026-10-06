class_name DayNightController
extends Node

## Runs the time of day and lights the world for it. Real time moves the
## simulation's clock on (FarmSimulation.advance_time); the hour then tints
## the whole 2D world through a CanvasModulate - dawn, full day, golden hour,
## dusk, blue night - while the UI (CanvasLayers) stays untouched. Indoor
## zones (ZoneRoot.indoor) get a warm, dim light at night instead of the sky.
##
## Night-aware nodes join the "night_lights" group and get
## set_night(amount) - 0 by day, 1 at full night - whenever it changes:
## NightLight lanterns, AmbientLife (butterflies and birds off to bed,
## fireflies out).

const NIGHT_GROUP := "night_lights"
## Real seconds per in-game minute: 6:00 to midnight takes ~12.5 minutes.
const REAL_SECONDS_PER_MINUTE := 0.7

## Sky tint over the day, by minute of the day (past 1440 = after midnight).
const SKY := [
	[0, Color(0.3, 0.34, 0.56)],
	[270, Color(0.3, 0.34, 0.56)],
	[330, Color(0.62, 0.52, 0.66)], # dawn
	[390, Color(0.94, 0.72, 0.64)], # sunrise
	[450, Color(1.0, 0.9, 0.82)],
	[510, Color(1.0, 1.0, 1.0)],
	[960, Color(1.0, 1.0, 1.0)],
	[1050, Color(1.0, 0.8, 0.56)], # golden hour
	[1110, Color(0.95, 0.62, 0.48)], # sunset
	[1160, Color(0.6, 0.48, 0.62)], # dusk
	[1220, Color(0.32, 0.36, 0.58)],
	[1560, Color(0.3, 0.34, 0.56)],
]
## Indoors: no sky, but the house gets dim and warm (oil lamp) at night.
const INDOOR_DAY := Color(1.0, 1.0, 1.0)
const INDOOR_NIGHT := Color(0.78, 0.66, 0.54)

var simulation: FarmSimulation
var _canvas_modulate: CanvasModulate
var _indoor := false
var _night := -1.0

func setup(p_simulation: FarmSimulation, world_manager: WorldManager) -> void:
	simulation = p_simulation
	_canvas_modulate = CanvasModulate.new()
	add_child(_canvas_modulate)
	world_manager.zone_loaded.connect(_on_zone_loaded)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_indoor = zone.indoor
	# Nodes of the new zone get the current state right away.
	_night = -1.0
	_apply.call_deferred()

func _process(delta: float) -> void:
	if simulation == null:
		return
	simulation.advance_time(delta / REAL_SECONDS_PER_MINUTE)
	_apply()

## 0 by day, 1 at full night, in between at dawn and dusk.
func get_night_amount() -> float:
	var sky := sky_color(_minute())
	return clampf(inverse_lerp(1.0, 0.5, sky.v), 0.0, 1.0)

static func sky_color(minute: float) -> Color:
	for i in SKY.size() - 1:
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if minute <= b[0]:
			var t := inverse_lerp(float(a[0]), float(b[0]), minute)
			return (a[1] as Color).lerp(b[1], smoothstep(0.0, 1.0, t))
	return SKY[SKY.size() - 1][1]

func _minute() -> float:
	return float(simulation.state.clock.minute_of_day)

func _apply() -> void:
	var night := get_night_amount()
	_canvas_modulate.color = INDOOR_DAY.lerp(INDOOR_NIGHT, night) if _indoor else sky_color(_minute())
	if absf(night - _night) > 0.01:
		_night = night
		get_tree().call_group(NIGHT_GROUP, "set_night", night)
