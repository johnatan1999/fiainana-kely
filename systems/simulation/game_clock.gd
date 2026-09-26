class_name GameClock
extends RefCounted

## Two-season Malagasy agricultural calendar: Asara (hot/rainy) and Asotry
## (cool/dry), alternating every DAYS_PER_SEASON days.
enum Season { ASARA, ASOTRY }
const DAYS_PER_SEASON := 30

var current_day: int = 1

func advance_day() -> void:
	current_day += 1

func get_season() -> Season:
	return Season.ASOTRY if ((current_day - 1) / DAYS_PER_SEASON) % 2 == 1 else Season.ASARA

## 1..DAYS_PER_SEASON - the date players plan around ("Asara, day 9").
func get_day_of_season() -> int:
	return (current_day - 1) % DAYS_PER_SEASON + 1

## Days left in the current season after today (0 on its last day).
func get_days_left_in_season() -> int:
	return DAYS_PER_SEASON - get_day_of_season()

## 1-based; a year is one Asara plus one Asotry.
func get_year() -> int:
	return (current_day - 1) / (DAYS_PER_SEASON * Season.size()) + 1
