class_name ShopProfile
extends Resource

## What a shop (structures/shop) sells, what it pays and when it's open. The
## one ShopUI shows whichever shop the player opened through it: the village
## grocery has the everyday seeds and goods every day; the bourg's zoma
## market has the export crops' seeds, pays more for harvests, and only
## opens on market day.

## Which seeds (by CropData.Category) are on the shelf - each seed's card is
## also where its harvest is sold.
enum SeedRange {
	## Food and cash crops (VIVRIER, RENTE): what the village grows.
	LOCAL,
	## Export crops only (vanilla, clove...): what the collectors buy.
	EXPORT,
	ALL,
}

## The shop window's title (a translation key).
@export var title := "Marché du village"
@export var seeds := SeedRange.ALL
@export var sells_tools := true
@export var sells_food := true
@export var sells_animals := true
## Harvests and goods sold here pay this much of their usual price
## (1.25 = +25 %).
@export_range(0.5, 2.0, 0.05) var sell_multiplier := 1.0
## The weekdays it opens (GameClock.Weekday bits); none ticked = every day.
@export_flags("Alatsinainy", "Talata", "Alarobia", "Alakamisy", "Zoma", "Sabotsy", "Alahady") var open_days := 0
## Opening hours, in minutes of the day (past 1440 = after midnight).
@export_range(0, 1560, 30) var opens_at := 0
@export_range(0, 1560, 30) var closes_at := 1560
## Shown when the player comes while it's closed (a translation key).
@export var closed_message := ""

func is_open(weekday: int, minute_of_day: int) -> bool:
	var day_ok := open_days == 0 or open_days & (1 << weekday) != 0
	return day_ok and minute_of_day >= opens_at and minute_of_day < closes_at

func sells_seed(crop: CropData) -> bool:
	match seeds:
		SeedRange.LOCAL:
			return crop.category != CropData.Category.EXPORT
		SeedRange.EXPORT:
			return crop.category == CropData.Category.EXPORT
	return true

## Whether this shop has the shelf for `item` at all.
func sells(item: ItemData, item_db: ItemDatabase) -> bool:
	match item.category:
		ItemData.Category.SEEDS:
			var crop := item_db.get_crop(item.crop_id)
			return crop != null and sells_seed(crop)
		ItemData.Category.TOOLS:
			return sells_tools
		ItemData.Category.FOOD:
			return sells_food
		ItemData.Category.ANIMALS:
			return sells_animals
	return false

## ItemDatabase.get_shop_catalog(), down to what this shop sells.
func filter_catalog(catalog: Dictionary, item_db: ItemDatabase) -> Dictionary:
	var filtered := {}
	for category in catalog:
		filtered[category] = (catalog[category] as Array).filter(func(item: ItemData) -> bool:
			return sells(item, item_db))
	return filtered

## What selling one `base_price` item here pays.
func sell_price(base_price: int) -> int:
	return roundi(base_price * sell_multiplier)
