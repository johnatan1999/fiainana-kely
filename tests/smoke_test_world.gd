extends Node

## Loads World.tscn (the real main scene) and every zone scene individually,
## running a few frames each, to catch wiring/parse errors before playtesting.
##
## Runs through tests/runner.tscn (full game environment, autoloads loaded):
##   godot --headless --path . res://tests/runner.tscn -- smoke_test_world

const SCENES := [
	"res://world/world.tscn",
	"res://world/areas/interior/player_interior_house.tscn",
	"res://world/areas/exterior/player_village.tscn",
	"res://world/areas/exterior/rice_fields.tscn",
	"res://world/areas/interior/farm/chicken_coop_interior.tscn",
]

var _scene_index := 0
var _frames := 0

func _ready() -> void:
	_load_next()

func _load_next() -> void:
	for child in get_children():
		child.queue_free()
	if _scene_index >= SCENES.size():
		print("All scenes instantiated and ran without error.")
		get_tree().quit()
		return
	var path: String = SCENES[_scene_index]
	var packed: PackedScene = load(path)
	var instance := packed.instantiate()
	add_child(instance)
	print("Loaded %s" % path)
	_frames = 0

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 6:
		_scene_index += 1
		call_deferred("_load_next")
