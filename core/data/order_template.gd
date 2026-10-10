class_name OrderTemplate
extends Resource

## One kind of order a villager may give (VillagerData.orders): `quantity`
## of `item_id`, to deliver within `days` once accepted, paid `unit_reward`
## each - set above the item's sell price, it's what makes an order worth
## more than the shop. FarmSimulation only offers it when the player can
## actually get the items in time (see OrderRules.can_fulfil()).

## A crop id ("cassava"...) or an item id ("egg", "mango").
@export var item_id := ""
## Picked at random in this range (x..y) when the order is offered.
@export var quantity := Vector2i(3, 5)
## Ariary per item delivered.
@export var unit_reward := 1000
## Days to deliver, from the day it's accepted (that day included).
@export var days := 5
## What the villager says, in French (tr()), the item named in the line
## ("... %d racines de manioc ?") - %d is the quantity. Empty: a generic
## line.
@export_multiline var request_line := ""
@export var thanks_line := ""
