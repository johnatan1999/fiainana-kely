extends SceneTree

## Adds a node with a script to world.tscn - a manager under Gameplay, a
## panel under UI... - if there's none by that name there yet, and saves the
## scene. Wire it up in world.gd afterwards (@onready + setup()).
##   godot --headless --editor --path . --script res://tools/add_world_node.gd -- <Parent> <NodeName> <Node|Control> <res://path/to/script.gd>
## e.g. -- Gameplay OrderManager Node res://systems/orders/order_manager.gd
## With --editor: re-saving a scene outside the editor writes every exported
## default into it (see CLAUDE.md).

const WORLD := "res://world/world.tscn"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or not args[2] in ["Node", "Control"]:
		push_error("add_world_node: -- <Parent> <NodeName> <Node|Control> <script>, e.g. -- Gameplay OrderManager Node res://systems/orders/order_manager.gd")
		quit(2)
		return
	var world: Node = (load(WORLD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var parent := world.get_node(args[0])
	if parent.has_node(args[1]):
		print("%s: %s/%s is already there" % [WORLD, args[0], args[1]])
	else:
		var node: Node = Node.new() if args[2] == "Node" else Control.new()
		node.name = args[1]
		node.set_script(load(args[3]))
		parent.add_child(node)
		node.owner = world
		var scene := PackedScene.new()
		scene.pack(world)
		var error := ResourceSaver.save(scene, WORLD)
		print("%s: %s/%s added%s" % [WORLD, args[0], args[1], "" if error == OK else " - SAVE FAILED (%d)" % error])
	world.free()
	quit()
