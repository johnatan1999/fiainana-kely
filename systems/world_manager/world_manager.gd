class_name WorldManager
extends Node

## Owns zone loading/unloading. The player, camera and simulation persist across
## zone changes - only the zone scene (background, plots, triggers) is swapped.
##
## Never hunts down other managers' structures itself - it only emits
## zone_loaded/zone_unloading, and FarmingController/AnimalManager/
## FarmLandManager each listen and wire themselves up to whatever they find in
## the new zone. This is the only thing WorldManager needs to know about every
## other system for; adding a new manager/structure type never touches this
## file.

signal zone_loaded(zone: ZoneRoot)
signal zone_unloading(zone: ZoneRoot)

const ChickenScene := preload("res://entities/animals/chicken/chicken.tscn")
## How many decorative (non-simulated) chickens to show around the coop
## building in the village, capped regardless of how many are actually owned.
const MAX_DECORATIVE_CHICKENS := 4

const ZONE_PATHS := {
	Zone.ID.PLAYER_HOUSE: "res://world/areas/interior/player_interior_house.tscn",
	Zone.ID.VILLAGE: "res://world/areas/exterior/player_village.tscn",
	Zone.ID.CHICKEN_COOP: "res://world/areas/interior/farm/chicken_coop_interior.tscn",
}

var simulation: FarmSimulation
var player: PlayerController
var zone_container: Node2D

var current_zone: ZoneRoot
var current_zone_id: Zone.ID

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_zone_container: Node2D) -> void:
	simulation = p_simulation
	player = p_player
	zone_container = p_zone_container

## ZoneTransition/SleepSpot fire from inside Area2D signals during the physics
## step, which forbids reparenting/freeing physics nodes right away - defer it.
func request_zone_change(zone_id: Zone.ID, spawn_name: String) -> void:
	call_deferred("change_zone", zone_id, spawn_name)

func change_zone(zone_id: Zone.ID, override_spawn_name: String = "") -> void:
	var previous_zone_id = current_zone_id
	if current_zone != null:
		zone_unloading.emit(current_zone)
		current_zone.queue_free()

	# Chargement dynamique de la scène à la demande
	var zone_scene := load(ZONE_PATHS[zone_id]) as PackedScene
	var zone: ZoneRoot = zone_scene.instantiate()
	zone_container.add_child(zone)
	current_zone = zone
	current_zone_id = zone_id

	var spawn: Marker2D = null

	# Cas A : Spawn forcé (ex: chargement de sauvegarde "SpawnDefault")
	if not override_spawn_name.is_empty():
		spawn = _find_spawn(zone, override_spawn_name)

	# Cas B : Convention automatique "SpawnFrom_VILLAGE"
	if spawn == null:
		var expected_spawn = "SpawnFrom_"+Zone.ID.keys()[previous_zone_id]
		spawn = _find_spawn(zone, expected_spawn)

	# Cas C : Fallback de sécurité
	if spawn == null:
		spawn = _find_spawn(zone, "SpawnDefault")

	if spawn:
		player.global_position = spawn.global_position

	player.camera.limit_left = zone.camera_limit_left
	player.camera.limit_top = zone.camera_limit_top
	player.camera.limit_right = zone.camera_limit_right
	player.camera.limit_bottom = zone.camera_limit_bottom
	player.camera.zoom = Vector2(zone.camera_zoom, zone.camera_zoom)

	_apply_zone_bgm(zone)
	_wire_zone_content(zone)

# Fonction utilitaire pour chercher dans /Spawns ou à la racine
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
		transition.triggered.connect(request_zone_change)

	zone_loaded.emit(zone)

## Purely cosmetic - unlike AnimalManager's chickens, these aren't tied to any
## AnimalState (no hunger/thirst/eggs). They just give a visual sense, from
## outside, that the coop isn't empty. The real, simulated chickens only
## exist inside chicken_coop_interior.tscn.
func _spawn_decorative_chickens(coop_building: Node2D, container: Node2D) -> void:
	if container == null:
		return
	var count: int = min(simulation.get_all_animal_ids().size(), MAX_DECORATIVE_CHICKENS)
	for i in range(count):
		var chicken: Chicken = ChickenScene.instantiate()
		chicken.start_wild = true
		# container and coop_building are both direct children of the same
		# zone root, so their local spaces match - no need for global_position.
		chicken.position = coop_building.position + Vector2(randf_range(-40.0, 40.0), randf_range(20.0, 50.0))
		container.add_child(chicken)

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
