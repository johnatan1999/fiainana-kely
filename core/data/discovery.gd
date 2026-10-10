class_name Discovery
extends Resource

## An entry of the player's notebook (the kahie - see docs/forest.md): an
## animal seen, a wild plant gathered, a place found. Fara draws each one in
## it while she lives at home. One .tres per entry in data/discoveries/; its
## id is the file's name. (Cooked dishes have their page too, from the
## recipes - see FarmSimulation.get_notebook().)
##
## Animals and plants keep their own hours and seasons: an animal shows
## only then (WildAnimal), a plant only grows then (ForageSpot).

enum Category { FAUNA, FLORA, PLACE }
## The animals' and plants' drawings (tools/placeholder_art/gen_forest.gd):
## cells of SHEET_CELL, a row per category (animals, then plants).
const SHEET := preload("res://assets/sprites/props/forest.png")
const SHEET_CELL := 128
const DIR := "res://data/discoveries/"
## Seasons, as bits (GameClock.Season): both, Asara only, Asotry only.
const ALL_SEASONS := 3

@export var category := Category.FAUNA
## In French, and in Malagasy.
@export var display_name := ""
@export var malagasy_name := ""
## What the notebook says once it's found - in French (tr()).
@export_multiline var description := ""
## What it says before: a hint on where and when to look.
@export_multiline var hint := ""
## Fara's word under her drawing.
@export var fara_line := ""

@export_group("Animal or plant")
## When it's about: from..to (minutes of the day, past 1440 = after
## midnight; from == to: all day) and in which seasons (bits of
## GameClock.Season).
@export var active_from := 6 * 60
@export var active_to := 6 * 60
@export_flags("Asara", "Asotry") var seasons := ALL_SEASONS
## Not out in the rain.
@export var shy_of_rain := false
## Plants: the item gathered, how many, and days before it grows again.
@export var item_id := ""
@export var quantity := 1
@export var regrow_days := 3
## Its drawing on SHEET: the column of its first cell, on its category's
## row - an animal's two frames, a plant ready then gathered. -1: none (a
## place).
@export var sheet_column := -1

## Every entry: id (the file's name) -> Discovery, by name.
static func load_all() -> Dictionary:
	return ResourceDir.load_all(DIR, Discovery)

## Its drawing, `cell` cells on from its first (an animal's second frame,
## a plant gathered) - null without one.
func get_drawing(cell := 0) -> AtlasTexture:
	if sheet_column < 0:
		return null
	var drawing := AtlasTexture.new()
	drawing.atlas = SHEET
	drawing.region = Rect2((sheet_column + cell) * SHEET_CELL, category * SHEET_CELL, SHEET_CELL, SHEET_CELL)
	return drawing

func is_in_season(season: int) -> bool:
	return seasons & (1 << season) != 0

## Whether it's about at `minute_of_day` in `season`, rain or not.
func is_active(minute_of_day: int, season: int, raining: bool) -> bool:
	if not is_in_season(season) or (raining and shy_of_rain):
		return false
	if active_from == active_to:
		return true
	# The day runs from 6:00 to 2:00: the small hours belong to the evening.
	var now := minute_of_day + 1440 if minute_of_day < 6 * 60 else minute_of_day
	return now >= active_from and now < active_to
