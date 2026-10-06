class_name TreeManager
extends Node

## Bridges FarmSimulation's fruit trees to the WorldTree nodes of whichever
## zone is loaded - mirrors AnimalManager. When a zone loads, each of its
## fruit trees is registered in the simulation (it keeps ripening from then
## on, even while the player is elsewhere) and kept in sync with its state.
## Never enforces rules itself: picking goes through FarmSimulation.
##
## A tree's simulation id is "<zone_id>:<WorldTree.tree_id>" - the tree_id
## is stable, given in the editor, so renaming or moving the node keeps its
## saved state. Missing or duplicate ids are reported (and a duplicate isn't
## registered twice).

var simulation: FarmSimulation
var item_db: ItemDatabase

var _world_manager: WorldManager
var _trees: Dictionary = {} # tree_id: String -> WorldTree, current zone only

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, p_world_manager: WorldManager) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_world_manager = p_world_manager
	simulation.tree_changed.connect(_refresh)
	# The "fruit in N days" countdown moves every day, even with no state change.
	simulation.day_changed.connect(func(_day: int): _refresh_all())
	p_world_manager.zone_loaded.connect(_on_zone_loaded)
	p_world_manager.zone_unloading.connect(func(_zone: ZoneRoot): _trees.clear())

func _on_zone_loaded(zone: ZoneRoot) -> void:
	_trees.clear()
	for tree: WorldTree in _find_trees(zone):
		if tree.tree_data == null or not tree.tree_data.bears_fruit():
			continue # decor
		var local_id := tree.tree_id
		if local_id.is_empty():
			local_id = str(zone.get_path_to(tree))
			push_warning("TreeManager: %s has no tree_id - open its zone in the editor and save it. Using its path for now." % local_id)
		var tree_id := "%s:%s" % [_world_manager.current_zone_id, local_id]
		if _trees.has(tree_id):
			push_error("TreeManager: two trees share the id '%s' (%s) - the second one won't bear fruit." % [tree_id, zone.get_path_to(tree)])
			continue
		if not simulation.register_tree(tree_id, tree.tree_data.id):
			push_warning("TreeManager: species '%s' of %s isn't in World.TREE_RESOURCES - it won't bear fruit." % [tree.tree_data.id, tree_id])
			continue
		_trees[tree_id] = tree
		tree.interacted.connect(_on_tree_interacted.bind(tree_id))
		_refresh(tree_id)

func _on_tree_interacted(tree_id: String) -> void:
	var quantity := simulation.harvest_tree(tree_id)
	if quantity > 0:
		# harvest_tree() fires tree_changed -> _refresh(): the fruit disappears.
		AudioManager.play_harvest_sfx()
		UIEvents.notify(tr("+%d %s") % [quantity, _fruit_name(tree_id)])
	else:
		AudioManager.play_action_denied_sfx()
		UIEvents.notify(_waiting_text(tree_id))

func _refresh_all() -> void:
	for tree_id in _trees:
		_refresh(tree_id)

func _refresh(tree_id: String) -> void:
	var tree: WorldTree = _trees.get(tree_id)
	if tree == null or not is_instance_valid(tree):
		return
	var ripe := simulation.can_harvest_tree(tree_id)
	var prompt := tr("Cueillir (%s)") % _fruit_name(tree_id) if ripe else _waiting_text(tree_id)
	tree.show_state(prompt, ripe)

## "Manguier : fruits dans 3 jours" / "...demain" / "...en Asara".
func _waiting_text(tree_id: String) -> String:
	var tree_data := _tree_data(tree_id)
	var tree_name := tr(tree_data.display_name)
	var days := simulation.get_tree_days_until_fruit(tree_id)
	if days < 0:
		return tr("%s : fruits en %s") % [tree_name, tr(_season_name(tree_data.fruit_season))]
	if days == 1:
		return tr("%s : fruits demain") % tree_name
	return tr("%s : fruits dans %d jours") % [tree_name, days]

func _fruit_name(tree_id: String) -> String:
	var fruit_id := _tree_data(tree_id).fruit_item_id
	var item := item_db.get_item(fruit_id)
	return item.get_display_name() if item else fruit_id

func _tree_data(tree_id: String) -> TreeData:
	return simulation.get_tree_data(simulation.get_tree_state(tree_id).tree_type_id)

static func _season_name(season: CropData.Season) -> String:
	match season:
		CropData.Season.ASARA:
			return "Asara"
		CropData.Season.ASOTRY:
			return "Asotry"
	return "toute saison"

func _find_trees(node: Node) -> Array[WorldTree]:
	var found: Array[WorldTree] = []
	for child in node.get_children():
		if child is WorldTree:
			found.append(child)
		found.append_array(_find_trees(child))
	return found
