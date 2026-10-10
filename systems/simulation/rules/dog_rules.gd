class_name DogRules
extends SimRules

## The family's dog (alika): its name, its bowl, petting it - and the nights it
## keeps watch.
## A part of FarmSimulation (SimRules): simulation.dog.

## The puppy's name until the player gives it one.
const DOG_NAMES := ["Tsiky", "Bobaka", "Kintana", "Kely", "Soa", "Tsara", "Mavo", "Rary"]
const DOG_NAME_MAX_LENGTH := 14
## Coats (Dog.COATS).
const DOG_COATS := 4
## A puppy grows into a dog in this many days.
const DOG_GROWN_DAYS := 14
## Days petted, for a heart; and the most there is.
const DOG_BOND_PER_HEART := 4
const DOG_MAX_HEARTS := 5

func has_dog() -> bool:
	return state.dog != null

## The puppy comes to the farm. False if there's one already.
func adopt_dog(coat := -1) -> bool:
	if has_dog():
		return false
	state.dog = DogState.new(DOG_NAMES[randi() % DOG_NAMES.size()],
		coat if coat >= 0 else randi() % DOG_COATS, state.day)
	sim.dog_adopted.emit()
	sim.dog_changed.emit()
	return true

func get_dog_name() -> String:
	return state.dog.name if has_dog() else ""

## Named by the player: trimmed, DOG_NAME_MAX_LENGTH at most. False for an
## empty name.
func rename_dog(dog_name: String) -> bool:
	var clean := dog_name.strip_edges().left(DOG_NAME_MAX_LENGTH).strip_edges()
	if not has_dog() or clean.is_empty():
		return false
	state.dog.name = clean
	sim.dog_changed.emit()
	return true

func get_dog_coat() -> int:
	return state.dog.coat if has_dog() else 0

## Days since it came (0: it came today).
func get_dog_days() -> int:
	return state.day - state.dog.since if has_dog() else 0

## 0 (a puppy, the day it came) to 1 (grown, after DOG_GROWN_DAYS).
func get_dog_growth() -> float:
	if not has_dog():
		return 1.0
	return clampf(float(get_dog_days()) / DOG_GROWN_DAYS, 0.0, 1.0)

## Its bowl filled today: tonight it stays at the farm and keeps watch. The
## family's leftover rice - nothing to buy, a daily care like the zebus'
## trough.
func feed_dog() -> bool:
	if not has_dog() or is_dog_fed():
		return false
	state.dog.fed_day = state.day
	sim.dog_changed.emit()
	return true

func is_dog_fed() -> bool:
	return has_dog() and state.dog.fed_day == state.day

## Last night (asked in the morning, from advance_day): it had eaten, so it
## stayed and kept watch. Not fed, it went looking for food in the village.
func dog_kept_watch() -> bool:
	return has_dog() and state.dog.fed_day == state.day - 1

## Petted: the first time in a day, it grows fonder of the player (true).
func pet_dog() -> bool:
	if not has_dog() or is_dog_petted():
		return false
	state.dog.petted_day = state.day
	state.dog.bond = mini(state.dog.bond + 1, DOG_BOND_PER_HEART * DOG_MAX_HEARTS)
	sim.dog_changed.emit()
	return true

func is_dog_petted() -> bool:
	return has_dog() and state.dog.petted_day == state.day

## How fond of the player it is: 0 to DOG_MAX_HEARTS.
func get_dog_hearts() -> int:
	return state.dog.bond / DOG_BOND_PER_HEART if has_dog() else 0
