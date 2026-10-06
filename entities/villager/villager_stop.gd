class_name VillagerStop
extends Resource

## One step of a villager's day: from `hour`:`minute`, be at `spot` (a
## marker of the zone's VillagerRoads) doing `activity`, until the next
## step. Before the day's first step, and when the next step is past
## midnight, the villager is at home.

enum Activity {
	## Stands there, turning now and then (a stall, a chat, a bench).
	STAND,
	## Strolls around the spot, a few steps at a time.
	WANDER,
	## Goes in and disappears: a house door, or a zone exit (gone to the
	## rice fields...).
	INSIDE,
}

@export_range(0, 23) var hour := 7
@export_range(0, 59, 5) var minute := 0
@export var spot := ""
@export var activity := Activity.STAND
## Still done in the rain (a covered stall, work in the rice fields);
## otherwise the villager stays home while it rains.
@export var rain_proof := false

func get_minute_of_day() -> int:
	return hour * 60 + minute
