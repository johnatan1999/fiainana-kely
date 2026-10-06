class_name GameClock
extends RefCounted

## Two-season Malagasy agricultural calendar: Asara (hot/rainy) and Asotry
## (cool/dry), alternating every DAYS_PER_SEASON days.
enum Season { ASARA, ASOTRY }
const DAYS_PER_SEASON := 30
## Every day starts at 6:00 - waking up.
const DAY_START_MINUTE := 6 * 60
## Time stops at 2:00 (the night after): the night goes on until the player
## sleeps - no forced faint, the cost of staying up is the dark.
const LATEST_MINUTE := 26 * 60

var current_day: int = 1
## Minutes since midnight of current_day: past 24:00 (1440) means the small
## hours of the night after, still the same day until the player sleeps.
var minute_of_day: int = DAY_START_MINUTE

func advance_day() -> void:
	current_day += 1
	minute_of_day = DAY_START_MINUTE

## Returns whether the time actually moved (it doesn't past LATEST_MINUTE).
func advance_minutes(minutes: int) -> bool:
	var before := minute_of_day
	minute_of_day = mini(minute_of_day + maxi(minutes, 0), LATEST_MINUTE)
	return minute_of_day != before

## 0..23, as shown on a clock.
func get_hour() -> int:
	return (minute_of_day / 60) % 24

func get_minute() -> int:
	return minute_of_day % 60

func get_season() -> Season:
	return get_season_on(current_day)

func get_season_on(day: int) -> Season:
	return Season.ASOTRY if ((day - 1) / DAYS_PER_SEASON) % 2 == 1 else Season.ASARA

## 1..DAYS_PER_SEASON - the date players plan around ("Asara, day 9").
func get_day_of_season() -> int:
	return (current_day - 1) % DAYS_PER_SEASON + 1

## Days left in the current season after today (0 on its last day).
func get_days_left_in_season() -> int:
	return DAYS_PER_SEASON - get_day_of_season()

## 1-based; a year is one Asara plus one Asotry.
func get_year() -> int:
	return (current_day - 1) / (DAYS_PER_SEASON * Season.size()) + 1
