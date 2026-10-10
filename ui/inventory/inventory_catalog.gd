class_name InventoryCatalog
extends RefCounted

## Presentation layer for the inventory screen: turns an inventory item_id
## into what the book shows - names, icon, which tab it goes in, description
## and detail rows. All facts come from ItemDatabase (the data layer); this
## only decides how the inventory lays them out. Every text it returns is
## already translated to the current language (the French texts in the
## tables below are the keys of localization/translations.csv).

enum Category { CROPS, ANIMALS, TOOLS, FOOD, VILLAGERS, NOTEBOOK }

const CATEGORY_NAMES := {
	Category.CROPS: "Cultures",
	Category.ANIMALS: "Élevage",
	Category.TOOLS: "Outils",
	Category.FOOD: "Nourriture",
	Category.VILLAGERS: "Villageois",
	Category.NOTEBOOK: "Carnet",
}
## The notebook's pages (Discovery.Category, then the dishes).
const NOTEBOOK_PAGES := ["Faune", "Flore", "Lieux", "Cuisine"]
const NOTEBOOK_COLORS := [Color(0.55, 0.45, 0.3), Color(0.35, 0.55, 0.3), Color(0.4, 0.5, 0.65), Color(0.75, 0.5, 0.2)]
const UNKNOWN_COLOR := Color(0.35, 0.3, 0.27)

## Where a villager is, by the spot of their current step (VillagerRoads
## markers) - "En ce moment : au marché". A spot missing here reads as
## "quelque part au village".
const SPOT_PLACES := {
	"Market": "au marché",
	"Square": "sur la place",
	"Bench_East": "sur le banc, près de la maison de l'est",
	"Hut": "à la cabane des rizières",
	"NeighbourPaddy_1": "dans la rizière des voisins",
	"NeighbourPaddy_2": "dans la rizière des voisins",
	"School": "à l'école",
	"Pitch": "sur le terrain de foot",
	"WaterPoint": "au point d'eau",
	"Eatery": "à la gargote",
	"Grocery": "à l'épicerie",
	"Mortar": "au mortier, devant la maison",
	"Laundry": "à la corde à linge",
	"Kitchen": "à la cuisine",
	"Coop": "au poulailler",
	"Orchard": "au verger",
	"Woodpile": "au tas de bois",
	"Bridge": "sur le pont du bourg",
	"WashingStones": "au lavoir du bourg",
	"MarketSquare": "sur la place du marché, au bourg",
	"Market_Collector": "à son étal du tsena, au bourg",
	"Market_Vegetables_1": "à son étal du tsena, au bourg",
	"Market_Vegetables_3": "à son étal du tsena, au bourg",
	"Market_Cloth_1": "à son étal du tsena, au bourg",
	"Taxi": "à l'arrêt du taxi-brousse",
	"ZebuMarket": "au tsena omby du bourg, avec ses zébus",
}
const HOME_PLACES := {
	"House_West": "la maison de l'ouest",
	"House_East": "la maison de l'est",
	"House_South": "la maison du sud",
	"House_Rabe": "une maison du bourg, à l'est du marché",
	"House_Lalao": "une maison du bourg, à l'ouest du marché",
	"House_Ratsimba": "une maison du bourg, au sud-est du marché",
	"School": "le logement de l'école",
}
const PLACEHOLDER_VILLAGER := Color(0.62, 0.45, 0.32)

const SEASON_NAMES := {
	CropData.Season.RAINY: "Asara",
	CropData.Season.DRY: "Asotry",
	CropData.Season.ALL_YEAR: "Toute saison",
}

const WATER_NEED_NAMES := {
	CropData.WaterNeed.LOW: "Faible",
	CropData.WaterNeed.MEDIUM: "Moyen",
	CropData.WaterNeed.HIGH: "Élevé",
}

const CROP_TYPE_NAMES := {
	CropData.Category.FOOD: "Culture vivrière",
	CropData.Category.CASH: "Culture de rente",
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

## One of the player's zebus (FarmSimulation's zebu API): its growth, its
## worth at the zebu market, today's trough.
static func describe_zebu(simulation: FarmSimulation, zebu_id: String) -> Dictionary:
	var zebu := simulation.zebus.get_zebu(zebu_id)
	var grown := simulation.zebus.is_zebu_grown(zebu_id)
	var details: Array = [
		[_t("Croissance"), _t("Adulte") if grown
			else "%d / %d" % [zebu["grown_days"], ZebuRules.ZEBU_GROW_DAYS]],
		[_t("Valeur au marché"), Currency.format(simulation.zebus.get_zebu_value(zebu_id))],
		[_t("Abreuvoir"), _t("Plein aujourd'hui") if simulation.zebus.is_zebu_trough_full() else _t("À remplir")],
	]
	var description := _t("Un zébu adulte, à vendre au tsena omby du bourg le zoma.") if grown \
		else _t("Il grandit d'un jour chaque jour où l'abreuvoir du parc est rempli (ou qu'il pleut).")
	var entry := _make("zebu:" + zebu_id, zebu["name"], zebu_icon(), Category.ANIMALS,
		ItemData.Category.ANIMALS, description, details)
	entry["meta"] = _t("Au parc de la ferme")
	entry["sort_group"] = 1
	return entry

## The family's dog (FarmSimulation's dog API): its bowl, its fondness for
## the player, tonight.
static func describe_dog(simulation: FarmSimulation) -> Dictionary:
	var fed := simulation.dog.is_dog_fed()
	var details: Array = [
		[_t("Gamelle"), _t("Remplie aujourd'hui") if fed else _t("À remplir")],
		[_t("Attachement"), "%d/%d" % [simulation.dog.get_dog_hearts(), DogRules.DOG_MAX_HEARTS]],
		[_t("Cette nuit"), _t("Il garde la ferme") if fed else _t("Il ira chercher à manger")],
	]
	var description := _t("Ton chien. Il te suit partout dehors. Caresse-le chaque jour, et remplis sa gamelle près de sa niche : un chien qui a mangé garde la ferme la nuit et chasse les voleurs de poules.")
	var entry := _make("dog:family", simulation.dog.get_dog_name(), dog_icon(), Category.ANIMALS,
		ItemData.Category.ANIMALS, description, details)
	entry["meta"] = _t("À tes côtés")
	entry["sort_group"] = 1
	return entry

## The dog sitting (frame 4 of the dog sheet), for icons.
static func dog_icon() -> Texture2D:
	var icon := AtlasTexture.new()
	icon.atlas = load("res://assets/sprites/animals/dog.png")
	icon.region = Rect2(0, 96, 112, 96)
	return icon

## A zebu standing (frame 0 of the zebu sheet), for icons.
static func zebu_icon() -> Texture2D:
	var icon := AtlasTexture.new()
	icon.atlas = load("res://assets/sprites/animals/zebu.png")
	icon.region = Rect2(0, 0, 128, 96)
	return icon

## French: singular for 0 and 1 ("0 jour", "1 jour", "2 jours").
## A villager, for the Villageois tab: their portrait, who they are, and
## the player's friendship, next gift, order and where to find them now.
## `id` is their VillagerData file's name; the entry's id is
## "villager:<id>".
static func describe_villager(db: ItemDatabase, simulation: FarmSimulation, villager_id: String,
		data: VillagerData) -> Dictionary:
	if data.family:
		return _describe_family(villager_id, data, simulation)
	var hearts := simulation.friendship.get_hearts(villager_id)
	var max_hearts := FriendshipRules.FRIENDSHIP_MAX_HEARTS
	# Short values (the card's right column is narrow); the longer texts go
	# in the description, which wraps.
	var details: Array = [[_t("Amitié"), _t("%d/%d cœurs") % [hearts, max_hearts]]]
	if hearts < max_hearts:
		details.append([_t("Prochain cœur"), "%d %%" % roundi(simulation.friendship.get_heart_progress(villager_id) * 100.0)])
	if hearts > 0:
		details.append([_t("Prix d'ami"), "+%d %%" % roundi(OrderRules.ORDER_BONUS_PER_HEART * 100.0 * hearts)])
	var order := simulation.orders.get_order(villager_id)
	if order.is_empty():
		details.append([_t("Commande"), _t("Aucune")])
	else:
		details.append([_t("Commande"), "%d %s" % [order["quantity"], db.get_display_name(order["item"]).to_lower()]])
		if simulation.orders.is_order_offered(villager_id):
			details.append([_t("Délai"), _t("à voir")])
		else:
			details.append([_t("Délai"), _days(simulation.orders.get_order_days_left(villager_id), "%d jour", "%d jours")])
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

## A page of the player's notebook (the kahie): found, what it is, with
## Fara's word under her drawing; not yet, "???" and a hint where to look.
## `id`: a Discovery id, or "cuisine:<recipe>". The entry's id is
## "notebook:<id>"; sort_group keeps the pages in order.
static func describe_discovery(db: ItemDatabase, simulation: FarmSimulation, discovery_id: String) -> Dictionary:
	var found := simulation.notebook.is_discovered(discovery_id)
	var page := 3
	var title := ""
	var malagasy := ""
	var text := ""
	var hint := ""
	var fara := ""
	var icon: Texture2D = null
	if discovery_id.begins_with(NotebookRules.CUISINE_PREFIX):
		var recipe := simulation.kitchen.get_recipe(discovery_id.trim_prefix(NotebookRules.CUISINE_PREFIX))
		title = _t(recipe.display_name) if recipe != null else discovery_id
		malagasy = recipe.malagasy_name if recipe != null else ""
		text = _t("Cuisiné à la cuisine de la ferme.")
		hint = _t("Une recette à cuisiner à la cuisine de la ferme.")
		fara = _t("Miam, ça a l'air bon !")
		if recipe != null:
			icon = db.get_icon(recipe.result)
	else:
		var discovery := simulation.notebook.get_discovery(discovery_id)
		page = discovery.category
		title = _t(discovery.display_name)
		malagasy = discovery.malagasy_name
		text = _t(discovery.description)
		hint = _t(discovery.hint)
		fara = _t(discovery.fara_line)
		icon = discovery.get_drawing()
	var details: Array = [[_t("Page"), _t(NOTEBOOK_PAGES[page])]]
	if not found:
		return {
			"id": "notebook:" + discovery_id, "name": "???", "icon": null, "color": UNKNOWN_COLOR,
			"category": Category.NOTEBOOK, "description": _t("Pas encore trouvé. ") + hint,
			"details": details, "meta": _t(NOTEBOOK_PAGES[page]), "sort_group": page,
		}
	details.append([_t("Trouvé"), _t("jour %d") % int(simulation.state.discoveries[discovery_id])])
	return {
		"id": "notebook:" + discovery_id, "name": "%s · %s" % [title, malagasy] if not malagasy.is_empty() else title,
		"icon": icon, "color": NOTEBOOK_COLORS[page], "category": Category.NOTEBOOK,
		"description": text + "\n\n" + _t("Dessin de Fara : « %s »") % fara,
		"details": details, "meta": _t(NOTEBOOK_PAGES[page]), "sort_group": page,
	}

## The player's family: who they are and where they are now - no
## friendship or orders with them.
static func _describe_family(villager_id: String, data: VillagerData, simulation: FarmSimulation) -> Dictionary:
	return {
		"id": "villager:" + villager_id,
		"name": data.display_name,
		"icon": VillagerPortrait.make(data.look),
		"color": PLACEHOLDER_VILLAGER,
		"category": Category.VILLAGERS,
		"description": _t(data.role),
		"details": [[_t("En ce moment"), _place_text(simulation, data)]],
		"meta": _t("Famille"),
		"sort_group": 0, # the family first
	}

## Where they are now, by their routine (and the weather) - the same rule
## as Villager, without needing their zone to be loaded.
static func _place_text(simulation: FarmSimulation, data: VillagerData) -> String:
	var clock := simulation.state.clock
	var stop := data.get_stop(clock.minute_of_day, clock.get_weekday(), simulation.get_conditions())
	if stop != null and simulation.is_raining() and not stop.rain_proof:
		stop = null
	if stop == null or (stop.spot == data.home and stop.activity == VillagerStop.Activity.INSIDE):
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
