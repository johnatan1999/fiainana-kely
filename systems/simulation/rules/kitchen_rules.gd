class_name KitchenRules
extends SimRules

## The kitchen: recipes, and cooking them.
## A part of FarmSimulation (SimRules): simulation.kitchen.

var _recipes: Dictionary = {} # recipe_id: String -> Recipe

## Registered by KitchenManager (data/recipes/).
func register_recipe(recipe_id: String, recipe: Recipe) -> void:
	_recipes[recipe_id] = recipe

func get_recipe(recipe_id: String) -> Recipe:
	return _recipes.get(recipe_id)

func get_recipe_ids() -> Array:
	var ids := _recipes.keys()
	ids.sort()
	return ids

func has_kitchen() -> bool:
	return sim.projects.get_building_level("kitchen") >= 1

## How many times the recipe can be cooked with what's in the bag.
func get_cookable_count(recipe_id: String) -> int:
	var recipe := get_recipe(recipe_id)
	if recipe == null or recipe.ingredients.is_empty():
		return 0
	var count := 1 << 30
	for item_id: String in recipe.ingredients:
		count = mini(count, state.get_inventory_count(item_id) / int(recipe.ingredients[item_id]))
	return count

func can_cook(recipe_id: String) -> bool:
	return has_kitchen() and get_cookable_count(recipe_id) > 0

## The ingredients out of the bag, the dish in. Returns whether it cooked.
func cook(recipe_id: String) -> bool:
	if not can_cook(recipe_id):
		return false
	var recipe := get_recipe(recipe_id)
	for item_id: String in recipe.ingredients:
		sim.add_item(item_id, -int(recipe.ingredients[item_id]))
	sim.add_item(recipe.result, recipe.quantity)
	day_log.cooked[recipe_id] = int(day_log.cooked.get(recipe_id, 0)) + recipe.quantity
	sim.notebook.discover(NotebookRules.CUISINE_PREFIX + recipe_id)
	return true
