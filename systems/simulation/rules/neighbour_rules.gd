class_name NeighbourRules
extends SimRules

## The neighbours' paddies: their rice follows the calendar, and the player can
## help with the harvest.
## A part of FarmSimulation (SimRules): simulation.neighbours.

## The neighbours' paddies (VillagePaddy - decor, not the player's): their
## rice follows the calendar, two crops a year. Planted out at the start of
## each season, it grows through NEIGHBOUR_RICE_STAGES (day of the season ->
## CropVisual stage), then the farmers cut it over NEIGHBOUR_HARVEST_DAYS
## from NEIGHBOUR_HARVEST_FROM_DAY, during their working hours, column by
## column from the west. The player can lend a hand: each tuft they cut
## earns NEIGHBOUR_HARVEST_REWARD - seed rice, the neighbours' way of
## sharing.
const NEIGHBOUR_RICE_STAGES := {1: 1, 9: 2, 22: 3}
const NEIGHBOUR_HARVEST_FROM_DAY := 26
const NEIGHBOUR_HARVEST_DAYS := 3
const NEIGHBOUR_WORK_HOURS := Vector2i(6 * 60 + 30, 16 * 60)
const NEIGHBOUR_HARVEST_REWARD := "rice_seed"

var _neighbour_paddies: Dictionary = {} # paddy_id: String -> size in cells (Vector2i)

## Registered by NeighbourPaddyManager when its zone loads.
func register_neighbour_paddy(paddy_id: String, size: Vector2i) -> void:
	_neighbour_paddies[paddy_id] = size

## The CropVisual stage of the neighbours' rice still standing today.
func get_neighbour_rice_stage() -> int:
	var day := state.clock.get_day_of_season()
	var stage := 1
	for from_day: int in NEIGHBOUR_RICE_STAGES:
		if day >= from_day:
			stage = NEIGHBOUR_RICE_STAGES[from_day]
	return stage

## How much of the farmers' harvest is done, 0..1: through the working
## hours of the harvest days.
func get_neighbour_harvest_progress() -> float:
	var day := state.clock.get_day_of_season()
	if day < NEIGHBOUR_HARVEST_FROM_DAY:
		return 0.0
	var hours := NEIGHBOUR_WORK_HOURS
	var today := clampf(float(state.clock.minute_of_day - hours.x) / (hours.y - hours.x), 0.0, 1.0)
	return clampf((day - NEIGHBOUR_HARVEST_FROM_DAY + today) / NEIGHBOUR_HARVEST_DAYS, 0.0, 1.0)

## Harvest time: from its first day until all is cut.
func is_neighbour_harvest_on() -> bool:
	return state.clock.get_day_of_season() >= NEIGHBOUR_HARVEST_FROM_DAY \
			and get_neighbour_harvest_progress() < 1.0

func is_neighbour_tuft_cut(paddy_id: String, cell: Vector2i) -> bool:
	var size: Vector2i = _neighbour_paddies.get(paddy_id, Vector2i.ZERO)
	var order := _harvest_index(size, cell)
	if order < 0:
		return false
	var cut_by_farmers := int(get_neighbour_harvest_progress() * size.x * size.y)
	return order < cut_by_farmers or _player_cut_cells(paddy_id).has(_cell_key(cell))

## The player cuts the tuft at `cell` of a neighbours' paddy. Returns the
## seed rice earned (0 when it can't be cut: not harvest time, already cut,
## not a cell of that paddy).
func help_neighbour_harvest(paddy_id: String, cell: Vector2i) -> int:
	var size: Vector2i = _neighbour_paddies.get(paddy_id, Vector2i.ZERO)
	if not is_neighbour_harvest_on() or _harvest_index(size, cell) < 0 \
			or is_neighbour_tuft_cut(paddy_id, cell):
		return 0
	var season := _season_index()
	var entry: Dictionary = state.neighbour_harvest.get(paddy_id, {})
	if entry.get("season", -1) != season:
		entry = {"season": season, "cells": []}
		state.neighbour_harvest[paddy_id] = entry
	entry["cells"].append(_cell_key(cell))
	sim.add_item(NEIGHBOUR_HARVEST_REWARD, 1)
	day_log.neighbour_tufts += 1
	sim.neighbour_paddy_changed.emit(paddy_id)
	return 1

## How many tufts the player cut in that paddy this season.
func get_neighbour_tufts_helped(paddy_id: String) -> int:
	return _player_cut_cells(paddy_id).size()

func _player_cut_cells(paddy_id: String) -> Array:
	var entry: Dictionary = state.neighbour_harvest.get(paddy_id, {})
	return entry.get("cells", []) if entry.get("season", -1) == _season_index() else []

func _season_index() -> int:
	return (state.clock.current_day - 1) / GameClock.DAYS_PER_SEASON

## The order the farmers cut the tufts in - column by column from the west,
## top to bottom - or -1 outside the paddy.
static func _harvest_index(size: Vector2i, cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return -1
	return cell.x * size.y + cell.y

static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
