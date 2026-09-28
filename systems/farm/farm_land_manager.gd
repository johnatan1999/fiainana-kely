class_name FarmLandManager
extends Node

## Bridges on-site land purchase panels (FarmZoneSign/ModularFarmZoneSign) to
## FarmSimulation's dynamic tile grid (FarmSimulation.add_tile). Land is
## bought by walking up to a physical panel in the world.
##
## The land itself is designed in the zone scenes, as FarmField nodes: each
## field's painted cells are its plots, and its `kind` says how they're
## obtained. Fields register here when their zone loads:
## - STARTER: owned from the start.
## - ZONE (macro progression): all cells unlocked at once for the flat price
##   of its FarmZoneData. The player picks WHICH zone to buy, never where
##   its tiles land.
## - PROGRESSIVE (micro progression): cells unlocked a few at a time (1 / 3x3
##   / 5x5 patches), always in a fixed left-to-right, row-by-row order - the
##   player only picks how many.
##
## Registration also restores owned land: cells of an owned field that have
## no plot yet (a field repainted bigger since the save) are added. All
## economy rules go through FarmSimulation.

signal zone_unlocked(zone_id: String)
signal progressive_tiles_changed(unlocked_count: int)

var simulation: FarmSimulation

var _zones: Dictionary = {} # zone_id: String -> {"data": FarmZoneData, "cells": Array[Vector2i]}
var _progressive_sequence: Array[Vector2i] = [] # fixed unlock order

## p_world_manager is null in unit tests that construct FarmLandManager
## standalone (it's never added to a tree there, so there's no WorldManager
## to listen to) - they call register_field() themselves.
func setup(p_simulation: FarmSimulation, p_world_manager: WorldManager = null) -> void:
	simulation = p_simulation
	if p_world_manager:
		p_world_manager.zone_loaded.connect(_on_zone_loaded)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	register_fields_in(zone)
	_setup_signs(zone)

## Registers every FarmField anywhere under `zone`.
func register_fields_in(zone: Node) -> void:
	for field in _find_descendants(zone, func(node: Node) -> bool: return node is FarmField):
		register_field(field.kind, field.get_cells(), field.zone_data)

## `cells` are in the simulation's grid space. Registering the same field
## again (its zone reloaded) just refreshes it.
func register_field(kind: FarmField.Kind, cells: Array[Vector2i], zone_data: FarmZoneData = null) -> void:
	match kind:
		FarmField.Kind.STARTER:
			_add_tiles(cells)
		FarmField.Kind.ZONE:
			if zone_data == null:
				push_error("FarmLandManager: a ZONE FarmField has no zone_data - it can't be bought")
				return
			_zones[zone_data.id] = {"data": zone_data, "cells": cells.duplicate()}
			if is_zone_unlocked(zone_data.id):
				_add_tiles(cells)
		FarmField.Kind.PROGRESSIVE:
			# One progressive zone per game for now: its unlock count is a
			# single number in FarmState.
			_progressive_sequence = _row_by_row(cells)
			_add_tiles(_progressive_sequence.slice(0, get_progressive_unlocked_count()))

func _row_by_row(cells: Array[Vector2i]) -> Array[Vector2i]:
	var sorted := cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return sorted

func _add_tiles(cells: Array) -> void:
	for cell: Vector2i in cells:
		simulation.add_tile(cell.x, cell.y) # no-op if a plot is already there

func get_zone_data(zone_id: String) -> FarmZoneData:
	return _zones.get(zone_id, {}).get("data")

func get_zone_cells(zone_id: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_zones.get(zone_id, {}).get("cells", []))
	return cells

func get_zone_tile_count(zone_id: String) -> int:
	return get_zone_cells(zone_id).size()

func is_zone_unlocked(zone_id: String) -> bool:
	return simulation.state.unlocked_zone_ids.has(zone_id)

func get_progressive_unlocked_count() -> int:
	return simulation.state.progressive_tiles_unlocked

func get_progressive_capacity() -> int:
	return _progressive_sequence.size()

## Unlocks every tile of a predefined zone at once. Fails if it's already
## owned, unknown (its field isn't registered), or unaffordable.
func buy_zone(zone_id: String) -> bool:
	if is_zone_unlocked(zone_id):
		return false
	var zone_data := get_zone_data(zone_id)
	if zone_data == null:
		return false
	if not simulation.spend_money(zone_data.price):
		return false

	simulation.state.unlocked_zone_ids[zone_id] = true
	_add_tiles(get_zone_cells(zone_id))
	zone_unlocked.emit(zone_id)
	return true

## Unlocks the next `patch_size` tiles of the progressive zone, in their
## fixed order. Fails if that would run past the zone's capacity, or the
## player can't afford total_price. total_price is supplied by the caller
## (the ItemData's price) rather than computed here, so there's a single
## source of truth for pricing - the shop catalog.
func buy_progressive_patch(patch_size: int, total_price: int) -> bool:
	if patch_size <= 0:
		return false
	var unlocked := get_progressive_unlocked_count()
	if unlocked + patch_size > _progressive_sequence.size():
		return false
	if not simulation.spend_money(total_price):
		return false

	_add_tiles(_progressive_sequence.slice(unlocked, unlocked + patch_size))
	simulation.state.progressive_tiles_unlocked = unlocked + patch_size
	progressive_tiles_changed.emit(simulation.state.progressive_tiles_unlocked)
	return true

## Purchases happen exclusively through on-site FarmZoneSign/
## ModularFarmZoneSign panels - wire up whichever of them exist in the
## freshly-loaded zone, wherever they sit in its tree (a sign can live
## inside the FarmField it sells).
func _setup_signs(zone: Node) -> void:
	for panel in _find_descendants(zone, func(node: Node) -> bool: return node is FarmZoneSign or node is ModularFarmZoneSign):
		panel.setup(self)

func _find_descendants(root: Node, matches: Callable) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children():
		if matches.call(child):
			found.append(child)
		found.append_array(_find_descendants(child, matches))
	return found
