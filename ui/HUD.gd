class_name HUD
extends Control

## Top-left panel: the date as players plan around it (season, day of the
## week, year, and how far into the season we are), the time of day, and
## the money. What
## the player holds is shown by the HotbarUI.
##
## Money reacts to changes: the number counts up/down to its new value and
## the difference floats up next to it (green gain, red spending) - so a sale
## or a purchase is felt, not just silently rewritten.

const SEASON_NAMES := {
	GameClock.Season.RAINY: "Asara",
	GameClock.Season.DRY: "Asotry",
}
const SEASON_GLYPHS := {
	GameClock.Season.RAINY: "sun",
	GameClock.Season.DRY: "dry_leaf",
}
## Season bar fill: lush green for the rainy season, dry tan for the cool one.
const SEASON_COLORS := {
	GameClock.Season.RAINY: Color(0.42, 0.66, 0.26),
	GameClock.Season.DRY: Color(0.8, 0.56, 0.26),
}
const GAIN_COLOR := Color(0.2, 0.55, 0.15)
const LOSS_COLOR := Color(0.75, 0.2, 0.12)
const COUNT_TIME := 0.4
const DELTA_RISE := 12.0
const DELTA_TIME := 1.1

@onready var season_glyph: HudGlyph = %SeasonGlyph
@onready var date_label: Label = %DateLabel
@onready var year_label: Label = %YearLabel
@onready var time_label: Label = %TimeLabel
@onready var weather_glyph: HudGlyph = %WeatherGlyph
@onready var season_bar: ProgressBar = %SeasonBar
@onready var days_label: Label = %DaysLabel
@onready var money_label: Label = %MoneyLabel
@onready var delta_label: Label = %DeltaLabel

var _simulation: FarmSimulation
## Money as currently drawn - tweened toward the real amount.
var _shown_money := 0.0
var _money_tween: Tween
var _delta_tween: Tween
## Off until the frame that sets the game up is over: loading a save changes
## money in that same frame, and that must not play as a "+192 000 Ar" gain.
var _animate_money := false

func setup(simulation: FarmSimulation) -> void:
	_simulation = simulation
	simulation.money_changed.connect(_on_money_changed)
	simulation.day_changed.connect(func(_day: int): _refresh_date())
	simulation.time_changed.connect(_refresh_time)
	simulation.weather_changed.connect(func(weather): weather_glyph.visible = weather == FarmState.Weather.RAIN)
	weather_glyph.visible = simulation.is_raining()
	_refresh_time(simulation.state.clock.minute_of_day)
	season_bar.max_value = GameClock.DAYS_PER_SEASON
	season_bar.add_theme_stylebox_override("fill", season_bar.get_theme_stylebox("fill").duplicate())
	delta_label.modulate.a = 0.0
	_refresh_date()
	_set_money_text(simulation.state.money)
	set.call_deferred("_animate_money", true)

## Every label here is built from a translated template plus live values, so
## a language switch (pause menu) needs a full redraw.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _simulation != null:
		_refresh_date()
		_set_money_text(roundi(_shown_money))

func _refresh_date() -> void:
	var clock := _simulation.state.clock
	var season := clock.get_season()
	season_glyph.kind = SEASON_GLYPHS[season]
	# The day of the season is on the bar below (DaysLabel): the date line
	# names the weekday instead - what villagers and the weekly market keep to.
	date_label.text = tr("%s · %s") % [tr(SEASON_NAMES[season]), GameClock.get_weekday_name(clock.get_weekday())]
	year_label.text = tr("An %d") % clock.get_year()
	season_bar.value = clock.get_day_of_season()
	(season_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = SEASON_COLORS[season]
	days_label.text = "%d/%d" % [clock.get_day_of_season(), GameClock.DAYS_PER_SEASON]

## Shown in 10-minute steps, like a village clock - not a ticking stopwatch.
func _refresh_time(_minute_of_day: int) -> void:
	var clock := _simulation.state.clock
	time_label.text = "%02d:%02d" % [clock.get_hour(), clock.get_minute() / 10 * 10]

func _on_money_changed(money: int) -> void:
	var delta := money - roundi(_shown_money)
	if not _animate_money or delta == 0:
		_set_money_text(money)
		return
	if _money_tween:
		_money_tween.kill()
	_money_tween = create_tween()
	_money_tween.tween_method(_set_money_text, _shown_money, float(money), COUNT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_show_delta(delta)

func _set_money_text(amount: float) -> void:
	_shown_money = amount
	money_label.text = Currency.format(roundi(amount))

## "+1 200 Ar" / "-500 Ar" floating up and fading next to the money.
func _show_delta(delta: int) -> void:
	if _delta_tween:
		_delta_tween.kill()
	delta_label.text = ("+" if delta > 0 else "") + Currency.format(delta)
	delta_label.add_theme_color_override("font_color", GAIN_COLOR if delta > 0 else LOSS_COLOR)
	delta_label.position.y = 0.0
	delta_label.modulate.a = 1.0
	_delta_tween = create_tween().set_parallel(true)
	_delta_tween.tween_property(delta_label, "position:y", -DELTA_RISE, DELTA_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_delta_tween.tween_property(delta_label, "modulate:a", 0.0, DELTA_TIME).set_delay(DELTA_TIME * 0.4)
