class_name WorldManager
extends Node

## Owns zone loading/unloading. The player, camera and simulation persist across
## zone changes - only the zone scene (background, plots, triggers) is swapped.
##
## Zones are data, not code: every .tres under ZONES_DIR is a ZoneData
## (id + scene) auto-discovered at startup. Adding a new zone to the game
## never touches this file - just drop in a new .tres and scene.
##
## Never hunts down other managers' structures itself either - it only emits
## zone_loaded/zone_unloading, and FarmingController/AnimalManager/
## FarmLandManager each listen and wire themselves up to whatever they find in
## the new zone.

signal zone_loaded(zone: ZoneRoot)
signal zone_unloading(zone: ZoneRoot)
## The player slept: the new day has begun, they're up at the WakeSpot
## (SaveController saves the game then).
signal slept

const ZONES_DIR := "res://data/world_zones/"

## Loaded on use, not preload()ed - see AnimalManager.SPECIES_SCENE_PATHS for
## the load cycle that preloading caused.
const CHICKEN_SCENE_PATH := "res://entities/animals/chicken/chicken.tscn"
## How many decorative (non-simulated) chickens to show around the coop
## building in the village, capped regardless of how many are actually owned.
const MAX_DECORATIVE_CHICKENS := 4

## Each direction (to black, back to clear) of a player-triggered transition.
const FADE_DURATION := 0.25

var simulation: FarmSimulation
var player: PlayerController
var zone_container: Node2D

var current_zone: ZoneRoot
var current_zone_id: String = ""

var _zones: Dictionary = {} # id: String -> ZoneData
var _fade_overlay: ColorRect
## The door the player last went in by, to come back out through it from a
## shared interior: {"zone": id, "spawn": path to a Marker2D in that zone}.
## Empty when unknown. Saved (see get/set_return_point) - quitting inside a
## house must not lose the way out.
var _return_point: Dictionary = {}

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_zone_container: Node2D) -> void:
	simulation = p_simulation
	player = p_player
	zone_container = p_zone_container
	_load_zone_registry()
	_create_fade_overlay()
	# The window can change shape (aspect "expand"): refit the camera.
	get_viewport().size_changed.connect(_apply_camera_limits)

## Built in code rather than as a .tscn node: a plain full-screen ColorRect on
## its own high-priority CanvasLayer, independent of zone_container's
## lifecycle (never freed/recreated by change_zone()).
func _create_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_overlay)
	# Deferred: this runs from World.gd's _ready(), while the root viewport is
	# still mid-setup adding World itself as a child - a synchronous
	# add_child() here hits "Parent node is busy setting up children".
	get_tree().root.add_child.call_deferred(layer)

func has_zone(zone_id: String) -> bool:
	return _zones.has(zone_id)

func _load_zone_registry() -> void:
	_zones.clear()
	var dir := DirAccess.open(ZONES_DIR)
	if dir == null:
		push_error("WorldManager: cannot open zones directory %s" % ZONES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var zone_data: ZoneData = load(ZONES_DIR + file_name)
			if zone_data == null or zone_data.id.is_empty():
				push_warning("WorldManager: %s has no valid ZoneData.id - skipped." % file_name)
			elif _zones.has(zone_data.id):
				push_warning("WorldManager: duplicate zone id '%s' (%s) - keeping the first one found." % [zone_data.id, file_name])
			else:
				_zones[zone_data.id] = zone_data
		file_name = dir.get_next()
	dir.list_dir_end()

## ZoneTransition/SleepSpot fire from inside Area2D signals during the physics
## step, which forbids reparenting/freeing physics nodes right away - defer it.
func request_zone_change(zone_id: String, spawn_name: String) -> void:
	call_deferred("_change_zone_with_fade", zone_id, spawn_name)

## Player-triggered transitions (walking through a door) fade to black to
## mask the instant scene swap. Direct callers - World.gd's initial zone
## load and SaveController.load_game() - call change_zone() straight instead,
## since there's nothing on screen yet worth hiding behind a fade at boot.
func _change_zone_with_fade(zone_id: String, spawn_name: String) -> void:
	player.input_enabled = false
	await _fade_to(1.0)
	change_zone(zone_id, spawn_name)
	await _fade_to(0.0)
	player.input_enabled = true

func _fade_to(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", target_alpha, FADE_DURATION)
	await tween.finished

func change_zone(zone_id: String, spawn_name: String = "SpawnDefault") -> void:
	var zone_data: ZoneData = _zones.get(zone_id)
	if zone_data == null:
		push_error("WorldManager: unknown zone id '%s' - is there a matching .tres in %s?" % [zone_id, ZONES_DIR])
		return

	if current_zone != null:
		zone_unloading.emit(current_zone)
		# Out of the tree now, not at the end of the frame: until then its
		# walls would still be in the physics space, and the player, set
		# down at the new spawn, could be pushed out of them - into an exit.
		zone_container.remove_child(current_zone)
		current_zone.queue_free()

	var zone: ZoneRoot = zone_data.scene.instantiate()
	zone_container.add_child(zone)
	current_zone = zone
	current_zone_id = zone_id

	var spawn := _find_spawn(zone, spawn_name)
	if spawn == null and spawn_name != "SpawnDefault":
		push_warning("WorldManager: spawn '%s' not found in zone '%s' - falling back to SpawnDefault." % [spawn_name, zone_id])
		spawn = _find_spawn(zone, "SpawnDefault")
	if spawn:
		player.global_position = spawn.global_position

	player.camera.zoom = Vector2(zone.camera_zoom, zone.camera_zoom)
	_apply_camera_limits()

	_apply_zone_bgm(zone)
	_wire_zone_content(zone)

## The zone's bounds (ZoneRoot.get_camera_bounds()), except along an axis
## where the zone is smaller than the view (a small room): there the limits
## are widened evenly around it, so the room sits still, centered, on the
## (black) clear color - instead of hugging one edge or sliding around as
## the player walks.
func _apply_camera_limits() -> void:
	if current_zone == null:
		return
	var bounds := current_zone.get_camera_bounds()
	var view := get_viewport().get_visible_rect().size / player.camera.zoom
	var x := _fit_axis(floori(bounds.position.x), ceili(bounds.end.x), view.x)
	var y := _fit_axis(floori(bounds.position.y), ceili(bounds.end.y), view.y)
	player.camera.limit_left = x.x
	player.camera.limit_right = x.y
	player.camera.limit_top = y.x
	player.camera.limit_bottom = y.y

static func _fit_axis(low: int, high: int, view: float) -> Vector2i:
	if high - low >= view:
		return Vector2i(low, high)
	var center := (low + high) / 2.0
	return Vector2i(floori(center - view / 2.0), ceili(center + view / 2.0))

## Looks in /Spawns, then anywhere by path from the zone root - so a spawn
## can be a node path ("Houses/House2/ExitSpawn") to a marker a structure
## owns, not only a marker placed by hand under /Spawns.
func _find_spawn(zone: ZoneRoot, spawn_name: String) -> Marker2D:
	var spawns_container := zone.get_node_or_null("Spawns")
	if spawns_container:
		var marker := spawns_container.get_node_or_null(spawn_name) as Marker2D
		if marker: return marker
	return zone.get_node_or_null(spawn_name) as Marker2D

func _apply_zone_bgm(zone: ZoneRoot) -> void:
	match zone.bgm:
		ZoneRoot.BGM.EXTERIOR:
			AudioManager.play_exterior_bgm()
		ZoneRoot.BGM.INTERIOR:
			AudioManager.play_interior_bgm()
		ZoneRoot.BGM.NONE:
			pass

## Only handles what's genuinely WorldManager's own job (sleeping, zone
## transitions, the decorative coop echo) plus emitting zone_loaded - every
## other system wires itself up by listening to that signal instead.
func _wire_zone_content(zone: ZoneRoot) -> void:
	var sleep_spot: SleepSpot = zone.get_node_or_null("SleepSpot")
	if sleep_spot:
		sleep_spot.sleep_requested.connect(_on_sleep_requested)

	var coop_building: Node2D = zone.get_node_or_null("ChickenCoopBuilding")
	if coop_building:
		_spawn_decorative_chickens(coop_building, zone.get_node_or_null("AnimalContainer"))

	for transition in _find_transitions(zone):
		transition.triggered.connect(_on_transition_triggered.bind(transition))

	zone_loaded.emit(zone)

## Purely cosmetic - unlike AnimalManager's chickens, these aren't tied to any
## AnimalState (no hunger/thirst/eggs). They just give a visual sense, from
## outside, that the coop isn't empty. The real, simulated chickens only
## exist inside chicken_coop_interior.tscn.
func _spawn_decorative_chickens(coop_building: Node2D, container: Node2D) -> void:
	if container == null:
		return
	var count: int = min(simulation.get_all_animal_ids().size(), MAX_DECORATIVE_CHICKENS)
	var chicken_scene: PackedScene = load(CHICKEN_SCENE_PATH)
	for i in range(count):
		var chicken: Chicken = chicken_scene.instantiate()
		chicken.start_wild = true
		# container and coop_building are both direct children of the same
		# zone root, so their local spaces match - no need for global_position.
		chicken.position = coop_building.position + Vector2(randf_range(-40.0, 40.0), randf_range(20.0, 50.0))
		container.add_child(chicken)

func _on_transition_triggered(target_zone: String, target_spawn: String, transition: ZoneTransition) -> void:
	if transition.back_to_entrance and not _return_point.is_empty() and has_zone(_return_point["zone"]):
		var back := _return_point
		_return_point = {}
		request_zone_change(back["zone"], back["spawn"])
		return
	if transition.return_point != null:
		_return_point = {
			"zone": current_zone_id,
			"spawn": String(current_zone.get_path_to(transition.return_point)),
		}
	request_zone_change(target_zone, target_spawn)

func get_return_point() -> Dictionary:
	return _return_point.duplicate()

func set_return_point(point: Dictionary) -> void:
	_return_point = {}
	if point.get("zone") is String and point.get("spawn") is String:
		_return_point = {"zone": point["zone"], "spawn": point["spawn"]}

func _find_transitions(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is ZoneTransition:
			result.append(child)
		result.append_array(_find_transitions(child))
	return result

func _on_sleep_requested() -> void:
	simulation.advance_day()
	var wake_spot := current_zone.get_node_or_null("WakeSpot")
	if wake_spot:
		player.global_position = wake_spot.global_position
	slept.emit()
