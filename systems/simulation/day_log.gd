class_name DayLog
extends RefCounted

## What happened today, for the evening meal (EveningManager): money in and
## out, what was harvested and picked up, the orders delivered, the
## friendships that grew, the tournament. Filled by FarmSimulation as things
## happen, started afresh each morning. Not saved: the game is saved at
## bedtime, when a new day starts empty - and leaving mid-day goes back to
## that empty morning.

var earned := 0
var spent := 0
## item_id -> quantity: crops and fruit harvested, tufts cut for the
## neighbours (their seed rice), products picked up (eggs).
var harvested: Dictionary = {}
var products: Dictionary = {}
var neighbour_tufts := 0
## Villager ids, in delivery order.
var orders_delivered: Array[String] = []
## villager_id -> friendship points gained today, and -> hearts reached
## today (only the ones who got a new heart).
var friendship: Dictionary = {}
var new_hearts: Dictionary = {}
## The Sunday tournament, if entered: {"bouts", "wins"}.
var cockfight: Dictionary = {}
var school_paid := 0
## recipe_id -> dishes cooked today in the kitchen.
var cooked: Dictionary = {}
## The notebook's new pages today (discovery ids).
var discoveries: Array[String] = []
## Side quests finished today (quest ids).
var quests_done: Array[String] = []
## Chicken thieves: the rumour started this morning; overnight, a hen taken,
## or the padlock held.
var thief_rumour := false
var chicken_stolen := false
var thieves_foiled := false
## Overnight, the dog barked the thieves away (it had eaten: it kept watch).
var dog_chased_thieves := false

func add_harvest(item_id: String, quantity: int) -> void:
	harvested[item_id] = int(harvested.get(item_id, 0)) + quantity

func add_product(item_id: String, quantity: int) -> void:
	products[item_id] = int(products.get(item_id, 0)) + quantity

func add_money(delta: int) -> void:
	if delta > 0:
		earned += delta
	else:
		spent -= delta

## The item harvested the most today ("" if nothing was).
func get_main_harvest() -> String:
	var best := ""
	for item_id: String in harvested:
		if best.is_empty() or harvested[item_id] > harvested[best]:
			best = item_id
	return best

func is_quiet() -> bool:
	return earned == 0 and spent == 0 and harvested.is_empty() and products.is_empty() \
		and orders_delivered.is_empty() and new_hearts.is_empty() and cockfight.is_empty() \
		and neighbour_tufts == 0 and cooked.is_empty() and discoveries.is_empty() \
		and quests_done.is_empty() and not chicken_stolen and not thieves_foiled \
		and not dog_chased_thieves
