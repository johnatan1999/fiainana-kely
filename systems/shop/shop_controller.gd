class_name ShopController
extends Node

## Bridges shop UI actions (button presses) to the simulation's economy rules.

var simulation: FarmSimulation
var zone_manager: ZoneManager

func setup(p_simulation: FarmSimulation, p_zone_manager: ZoneManager) -> void:
	simulation = p_simulation
	zone_manager = p_zone_manager

func buy_seed(crop_id: String, quantity: int = 1) -> bool:
	return simulation.buy_seed(crop_id, quantity)

func buy_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	return simulation.buy_item(item_id, unit_price, quantity)

func sell(item_id: String, quantity: int = 1) -> bool:
	return simulation.sell(item_id, quantity)

func sell_item(item_id: String, unit_price: int, quantity: int = 1) -> bool:
	return simulation.sell_item(item_id, unit_price, quantity)

func buy_chicken(quantity: int = 1) -> bool:
	return simulation.buy_chicken(quantity)

func buy_zone(zone_id: String) -> bool:
	return zone_manager.buy_zone(zone_id)

func buy_progressive_patch(patch_size: int, total_price: int) -> bool:
	return zone_manager.buy_progressive_patch(patch_size, total_price)
