class_name FriendshipRules
extends SimRules

## Friendship with each villager: points, hearts and their gifts - and what
## each gesture is worth.
## A part of FarmSimulation (SimRules): simulation.friendship.

## Friendship with each villager: points, FRIENDSHIP_PER_HEART a heart, up
## to FRIENDSHIP_MAX_HEARTS. Earned by talking to them (once a day), by
## delivering their orders, and - for the farmers - by helping with the
## neighbours' harvest. Never lost. Each heart: a gift at some levels
## (VillagerData.friendship_rewards) and a better price on their orders
## (OrderRules.ORDER_BONUS_PER_HEART).
const FRIENDSHIP_PER_HEART := 100
const FRIENDSHIP_MAX_HEARTS := 5
const FRIENDSHIP_TALK := 10
const FRIENDSHIP_ORDER := 60
const FRIENDSHIP_HARVEST_HELP := 5
const FRIENDSHIP_COCKFIGHT := 15
## Friendship with every rooster owner when the player's rooster is the
## season's best.
const FRIENDSHIP_CHAMPION := 40

var _friendship_rewards: Dictionary = {} # villager_id: String -> Array[FriendshipReward]

## Registered by FriendshipManager for every villager (their VillagerData
## file's name and its gifts).
func register_friend(villager_id: String, rewards: Array[FriendshipReward]) -> void:
	_friendship_rewards[villager_id] = rewards

func get_friendship(villager_id: String) -> int:
	return state.friendship.get(villager_id, 0)

func get_hearts(villager_id: String) -> int:
	return mini(get_friendship(villager_id) / FRIENDSHIP_PER_HEART, FRIENDSHIP_MAX_HEARTS)

## Progress towards the next heart, 0..1 (1 at the most hearts).
func get_heart_progress(villager_id: String) -> float:
	if get_hearts(villager_id) >= FRIENDSHIP_MAX_HEARTS:
		return 1.0
	return float(get_friendship(villager_id) % FRIENDSHIP_PER_HEART) / FRIENDSHIP_PER_HEART

## Adds friendship points; each heart reached gives its gift (if any).
func add_friendship(villager_id: String, points: int) -> void:
	if points <= 0:
		return
	var before := get_hearts(villager_id)
	var cap := FRIENDSHIP_PER_HEART * FRIENDSHIP_MAX_HEARTS
	var gained := mini(get_friendship(villager_id) + points, cap) - get_friendship(villager_id)
	state.friendship[villager_id] = get_friendship(villager_id) + gained
	day_log.friendship[villager_id] = int(day_log.friendship.get(villager_id, 0)) + gained
	var after := get_hearts(villager_id)
	if after > before:
		day_log.new_hearts[villager_id] = after
	sim.friendship_changed.emit(villager_id, after)
	for hearts in range(before + 1, after + 1):
		var reward := _friendship_reward(villager_id, hearts)
		if reward != null:
			sim.add_item(reward.item_id, reward.quantity)
		sim.friendship_level_up.emit(villager_id, hearts, reward)

## Talking to a villager: friendship once a day. Returns whether it counted.
func talk_to(villager_id: String) -> bool:
	if state.friendship_talk_day.get(villager_id, 0) == state.day:
		return false
	state.friendship_talk_day[villager_id] = state.day
	add_friendship(villager_id, FRIENDSHIP_TALK)
	return true

func _friendship_reward(villager_id: String, hearts: int) -> FriendshipReward:
	for reward: FriendshipReward in _friendship_rewards.get(villager_id, []):
		if reward != null and reward.hearts == hearts:
			return reward
	return null
