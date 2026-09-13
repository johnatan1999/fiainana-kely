class_name ShopController
extends Node

## Bridges shop UI actions (button presses) to the simulation's economy rules.

var simulation: FarmSimulation

func setup(p_simulation: FarmSimulation) -> void:
	simulation = p_simulation

func buy_seed(crop_id: String, quantity: int = 1) -> bool:
	return simulation.buy_seed(crop_id, quantity)

func sell(item_id: String, quantity: int = 1) -> bool:
	return simulation.sell(item_id, quantity)
