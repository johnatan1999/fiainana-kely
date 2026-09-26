class_name SaveController
extends Node

## Persists/restores the simulation's state, plus the player's zone and
## position, to a single JSON save file.

const SAVE_PATH := "user://savegame.json"
const DEFAULT_ZONE_ID := "village"

## Bump this whenever the save format changes, and add a matching
## _migrate_to_vN() step below - never rewrite an existing step once it has
## shipped, only append new ones. This is the single place format drift gets
## fixed, instead of runtime code scattered across load_game() staying
## permanently tolerant of every historical format.
const SAVE_VERSION := 5

var simulation: FarmSimulation
var world_manager: WorldManager
var player: PlayerController

func setup(p_simulation: FarmSimulation, p_world_manager: WorldManager, p_player: PlayerController) -> void:
	simulation = p_simulation
	world_manager = p_world_manager
	player = p_player

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := simulation.to_save_data()
	data["save_version"] = SAVE_VERSION
	data["zone_id"] = world_manager.current_zone_id
	data["return_point"] = world_manager.get_return_point()
	data["player_position"] = {"x": player.global_position.x, "y": player.global_position.y}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

## Restores simulation state, then re-enters the saved zone at the saved
## position instead of the zone's default spawn marker.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var save_version := int(data.get("save_version", 0))
	if save_version > SAVE_VERSION:
		push_error("Save file is from a newer game version (v%d) than this build supports (v%d) - refusing to load it to avoid corrupting it." % [save_version, SAVE_VERSION])
		return false
	data = _migrate(data, save_version)

	simulation.load_save_data(data)

	# Optional key (older saves have none): only means "no way back known yet".
	world_manager.set_return_point(data.get("return_point", {}) if data.get("return_point") is Dictionary else {})
	var zone_id: String = data.get("zone_id", DEFAULT_ZONE_ID)
	if world_manager.has_zone(zone_id):
		world_manager.change_zone(zone_id, "SpawnDefault")
	else:
		push_error("Unknown zone: " + zone_id)

	var pos_data = data.get("player_position")
	if pos_data is Dictionary:
		player.global_position = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))

	return true

## Applies every migration step between the save's version and SAVE_VERSION,
## in order. A save from any older version keeps loading correctly as the
## format evolves - the next format change adds one more `if from_version < N`
## step here instead of teaching load_game() itself to tolerate old formats
## forever.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version < 1:
		data = _migrate_to_v1(data)
	if from_version < 2:
		data = _migrate_to_v2(data)
	if from_version < 3:
		data = _migrate_to_v3(data)
	if from_version < 4:
		data = _migrate_to_v4(data)
	if from_version < 5:
		data = _migrate_to_v5(data)
	return data

## v0 (unversioned save, predates this field entirely) -> v1: zone_id was
## briefly written as a raw Zone.ID int by a save_game() bug instead of its
## string key name - normalize it to the string key name v1 expects.
## Hardcoded snapshot of the enum as it existed at v1, deliberately NOT
## referencing the (now-deleted) Zone.ID class - a migration step has to keep
## meaning exactly what it meant when it shipped, independent of whatever the
## live code looks like today.
const _V1_ENUM_KEYS := ["VILLAGE", "PLAYER_HOUSE", "CHICKEN_COOP"]
func _migrate_to_v1(data: Dictionary) -> Dictionary:
	var zone_id_data = data.get("zone_id")
	if zone_id_data is float or zone_id_data is int:
		var idx := int(zone_id_data)
		if idx >= 0 and idx < _V1_ENUM_KEYS.size():
			data["zone_id"] = _V1_ENUM_KEYS[idx]
	return data

## v1 -> v2: zone ids moved from Zone.ID enum key names ("VILLAGE") to
## free-form lowercase ZoneData ids ("village") when WorldManager switched to
## a data-driven, auto-discovered zone registry (data/world_zones/*.tres).
const _V2_ZONE_ID_MAP := {
	"VILLAGE": "village",
	"PLAYER_HOUSE": "player_house",
	"CHICKEN_COOP": "chicken_coop",
}
func _migrate_to_v2(data: Dictionary) -> Dictionary:
	var old_id = data.get("zone_id")
	if old_id is String and _V2_ZONE_ID_MAP.has(old_id):
		data["zone_id"] = _V2_ZONE_ID_MAP[old_id]
	return data

## v2 -> v3: items of crops removed from the game (turnip, cut in 9aacc4a)
## are dropped from the inventory and refunded, so the player never just
## loses what they owned. Turnip was cut before the currency change
## (a3068a9), which multiplied every price by exactly 100 - so its last
## shipped prices (sell 30, seed 10) are converted the same way.
## Hardcoded snapshot, same reason as v1.
const _V3_REMOVED_ITEM_REFUNDS := {
	"turnip": 30 * 100,
	"turnip_seed": 10 * 100,
}
func _migrate_to_v3(data: Dictionary) -> Dictionary:
	var inventory = data.get("inventory")
	if not inventory is Dictionary:
		return data
	var refund := 0
	for item_id in _V3_REMOVED_ITEM_REFUNDS:
		if inventory.has(item_id):
			refund += maxi(0, int(inventory[item_id])) * _V3_REMOVED_ITEM_REFUNDS[item_id]
			inventory.erase(item_id)
	if refund > 0:
		data["money"] = int(data.get("money", 0)) + refund
		print("SaveController: removed-crop items refunded for %d Ar." % refund)
	return data

## v3 -> v4: the hoe and watering can became real inventory items (they
## used to be always-owned pseudo tools, "hoe"/"watering_can" in the hotbar).
## Every player had them, so every save gets them, and hotbar slots holding
## the old pseudo ids now hold the items. Hardcoded snapshot, same reason as v1.
const _V4_STARTER_TOOLS := ["tool_hoe", "tool_watering_can"]
const _V4_HOTBAR_IDS := {"hoe": "tool_hoe", "watering_can": "tool_watering_can"}
func _migrate_to_v4(data: Dictionary) -> Dictionary:
	var inventory = data.get("inventory")
	if not inventory is Dictionary:
		inventory = {}
		data["inventory"] = inventory
	for item_id in _V4_STARTER_TOOLS:
		inventory[item_id] = maxi(int(inventory.get(item_id, 0)), 1)
	var hotbar = data.get("hotbar")
	if hotbar is Array:
		for i in hotbar.size():
			hotbar[i] = _V4_HOTBAR_IDS.get(str(hotbar[i]), hotbar[i])
	return data

## v4 -> v5: animals bought but not settled yet were inventory items
## ("<species prefix>_unplaced" x count); they're now their own list,
## pending_animals (species index as a string key -> count), out of the bag.
## Hardcoded snapshot of the prefixes, in AnimalData.Species order as of v5.
const _V5_SPECIES_PREFIXES := ["chicken", "duck", "goose", "pig", "zebu"]
func _migrate_to_v5(data: Dictionary) -> Dictionary:
	var inventory = data.get("inventory")
	if not inventory is Dictionary:
		return data
	var pending := {}
	for species in _V5_SPECIES_PREFIXES.size():
		var key: String = _V5_SPECIES_PREFIXES[species] + "_unplaced"
		if inventory.has(key):
			var count := int(inventory[key])
			inventory.erase(key)
			if count > 0:
				pending[str(species)] = count
	data["pending_animals"] = pending
	return data

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		save_game()
	elif event.is_action_pressed("load_game"):
		load_game()
