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
