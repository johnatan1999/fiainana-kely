class_name TreeRules
extends SimRules

## Fruit trees: placed in the zone scenes (WorldTree), registered here by
## TreeManager the first time their zone loads. From then on they ripen every
## day, whichever zone the player is in.
## A part of FarmSimulation (SimRules): simulation.trees.

var _tree_registry: Dictionary = {} # tree_type_id: String -> TreeData

func get_tree_data(tree_type_id: String) -> TreeData:
	return _tree_registry.get(tree_type_id)

func get_tree_state(tree_id: String) -> TreeState:
	return state.trees.get(tree_id)

## Starts tracking a tree. A tree discovered in season starts ripe - the
## player's first visit should show what it's for. Registering a known tree
## again is a no-op, unless its species was changed in the editor since.
## Returns false for unknown or decorative (fruitless) species.
func register_tree(tree_id: String, tree_type_id: String) -> bool:
	var tree_data := get_tree_data(tree_type_id)
	if tree_data == null or not tree_data.bears_fruit():
		return false
	var tree := get_tree_state(tree_id)
	if tree != null and tree.tree_type_id == tree_type_id:
		return true
	tree = TreeState.new(tree_type_id)
	tree.fruit_ready = tree_data.is_in_season(state.clock.get_season())
	state.trees[tree_id] = tree
	sim.tree_changed.emit(tree_id)
	return true

func can_harvest_tree(tree_id: String) -> bool:
	var tree := get_tree_state(tree_id)
	return tree != null and tree.fruit_ready and get_tree_data(tree.tree_type_id) != null

## Picks every fruit. Returns how many were added to the inventory (0 if
## nothing was ripe).
func harvest_tree(tree_id: String) -> int:
	if not can_harvest_tree(tree_id):
		return 0
	var tree := get_tree_state(tree_id)
	var tree_data := get_tree_data(tree.tree_type_id)
	var quantity := randi_range(tree_data.yield_min, tree_data.yield_max)
	tree.fruit_ready = false
	tree.days_growing = 0
	sim.add_item(tree_data.fruit_item_id, quantity)
	day_log.add_harvest(tree_data.fruit_item_id, quantity)
	sim.tree_changed.emit(tree_id)
	return quantity

## Days of growth left before the fruit is ripe, counting only today's
## season: 0 if ripe now, -1 if out of season (no fruit until it returns).
func get_tree_days_until_fruit(tree_id: String) -> int:
	var tree := get_tree_state(tree_id)
	if tree == null or tree.fruit_ready:
		return 0
	var tree_data := get_tree_data(tree.tree_type_id)
	if tree_data == null or not tree_data.is_in_season(state.clock.get_season()):
		return -1
	return maxi(1, tree_data.fruit_cycle_days - tree.days_growing)

## The night (FarmSimulation.advance_day), before the clock advances, so "in
## season" means the day that just ended. Fruit only grows in season, and
## whatever is left on the tree when the season ends rots - picking is a
## seasonal rush, not a stockpile.
func advance_trees() -> void:
	var season := state.clock.get_season()
	var next_season := state.clock.get_season_on(state.day + 1)
	for tree_id in state.trees:
		var tree: TreeState = state.trees[tree_id]
		var tree_data := get_tree_data(tree.tree_type_id)
		if tree_data == null:
			continue # species removed from the registry - kept as-is in the save
		var before := [tree.fruit_ready, tree.days_growing]
		if tree_data.is_in_season(season) and not tree.fruit_ready:
			tree.days_growing += 1
			if tree.days_growing >= tree_data.fruit_cycle_days:
				tree.fruit_ready = true
		if not tree_data.is_in_season(next_season):
			tree.fruit_ready = false
			tree.days_growing = 0
		if before != [tree.fruit_ready, tree.days_growing]:
			sim.tree_changed.emit(tree_id)
