class_name SaveController
extends Node

## Persists/restores the simulation's state, plus the player's zone and
## position, in the save slot being played (SaveSlots).
##
## The game saves itself when the player goes to bed (WorldManager.slept),
## and only then: quitting during the day goes back to that morning. A
## tournament or a harvest can't be replayed by reloading - their outcome
## stands. Also saved once at the start of a new game, so its slot shows.
## Development builds keep the save_game / load_game keys (F5 / F9).

## After a night's sleep: whether the new morning was saved (false: no
## slot, or writing failed). No UI here - the migrations are unit-tested
## without the autoloads.
signal night_saved(saved: bool)

const DEFAULT_ZONE_ID := "village"

## Bump this whenever the save format changes, and add a matching
## _migrate_to_vN() step below - never rewrite an existing step once it has
## shipped, only append new ones. This is the single place format drift gets
## fixed, instead of runtime code scattered across load_game() staying
## permanently tolerant of every historical format.
const SAVE_VERSION := 8

var simulation: FarmSimulation
var world_manager: WorldManager
var player: PlayerController
## The slot this game is saved in (SaveSlots), -1 = never saved.
var slot := -1
## Time actually played in this game (the tree not paused), in seconds.
var _play_seconds := 0.0

func setup(p_simulation: FarmSimulation, p_world_manager: WorldManager, p_player: PlayerController,
		p_slot: int = -1) -> void:
	simulation = p_simulation
	world_manager = p_world_manager
	player = p_player
	slot = p_slot
	world_manager.slept.connect(_on_slept)

func _process(delta: float) -> void:
	_play_seconds += delta

func has_save() -> bool:
	return slot >= 0 and SaveSlots.exists(slot)

## Returns whether it was saved (not without a slot, or if writing failed).
func save_game() -> bool:
	if slot < 0:
		return false
	var data := simulation.to_save_data()
	data["save_version"] = SAVE_VERSION
	data["zone_id"] = world_manager.current_zone_id
	data["return_point"] = world_manager.get_return_point()
	data["player_position"] = {"x": player.global_position.x, "y": player.global_position.y}
	data["summary"] = {
		"day": simulation.state.day,
		"money": simulation.state.money,
		"play_seconds": int(_play_seconds),
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	return SaveSlots.write(slot, data)

## A night's sleep: the new morning is saved.
func _on_slept() -> void:
	night_saved.emit(save_game())

## Restores simulation state, then re-enters the saved zone at the saved
## position instead of the zone's default spawn marker.
func load_game() -> bool:
	if not has_save():
		return false
	var data := SaveSlots.read(slot)
	if data.is_empty():
		return false
	_play_seconds = float(data.get("summary", {}).get("play_seconds", 0)) if data.get("summary") is Dictionary else 0.0

	var save_version := int(data.get("save_version", 0))
	if save_version > SAVE_VERSION:
		push_error("Save file is from a newer game version (v%d) than this build supports (v%d) - refusing to load it to avoid corrupting it." % [save_version, SAVE_VERSION])
		return false
	data = _migrate(data, save_version)

	simulation.load_save_data(data)

	# Optional key (older saves have none): only means "no way back known yet".
	world_manager.set_return_point(data.get("return_point", {}) if data.get("return_point") is Dictionary else {})
	var zone_id: String = data.get("zone_id", DEFAULT_ZONE_ID)
	if world_manager.has_zone(zone_id):
		world_manager.change_zone(zone_id, "SpawnDefault")
	else:
		push_error("Unknown zone: " + zone_id)

	var pos_data = data.get("player_position")
	if pos_data is Dictionary:
		player.global_position = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))

	return true

## Applies every migration step between the save's version and SAVE_VERSION,
## in order. A save from any older version keeps loading correctly as the
## format evolves - the next format change adds one more `if from_version < N`
## step here instead of teaching load_game() itself to tolerate old formats
## forever.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version < 1:
		data = _migrate_to_v1(data)
	if from_version < 2:
		data = _migrate_to_v2(data)
	if from_version < 3:
		data = _migrate_to_v3(data)
	if from_version < 4:
		data = _migrate_to_v4(data)
	if from_version < 5:
		data = _migrate_to_v5(data)
	if from_version < 6:
		data = _migrate_to_v6(data)
	if from_version < 7:
		data = _migrate_to_v7(data)
	if from_version < 8:
		data = _migrate_to_v8(data)
	return data

## v0 (unversioned save, predates this field entirely) -> v1: zone_id was
## briefly written as a raw Zone.ID int by a save_game() bug instead of its
## string key name - normalize it to the string key name v1 expects.
## Hardcoded snapshot of the enum as it existed at v1, deliberately NOT
## referencing the (now-deleted) Zone.ID class - a migration step has to keep
## meaning exactly what it meant when it shipped, independent of whatever the
## live code looks like today.
const _V1_ENUM_KEYS := ["VILLAGE", "PLAYER_HOUSE", "CHICKEN_COOP"]
func _migrate_to_v1(data: Dictionary) -> Dictionary:
	var zone_id_data = data.get("zone_id")
	if zone_id_data is float or zone_id_data is int:
		var idx := int(zone_id_data)
		if idx >= 0 and idx < _V1_ENUM_KEYS.size():
			data["zone_id"] = _V1_ENUM_KEYS[idx]
	return data

## v1 -> v2: zone ids moved from Zone.ID enum key names ("VILLAGE") to
## free-form lowercase ZoneData ids ("village") when WorldManager switched to
## a data-driven, auto-discovered zone registry (data/world_zones/*.tres).
const _V2_ZONE_ID_MAP := {
	"VILLAGE": "village",
	"PLAYER_HOUSE": "player_house",
	"CHICKEN_COOP": "chicken_coop",
}
func _migrate_to_v2(data: Dictionary) -> Dictionary:
	var old_id = data.get("zone_id")
	if old_id is String and _V2_ZONE_ID_MAP.has(old_id):
		data["zone_id"] = _V2_ZONE_ID_MAP[old_id]
	return data

## v2 -> v3: items of crops removed from the game (turnip, cut in 9aacc4a)
## are dropped from the inventory and refunded, so the player never just
## loses what they owned. Turnip was cut before the currency change
## (a3068a9), which multiplied every price by exactly 100 - so its last
## shipped prices (sell 30, seed 10) are converted the same way.
## Hardcoded snapshot, same reason as v1.
const _V3_REMOVED_ITEM_REFUNDS := {
	"turnip": 30 * 100,
	"turnip_seed": 10 * 100,
}
func _migrate_to_v3(data: Dictionary) -> Dictionary:
	var inventory = data.get("inventory")
	if not inventory is Dictionary:
		return data
	var refund := 0
	for item_id in _V3_REMOVED_ITEM_REFUNDS:
		if inventory.has(item_id):
			refund += maxi(0, int(inventory[item_id])) * _V3_REMOVED_ITEM_REFUNDS[item_id]
			inventory.erase(item_id)
	if refund > 0:
		data["money"] = int(data.get("money", 0)) + refund
		print("SaveController: removed-crop items refunded for %d Ar." % refund)
	return data

## v3 -> v4: the hoe and watering can became real inventory items (they
## used to be always-owned pseudo tools, "hoe"/"watering_can" in the hotbar).
## Every player had them, so every save gets them, and hotbar slots holding
## the old pseudo ids now hold the items. Hardcoded snapshot, same reason as v1.
const _V4_STARTER_TOOLS := ["tool_hoe", "tool_watering_can"]
const _V4_HOTBAR_IDS := {"hoe": "tool_hoe", "watering_can": "tool_watering_can"}
func _migrate_to_v4(data: Dictionary) -> Dictionary:
	var inventory = data.get("inventory")
	if not inventory is Dictionary:
		inventory = {}
		data["inventory"] = inventory
	for item_id in _V4_STARTER_TOOLS:
		inventory[item_id] = maxi(int(inventory.get(item_id, 0)), 1)
	var hotbar = data.get("hotbar")
	if hotbar is Array:
		for i in hotbar.size():
			hotbar[i] = _V4_HOTBAR_IDS.get(str(hotbar[i]), hotbar[i])
	return data

## v4 -> v5: animals bought but not settled yet were inventory items
## ("<species prefix>_unplaced" x count); they're now their own list,
## pending_animals (species index as a string key -> count), out of the bag.
## Hardcoded snapshot of the prefixes, in AnimalData.Species order as of v5.
const _V5_SPECIES_PREFIXES := ["chicken", "duck", "goose", "pig", "zebu"]
func _migrate_to_v5(data: Dictionary) -> Dictionary:
	var inventory = data.get("inventory")
	if not inventory is Dictionary:
		return data
	var pending := {}
	for species in _V5_SPECIES_PREFIXES.size():
		var key: String = _V5_SPECIES_PREFIXES[species] + "_unplaced"
		if inventory.has(key):
			var count := int(inventory[key])
			inventory.erase(key)
			if count > 0:
				pending[str(species)] = count
	data["pending_animals"] = pending
	return data

## v5 -> v6: plots used to share one grid, each world zone with fields
## taking its own region of it by hand (FarmView.grid_offset: the rice
## fields at x >= 100). Plots now belong to a zone and use its own grid:
## each one gets its zone, its cell shifted back by that zone's old offset.
## Hardcoded snapshot of the offsets as of v5, same reason as v1.
const _V6_ZONE_OFFSETS := [["rice_fields", Vector2i(100, 0)]]
const _V6_DEFAULT_ZONE := "village"
func _migrate_to_v6(data: Dictionary) -> Dictionary:
	var plots = data.get("plots")
	if not plots is Dictionary:
		return data
	for key in plots:
		var plot: Dictionary = plots[key]
		if plot.has("zone"):
			continue
		var cell := Vector2i(int(plot.get("x", 0)), int(plot.get("y", 0)))
		var zone := _V6_DEFAULT_ZONE
		for entry in _V6_ZONE_OFFSETS:
			var offset: Vector2i = entry[1]
			if cell.x >= offset.x and cell.y >= offset.y:
				zone = entry[0]
				cell -= offset
		plot["zone"] = zone
		plot["x"] = cell.x
		plot["y"] = cell.y
	return data

## v6 -> v7: the player's farm left the village for a zone of its own
## ("farm", tools/split_farm.gd), at the same coordinates. What was the farm
## goes with it: every village plot (all were farm fields), the orchard's
## trees, a way back out of the house or the coop, and a player saved in the
## village's west part (where the farm was). Hardcoded snapshot, same reason
## as v1.
const _V7_FARM_WIDTH := 1440.0
const _V7_FARM_TREES := "village:Trees/Verger_Manguier_"
const _V7_FARM_DOORS := ["HouseGroup/House", "ChickenCoopBuilding"]
func _migrate_to_v7(data: Dictionary) -> Dictionary:
	var plots = data.get("plots")
	if plots is Dictionary:
		for key in plots:
			var plot: Dictionary = plots[key]
			if plot.get("zone", "village") == "village":
				plot["zone"] = "farm"
	var trees = data.get("trees")
	if trees is Dictionary:
		for tree_id in trees.keys():
			if str(tree_id).begins_with(_V7_FARM_TREES):
				trees[str(tree_id).replace("village:", "farm:")] = trees[tree_id]
				trees.erase(tree_id)
	var back = data.get("return_point")
	if back is Dictionary and back.get("zone") == "village":
		for door: String in _V7_FARM_DOORS:
			if str(back.get("spawn", "")).begins_with(door):
				back["zone"] = "farm"
	var position = data.get("player_position")
	if data.get("zone_id", DEFAULT_ZONE_ID) == "village" and position is Dictionary \
			and float(position.get("x", 0.0)) < _V7_FARM_WIDTH:
		data["zone_id"] = "farm"
	return data

## v7 -> v8: every id, file and node name moved to English (French and
## Malagasy words stay in player-facing text only): the "bourg" zone became
## "market_town", items and farm zones got English ids, and scene nodes were
## renamed word by word (Haie_Sud_1_01 -> Hedge_South_1_01) - which changes
## tree ids ("<zone>:Trees/<node>"), neighbour paddy ids ("<zone>:<node>")
## and the return point's node path. tools/rename_to_english.gd renamed the
## scenes with the same tables (v8_english_name), so both always agree.
## Hardcoded snapshot, same reason as v1.
const _V8_ZONE_IDS := {"bourg": "market_town"}
const _V8_ITEM_IDS := {
	"food_vary_sy_laoka": "food_rice_and_side_dish",
	"food_vary_amin_anana": "food_rice_with_greens",
	"tool_angady": "tool_spade",
}
const _V8_FARM_ZONE_IDS := {
	"riziere_haute": "upper_paddy",
	"riziere_basse": "lower_paddy",
	"tany_lonaka_nord": "fertile_land_north",
	"tany_lonaka_sud": "fertile_land_south",
}
## Whole node names first (word order, or a better English name), then word
## by word on "_"-separated parts; digits are kept as they are.
const _V8_NAME_OVERRIDES := {
	"Bourg": "MarketTown",
	"CentreVillage": "VillageCenter",
	"Riziere_Haute": "UpperPaddy",
	"Riziere_Basse": "LowerPaddy",
	"RizieresVoisins": "NeighbourPaddies",
	"Riziere_Voisins": "NeighbourPaddy",
	"Tsena": "MarketSquare",
	"Tsena_Omby": "ZebuMarket",
	"TsenaOmby": "ZebuMarket",
	"Trano": "House",
	"ToBourg": "ToMarketTown",
	"SpawnFrom_BOURG": "SpawnFrom_MARKET_TOWN",
	"Vers_bourg": "To_market_town",
	"Route_Bourg": "Road_MarketTown",
	"NiggaHen": "BlackHen",
	"MarketStallLamba": "MarketStallCloth",
}
const _V8_NAME_WORDS := {
	"Aigrettes": "Egrets", "Ala": "Forest", "Akoho": "Hens", "Andrefana": "West",
	"Atsimo": "South", "Atsinanana": "East", "Avaratra": "North", "Banc": "Bench",
	"Basse": "Lower", "Bois": "Woodpile", "Bosquet": "Grove", "BotteRiz": "RiceBundle",
	"But": "Goal", "Cabane": "Hut", "Centre": "Center", "Cour": "Yard", "Cuisine": "Kitchen",
	"Dada": "Father", "Drapeau": "Flag", "Epicerie": "Grocery", "Est": "East",
	"Fanoto": "Mortar", "Fantsakana": "WaterPoint", "Ferme": "Farm", "Foin": "Hay",
	"Foyer": "Hearth", "Gerbe": "Sheaf", "GerbeRiz": "RiceSheaf", "Gony": "RiceSacks",
	"GrandeMaison": "BigHouse", "Grenier": "Granary", "Haie": "Hedge", "Haute": "Upper",
	"Hotely": "Eatery", "Jarres": "Jars", "Kianja": "Pitch", "Lamba": "Cloth",
	"Lanterne": "Lantern", "Lavoir": "WashingStones", "Legioma": "Vegetables",
	"Linge": "Laundry", "Maison": "House", "MaisonEst": "HouseEast",
	"MaisonOuest": "HouseWest", "MaisonSud": "HouseSouth", "Manga": "Mango",
	"Manguier": "MangoTree", "Marche": "Market", "Mpanangona": "Collector",
	"NatteRiz": "RiceMat", "Neny": "Mother", "Nord": "North", "NordEst": "NorthEast",
	"Omby": "Zebu", "Ouest": "West", "Panier": "Basket", "Panneau": "Sign",
	"PetitPanier": "SmallBasket", "Place": "Square", "Pont": "Bridge",
	"Poulailler": "Coop", "Remise": "Shed", "Renirano": "River", "Riziere": "Paddy",
	"RiziereBasse": "LowerPaddy", "RiziereHaute": "UpperPaddy", "Roseaux": "Reeds",
	"Route": "Road", "Sarety": "ZebuCart", "Sekoly": "School", "Sinibe": "WaterJar",
	"Siny": "Jars", "Sobika": "Basket", "Sud": "South", "TanyLonaka": "FertileLand",
	"TanyLonakaNord": "FertileLandNorth", "TanyLonakaSud": "FertileLandSouth",
	"TaxiBrousse": "BushTaxi", "Trano": "House", "TranoGasy": "HouseTraditional",
	"TranoKely": "HouseSmall", "Tsena": "Market", "Verger": "Orchard", "Vers": "To",
	"Voisins": "Neighbours",
}
## The English name of a v7 node name (unchanged if it had nothing to
## translate). Also used by tools/rename_to_english.gd.
static func v8_english_name(old_name: String) -> String:
	if _V8_NAME_OVERRIDES.has(old_name):
		return _V8_NAME_OVERRIDES[old_name]
	var parts := old_name.split("_")
	# "Riziere_Voisins_1": a whole-name override, then the number.
	for cut in range(parts.size() - 1, 0, -1):
		var head := "_".join(parts.slice(0, cut))
		if _V8_NAME_OVERRIDES.has(head) and Array(parts.slice(cut)).all(func(p: String) -> bool: return p.is_valid_int()):
			return "_".join([_V8_NAME_OVERRIDES[head]] + Array(parts.slice(cut)))
	var out: Array[String] = []
	for part in parts:
		# "Riziere1", "TranoKely01": the word, then its digits.
		var word := part
		var digits := ""
		while not word.is_empty() and word[word.length() - 1].is_valid_int():
			digits = word[word.length() - 1] + digits
			word = word.left(word.length() - 1)
		out.append(_V8_NAME_WORDS.get(word, word) + digits)
	return "_".join(out)

## A node path ("HouseGroup/TranoKely01/ExitSpawn"), name by name.
static func v8_english_path(old_path: String) -> String:
	return "/".join(Array(old_path.split("/")).map(func(n: String) -> String: return v8_english_name(n)))

func _migrate_to_v8(data: Dictionary) -> Dictionary:
	var zone_of := func(zone_id) -> String: return _V8_ZONE_IDS.get(str(zone_id), str(zone_id))
	if data.has("zone_id"):
		data["zone_id"] = zone_of.call(data["zone_id"])
	var back = data.get("return_point")
	if back is Dictionary:
		if back.has("zone"):
			back["zone"] = zone_of.call(back["zone"])
		if back.has("spawn"):
			back["spawn"] = v8_english_path(str(back["spawn"]))
	var plots = data.get("plots")
	if plots is Dictionary:
		for key in plots:
			var plot: Dictionary = plots[key]
			if plot.has("zone"):
				plot["zone"] = zone_of.call(plot["zone"])
	# "<zone>:<node path>" keys: trees, neighbours' paddies.
	for field in ["trees", "neighbour_harvest"]:
		var table = data.get(field)
		if not table is Dictionary:
			continue
		for key in table.keys():
			var text := str(key)
			var zone := text.get_slice(":", 0)
			var renamed := "%s:%s" % [zone_of.call(zone), v8_english_path(text.substr(zone.length() + 1))]
			if renamed != text:
				table[renamed] = table[key]
				table.erase(key)
	var inventory = data.get("inventory")
	if inventory is Dictionary:
		for old_id in _V8_ITEM_IDS:
			if inventory.has(old_id):
				inventory[_V8_ITEM_IDS[old_id]] = inventory[old_id]
				inventory.erase(old_id)
	var hotbar = data.get("hotbar")
	if hotbar is Array:
		for i in hotbar.size():
			hotbar[i] = _V8_ITEM_IDS.get(str(hotbar[i]), hotbar[i])
	var orders = data.get("orders")
	if orders is Dictionary:
		for villager_id in orders:
			var order = orders[villager_id]
			if order is Dictionary and order.has("item"):
				order["item"] = _V8_ITEM_IDS.get(str(order["item"]), order["item"])
	var unlocked = data.get("unlocked_zone_ids")
	if unlocked is Array:
		data["unlocked_zone_ids"] = unlocked.map(func(id) -> String: return _V8_FARM_ZONE_IDS.get(str(id), str(id)))
	return data

## Development only: save or reload at any time.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("save_game"):
		if save_game():
			print("[dev] saved in slot %d" % (slot + 1))
	elif event.is_action_pressed("load_game"):
		load_game()
