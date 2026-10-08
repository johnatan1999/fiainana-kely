extends Node

## Runs one integration test in the full game environment - autoloads
## (AudioManager, UIEvents, GameSettings...) included, which `--script` mode
## doesn't load. Tests are plain Nodes in tests/, added as this node's child:
##   godot --headless --fixed-fps 60 --path . res://tests/runner.tscn -- <test file name>
## e.g. `-- smoke_test_world`. A test prints its PASS/FAIL lines and quits
## with exit code 1 if anything failed (see each test's _finish()).
## --fixed-fps 60: every frame is exactly 1/60 s of game time and the next
## one starts right away - the same run, without waiting on the wall clock
## (behaviour_test: ~13 s instead of ~3.5 min).
##
## Exit codes: 2 = no such test, or its script doesn't compile; 3 = the test
## didn't finish within TIMEOUT_SECONDS of real time (stuck awaiting
## something) - so a broken test fails instead of hanging.
##
## Pure simulation tests don't need any of this: run_tests.gd stays a
## `--script` SceneTree.

const TIMEOUT_SECONDS := 600

var _started_msec := 0

func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	get_tree().process_frame.connect(_check_timeout)
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("tests/runner.tscn: name the test to run after --, e.g. `-- smoke_test_world`.")
		get_tree().quit(2)
		return
	var path := "res://tests/%s.gd" % args[0]
	if not ResourceLoader.exists(path):
		push_error("tests/runner.tscn: no test named '%s' in tests/." % args[0])
		get_tree().quit(2)
		return
	# A script with a parse error still loads, but can't be instantiated.
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		push_error("tests/runner.tscn: %s doesn't compile - see the errors above." % path)
		get_tree().quit(2)
		return
	var test: Node = script.new()
	test.name = args[0]
	add_child(test)

## Real time, not game time (with --fixed-fps, game time runs ahead). On
## the tree's process_frame, which still fires while a test has the game
## paused (an open shop...) - _process wouldn't.
func _check_timeout() -> void:
	if Time.get_ticks_msec() - _started_msec > TIMEOUT_SECONDS * 1000:
		get_tree().process_frame.disconnect(_check_timeout)
		push_error("tests/runner.tscn: the test didn't finish within %d s - stuck?" % TIMEOUT_SECONDS)
		print("FAIL: test timed out after %d s" % TIMEOUT_SECONDS)
		get_tree().quit(3)
