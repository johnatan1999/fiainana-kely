class_name NeighbourPaddyManager
extends Node

## Bridges FarmSimulation's neighbours' paddies to the VillagePaddy nodes of
## whichever zone is loaded - mirrors TreeManager. Keeps their look in sync
## with the calendar (the rice's stage; the tufts cut, which move through
## the harvest days' working hours), lets the player cut a tuft
## (FarmSimulation.help_neighbour_harvest) and announces the harvest on the
## morning it starts. Never enforces rules itself.
##
## A paddy's simulation id is "<zone_id>:<node name>". During the harvest,
## the villagers working in it call out to the player (Villager.call_out).

const THANKS_COOLDOWN := 20.0
const HARVEST_CALL := "C'est la moisson ! Tu nous aides ?"

var simulation: FarmSimulation
var item_db: ItemDatabase

var _world_manager: WorldManager
var _player: Node2D
var _paddies: Dictionary = {} # paddy_id: String -> VillagePaddy, current zone only
## Not on loading a save that lands on the first harvest day.
var _announce := false
var _last_thanks := -INF

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, p_world_manager: WorldManager, player: Node2D) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_world_manager = p_world_manager
	_player = player
	simulation.time_changed.connect(func(_minute: int): _refresh_all())
	simulation.day_changed.connect(_on_day_changed)
	simulation.neighbour_paddy_changed.connect(_refresh)
	simulation.state_loaded.connect(func():
		_announce = false
		set.call_deferred("_announce", true))
	set.call_deferred("_announce", true)
	p_world_manager.zone_loaded.connect(_on_zone_loaded)
	p_world_manager.zone_unloading.connect(func(_zone: ZoneRoot): _paddies.clear())

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_paddies.clear()
	for paddy: VillagePaddy in _find_paddies(zone):
		var paddy_id := "%s:%s" % [_world_manager.current_zone_id, paddy.name]
		simulation.register_neighbour_paddy(paddy_id, paddy.size)
		_paddies[paddy_id] = paddy
		paddy.interacted.connect(_on_paddy_interacted.bind(paddy_id))
		_refresh(paddy_id)

func _on_day_changed(_day: int) -> void:
	_refresh_all()
	if _announce and simulation.state.clock.get_day_of_season() == FarmSimulation.NEIGHBOUR_HARVEST_FROM_DAY:
		UIEvents.notify(tr("C'est la moisson chez les voisins : va leur donner un coup de main aux rizières !"))

func _on_paddy_interacted(paddy_id: String) -> void:
	var paddy: VillagePaddy = _paddies.get(paddy_id)
	if paddy == null:
		return
	var cell := paddy.tuft_near(_player.global_position)
	var gained := simulation.help_neighbour_harvest(paddy_id, cell)
	if gained <= 0:
		AudioManager.play_action_denied_sfx()
		return
	# help_neighbour_harvest() fires neighbour_paddy_changed -> _refresh().
	AudioManager.play_harvest_sfx()
	var reward := item_db.get_item(FarmSimulation.NEIGHBOUR_HARVEST_REWARD)
	HarvestPopup.spawn(paddy, paddy.get_tuft_position(cell) + Vector2(0, -36),
		reward.icon if reward else null,
		tr("+%d %s") % [gained, reward.get_display_name() if reward else ""])
	_thank(paddy)

## A farmer at work in the paddy thanks the player - now and then, not for
## every tuft.
func _thank(paddy: VillagePaddy) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_thanks < THANKS_COOLDOWN:
		return
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if villager.is_working() and paddy.get_rect().grow(8.0).has_point(villager.global_position):
			villager.say(tr("Misaotra ! Merci du coup de main !"))
			_last_thanks = now
			return

func _refresh_all() -> void:
	for paddy_id in _paddies:
		_refresh(paddy_id)

func _refresh(paddy_id: String) -> void:
	var paddy: VillagePaddy = _paddies.get(paddy_id)
	if paddy == null or not is_instance_valid(paddy):
		return
	var cut := {}
	for x in paddy.size.x:
		for y in paddy.size.y:
			if simulation.is_neighbour_tuft_cut(paddy_id, Vector2i(x, y)):
				cut[Vector2i(x, y)] = true
	paddy.show_state(simulation.get_neighbour_rice_stage(), cut)
	var harvesting := simulation.is_neighbour_harvest_on() and paddy.tuft_near(paddy.global_position) != Vector2i(-1, -1)
	paddy.set_prompt(tr("Aider à moissonner") if harvesting else "")
	# The farmers working in it call out to the player during the harvest.
	for villager: Villager in get_tree().get_nodes_in_group(Villager.GROUP):
		if harvesting and paddy.get_rect().grow(8.0).has_point(villager.get_spot_position()):
			villager.call_out = tr(HARVEST_CALL)
		elif villager.call_out == tr(HARVEST_CALL):
			villager.call_out = ""

func _find_paddies(node: Node) -> Array[VillagePaddy]:
	var found: Array[VillagePaddy] = []
	for child in node.get_children():
		if child is VillagePaddy:
			found.append(child)
		found.append_array(_find_paddies(child))
	return found
