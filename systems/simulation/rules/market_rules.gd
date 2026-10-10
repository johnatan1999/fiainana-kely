class_name MarketRules
extends SimRules

## Buying and selling: seeds, the shops' items, crops and products.
## A part of FarmSimulation (SimRules): simulation.market.

## Whether the shop offers it: the padlock only for a built coop that
## isn't safe yet.
func is_item_on_sale(item_id: String) -> bool:
	if item_id == ThiefRules.PADLOCK_ITEM:
		return state.has_coop and not sim.thieves.is_coop_safe()
	return true

func buy_seed(crop_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var crop_data := sim.fields.get_crop_data(crop_id)
	if crop_data == null:
		return false
	if state.day < crop_data.unlock_day:
		return false
	var cost := crop_data.seed_price * quantity
	if state.money < cost:
		return false
	sim.add_money(-cost)
	var seed_key := crop_id + "_seed"
	sim.add_item(seed_key, quantity)
	return true

## Generic purchase path for shop items that aren't crops (tools/food/animals):
## unlike buy_seed(), the caller supplies the price since these items have no
## entry in the crops (FieldRules.get_crop_data()).
func buy_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	if quantity <= 0 or unit_price < 0 or not is_item_on_sale(item_id):
		return false
	if item_id == ThiefRules.PADLOCK_ITEM:
		if state.money < unit_price:
			return false
		sim.add_money(-unit_price)
		sim.thieves.secure_coop()
		return true
	var cost := unit_price * quantity
	if state.money < cost:
		return false
	sim.add_money(-cost)
	sim.add_item(item_id, quantity)
	return true

## `price_multiplier`: what the shop pays on top of the crop's sell_price
## (ShopProfile.sell_multiplier - the weekly market pays more).
func sell(item_id: String, quantity: int = 1, price_multiplier: float = 1.0) -> bool:
	if quantity <= 0 or price_multiplier <= 0.0:
		return false
	var crop_data := sim.fields.get_crop_data(item_id)
	if crop_data == null:
		return false
	if state.get_inventory_count(item_id) < quantity:
		return false
	sim.add_item(item_id, -quantity)
	sim.add_money(roundi(crop_data.sell_price * price_multiplier) * quantity)
	return true

## Generic sell path for non-crop products (eggs, and future animal
## products): symmetric to buy_item() - the caller supplies the unit price
## since these items have no entry in the crops (FieldRules.get_crop_data()).
func sell_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	if quantity <= 0 or unit_price < 0:
		return false
	if state.get_inventory_count(item_id) < quantity:
		return false
	sim.add_item(item_id, -quantity)
	sim.add_money(unit_price * quantity)
	return true
