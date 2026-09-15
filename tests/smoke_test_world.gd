extends SceneTree

## Loads World.tscn (the real main scene) and every zone scene individually,
## running a few frames each, to catch wiring/parse errors before playtesting.

const SCENES := [
	"res://scenes/world/World.tscn",
	"res://scenes/areas/interiors/Interior_House.tscn",
	"res://scenes/areas/exterior/Exterior.tscn",
]

var _scene_index := 0
var _frames := 0

func _initialize() -> void:
	_load_next()

func _load_next() -> void:
	for child in root.get_children():
		child.queue_free()
	if _scene_index >= SCENES.size():
		print("All scenes instantiated and ran without error.")
		quit()
		return
	var path: String = SCENES[_scene_index]
	var packed: PackedScene = load(path)
	var instance := packed.instantiate()
	root.add_child(instance)
	print("Loaded %s" % path)
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 5:
		_scene_index += 1
		call_deferred("_load_next")
	return false
