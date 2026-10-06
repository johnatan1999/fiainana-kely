extends Node

## Runs one integration test in the full game environment - autoloads
## (AudioManager, UIEvents, GameSettings...) included, which `--script` mode
## doesn't load. Tests are plain Nodes in tests/, added as this node's child:
##   godot --headless --path . res://tests/runner.tscn -- <test file name>
## e.g. `-- smoke_test_world`. A test prints its PASS/FAIL lines and quits
## with exit code 1 if anything failed (see each test's _finish()).
##
## Pure simulation tests don't need any of this: run_tests.gd stays a
## `--script` SceneTree.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("tests/runner.tscn: name the test to run after --, e.g. `-- smoke_test_world`.")
		get_tree().quit(2)
		return
	var script: GDScript = load("res://tests/%s.gd" % args[0])
	if script == null:
		push_error("tests/runner.tscn: no test named '%s' in tests/." % args[0])
		get_tree().quit(2)
		return
	var test: Node = script.new()
	test.name = args[0]
	add_child(test)
