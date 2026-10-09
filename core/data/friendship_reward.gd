class_name FriendshipReward
extends Resource

## A gift a villager gives the player once their friendship reaches
## `hearts` (VillagerData.friendship_rewards): `quantity` of `item_id`,
## with what they say (in French, tr()).

@export_range(1, 5) var hearts := 2
## A seed ("tomato_seed"), a crop, an item ("food_vary_amin_anana")...
@export var item_id := ""
@export var quantity := 1
@export var line := ""
