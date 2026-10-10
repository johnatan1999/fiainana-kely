class_name HotbarRules
extends SimRules

## The hotbar's layout: which item is in which of the FarmState.HOTBAR_SIZE
## slots. The rules that always hold - enforced here, whoever changes the
## bar: exactly HOTBAR_SIZE slots, only items the player owns, never the same
## item twice. *Which* items are worth putting there, and selection and
## controls, are Hotbar's business.
## A part of FarmSimulation (SimRules): simulation.hotbar.

func get_hotbar_item(index: int) -> String:
	if index < 0 or index >= state.hotbar.size():
		return ""
	return state.hotbar[index]

func find_in_hotbar(item_id: String) -> int:
	return state.hotbar.find(item_id) if item_id != "" else -1

func is_hotbar_initialized() -> bool:
	return not state.hotbar.is_empty()

## First layout of a new game (or a save from before the hotbar): the owned
## items of `item_ids`, in order. Does nothing once the bar has a layout.
func init_hotbar(item_ids: Array) -> void:
	if is_hotbar_initialized():
		return
	for item_id in item_ids:
		if state.hotbar.size() < FarmState.HOTBAR_SIZE and state.get_inventory_count(item_id) > 0 and not item_id in state.hotbar:
			state.hotbar.append(item_id)
	state.hotbar.resize(FarmState.HOTBAR_SIZE)
	normalize()
	sim.hotbar_changed.emit()

## Puts an owned item in slot `index`. If it was already in another slot the
## two slots swap; otherwise whatever was in `index` leaves the bar (it stays
## in the inventory). Returns whether the bar changed.
func place_in_hotbar(item_id: String, index: int) -> bool:
	if not is_hotbar_initialized() or index < 0 or index >= FarmState.HOTBAR_SIZE:
		return false
	if state.get_inventory_count(item_id) <= 0:
		return false
	var previous := find_in_hotbar(item_id)
	if previous == index:
		return false
	if previous != -1:
		state.hotbar[previous] = state.hotbar[index]
	state.hotbar[index] = item_id
	sim.hotbar_changed.emit()
	return true

## Takes an item out of the bar (it stays in the inventory).
func remove_from_hotbar(item_id: String) -> bool:
	var index := find_in_hotbar(item_id)
	if index == -1:
		return false
	state.hotbar[index] = ""
	sim.hotbar_changed.emit()
	return true

## Brings a loaded/initialized layout back within the rules above.
func normalize() -> void:
	if not is_hotbar_initialized():
		return
	state.hotbar.resize(FarmState.HOTBAR_SIZE)
	var seen := {}
	for i in FarmState.HOTBAR_SIZE:
		var item_id = state.hotbar[i]
		if item_id == null or seen.has(item_id) or state.get_inventory_count(str(item_id)) <= 0:
			state.hotbar[i] = ""
		else:
			seen[item_id] = true
