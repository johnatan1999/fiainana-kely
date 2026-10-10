class_name Quest
extends Resource

## A side quest (fangatahana): a villager asks the player for help - a
## little story in steps (QuestStep), no deadline. One .tres per quest in
## data/quests/, its id the file's name. FarmSimulation holds the rules,
## QuestManager the world. See docs/quests.md.
##
## Offered by `giver` ("!" over their head) once its requirements are met;
## accepted, its steps follow one another; after the last, the reward.

const ALL_SEASONS := 3
const DIR := "res://data/quests/"

@export var title := ""
## Who asks (a villager id: "rakoto"...).
@export var giver := ""
## The story, as the giver tells it when offering the quest.
@export_multiline var offer_line := ""

@export_group("Requirements")
## Not before this day of the game.
@export var min_day := 1
## The player's friendship with the giver, in hearts.
@export_range(0, 5) var min_hearts := 0
## Quests to have finished first (ids) - a quest can follow another.
@export var after_quests: Array[String] = []
## Notebook pages to have found first (Discovery ids).
@export var after_discoveries: Array[String] = []
## The seasons it's offered in (bits of GameClock.Season).
@export_flags("Asara", "Asotry") var seasons := ALL_SEASONS

@export_group("Steps")
@export var steps: Array[QuestStep] = []

@export_group("Reward")
@export var reward_money := 0
## item id -> quantity.
@export var reward_items: Dictionary = {}
## Friendship points with the giver (FriendshipRules.FRIENDSHIP_PER_HEART: a
## heart).
@export var reward_friendship := 0
## Something it gives the farm, beyond items: "dog" (FarmSimulation's
## _unlock). And how the reward says it ("un chiot").
@export var reward_unlock := ""
@export var reward_unlock_label := ""
## Told at dinner, the evening it's finished, by `evening_speaker` (a
## family id: "father", "mother", "fara"). Empty: nothing.
@export var evening_speaker := "father"
@export_multiline var evening_line := ""

static func load_all() -> Dictionary:
	return ResourceDir.load_all(DIR, Quest)

func is_in_season(season: int) -> bool:
	return seasons & (1 << season) != 0
