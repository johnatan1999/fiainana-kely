class_name FightingRoosterData
extends Resource

## A villager's fighting rooster (akoho gasy), one of the player's rooster's
## opponents at the Sunday tournament (see docs/cockfight.md). One .tres
## per rooster in data/roosters/; its id is the file's name.

const DIR := "res://data/roosters/"

@export var display_name := ""
## Its owner: a villager id (their VillagerData file's name). Fighting their
## rooster brings the player closer to them.
@export var owner_id := ""
## How strong it is in the first week (the player's rooster starts at
## FarmSimulation.ROOSTER_START_STAT * 2), and what it gains each week -
## the villagers train theirs too.
@export var base_power := 60
@export var power_per_week := 3
## Its plumage, tinting the rooster art (white = as drawn).
@export var color := Color.WHITE

## Every rooster: id (the file's name) -> FightingRoosterData, by name.
static func load_all() -> Dictionary:
	var all := {}
	var files := Array(DirAccess.get_files_at(DIR)).filter(func(file): return file.ends_with(".tres"))
	files.sort()
	for file: String in files:
		var data := load(DIR + file) as FightingRoosterData
		if data != null:
			all[file.get_basename()] = data
	return all
