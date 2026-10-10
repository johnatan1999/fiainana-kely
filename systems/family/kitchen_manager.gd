class_name KitchenManager
extends Node

## The farm's kitchen (FamilyProject "kitchen"), between FarmSimulation (the
## recipes, cooking) and the world: registers data/recipes/, and once the
## kitchen is built, interacting with it opens the CookingPanel - the dishes
## go in the bag, to sell (they're worth more than what went in, more still
## at the weekly market). Also answers the rice granary: a word on what it
## does. See docs/family_projects.md.

const KITCHEN_NODE := "Kitchen"
const GRANARY_NODE := "Granary"

var simulation: FarmSimulation
var item_db: ItemDatabase

var _panel: CookingPanel

func setup(p_simulation: FarmSimulation, p_item_db: ItemDatabase, world_manager: WorldManager,
		panel: CookingPanel) -> void:
	simulation = p_simulation
	item_db = p_item_db
	_panel = panel
	var recipes := Recipe.load_all()
	for recipe_id: String in recipes:
		simulation.kitchen.register_recipe(recipe_id, recipes[recipe_id])
	_panel.cook_requested.connect(_on_cook_requested)
	simulation.inventory_changed.connect(func(_item: String, _count: int):
		if _panel.is_open():
			_show_panel())
	world_manager.zone_loaded.connect(_on_zone_loaded)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	var kitchen := zone.get_node_or_null(KITCHEN_NODE) as HouseAnnex
	if kitchen != null and not kitchen.interacted.is_connected(_show_panel):
		kitchen.interacted.connect(_show_panel)
		kitchen.set_prompt(tr("Cuisiner"))
	var granary := zone.get_node_or_null(GRANARY_NODE) as HouseAnnex
	if granary != null and not granary.interacted.is_connected(_on_granary):
		granary.interacted.connect(_on_granary)
		granary.set_prompt(tr("Regarder le grenier"))

func _on_granary() -> void:
	UIEvents.notify(tr("Le grenier garde le riz loin des rats : %d %% de riz en plus à chaque récolte de riz.")
		% roundi((ProjectRules.GRANARY_RICE_MULTIPLIER - 1.0) * 100.0))

func _show_panel() -> void:
	if not simulation.kitchen.has_kitchen():
		return
	var recipes := []
	var any := false
	for recipe_id: String in simulation.kitchen.get_recipe_ids():
		var recipe := simulation.kitchen.get_recipe(recipe_id)
		var parts := []
		var missing := false
		for item_id: String in recipe.ingredients:
			var need := int(recipe.ingredients[item_id])
			var have := simulation.state.get_inventory_count(item_id)
			missing = missing or have < need
			parts.append(tr("%d %s (tu en as %d)") % [need,
				EveningManager.plural(item_db.get_display_name(item_id).to_lower(), need), have])
		var count := simulation.kitchen.get_cookable_count(recipe_id)
		any = any or count > 0
		recipes.append({
			"id": recipe_id, "name": tr(recipe.display_name), "malagasy": recipe.malagasy_name,
			"icon": item_db.get_icon(recipe.result), "ingredients": ", ".join(parts), "missing": missing,
			"price": _sell_price(recipe.result), "count": count,
		})
	var note := tr("Les plats se vendent à l'épicerie, et mieux encore au tsena du zoma.")
	if not any:
		note = tr("Il te manque des ingrédients : récolte d'abord, puis reviens cuisiner.")
	_panel.show_recipes(recipes, note)

func _sell_price(item_id: String) -> int:
	var item := item_db.get_item(item_id)
	return item.sell_price if item != null else 0

func _on_cook_requested(recipe_id: String, times: int) -> void:
	var cooked := 0
	for i in times:
		if simulation.kitchen.cook(recipe_id):
			cooked += 1
	if cooked > 0:
		AudioManager.play_harvest_sfx()
		var recipe := simulation.kitchen.get_recipe(recipe_id)
		UIEvents.notify(tr("+%d %s") % [cooked * recipe.quantity, item_db.get_display_name(recipe.result)])
	_show_panel()
