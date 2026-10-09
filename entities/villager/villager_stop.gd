class_name VillagerStop
extends Resource

## One step of a villager's day: from `hour`:`minute`, be at `spot` (a
## marker of the VillagerRoads of zone `zone`) doing `activity`, until the
## next step. Before the day's first step, the villager is at home.

enum Activity {
	## Stands there, turning now and then (a stall, a chat, a bench).
	STAND,
	## Strolls around the spot, a few steps at a time.
	WANDER,
	## Goes in and disappears: a house door, a shed.
	INSIDE,
	## Bent over at work (planting rice, weeding), shuffling along now and
	## then.
	WORK,
}

@export_range(0, 23) var hour := 7
@export_range(0, 59, 5) var minute := 0
## The world zone of the spot (a WorldManager zone id); empty = the
## villager's home zone (VillagerData.home_zone).
@export var zone := ""
@export var spot := ""
@export var activity := Activity.STAND
## The weekdays this step happens on (GameClock.Weekday bits); none ticked
## = every day. On the other days the step is skipped - the previous one
## goes on (school on weekdays only, the weekly market on Fridays).
@export_flags("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday") var days := 0
## Still done in the rain (a covered stall, work in the rice fields);
## otherwise the villager stays home while it rains.
@export var rain_proof := false
## A story condition (FarmSimulation.get_conditions()) this step needs, or
## that cancels it - skipped like on another weekday. Fara goes to school
## `unless` "school_fees_overdue", and helps at home `only_if` it is.
@export var only_if := ""
@export var unless := ""

func get_minute_of_day() -> int:
	return hour * 60 + minute

func happens_on(weekday: int) -> bool:
	return days == 0 or days & (1 << weekday) != 0

## On `weekday` (GameClock.Weekday), with `conditions` (name -> true).
func happens(weekday: int, conditions: Dictionary) -> bool:
	return happens_on(weekday) and (only_if.is_empty() or conditions.has(only_if)) \
		and (unless.is_empty() or not conditions.has(unless))

## The `days` bits for a list of GameClock.Weekday values.
static func days_mask(weekdays: Array) -> int:
	var mask := 0
	for weekday: int in weekdays:
		mask |= 1 << weekday
	return mask
