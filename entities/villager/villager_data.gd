class_name VillagerData
extends Resource

## A villager: who they are, what they look like, and their day. One .tres
## per villager in data/villagers/.

@export var display_name := ""
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
@export var greetings: PackedStringArray = []

## The step for `minute_of_day`, or null = at home. The day runs from 6:00
## to 2:00: the small hours belong to the evening before.
func get_stop(minute_of_day: int) -> VillagerStop:
	var now := _day_minute(minute_of_day)
	var current: VillagerStop = null
	for stop in routine:
		if stop != null and _day_minute(stop.get_minute_of_day()) <= now:
			current = stop
	return current

static func _day_minute(minute_of_day: int) -> int:
	return minute_of_day + 24 * 60 if minute_of_day < 6 * 60 else minute_of_day
