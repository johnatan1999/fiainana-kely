class_name Hotbar
extends Node

## The 8-slot bar of things the player holds - a view of the inventory: only
## real inventory items with a use on the farm (tools, seed stacks - see
## ItemDatabase.is_hotbar_item()). Owns *what* is in each slot (stored in
## FarmState.hotbar so it's saved) and *which* slot is selected; HotbarUI
## only draws it, FarmingController asks what the held item does, and the
## inventory book arranges it (assign()/remove()).
##
## Slot rules, built for muscle memory:
## - an item the player *newly acquires* takes the first empty slot - one
##   they removed from the bar on purpose isn't pushed back in;
## - an item they no longer have empties its slot (nothing shifts around);
## - placing an item already in the bar onto another slot swaps the two.
##
## Selection: number keys pick a slot directly, next/prev (Tab / wheel / L-R
## shoulder) skip empty slots so cycling on a gamepad is quick.

signal slots_changed
signal selection_changed(index: int)

const SIZE := 8
const SEED_SUFFIX := "_seed"

var simulation: FarmSimulation
var item_db: ItemDatabase
var selected_index := 0
## Last inventory count seen per item - an item going from 0 to more is a
## new acquisition (auto-slotted), anything else isn't.
var _known_counts: Dictionary = {}

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase) -> void:
	simulation = p_simulation
	item_db = p_item_db
	simulation.inventory_changed.connect(_on_inventory_changed)
	simulation.state_loaded.connect(_reset_from_state)
	_reset_from_state()

func get_item(index: int) -> String:
	var slots := _slots()
	return slots[index] if index >= 0 and index < slots.size() else ""

func get_selected_item() -> String:
	return get_item(selected_index)

## What the held item does when used (ShopItemData.ToolType).
func get_selected_tool_type() -> ShopItemData.ToolType:
	return item_db.get_tool_type(get_selected_item())

## How many of the item in `index` the player has (0 for an empty slot).
func get_count(index: int) -> int:
	var item_id := get_item(index)
	return simulation.state.get_inventory_count(item_id) if item_id != "" else 0

func index_of(item_id: String) -> int:
	return _slots().find(item_id)

static func is_seed_id(item_id: String) -> bool:
	return item_id.ends_with(SEED_SUFFIX)

## Puts `item_id` in slot `index` (from the inventory book). If it was
## already in another slot, the two slots swap; otherwise whatever was in
## `index` leaves the bar (it stays in the inventory).
func assign(item_id: String, index: int) -> void:
	if index < 0 or index >= SIZE or not item_db.is_hotbar_item(item_id):
		return
	if simulation.state.get_inventory_count(item_id) <= 0:
		return
	var slots := _slots()
	var previous := slots.find(item_id)
	if previous == index:
		return
	if previous != -1:
		slots[previous] = slots[index]
	slots[index] = item_id
	slots_changed.emit()

## Takes `item_id` out of the bar (it stays in the inventory).
func remove(item_id: String) -> void:
	var index := index_of(item_id)
	if index == -1:
		return
	_slots()[index] = ""
	slots_changed.emit()

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

## New game, or a save just loaded: default layout if there's none yet (a
## new game, or a save from before the hotbar), then drop anything the
## player doesn't own - without auto-adding: the saved layout is respected.
func _reset_from_state() -> void:
	var slots := _slots()
	if slots.is_empty():
		for item_id in item_db.get_tool_ids() + item_db.get_seed_ids():
			if slots.size() < SIZE and simulation.state.get_inventory_count(item_id) > 0:
				slots.append(item_id)
	slots.resize(SIZE)
	for i in SIZE:
		var item_id = slots[i]
		if item_id == null or not _holds(str(item_id)):
			slots[i] = ""
	_known_counts = simulation.state.inventory.duplicate()
	slots_changed.emit()

func _on_inventory_changed(item_id: String, count: int) -> void:
	var was_owned: bool = _known_counts.get(item_id, 0) > 0
	_known_counts[item_id] = count
	var slots := _slots()
	var index := slots.find(item_id)
	if count <= 0 and index != -1:
		slots[index] = ""
		slots_changed.emit()
	elif count > 0 and not was_owned and index == -1 and item_db.is_hotbar_item(item_id):
		var free := slots.find("")
		if free != -1: # bar full: still reachable from the inventory book
			slots[free] = item_id
			slots_changed.emit()

## Whether `item_id` can stay in the bar: a hotbar item the player still has.
func _holds(item_id: String) -> bool:
	return item_id != "" and item_db.is_hotbar_item(item_id) and simulation.state.get_inventory_count(item_id) > 0
