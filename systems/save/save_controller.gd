class_name SaveController
extends Node

## Persists/restores the simulation's state, plus the player's zone and
## position, to a single JSON save file.

const SAVE_PATH := "user://savegame.json"
const DEFAULT_ZONE_ID := "VILLAGE"

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
	data["zone_id"] = Zone.ID.keys()[world_manager.current_zone_id]
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
	simulation.load_save_data(data)

	var zone_id_data = data.get("zone_id", DEFAULT_ZONE_ID)
	var zone_id := _parse_zone_id(zone_id_data)
	if zone_id != -1:
		world_manager.change_zone(zone_id as Zone.ID, "SpawnDefault")
	else:
		push_error("Unknown zone: %s" % [zone_id_data])
		
	var pos_data = data.get("player_position")
	if pos_data is Dictionary:
		player.global_position = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))

	return true

## Accepts the current String-key format ("VILLAGE"), and the raw numeric
## format a save briefly got corrupted into by an old save_game() bug -
## returns -1 if neither matches so callers can fall back safely.
func _parse_zone_id(zone_id_data) -> int:
	if zone_id_data is String and Zone.ID.has(zone_id_data):
		return Zone.ID[zone_id_data]
	if (zone_id_data is float or zone_id_data is int) and int(zone_id_data) in Zone.ID.values():
		return int(zone_id_data)
	return -1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		save_game()
	elif event.is_action_pressed("load_game"):
		load_game()
