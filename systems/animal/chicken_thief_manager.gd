class_name ChickenThiefManager
extends Node

## Chicken thieves (mpangalatra akoho), between FarmSimulation (the rumour,
## the nights, the padlock - the rules) and the world. Decides nothing:
## - in the morning: the rumour ("des poules ont disparu chez Naivo"), a
##   hen taken overnight, or the padlock that held;
## - the padlock on the farm's coop door (CoopPadlock), once bought;
## - feathers in front of the coop the morning after a theft
##   (ScatteredFeathers), for the day.
## What the family says of it at dinner: EveningManager. See
## docs/chicken_thieves.md.

## Where they go on the coop, from its door (Coop.get_door_position()).
const PADLOCK_OFFSET := Vector2(14, -40)
const FEATHERS_OFFSET := Vector2(-10, 26)

var simulation: FarmSimulation

var _names: Dictionary = {} # villager_id -> display name

func setup(p_simulation: FarmSimulation, world_manager: WorldManager) -> void:
	simulation = p_simulation
	var villagers := VillagerData.load_all()
	for villager_id: String in villagers:
		_names[villager_id] = villagers[villager_id].display_name
	# The night's news, once the morning's UI is there.
	simulation.thief_alert_started.connect(func(_villager: String): _say_rumour.call_deferred())
	simulation.chicken_stolen.connect(func(_animal: String): _say_theft.call_deferred())
	simulation.thieves_foiled.connect(func(): _say_foiled.call_deferred())
	simulation.coop_secured.connect(_on_coop_secured)
	simulation.day_changed.connect(func(_day: int): _refresh())
	world_manager.zone_loaded.connect(func(_zone: ZoneRoot): _refresh())

func _say_rumour() -> void:
	var neighbour: String = _names.get(simulation.state.thief_rumour, tr("des voisins"))
	var text := tr("Mpangalatra akoho ! Des poules ont disparu chez %s cette nuit.") % neighbour
	if simulation.is_coop_safe():
		text += " " + tr("Ton poulailler, lui, ferme bien.")
	else:
		text += " " + tr("Un cadenas sur le poulailler, au marché, ne serait pas de trop.")
	UIEvents.notify(text)

func _say_theft() -> void:
	UIEvents.notify(tr("Cette nuit, un voleur est entré dans le poulailler : il manque une poule."))

func _say_foiled() -> void:
	UIEvents.notify(tr("Cette nuit, des voleurs ont essayé d'ouvrir le poulailler : le cadenas a tenu !"))

func _on_coop_secured() -> void:
	UIEvents.notify(tr("Tu poses le cadenas sur la porte du poulailler. Les voleurs n'ont qu'à bien se tenir."))
	_refresh()

## The padlock and the feathers on the coop of the zone, if there's one.
func _refresh() -> void:
	if not is_inside_tree():
		return
	for coop: Coop in get_tree().get_nodes_in_group(Coop.GROUP):
		var door := coop.to_local(coop.get_door_position())
		var padlock := coop.get_node_or_null("Padlock")
		var locked := simulation.state.coop_padlock and simulation.get_building_level("coop") < 3
		if locked and padlock == null:
			padlock = CoopPadlock.new()
			padlock.name = "Padlock"
			padlock.position = door + PADLOCK_OFFSET
			padlock.z_index = 1
			coop.add_child(padlock)
		elif not locked and padlock != null:
			padlock.queue_free()
		var feathers := coop.get_node_or_null("Feathers")
		var stolen := simulation.state.thief_stolen_day > 0 and simulation.state.thief_stolen_day == simulation.state.day
		if stolen and feathers == null:
			feathers = ScatteredFeathers.new()
			feathers.name = "Feathers"
			feathers.position = door + FEATHERS_OFFSET
			feathers.z_index = -1
			coop.add_child(feathers)
		elif not stolen and feathers != null:
			feathers.queue_free()
