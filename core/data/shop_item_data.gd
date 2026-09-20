class_name ShopItemData
extends Resource

## Generic catalog entry shown in the shop UI. Seeds are synthesized at
## runtime from CropData (see ShopItemData.from_crop_data) so crop economy
## numbers only ever live in one place; Tools/Food/Animals are hand-authored
## .tres resources under data/shop_items/.

enum Category { SEEDS, TOOLS, FOOD, ANIMALS }

@export var id: String
@export var display_name: String
@export var malagasy_name: String = ""
@export var description: String = ""
@export var category: Category = Category.SEEDS
@export var price: int = 0
## 0 = not sellable from this card (e.g. tools). Crops/eggs set this so the
## same ItemCard can show a "Vendre" affordance alongside "Acheter".
@export var sell_price: int = 0
@export var icon: Texture2D

## Only set for SEEDS: the real CropData id, so ShopUI can route the purchase
## through FarmSimulation.buy_seed() (unlock_day gating, seed inventory key)
## instead of the generic buy_item() path used by every other category.
@export var crop_id: String = ""

## Only meaningful for ANIMALS: routes the purchase through
## FarmSimulation.buy_chicken() instead of the generic buy_item() path, since
## buying livestock needs to become a real AnimalState once placed in a coop.
@export var animal_species: AnimalData.Species = AnimalData.Species.CHICKEN

static func from_crop_data(crop_data: CropData) -> ShopItemData:
	var item := ShopItemData.new()
	item.id = crop_data.id + "_seed"
	item.display_name = "Graine de %s" % crop_data.display_name
	item.malagasy_name = crop_data.malagasy_name
	item.description = "Pousse en %d jours. Idéal en %s." % [
		crop_data.growth_days,
		"Asara" if crop_data.ideal_season == CropData.Season.ASARA
		else "Asotry" if crop_data.ideal_season == CropData.Season.ASOTRY
		else "toute saison",
	]
	item.category = Category.SEEDS
	item.price = crop_data.seed_price
	item.sell_price = crop_data.sell_price
	item.icon = crop_data.icon
	item.crop_id = crop_data.id
	return item
