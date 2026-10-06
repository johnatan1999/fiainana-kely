extends SceneTree

## Adds a node with a script under World's Gameplay node (a new manager or
## controller) - if there's none by that name yet - and saves world.tscn.
## Wire it up in world.gd afterwards (@onready + setup()).
##   godot --headless --editor --path . --script res://tools/add_gameplay_node.gd -- <NodeName> <res://path/to/script.gd>
## With --editor: re-saving a scene outside the editor writes every exported
## default into it (see CLAUDE.md).

const WORLD := "res://world/world.tscn"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("add_gameplay_node: give the node name and its script, e.g. -- NeighbourPaddyManager res://systems/farm/neighbour_paddy_manager.gd")
		quit(2)
		return
	var world: Node = (load(WORLD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var gameplay := world.get_node("Gameplay")
	if gameplay.has_node(args[0]):
		print("%s: Gameplay/%s is already there" % [WORLD, args[0]])
	else:
		var node := Node.new()
		node.name = args[0]
		node.set_script(load(args[1]))
		gameplay.add_child(node)
		node.owner = world
		var scene := PackedScene.new()
		scene.pack(world)
		var error := ResourceSaver.save(scene, WORLD)
		print("%s: Gameplay/%s added%s" % [WORLD, args[0], "" if error == OK else " - SAVE FAILED (%d)" % error])
	world.free()
	quit()
