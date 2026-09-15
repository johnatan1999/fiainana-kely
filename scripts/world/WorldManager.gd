class_name WorldManager
extends Node

## Owns zone loading/unloading. The player, camera and simulation persist across
## zone changes - only the zone scene (background, plots, triggers) is swapped.

const ZONES := {
	"house": preload("res://scenes/areas/interiors/Interior_House.tscn"),
	"exterior": preload("res://scenes/areas/exterior/Exterior.tscn"),
}

var simulation: FarmSimulation
var player: PlayerController
var farming_controller: FarmingController
var shop_ui: ShopUI
var zone_container: Node2D
var animal_manager: AnimalManager
var zone_manager: ZoneManager

var current_zone: ZoneRoot
var current_zone_id: String = ""

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_farming_controller: FarmingController, p_shop_ui: ShopUI, p_zone_container: Node2D, p_animal_manager: AnimalManager, p_zone_manager: ZoneManager) -> void:
	simulation = p_simulation
	player = p_player
	farming_controller = p_farming_controller
	shop_ui = p_shop_ui
	zone_container = p_zone_container
	animal_manager = p_animal_manager
	zone_manager = p_zone_manager

## ZoneTransition/SleepSpot fire from inside Area2D signals during the physics
## step, which forbids reparenting/freeing physics nodes right away - defer it.
func request_zone_change(zone_id: String, spawn_name: String) -> void:
	call_deferred("change_zone", zone_id, spawn_name)

func change_zone(zone_id: String, spawn_name: String) -> void:
	if current_zone != null:
		current_zone.queue_free()
		farming_controller.set_farm_view(null)
		animal_manager.set_farm_area(null)
		zone_manager.set_zone_markers(null)

	var zone: ZoneRoot = ZONES[zone_id].instantiate()
	zone_container.add_child(zone)
	current_zone = zone
	current_zone_id = zone_id

	var spawn := zone.get_node_or_null(spawn_name)
	if spawn:
		player.global_position = spawn.global_position

	player.camera.limit_left = zone.camera_limit_left
	player.camera.limit_top = zone.camera_limit_top
	player.camera.limit_right = zone.camera_limit_right
	player.camera.limit_bottom = zone.camera_limit_bottom
	player.camera.zoom = Vector2(zone.camera_zoom, zone.camera_zoom)

	_apply_zone_bgm(zone)
	_wire_zone_content(zone)

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

	var shop_trigger: ShopTrigger = zone.get_node_or_null("ShopTrigger")
	if shop_trigger:
		shop_trigger.setup(player, shop_ui)

	if zone.get_node_or_null("Coop"):
		animal_manager.set_farm_area(zone)

	# Safe to call unconditionally - a zone without any ZoneMarker_*/
	# ProgressiveZoneMarker nodes just leaves ZoneManager's markers empty.
	zone_manager.set_zone_markers(zone)

	for transition in _find_transitions(zone):
		transition.triggered.connect(request_zone_change)

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
