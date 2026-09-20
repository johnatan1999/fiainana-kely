class_name AnimalState
extends RefCounted

## Runtime state of a single animal. Static definitions live in AnimalData.
## Never touches Node2D - Chicken.gd reads `activity` to pick which
## animation/behavior to play, it never writes gameplay rules back here.

enum Activity { IDLE, WALK, EAT, DRINK, SLEEP }

var id: String
var species: AnimalData.Species
var age_days: int = 0

var hunger: float = 100.0
var thirst: float = 100.0
var fed_today: bool = false
var watered_today: bool = false

## Consecutive days both fed and watered - gates breeding and the product cycle.
var days_well_cared: int = 0
var days_since_product: int = 0

var activity: Activity = Activity.IDLE

func _init(p_id: String, p_species: AnimalData.Species) -> void:
	id = p_id
	species = p_species

func is_starving() -> bool:
	return hunger <= 0.0 or thirst <= 0.0

func is_well_cared_today() -> bool:
	return fed_today and watered_today
