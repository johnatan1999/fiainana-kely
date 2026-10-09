class_name MarketDayOnly
extends Node2D

## Its children (the zebus for sale at the zebu market) are only there on
## market day (GameClock.MARKET_DAY): on the other days they're taken out
## of the tree - not just hidden, so they don't block the way - and put back
## on the next market day. Keeps the weekday (DayNightController.
## CALENDAR_GROUP).

var _kept: Array[Node] = []

func _ready() -> void:
	add_to_group(DayNightController.CALENDAR_GROUP)

func set_weekday(weekday: int) -> void:
	var market := weekday == GameClock.MARKET_DAY
	if market:
		for child in _kept:
			add_child(child)
		_kept.clear()
	else:
		for child in get_children():
			_kept.append(child)
			remove_child(child)

func is_market_on() -> bool:
	return _kept.is_empty()

## Freed with the zone: free what's out of the tree along with it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for child in _kept:
			child.free()
		_kept.clear()
