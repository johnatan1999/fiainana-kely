class_name CropState
extends RefCounted

## Runtime state of a single planted crop. Static definitions live in CropData.

enum Stage { SEED, SPROUT, GROWING, MATURE }

var crop_id: String
var age: int = 0
var growth_days: int

func _init(p_crop_id: String, p_growth_days: int) -> void:
	crop_id = p_crop_id
	growth_days = p_growth_days

func is_mature() -> bool:
	return age >= growth_days

## Presentation reads this instead of branching on age/growth_days itself.
func get_stage() -> Stage:
	if is_mature():
		return Stage.MATURE
	elif age <= 0:
		return Stage.SEED
	elif age == 1:
		return Stage.SPROUT
	else:
		return Stage.GROWING
