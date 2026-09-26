class_name InventoryCatalog
extends RefCounted

## Turns a raw FarmState.inventory item_id into everything the inventory
## screen shows about it: names, icon, which tab it belongs to, description
## and a list of detail rows. Reuses the registries that already exist
## (CropData via FarmSimulation, ShopUI's hand-authored catalog) so nothing
## here duplicates economy numbers or drifts out of sync with the Shop.

enum Category { CROPS, ANIMALS, TOOLS, FOOD }

const CATEGORY_NAMES := {
	Category.CROPS: "Cultures",
	Category.ANIMALS: "Animaux",
	Category.TOOLS: "Outils",
	Category.FOOD: "Nourriture",
}

const SEASON_NAMES := {
	CropData.Season.ASARA: "Asara",
	CropData.Season.ASOTRY: "Asotry",
	CropData.Season.TOUTE_SAISON: "Toute saison",
}

const WATER_NEED_NAMES := {
	CropData.WaterNeed.LOW: "Faible",
	CropData.WaterNeed.MEDIUM: "Moyen",
	CropData.WaterNeed.HIGH: "Élevé",
}

const CROP_TYPE_NAMES := {
	CropData.Category.VIVRIER: "Culture vivrière",
	CropData.Category.RENTE: "Culture de rente",
	CropData.Category.EXPORT: "Culture d'export",
}

static var _warned_unknown_ids := {}

## Shop categories -> inventory tabs. Seeds and harvests share "Cultures";
## animal products (eggs) live with the animals that make them.
const SHOP_TO_INVENTORY := {
	ShopItemData.Category.SEEDS: Category.CROPS,
	ShopItemData.Category.ANIMALS: Category.ANIMALS,
	ShopItemData.Category.TOOLS: Category.TOOLS,
	ShopItemData.Category.FOOD: Category.FOOD,
}

## Returns {id, name, malagasy_name, icon, color, category, description,
## details: Array of [label, value]} - color is the placeholder square shown
## when the item has no icon art yet.
static func describe(simulation: FarmSimulation, item_id: String) -> Dictionary:
	if item_id == "chicken_unplaced":
		var chicken := _find_shop_item("animal_chicken")
		return _entry(item_id, "Poule (à placer)", "Akoho", null, Category.ANIMALS,
			"%s\nÀ installer dans le poulailler : appuie sur E devant le poulailler." % (chicken.description if chicken else ""),
			[])

	if item_id.ends_with("_seed"):
		var seed_crop := simulation.get_crop_data(item_id.trim_suffix("_seed"))
		if seed_crop != null:
			return _entry(item_id, "Graine de %s" % seed_crop.display_name, seed_crop.malagasy_name,
				seed_crop.icon, Category.CROPS,
				"À semer sur une parcelle labourée, puis à arroser chaque jour.",
				[
					["Pousse en", "%d jours" % seed_crop.growth_days],
					["Saison idéale", SEASON_NAMES.get(seed_crop.ideal_season, "?")],
					["Besoin en eau", WATER_NEED_NAMES.get(seed_crop.water_need, "?")],
					["Rendement", _yield_text(seed_crop)],
					["Prix d'achat", Currency.format(seed_crop.seed_price)],
				])

	var crop := simulation.get_crop_data(item_id)
	if crop != null:
		return _entry(item_id, crop.display_name, crop.malagasy_name, crop.icon, Category.CROPS,
			"Fraîchement récolté. À vendre au marché ou à garder pour plus tard.",
			[
				["Type", CROP_TYPE_NAMES.get(crop.category, "?")],
				["Prix de vente", Currency.format(crop.sell_price)],
			])

	var shop_item := _find_shop_item(item_id)
	if shop_item != null:
		var details: Array = []
		if shop_item.price > 0:
			details.append(["Prix d'achat", Currency.format(shop_item.price)])
		if shop_item.sell_price > 0:
			details.append(["Prix de vente", Currency.format(shop_item.sell_price)])
		return _entry(item_id, shop_item.display_name, shop_item.malagasy_name, shop_item.icon,
			SHOP_TO_INVENTORY.get(shop_item.category, Category.TOOLS), shop_item.description, details)

	# Once per id: describe() runs on every inventory refresh, and a stale id
	# would otherwise flood the log. Old saves get cleaned up by
	# SaveController's migrations; this only catches ids nothing knows yet.
	if not _warned_unknown_ids.has(item_id):
		_warned_unknown_ids[item_id] = true
		push_warning("InventoryCatalog: unknown item id '%s' - shown under Outils." % item_id)
	return _entry(item_id, item_id, "", null, Category.TOOLS, "", [])

static func _yield_text(crop: CropData) -> String:
	if crop.yield_min == crop.yield_max:
		return str(crop.yield_min)
	return "%d à %d" % [crop.yield_min, crop.yield_max]

static func _entry(id: String, display_name: String, malagasy_name: String, icon: Texture2D,
		category: Category, description: String, details: Array) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"malagasy_name": malagasy_name,
		"icon": icon,
		"color": placeholder_color(category),
		"category": category,
		"description": description,
		"details": details,
	}

## Same palette the Shop uses for icon-less items, so an item looks the same
## on both screens.
static func placeholder_color(category: Category) -> Color:
	for shop_category in SHOP_TO_INVENTORY:
		if SHOP_TO_INVENTORY[shop_category] == category:
			return ItemCard.CATEGORY_PLACEHOLDER_COLORS.get(shop_category, Color.GRAY)
	return Color.GRAY

static func _find_shop_item(item_id: String) -> ShopItemData:
	for shop_item: ShopItemData in ShopUI.TOOLS_FOOD_ANIMALS_RESOURCES:
		if shop_item.id == item_id:
			return shop_item
	return null
