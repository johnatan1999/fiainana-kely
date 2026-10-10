class_name ItemDatabase
extends RefCounted

## Single source of truth for "what is this item": every id that can appear
## in FarmState.inventory or on a shop shelf resolves here. Built once by
## World from the same crop/animal registries FarmSimulation uses, then
## handed to every screen that shows items (ShopUI, InventoryUI) - so no UI
## ever reads another UI's constants, and economy numbers only live in the
## CropData/AnimalData/ItemData resources themselves.

## What kind of thing an inventory id is - drives how each screen presents it.
## AUTHORED = a hand-authored ItemData from ITEM_PATHS (tool, food, animal,
## egg...).
enum Kind { SEED, CROP, AUTHORED, UNKNOWN }

## Hand-authored catalog entries (tools, food, animals, animal products) -
## including ones the market doesn't sell (sold_in_shop = false, e.g. the
## starter tools): they still need names, icons and a tool type everywhere.
## An explicit list rather than a directory scan: exported builds remap
## .tres files, so a scan of data/items/ would silently find nothing.
## Paths loaded in _init() rather than preload()ed: preloading them at
## compile time could run while item_data.gd itself was still compiling
## (load cycle through the scripts that reference ItemDatabase), leaving the
## entries as bare Resources with no ItemData script.
## animal_zebu.tres is deliberately left out: zebus aren't items - they're
## bought one by one at the market-day zebu market (FarmSimulation's zebu API).
const ITEM_PATHS := [
	"res://data/items/tool_hoe.tres",
	"res://data/items/tool_watering_can.tres",
	"res://data/items/tool_spade.tres",
	"res://data/items/tool_watering_can_tin.tres",
	"res://data/items/tool_plough.tres",
	"res://data/items/coop_padlock.tres",
	"res://data/items/food_rice_and_side_dish.tres",
	"res://data/items/food_rice_with_greens.tres",
	"res://data/items/food_grilled_corn.tres",
	"res://data/items/food_mofo_gasy.tres",
	"res://data/items/food_tomato_rougail.tres",
	"res://data/items/wild_greens.tres",
	"res://data/items/honey.tres",
	"res://data/items/ravintsara.tres",
	"res://data/items/mushroom.tres",
	"res://data/items/animal_chicken.tres",
	"res://data/items/egg.tres",
	"res://data/items/manure.tres",
	"res://data/items/mango.tres",
]

const SEED_SUFFIX := "_seed"

var _crops: Dictionary # crop_id -> CropData
var _animals: Dictionary # AnimalData.Species -> AnimalData
var _items: Dictionary = {} # item_id -> ItemData
var _item_list: Array[ItemData] = [] # ITEM_PATHS order
var _seed_items: Dictionary = {} # "<crop_id>_seed" -> ItemData (synthesized)

func _init(crop_registry: Dictionary, animal_registry: Dictionary) -> void:
	_crops = crop_registry
	_animals = animal_registry
	for path in ITEM_PATHS:
		var item := load(path) as ItemData
		if item == null:
			push_error("ItemDatabase: %s is not a ItemData." % path)
			continue
		_item_list.append(item)
		_items[item.id] = item
	for crop_id in _crops:
		var seed_item := ItemData.from_crop_data(_crops[crop_id])
		_seed_items[seed_item.id] = seed_item

## Everything the market sells, per ItemData.Category, in a stable order:
## seeds follow the crop registry order, the rest follow ITEM_PATHS.
func get_shop_catalog() -> Dictionary:
	var catalog := {}
	for category in ItemData.Category.values():
		catalog[category] = []
	for seed_item in _seed_items.values():
		catalog[ItemData.Category.SEEDS].append(seed_item)
	for item in _item_list:
		if item.sold_in_shop:
			catalog[item.category].append(item)
	return catalog

func get_kind(item_id: String) -> Kind:
	if _seed_items.has(item_id):
		return Kind.SEED
	if _crops.has(item_id):
		return Kind.CROP
	if _items.has(item_id):
		return Kind.AUTHORED
	return Kind.UNKNOWN

## The CropData behind a seed or harvest id, else null.
func get_crop(item_id: String) -> CropData:
	if item_id.ends_with(SEED_SUFFIX):
		return _crops.get(item_id.trim_suffix(SEED_SUFFIX))
	return _crops.get(item_id)

## The ItemData of a seed (synthesized) or hand-authored item, else null.
## Harvested crops have none - see get_crop().
func get_item(item_id: String) -> ItemData:
	if _seed_items.has(item_id):
		return _seed_items[item_id]
	return _items.get(item_id)

## The name shown for any id - a seed, a harvested crop or an item -
## translated; the id itself if it's unknown.
func get_display_name(item_id: String) -> String:
	var item := get_item(item_id)
	if item != null:
		return item.get_display_name()
	var crop := get_crop(item_id)
	return tr(crop.display_name) if crop != null else item_id

## The icon for any id - a seed, a harvested crop or an item - or null.
func get_icon(item_id: String) -> Texture2D:
	var item := get_item(item_id)
	if item != null:
		return item.icon
	var crop := get_crop(item_id)
	return crop.icon if crop != null else null

## What a species is (name, icon, product cycle...), or null if unregistered.
func get_animal(species: AnimalData.Species) -> AnimalData:
	return _animals.get(species)

## The item that sells animals of this species (for its description).
func get_item_for_species(species: AnimalData.Species) -> ItemData:
	for item in _item_list:
		if item.category == ItemData.Category.ANIMALS and item.animal_species == species and item.price > 0:
			return item
	return null

## What using an item on a plot does: its tool action, PLANT for a seed
## stack, NONE for anything else (harvests, food, eggs...).
func get_use_action(item_id: String) -> FarmAction.Type:
	if _seed_items.has(item_id):
		return FarmAction.Type.PLANT
	var item: ItemData = _items.get(item_id)
	return item.tool_action if item != null else FarmAction.Type.NONE

func is_seed(item_id: String) -> bool:
	return _seed_items.has(item_id)

## The crop a seed stack plants, "" if item_id isn't a seed.
func get_seed_crop_id(item_id: String) -> String:
	var seed_item: ItemData = _seed_items.get(item_id)
	return seed_item.crop_id if seed_item != null else ""

## Whether an item has a use on the farm, and so belongs in the Hotbar:
## tools and seed stacks. Harvests, food, eggs... live in the inventory only.
func is_hotbar_item(item_id: String) -> bool:
	return get_use_action(item_id) != FarmAction.Type.NONE

## Tool items in catalog order - starter tools first, so a new game's bar
## always opens on the hoe then the watering can.
func get_tool_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _item_list:
		if item.tool_action != FarmAction.Type.NONE:
			ids.append(item.id)
	return ids

## Seed ids in crop registry order.
func get_seed_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_seed_items.keys())
	return ids
