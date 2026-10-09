class_name DayNightController
extends Node

## Runs the time of day and lights the world for it. Real time moves the
## simulation's clock on (FarmSimulation.advance_time); the hour then tints
## the whole 2D world through a CanvasModulate - dawn, full day, golden hour,
## dusk, blue night - while the UI (CanvasLayers) stays untouched. Indoor
## zones (ZoneRoot.indoor) get a warm, dim light at night instead of the sky.
##
## Two channels, kept apart on purpose:
## - LIGHT_GROUP: set_night(amount) - 0 by day, 1 at full night - whenever
##   the light changes. Looks only: NightLight lanterns, AmbientLife
##   (fireflies, wildlife). It's derived from the sky colors, which are a
##   look and may be retuned freely.
## - CLOCK_GROUP: set_time_of_day(minute_of_day) on every new minute.
##   Anything that *behaves* by the hour (chickens going in at 18:45...)
##   listens to this one, so retuning the sky never moves gameplay.
## - CALENDAR_GROUP: set_weekday(weekday) (GameClock.Weekday) on each new
##   day - before that day's first set_time_of_day. Villagers keep a weekly
##   routine (school on weekdays, the weekly market).
## All are also sent when a zone loads, so its nodes start in the right state.

const LIGHT_GROUP := "light_listeners"
const CLOCK_GROUP := "clock_listeners"
const CALENDAR_GROUP := "calendar_listeners"
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
## Rainy sky: the tint is multiplied by this at full overcast.
const OVERCAST_TINT := Color(0.72, 0.76, 0.86)

var simulation: FarmSimulation
var _canvas_modulate: CanvasModulate
var _indoor := false
## 0 = clear, 1 = fully overcast - set by WeatherController.
var _overcast := 0.0
var _night := -1.0

func setup(p_simulation: FarmSimulation, world_manager: WorldManager) -> void:
	simulation = p_simulation
	_canvas_modulate = CanvasModulate.new()
	add_child(_canvas_modulate)
	world_manager.zone_loaded.connect(_on_zone_loaded)
	simulation.day_changed.connect(func(_day: int): _broadcast_weekday())
	simulation.time_changed.connect(_broadcast_clock)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_indoor = zone.indoor
	# Nodes of the new zone get the current state right away.
	_night = -1.0
	_apply.call_deferred()
	_broadcast_weekday.call_deferred()
	_broadcast_clock.call_deferred(simulation.state.clock.minute_of_day)

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
	var tint := INDOOR_DAY.lerp(INDOOR_NIGHT, night) if _indoor else sky_color(_minute())
	_canvas_modulate.color = tint * Color.WHITE.lerp(OVERCAST_TINT, _overcast)
	if absf(night - _night) > 0.01:
		_night = night
		get_tree().call_group(LIGHT_GROUP, "set_night", night)

## Greys the light down for rain, on top of the time of day.
func set_overcast(amount: float) -> void:
	_overcast = clampf(amount, 0.0, 1.0)
	if is_inside_tree():
		_apply()

func get_overcast() -> float:
	return _overcast

func _broadcast_weekday() -> void:
	get_tree().call_group(CALENDAR_GROUP, "set_weekday", simulation.state.clock.get_weekday())

func _broadcast_clock(minute_of_day: int) -> void:
	get_tree().call_group(CLOCK_GROUP, "set_time_of_day", minute_of_day)
