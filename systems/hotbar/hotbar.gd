class_name Hotbar
extends Node

## The 8-slot bar of things the player holds: the two farming tools, then
## seed stacks. Owns *what* is in each slot (stored in FarmState.hotbar so it
## is saved) and *which* slot is selected; HotbarUI only draws it and
## FarmingController only asks what is selected.
##
## Slot rules, built for muscle memory:
## - a seed the player gets and doesn't have in the bar yet takes the first
##   empty slot, and keeps that slot while they have any left;
## - a seed stack that runs out empties its slot (nothing shifts around);
## - tools never leave their slots (they're not inventory items yet).
##
## Selection: number keys pick a slot directly (empty ones included - empty
## hands still harvest), next/prev (Tab / wheel / L-R shoulder) skip empty
## slots so cycling on a gamepad is quick.

signal slots_changed
signal selection_changed(index: int)

const SIZE := 8
## Tool slots aren't inventory items (yet) - pseudo item ids for the bar.
const HOE := "hoe"
const WATERING_CAN := "watering_can"
const TOOL_IDS := [HOE, WATERING_CAN]
const DEFAULT_LAYOUT := [HOE, WATERING_CAN]
const SEED_SUFFIX := "_seed"

var simulation: FarmSimulation
var selected_index := 0

func setup(p_simulation: FarmSimulation) -> void:
	simulation = p_simulation
	simulation.inventory_changed.connect(func(_item_id: String, _count: int): _sync())
	# A save load always emits day_changed (not always inventory_changed, e.g.
	# empty inventory) and replaces FarmState.hotbar - resync on it too.
	simulation.day_changed.connect(func(_day: int): _sync())
	_sync()

func get_item(index: int) -> String:
	var slots := _slots()
	return slots[index] if index >= 0 and index < slots.size() else ""

func get_selected_item() -> String:
	return get_item(selected_index)

## Seeds held in the selected slot, 0 for tools/empty.
func get_count(index: int) -> int:
	var item_id := get_item(index)
	if item_id.ends_with(SEED_SUFFIX):
		return simulation.state.get_inventory_count(item_id)
	return 0

static func is_tool_id(item_id: String) -> bool:
	return item_id in TOOL_IDS

static func is_seed_id(item_id: String) -> bool:
	return item_id.ends_with(SEED_SUFFIX)

func select(index: int) -> void:
	index = clampi(index, 0, SIZE - 1)
	if index == selected_index:
		return
	selected_index = index
	selection_changed.emit(selected_index)

## Next/previous non-empty slot, wrapping around. Stays put if the bar only
## has the current item.
func cycle(step: int) -> void:
	for offset in range(1, SIZE):
		var index := posmod(selected_index + step * offset, SIZE)
		if get_item(index) != "":
			select(index)
			return

func _unhandled_input(event: InputEvent) -> void:
	# exact_match: Shift+Tab must not also count as plain Tab (hotbar_next).
	if event.is_action_pressed("hotbar_prev", false, true):
		cycle(-1)
	elif event.is_action_pressed("hotbar_next", false, true):
		cycle(1)
	else:
		for i in SIZE:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				select(i)
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()

func _slots() -> Array:
	return simulation.state.hotbar

## Brings FarmState.hotbar in line with the inventory: default layout on a
## new game / old save, seeds that ran out removed, new seeds slotted in.
## Runs on every inventory change - 8 slots, cheap.
func _sync() -> void:
	var slots := _slots()
	var before := slots.duplicate()
	if slots.is_empty():
		slots.append_array(DEFAULT_LAYOUT)
	slots.resize(SIZE)
	for i in SIZE:
		var item_id = slots[i]
		if item_id == null or (is_seed_id(item_id) and simulation.state.get_inventory_count(item_id) <= 0):
			slots[i] = ""
	for item_id in _owned_seeds():
		if item_id in slots:
			continue
		var free := slots.find("")
		if free == -1:
			break # bar full - the seed stays reachable in the inventory
		slots[free] = item_id
	if slots != before:
		slots_changed.emit()

## Seed stacks the player holds, in crop registry order (stable, so a batch
## bought at once always lands in the same order).
func _owned_seeds() -> Array:
	var seeds := []
	for crop_id in simulation.get_all_crop_ids():
		var item_id: String = crop_id + SEED_SUFFIX
		if simulation.state.get_inventory_count(item_id) > 0:
			seeds.append(item_id)
	return seeds
