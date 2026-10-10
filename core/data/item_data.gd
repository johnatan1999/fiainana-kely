class_name ItemData
extends Resource

## What an item *is*, wherever it shows up: inventory book, hotbar, market
## shelf, info card. Selling it is only one of its facets (price,
## sold_in_shop) - the starter tools are items the market never lists.
## Seeds are synthesized at runtime from CropData (see from_crop_data) so crop
## economy numbers only ever live in one place; tools, food, animals and
## animal products are hand-authored .tres resources under data/items/.

enum Category { SEEDS, TOOLS, FOOD, ANIMALS }

## Identity color of each category - the placeholder square shown by every
## screen (shop cards, inventory cells) for an item with no icon art yet.
const CATEGORY_COLORS := {
	Category.SEEDS: Color(0.45, 0.65, 0.25),
	Category.TOOLS: Color(0.55, 0.5, 0.45),
	Category.FOOD: Color(0.75, 0.5, 0.2),
	Category.ANIMALS: Color(0.6, 0.4, 0.25),
}

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
## through MarketRules.buy_seed() (unlock_day gating, seed inventory key)
## instead of the generic buy_item() path used by every other category.
@export var crop_id: String = ""

## Only meaningful for ANIMALS: routes the purchase through
## AnimalRules.buy_chicken() instead of the generic buy_item() path, since
## buying livestock needs to become a real AnimalState once placed in a coop.
@export var animal_species: AnimalData.Species = AnimalData.Species.CHICKEN

## Only meaningful for TOOLS: what the tool does to a plot. Several items can
## share one - the starter hoe and the Angady both TILL.
@export var tool_action: FarmAction.Type = FarmAction.Type.NONE
## False for items the player gets but can't buy (the starter tools): they
## still exist for the inventory/hotbar, the market just doesn't list them.
@export var sold_in_shop: bool = true

## Set only on seed entries synthesized by from_crop_data(): their name and
## description are composed from the crop at display time, so they follow
## the current language (see get_display_name()/get_description()).
var _seed_crop: CropData

## display_name/description hold the French source texts (the translation
## keys, see localization/translations.csv) - screens show these instead.
func get_display_name() -> String:
	if _seed_crop != null:
		if _seed_crop.seed_display_name != "":
			return tr(_seed_crop.seed_display_name)
		return tr("Graine de %s") % tr(_seed_crop.display_name)
	return tr(display_name)

func get_description() -> String:
	if _seed_crop != null:
		return tr("Pousse en %d jours. Idéal en %s.") % [_seed_crop.growth_days, tr(_season_key(_seed_crop.ideal_season))]
	return tr(description)

static func _season_key(season: CropData.Season) -> String:
	match season:
		CropData.Season.RAINY:
			return "Asara"
		CropData.Season.DRY:
			return "Asotry"
	return "toute saison"

static func from_crop_data(crop_data: CropData) -> ItemData:
	var item := ItemData.new()
	item._seed_crop = crop_data
	item.id = crop_data.id + "_seed"
	item.display_name = crop_data.seed_display_name if crop_data.seed_display_name != "" else "Graine de %s" % crop_data.display_name
	item.malagasy_name = crop_data.malagasy_name
	item.description = "Pousse en %d jours. Idéal en %s." % [crop_data.growth_days, _season_key(crop_data.ideal_season)]
	item.category = Category.SEEDS
	item.price = crop_data.seed_price
	item.sell_price = crop_data.sell_price
	item.icon = crop_data.icon
	item.crop_id = crop_data.id
	return item
