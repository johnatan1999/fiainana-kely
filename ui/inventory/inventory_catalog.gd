class_name InventoryCatalog
extends RefCounted

## Presentation layer for the inventory screen: turns an inventory item_id
## into what the book shows - names, icon, which tab it goes in, description
## and detail rows. All facts come from ItemDatabase (the data layer); this
## only decides how the inventory lays them out. Every text it returns is
## already translated to the current language (the French texts in the
## tables below are the keys of localization/translations.csv).

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

## Shop categories -> inventory tabs. Seeds and harvests share "Cultures";
## animal products (eggs) live with the animals that make them.
const SHOP_TO_INVENTORY := {
	ShopItemData.Category.SEEDS: Category.CROPS,
	ShopItemData.Category.ANIMALS: Category.ANIMALS,
	ShopItemData.Category.TOOLS: Category.TOOLS,
	ShopItemData.Category.FOOD: Category.FOOD,
}

static var _warned_unknown_ids := {}

## Static functions have no Object.tr() - same lookup, through the server.
static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))

static func category_name(category: Category) -> String:
	return _t(CATEGORY_NAMES[category])

## Returns {id, name, icon, color, category, description,
## details: Array of [label, value]} - color is the placeholder square shown
## when the item has no icon art yet.
static func describe(db: ItemDatabase, item_id: String) -> Dictionary:
	match db.get_kind(item_id):
		ItemDatabase.Kind.SEED:
			var seed_crop := db.get_crop(item_id)
			return _entry(item_id, db.get_shop_item(item_id), Category.CROPS,
				_t("À semer sur une parcelle labourée, puis à arroser chaque jour."),
				[
					[_t("Pousse en"), _t("%d jours") % seed_crop.growth_days],
					[_t("Saison idéale"), _t(SEASON_NAMES.get(seed_crop.ideal_season, "?"))],
					[_t("Besoin en eau"), _t(WATER_NEED_NAMES.get(seed_crop.water_need, "?"))],
					[_t("Rendement"), _yield_text(seed_crop)],
					[_t("Prix d'achat"), Currency.format(seed_crop.seed_price)],
				])
		ItemDatabase.Kind.CROP:
			var crop := db.get_crop(item_id)
			return _make(item_id, _t(crop.display_name), crop.icon,
				Category.CROPS, ShopItemData.Category.SEEDS,
				_t("Fraîchement récolté. À vendre au marché ou à garder pour plus tard."),
				[
					[_t("Type"), _t(CROP_TYPE_NAMES.get(crop.category, "?"))],
					[_t("Prix de vente"), Currency.format(crop.sell_price)],
				])
		ItemDatabase.Kind.SHOP_ITEM:
			var item := db.get_shop_item(item_id)
			var details: Array = []
			if item.price > 0:
				details.append([_t("Prix d'achat"), Currency.format(item.price)])
			if item.sell_price > 0:
				details.append([_t("Prix de vente"), Currency.format(item.sell_price)])
			return _entry(item_id, item, SHOP_TO_INVENTORY.get(item.category, Category.TOOLS),
				item.get_description(), details)
		ItemDatabase.Kind.UNPLACED_ANIMAL:
			var animal := db.get_unplaced_species(item_id)
			var shop_item := db.get_shop_item_for_species(animal.species)
			var description := _t("À installer dans le poulailler : appuie sur E devant le poulailler.")
			if shop_item != null and shop_item.description != "":
				description = shop_item.get_description() + "\n" + description
			var icon: Texture2D = animal.icon
			if icon == null and shop_item != null:
				icon = shop_item.icon
			return _make(item_id, _t("%s (à placer)") % _t(animal.display_name), icon,
				Category.ANIMALS, ShopItemData.Category.ANIMALS, description, [])

	# Once per id: describe() runs on every inventory refresh, and a stale id
	# would otherwise flood the log. Old saves get cleaned up by
	# SaveController's migrations; this only catches ids nothing knows yet.
	if not _warned_unknown_ids.has(item_id):
		_warned_unknown_ids[item_id] = true
		push_warning("InventoryCatalog: unknown item id '%s' - shown under Outils." % item_id)
	return _make(item_id, item_id, null, Category.TOOLS, ShopItemData.Category.TOOLS, "", [])

static func _yield_text(crop: CropData) -> String:
	if crop.yield_min == crop.yield_max:
		return str(crop.yield_min)
	return _t("%d à %d") % [crop.yield_min, crop.yield_max]

## Names/icon/placeholder color straight from a catalog entry.
static func _entry(id: String, item: ShopItemData, category: Category, description: String, details: Array) -> Dictionary:
	return _make(id, item.get_display_name(), item.icon, category, item.category, description, details)

static func _make(id: String, display_name: String, icon: Texture2D,
		category: Category, color_category: ShopItemData.Category, description: String, details: Array) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"icon": icon,
		"color": ShopItemData.CATEGORY_COLORS.get(color_category, Color.GRAY),
		"category": category,
		"description": description,
		"details": details,
	}
