class_name HUD
extends Control

## Day, season and money. What the player holds is shown by the HotbarUI.

const SEASON_NAMES := {
	GameClock.Season.ASARA: "Asara",
	GameClock.Season.ASOTRY: "Asotry",
}

@onready var day_label: Label = $VBoxContainer/DayLabel
@onready var season_label: Label = $VBoxContainer/SeasonLabel
@onready var money_label: Label = $VBoxContainer/MoneyLabel

var _simulation: FarmSimulation

func setup(simulation: FarmSimulation) -> void:
	_simulation = simulation
	simulation.money_changed.connect(_on_money_changed)
	simulation.day_changed.connect(_on_day_changed)
	_refresh_all()

## Every label here is built from a translated template plus live values, so
## a language switch (pause menu) needs a full redraw.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _simulation != null:
		_refresh_all()

func _refresh_all() -> void:
	_on_day_changed(_simulation.state.day)
	_on_money_changed(_simulation.state.money)

func _on_day_changed(day: int) -> void:
	day_label.text = tr("Jour %d") % day
	season_label.text = tr("Saison : %s") % tr(SEASON_NAMES.get(_simulation.state.clock.get_season(), "?"))

func _on_money_changed(money: int) -> void:
	money_label.text = tr("Argent : %s") % Currency.format(money)
