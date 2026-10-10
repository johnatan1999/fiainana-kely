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

## Every entry: id (the file's name) -> Discovery, by name.
static func load_all() -> Dictionary:
	var all := {}
	var files := Array(DirAccess.get_files_at("res://data/discoveries/")).filter(func(file): return file.ends_with(".tres"))
	files.sort()
	for file: String in files:
		var data := load("res://data/discoveries/" + file) as Discovery
		if data != null:
			all[file.get_basename()] = data
	return all

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
