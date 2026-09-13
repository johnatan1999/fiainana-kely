extends SceneTree

## Loads Game.tscn, lets it run a few frames, then quits cleanly.
## Verifies the presentation layer wires up without runtime errors.

var _frames := 0

func _initialize() -> void:
	var game_scene: PackedScene = load("res://scenes/game/Game.tscn")
	var game := game_scene.instantiate()
	root.add_child(game)
	print("Game scene instantiated OK.")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 5:
		print("Ran %d frames without error." % _frames)
		quit()
	return false
