class_name InventoryCatalog
extends RefCounted

## Presentation layer for the inventory screen: turns an inventory item_id
## into what the book shows - names, icon, which tab it goes in, description
## and detail rows. All facts come from ItemDatabase (the data layer); this
## only decides how the inventory lays them out. Every text it returns is
## already translated to the current language (the French texts in the
## tables below are the keys of localization/translations.csv).

enum Category { CROPS, ANIMALS, TOOLS, FOOD, VILLAGERS }

const CATEGORY_NAMES := {
	Category.CROPS: "Cultures",
	Category.ANIMALS: "Élevage",
	Category.TOOLS: "Outils",
	Category.FOOD: "Nourriture",
	Category.VILLAGERS: "Villageois",
}

## Where a villager is, by the spot of their current step (VillagerRoads
## markers) - "En ce moment : au marché". A spot missing here reads as
## "quelque part au village".
const SPOT_PLACES := {
	"Marche": "au marché",
	"Place": "sur la place",
	"Banc_Est": "sur le banc, près de la maison de l'est",
	"Cabane": "à la cabane des rizières",
	"Riziere_Voisins_1": "dans la rizière des voisins",
	"Riziere_Voisins_2": "dans la rizière des voisins",
}
const HOME_PLACES := {
	"Maison_Ouest": "la maison de l'ouest",
	"Maison_Est": "la maison de l'est",
	"Maison_Sud": "la maison du sud",
}
const PLACEHOLDER_VILLAGER := Color(0.62, 0.45, 0.32)

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
	ItemData.Category.SEEDS: Category.CROPS,
	ItemData.Category.ANIMALS: Category.ANIMALS,
	ItemData.Category.TOOLS: Category.TOOLS,
	ItemData.Category.FOOD: Category.FOOD,
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
			return _entry(item_id, db.get_item(item_id), Category.CROPS,
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
				Category.CROPS, ItemData.Category.SEEDS,
				_t("Fraîchement récolté. À vendre au marché ou à garder pour plus tard."),
				[
					[_t("Type"), _t(CROP_TYPE_NAMES.get(crop.category, "?"))],
					[_t("Prix de vente"), Currency.format(crop.sell_price)],
				])
		ItemDatabase.Kind.AUTHORED:
			var item := db.get_item(item_id)
			var details: Array = []
			if item.price > 0:
				details.append([_t("Prix d'achat"), Currency.format(item.price)])
			if item.sell_price > 0:
				details.append([_t("Prix de vente"), Currency.format(item.sell_price)])
			return _entry(item_id, item, SHOP_TO_INVENTORY.get(item.category, Category.TOOLS),
				item.get_description(), details)

	# Once per id: describe() runs on every inventory refresh, and a stale id
	# would otherwise flood the log. Old saves get cleaned up by
	# SaveController's migrations; this only catches ids nothing knows yet.
	if not _warned_unknown_ids.has(item_id):
		_warned_unknown_ids[item_id] = true
		push_warning("InventoryCatalog: unknown item id '%s' - shown under Outils." % item_id)
	return _make(item_id, item_id, null, Category.TOOLS, ItemData.Category.TOOLS, "", [])

## The Élevage tab lists living animals too - not inventory items, so they
## get their own ids ("animal:<id>", "pending:<species>"), never valid item
## ids (no hotbar, no selling). `meta` replaces the card's quantity line,
## `sort_group` keeps waiting animals, then settled ones, before products.

## Animals bought and waiting for the player to settle them in a pen.
static func describe_pending(db: ItemDatabase, species: AnimalData.Species, count: int) -> Dictionary:
	var animal := db.get_animal(species)
	var entry := _make("pending:%d" % species, _t("%s - à installer") % _t(animal.display_name),
		_animal_icon(db, species), Category.ANIMALS, ItemData.Category.ANIMALS,
		_t("Le marchand te la garde : va au poulailler et appuie sur %s pour l'installer.") % InputBindings.get_button_label("interact"),
		[])
	entry["meta"] = _t("En attente : %d") % count
	entry["sort_group"] = 0
	return entry

## A settled animal: how it's doing today.
static func describe_animal(db: ItemDatabase, animal: AnimalState) -> Dictionary:
	var data := db.get_animal(animal.species)
	var number := int(animal.id.get_slice("_", animal.id.get_slice_count("_") - 1)) + 1
	var details: Array = [
		[_t("Nourriture"), _t("Donnée") if animal.fed_today else _t("À donner")],
		[_t("Eau"), _t("Donnée") if animal.watered_today else _t("À donner")],
		[_t("Âge"), _days(animal.age_days, "%d jour", "%d jours")],
		[_t("Soins réguliers"), _days(animal.days_well_cared, "%d jour d'affilée", "%d jours d'affilée")],
	]
	if data.product_id != "":
		details.append([_t("Ponte"), _t("tous les %d jours") % data.product_cycle_days])
	var entry := _make("animal:" + animal.id, _t("%s n°%d") % [_t(data.display_name), number],
		_animal_icon(db, animal.species), Category.ANIMALS, ItemData.Category.ANIMALS,
		_care_text(animal), details)
	entry["meta"] = _t("Au poulailler")
	entry["sort_group"] = 1
	return entry

## French: singular for 0 and 1 ("0 jour", "1 jour", "2 jours").
## A villager, for the Villageois tab: their portrait, who they are, and
## the player's friendship, next gift, order and where to find them now.
## `id` is their VillagerData file's name; the entry's id is
## "villager:<id>".
static func describe_villager(db: ItemDatabase, simulation: FarmSimulation, villager_id: String,
		data: VillagerData) -> Dictionary:
	var hearts := simulation.get_hearts(villager_id)
	var max_hearts := FarmSimulation.FRIENDSHIP_MAX_HEARTS
	# Short values (the card's right column is narrow); the longer texts go
	# in the description, which wraps.
	var details: Array = [[_t("Amitié"), _t("%d/%d cœurs") % [hearts, max_hearts]]]
	if hearts < max_hearts:
		details.append([_t("Prochain cœur"), "%d %%" % roundi(simulation.get_heart_progress(villager_id) * 100.0)])
	if hearts > 0:
		details.append([_t("Prix d'ami"), "+%d %%" % roundi(FarmSimulation.ORDER_BONUS_PER_HEART * 100.0 * hearts)])
	var order := simulation.get_order(villager_id)
	if order.is_empty():
		details.append([_t("Commande"), _t("Aucune")])
	else:
		details.append([_t("Commande"), "%d %s" % [order["quantity"], db.get_display_name(order["item"]).to_lower()]])
		if simulation.is_order_offered(villager_id):
			details.append([_t("Délai"), _t("à voir")])
		else:
			details.append([_t("Délai"), _days(simulation.get_order_days_left(villager_id), "%d jour", "%d jours")])
	details.append([_t("En ce moment"), _place_text(simulation, data)])
	var description := _t(data.role)
	var home: String = HOME_PLACES.get(data.home, "")
	if not home.is_empty():
		description += (". " if not description.is_empty() else "") + _t("Habite %s.") % _t(home)
	for gift: FriendshipReward in data.friendship_rewards:
		if gift != null and gift.hearts > hearts:
			description += " " + _t("Son cadeau à %d cœurs : %d %s.") % [gift.hearts, gift.quantity, db.get_display_name(gift.item_id).to_lower()]
			break
	var entry := {
		"id": "villager:" + villager_id,
		"name": data.display_name,
		"icon": VillagerPortrait.make(data.look),
		"color": PLACEHOLDER_VILLAGER,
		"category": Category.VILLAGERS,
		"description": description,
		"details": details,
		"meta": _t("%d/%d cœurs") % [hearts, max_hearts],
	}
	return entry

## Where they are now, by their routine (and the weather) - the same rule
## as Villager, without needing their zone to be loaded.
static func _place_text(simulation: FarmSimulation, data: VillagerData) -> String:
	var stop := data.get_stop(simulation.state.clock.minute_of_day)
	if stop != null and simulation.is_raining() and not stop.rain_proof:
		stop = null
	if stop == null or stop.spot == data.home:
		return _t("à la maison")
	return _t(SPOT_PLACES.get(stop.spot, "quelque part au village"))

static func _days(count: int, singular: String, plural: String) -> String:
	return _t(singular if count <= 1 else plural) % count

static func _care_text(animal: AnimalState) -> String:
	if animal.is_starving():
		return _t("A très faim ! Occupe-t'en vite.")
	if animal.fed_today and animal.watered_today:
		return _t("En pleine forme aujourd'hui.")
	if not animal.fed_today and not animal.watered_today:
		return _t("Attend à manger et à boire.")
	return _t("Attend à manger.") if not animal.fed_today else _t("Attend à boire.")

static func _animal_icon(db: ItemDatabase, species: AnimalData.Species) -> Texture2D:
	var animal := db.get_animal(species)
	if animal != null and animal.icon != null:
		return animal.icon
	var shop_item := db.get_item_for_species(species)
	return shop_item.icon if shop_item != null else null

static func _yield_text(crop: CropData) -> String:
	if crop.yield_min == crop.yield_max:
		return str(crop.yield_min)
	return _t("%d à %d") % [crop.yield_min, crop.yield_max]

## Names/icon/placeholder color straight from a catalog entry.
static func _entry(id: String, item: ItemData, category: Category, description: String, details: Array) -> Dictionary:
	var entry := _make(id, item.get_display_name(), item.icon, category, item.category, description, details)
	entry["glyph"] = ToolGlyph.glyph_for(item.tool_action)
	return entry

static func _make(id: String, display_name: String, icon: Texture2D,
		category: Category, color_category: ItemData.Category, description: String, details: Array) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"icon": icon,
		"color": ItemData.CATEGORY_COLORS.get(color_category, Color.GRAY),
		"category": category,
		"description": description,
		"details": details,
	}
