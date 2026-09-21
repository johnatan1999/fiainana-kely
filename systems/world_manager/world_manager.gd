class_name WorldManager
extends Node

## Owns zone loading/unloading. The player, camera and simulation persist across
## zone changes - only the zone scene (background, plots, triggers) is swapped.

const ZONE_PATHS := {
	Zone.ID.PLAYER_HOUSE: "res://world/areas/interior/player_interior_house.tscn",
	Zone.ID.VILLAGE: "res://world/areas/exterior/player_village.tscn",
	Zone.ID.CHICKEN_COOP: "res://world/areas/interior/farm/chicken_coop_interior.tscn",
}

var simulation: FarmSimulation
var player: PlayerController
var farming_controller: FarmingController
var shop_ui: ShopUI
var zone_container: Node2D
var animal_manager: AnimalManager
var farm_land_manager: FarmLandManager

var current_zone: ZoneRoot
var current_zone_id: Zone.ID

func _ready() -> void:
	StructureEvents.shop_spawned.connect(_on_shop_spawned)

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_farming_controller: FarmingController, p_shop_ui: ShopUI, p_zone_container: Node2D, p_animal_manager: AnimalManager, p_farm_land_manager: FarmLandManager) -> void:
	simulation = p_simulation
	player = p_player
	farming_controller = p_farming_controller
	shop_ui = p_shop_ui
	zone_container = p_zone_container
	animal_manager = p_animal_manager
	farm_land_manager = p_farm_land_manager

## ZoneTransition/SleepSpot fire from inside Area2D signals during the physics
## step, which forbids reparenting/freeing physics nodes right away - defer it.
func request_zone_change(zone_id: Zone.ID, spawn_name: String) -> void:
	call_deferred("change_zone", zone_id, spawn_name)

func change_zone(zone_id: Zone.ID, override_spawn_name: String = "") -> void:
	var previous_zone_id = current_zone_id
	if current_zone != null:
		current_zone.queue_free()
		farming_controller.set_farm_view(null)
		animal_manager.set_farm_area(null)
		farm_land_manager.set_zone_markers(null)

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

func _wire_zone_content(zone: ZoneRoot) -> void:
	var farm_view: FarmView = zone.get_node_or_null("FarmView")
	if farm_view:
		farm_view.setup(simulation)
		farming_controller.set_farm_view(farm_view)

	var sleep_spot: SleepSpot = zone.get_node_or_null("SleepSpot")
	if sleep_spot:
		sleep_spot.setup(player)
		sleep_spot.sleep_requested.connect(_on_sleep_requested)

	if zone.get_node_or_null("ChickenCoop"):
		animal_manager.set_farm_area(zone)

	# Safe to call unconditionally - a zone without any ZoneMarker_*/
	# ProgressiveZoneMarker nodes just leaves FarmLandManager's markers empty.
	farm_land_manager.set_zone_markers(zone)

	for transition in _find_transitions(zone):
		transition.triggered.connect(request_zone_change)

func _on_shop_spawned(shop: Shop) -> void:
	shop.setup(player, shop_ui)

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
