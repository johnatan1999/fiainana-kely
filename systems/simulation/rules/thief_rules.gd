class_name ThiefRules
extends SimRules

## Chicken thieves (mpangalatra akoho): the rumour, the nights they're about,
## the padlock.
## A part of FarmSimulation (SimRules): simulation.thieves.

## Not in the first weeks: the player has barely started.
const THIEF_FROM_DAY := 15
const THIEF_ALERT_CHANCE := 0.12
## Nights the thieves are about once the rumour starts.
const THIEF_ALERT_NIGHTS := 3
const THIEF_NIGHT_CHANCE := 0.4
## Days after an alert before another can start.
const THIEF_COOLDOWN_DAYS := 12
## Not with fewer hens: the last one is never taken.
const THIEF_MIN_HENS := 2
## Bought, it goes straight on the coop's door (never in the bag).
const PADLOCK_ITEM := "coop_padlock"
## Whose hens went missing, in the morning's rumour.
const THIEF_RUMOUR_NEIGHBOURS := ["naivo", "rakoto", "ravao", "neny_soa"]

## The chance thieves come round on a morning, and that they try the coop
## on a night they're about (tests set 1.0 or 0.0).
var thief_alert_chance := THIEF_ALERT_CHANCE
var thief_night_chance := THIEF_NIGHT_CHANCE

## The thieves are about (the nights after the rumour).
func is_thief_alert() -> bool:
	return state.day <= state.thief_alert_until

## Thieves can't get in: the brick coop, or a padlock on the door.
func is_coop_safe() -> bool:
	return sim.projects.get_building_level("coop") >= 3 or state.coop_padlock

func get_hen_ids() -> Array:
	return state.animals.keys().filter(func(id: String) -> bool:
		return (state.animals[id] as AnimalState).species == AnimalData.Species.CHICKEN)

## Morning (advance_day): the night that just passed, if the thieves were
## about - then maybe a new rumour.
func advance_thieves() -> void:
	if state.thief_alert_until > 0 and state.day - 1 <= state.thief_alert_until and randf() < thief_night_chance:
		_thieves_come()
	if is_thief_alert() or state.day < THIEF_FROM_DAY or state.day < state.thief_next_alert_day:
		return
	if not state.has_coop or get_hen_ids().size() < THIEF_MIN_HENS or randf() >= thief_alert_chance:
		return
	state.thief_alert_until = state.day + THIEF_ALERT_NIGHTS - 1
	state.thief_next_alert_day = state.thief_alert_until + 1 + THIEF_COOLDOWN_DAYS
	state.thief_rumour = THIEF_RUMOUR_NEIGHBOURS[randi() % THIEF_RUMOUR_NEIGHBOURS.size()]
	day_log.thief_rumour = true
	sim.thief_alert_started.emit(state.thief_rumour)

## A thief at the coop: it holds if it's safe; else a hen is gone (never
## the last). Either way, the thieves move on.
func _thieves_come() -> void:
	var hens := get_hen_ids()
	if hens.size() < THIEF_MIN_HENS:
		return
	state.thief_alert_until = state.day - 1
	if sim.dog.dog_kept_watch():
		day_log.dog_chased_thieves = true
		sim.thieves_chased.emit()
		return
	if is_coop_safe():
		day_log.thieves_foiled = true
		sim.thieves_foiled.emit()
		return
	hens.sort()
	var animal_id: String = hens[randi() % hens.size()]
	state.animals.erase(animal_id)
	state.thief_stolen_day = state.day
	day_log.chicken_stolen = true
	sim.animal_removed.emit(animal_id)
	sim.chicken_stolen.emit(animal_id)

## The padlock goes on the coop's door.
func secure_coop() -> void:
	state.coop_padlock = true
	sim.coop_secured.emit()
