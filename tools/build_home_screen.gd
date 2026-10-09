extends SceneTree

## Builds ui/home/home_screen.tscn, the game's main scene: a Node2D running
## HomeScreen (which builds the night scene and the menu in code).
##   godot --headless --editor --path . --script res://tools/build_home_screen.gd

const OUT := "res://ui/home/home_screen.tscn"

func _initialize() -> void:
	var screen := Node2D.new()
	screen.name = "HomeScreen"
	screen.set_script(load("res://ui/home/home_screen.gd"))
	var scene := PackedScene.new()
	scene.pack(screen)
	var error := ResourceSaver.save(scene, OUT)
	print("%s %s" % [OUT, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	screen.free()
	quit()
