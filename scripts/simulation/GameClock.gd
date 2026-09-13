class_name GameClock
extends RefCounted

var current_day: int = 1

func advance_day() -> void:
	current_day += 1
