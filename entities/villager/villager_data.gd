class_name VillagerData
extends Resource

## A villager: who they are, what they look like, and their day. One .tres
## per villager in data/villagers/.

const DIR := "res://data/villagers/"

@export var display_name := ""
## Who they are in the village, in French (tr()) - "Marchande au marché".
@export var role := ""
## The player's own family (living on the farm): no friendship hearts or
## orders with them - they're family.
@export var family := false
@export var look: VillagerLook
## Drawn size: 1 = an adult, about 0.8 = a child.
@export_range(0.6, 1.2, 0.05) var size := 1.0
## The world zone they live in, and the spot of their house door there (a
## VillagerRoads marker): where they sleep, and go when it rains.
@export var home_zone := "village"
@export var home := ""
## Their day, in order of time (see VillagerStop).
@export var routine: Array[VillagerStop] = []
## Said when the player comes up to them (one picked at random), in French
## - translated with tr().
@export var greetings := PackedStringArray()
## The orders they may give the player (FarmSimulation picks one now and
## then - see docs/orders.md).
@export var orders: Array[OrderTemplate] = []
## What they give the player as their friendship grows (see
## docs/friendship.md).
@export var friendship_rewards: Array[FriendshipReward] = []

## Every villager: id (the file's name) -> VillagerData, by name.
static func load_all() -> Dictionary:
	return ResourceDir.load_all(DIR, VillagerData)

## The step under way at `minute_of_day` on `weekday` (GameClock.Weekday),
## with today's story `conditions` (FarmSimulation.get_conditions()), or
## null before the day's first one (at home). The day runs from 6:00 to
## 2:00: the small hours belong to the evening before.
func get_stop(minute_of_day: int, weekday: int, conditions := {}) -> VillagerStop:
	var now := _day_minute(minute_of_day)
	var current: VillagerStop = null
	for stop in routine:
		if stop != null and stop.happens(weekday, conditions) and _day_minute(stop.get_minute_of_day()) <= now:
			current = stop
	return current

static func _day_minute(minute_of_day: int) -> int:
	return minute_of_day + 24 * 60 if minute_of_day < 6 * 60 else minute_of_day
