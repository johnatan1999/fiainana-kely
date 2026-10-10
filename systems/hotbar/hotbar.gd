class_name Hotbar
extends Node

## The player's hotbar: *which* slot is selected, the controls that change
## it, and the policy for what goes in the bar. The layout itself (which
## item is in which slot) is game state owned by FarmSimulation - read and
## changed only through its hotbar methods, which keep it valid. HotbarUI
## draws it, FarmingController asks what the held item does, the inventory
## book arranges it (assign()/remove()).
##
## Policy, built for muscle memory:
## - only items with a use on the farm go in the bar (tools, seed stacks -
##   ItemDatabase.is_hotbar_item());
## - an item the player *newly acquires* takes the first empty slot - one
##   they removed from the bar on purpose isn't pushed back in;
## - an item they no longer have empties its slot (FarmSimulation does that,
##   nothing shifts around);
## - placing an item already in the bar onto another slot swaps the two.
##
## Selection: number keys pick a slot directly, next/prev (Tab / wheel / L-R
## shoulder) skip empty slots so cycling on a gamepad is quick.

signal slots_changed
signal selection_changed(index: int)

const SIZE := FarmState.HOTBAR_SIZE

var simulation: FarmSimulation
var item_db: ItemDatabase
var selected_index := 0
## Last inventory count seen per item - an item going from 0 to more is a
## new acquisition (auto-slotted), anything else isn't.
var _known_counts: Dictionary = {}

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase) -> void:
	simulation = p_simulation
	item_db = p_item_db
	simulation.hotbar_changed.connect(func(): slots_changed.emit())
	simulation.inventory_changed.connect(_on_inventory_changed)
	simulation.state_loaded.connect(_on_state_loaded)
	_on_state_loaded()

func get_item(index: int) -> String:
	return simulation.hotbar.get_hotbar_item(index)

func get_selected_item() -> String:
	return get_item(selected_index)

## What using the held item does to a plot.
func get_selected_action() -> FarmAction.Type:
	return item_db.get_use_action(get_selected_item())

## Crop the held seed stack plants, "" if the held item isn't seeds.
func get_selected_seed_crop_id() -> String:
	return item_db.get_seed_crop_id(get_selected_item())

## How many of the item in `index` the player has (0 for an empty slot).
func get_count(index: int) -> int:
	var item_id := get_item(index)
	return simulation.state.get_inventory_count(item_id) if item_id != "" else 0

func index_of(item_id: String) -> int:
	return simulation.hotbar.find_in_hotbar(item_id)

## Puts `item_id` in slot `index` (from the inventory book) - swaps if it was
## already in the bar. Items with no farm use are refused.
func assign(item_id: String, index: int) -> void:
	if item_db.is_hotbar_item(item_id):
		simulation.hotbar.place_in_hotbar(item_id, index)

## Takes `item_id` out of the bar (it stays in the inventory).
func remove(item_id: String) -> void:
	simulation.hotbar.remove_from_hotbar(item_id)

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

## New game, or a save just loaded: default layout if there's none yet (tools
## first, then seeds), and items with no farm use taken out - without
## auto-adding anything: a saved layout is respected as it was.
func _on_state_loaded() -> void:
	simulation.hotbar.init_hotbar(item_db.get_tool_ids() + item_db.get_seed_ids())
	for i in SIZE:
		var item_id := get_item(i)
		if item_id != "" and not item_db.is_hotbar_item(item_id):
			simulation.hotbar.remove_from_hotbar(item_id)
	_known_counts = simulation.state.inventory.duplicate()

func _on_inventory_changed(item_id: String, count: int) -> void:
	var was_owned: bool = _known_counts.get(item_id, 0) > 0
	_known_counts[item_id] = count
	if count <= 0 or was_owned or index_of(item_id) != -1 or not item_db.is_hotbar_item(item_id):
		return
	for i in SIZE:
		if get_item(i) == "":
			simulation.hotbar.place_in_hotbar(item_id, i)
			return
	# Bar full: the item stays reachable from the inventory book.
