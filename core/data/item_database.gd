class_name ItemDatabase
extends RefCounted

## Single source of truth for "what is this item": every id that can appear
## in FarmState.inventory or on a shop shelf resolves here. Built once by
## World from the same crop/animal registries FarmSimulation uses, then
## handed to every screen that shows items (ShopUI, InventoryUI) - so no UI
## ever reads another UI's constants, and economy numbers only live in the
## CropData/AnimalData/ShopItemData resources themselves.

## What kind of thing an inventory id is - drives how each screen presents it.
enum Kind { SEED, CROP, SHOP_ITEM, UNPLACED_ANIMAL, UNKNOWN }

## Hand-authored catalog entries (tools, food, animals, animal products) -
## including ones the market doesn't sell (sold_in_shop = false, e.g. the
## starter tools): they still need names, icons and a tool type everywhere.
## An explicit list rather than a directory scan: exported builds remap
## .tres files, so a scan of data/shop_items/ would silently find nothing.
## Paths loaded in _init() rather than preload()ed: preloading them at
## compile time could run while shop_item_data.gd itself was still compiling
## (load cycle through the scripts that reference ItemDatabase), leaving the
## entries as bare Resources with no ShopItemData script.
## animal_zebu.tres is deliberately left out: FarmSimulation already supports
## buying any species, but there's no Zebu scene in AnimalManager and no
## structure to place one in - add it back here once both exist.
const ITEM_PATHS := [
	"res://data/shop_items/tool_hoe.tres",
	"res://data/shop_items/tool_watering_can.tres",
	"res://data/shop_items/tool_angady.tres",
	"res://data/shop_items/tool_watering_can_tin.tres",
	"res://data/shop_items/food_vary_sy_laoka.tres",
	"res://data/shop_items/food_vary_amin_anana.tres",
	"res://data/shop_items/animal_chicken.tres",
	"res://data/shop_items/egg.tres",
]

const SEED_SUFFIX := "_seed"
const UNPLACED_SUFFIX := "_unplaced"

var _crops: Dictionary # crop_id -> CropData
var _animals: Dictionary # AnimalData.Species -> AnimalData
var _shop_items: Dictionary = {} # item_id -> ShopItemData
var _shop_item_list: Array[ShopItemData] = [] # ITEM_PATHS order
var _seed_items: Dictionary = {} # "<crop_id>_seed" -> ShopItemData (synthesized)

func _init(crop_registry: Dictionary, animal_registry: Dictionary) -> void:
	_crops = crop_registry
	_animals = animal_registry
	for path in ITEM_PATHS:
		var item := load(path) as ShopItemData
		if item == null:
			push_error("ItemDatabase: %s is not a ShopItemData." % path)
			continue
		_shop_item_list.append(item)
		_shop_items[item.id] = item
	for crop_id in _crops:
		var seed_item := ShopItemData.from_crop_data(_crops[crop_id])
		_seed_items[seed_item.id] = seed_item

## Everything the market sells, per ShopItemData.Category, in a stable order:
## seeds follow the crop registry order, the rest follow ITEM_PATHS.
func get_shop_catalog() -> Dictionary:
	var catalog := {}
	for category in ShopItemData.Category.values():
		catalog[category] = []
	for seed_item in _seed_items.values():
		catalog[ShopItemData.Category.SEEDS].append(seed_item)
	for item in _shop_item_list:
		if item.sold_in_shop:
			catalog[item.category].append(item)
	return catalog

func get_kind(item_id: String) -> Kind:
	if _seed_items.has(item_id):
		return Kind.SEED
	if _crops.has(item_id):
		return Kind.CROP
	if _shop_items.has(item_id):
		return Kind.SHOP_ITEM
	if get_unplaced_species(item_id) != null:
		return Kind.UNPLACED_ANIMAL
	return Kind.UNKNOWN

## The CropData behind a seed or harvest id, else null.
func get_crop(item_id: String) -> CropData:
	if item_id.ends_with(SEED_SUFFIX):
		return _crops.get(item_id.trim_suffix(SEED_SUFFIX))
	return _crops.get(item_id)

## The catalog entry for a seed (synthesized) or hand-authored item, else null.
func get_shop_item(item_id: String) -> ShopItemData:
	if _seed_items.has(item_id):
		return _seed_items[item_id]
	return _shop_items.get(item_id)

## "<species prefix>_unplaced" is how FarmState counts animals bought but not
## yet placed in a structure - resolved against the animal registry, so any
## registered species works without a hardcoded id.
func get_unplaced_species(item_id: String) -> AnimalData:
	if not item_id.ends_with(UNPLACED_SUFFIX):
		return null
	for species in _animals:
		if FarmState.species_prefix(species) + UNPLACED_SUFFIX == item_id:
			return _animals[species]
	return null

## The shop entry that sells animals of this species (for its description).
func get_shop_item_for_species(species: AnimalData.Species) -> ShopItemData:
	for item in _shop_item_list:
		if item.category == ShopItemData.Category.ANIMALS and item.animal_species == species and item.price > 0:
			return item
	return null

## The farming action an item performs when used (ShopItemData.ToolType), or
## NONE - seeds aren't tools, they plant through their own path.
func get_tool_type(item_id: String) -> ShopItemData.ToolType:
	var item: ShopItemData = _shop_items.get(item_id)
	return item.tool_type if item != null else ShopItemData.ToolType.NONE

## Whether an item has a use on the farm, and so belongs in the Hotbar:
## tools and seed stacks. Harvests, food, eggs... live in the inventory only.
func is_hotbar_item(item_id: String) -> bool:
	return _seed_items.has(item_id) or get_tool_type(item_id) != ShopItemData.ToolType.NONE

## Tool items in catalog order - starter tools first, so a new game's bar
## always opens on the hoe then the watering can.
func get_tool_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _shop_item_list:
		if item.tool_type != ShopItemData.ToolType.NONE:
			ids.append(item.id)
	return ids

## Seed ids in crop registry order.
func get_seed_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_seed_items.keys())
	return ids
