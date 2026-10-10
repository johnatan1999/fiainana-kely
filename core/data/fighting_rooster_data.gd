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
## CockfightRules.ROOSTER_START_STAT * 2), and what it gains each week -
## the villagers train theirs too.
@export var base_power := 60
@export var power_per_week := 3
## Its plumage, tinting the rooster art (white = as drawn).
@export var color := Color.WHITE

## Every rooster: id (the file's name) -> FightingRoosterData, by name.
static func load_all() -> Dictionary:
	return ResourceDir.load_all(DIR, FightingRoosterData)
