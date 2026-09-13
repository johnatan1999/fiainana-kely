class_name SaveController
extends Node

## Persists/restores the simulation's state to a single JSON save file.

const SAVE_PATH := "user://savegame.json"

var simulation: FarmSimulation

func setup(p_simulation: FarmSimulation) -> void:
	simulation = p_simulation

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(simulation.to_save_data()))

func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	simulation.load_save_data(data)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		save_game()
	elif event.is_action_pressed("load_game"):
		load_game()
