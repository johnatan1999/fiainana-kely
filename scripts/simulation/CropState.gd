class_name CropState
extends RefCounted

## Runtime state of a single planted crop. Static definitions live in CropData.

enum Stage { SEED, SPROUT, GROWING, MATURE }

var crop_id: String
var age: int = 0
var growth_days: int

## days_total counts every elapsed day since planting, watered or not.
## days_watered counts only the days it was actually watered.
## Their ratio drives the quality penalty applied at harvest.
var days_watered: int = 0
var days_total: int = 0

func _init(p_crop_id: String, p_growth_days: int) -> void:
	crop_id = p_crop_id
	growth_days = p_growth_days

func is_mature() -> bool:
	return age >= growth_days

func get_watered_ratio() -> float:
	if days_total <= 0:
		return 1.0
	return float(days_watered) / float(days_total)

## Presentation reads this instead of branching on age/growth_days itself.
## Thresholds scale with growth_days so a 4-day maize and a 45-day vanilla
## both pass through all four stages.
func get_stage() -> Stage:
	if is_mature():
		return Stage.MATURE
	var progress := float(age) / float(growth_days) if growth_days > 0 else 0.0
	if progress <= 0.0:
		return Stage.SEED
	elif progress < 0.33:
		return Stage.SPROUT
	else:
		return Stage.GROWING
