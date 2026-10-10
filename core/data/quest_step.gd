class_name QuestStep
extends Resource

## One step of a side quest (Quest.steps), done in order. What it asks
## (`kind`):
## - TALK: talk to `villager`;
## - BRING: give `quantity` of `item_id` to `villager` (taken from the bag);
## - REACH: walk to the QuestTarget `target` (its area);
## - INTERACT: use the QuestTarget `target` - with `item_id` set, it needs
##   `quantity` of it, and uses them;
## - DISCOVER: have `discovery_id` in the notebook (done at once if it
##   already is).
## Texts in French (tr()). See docs/quests.md.

enum Kind { TALK, BRING, REACH, INTERACT, DISCOVER }

@export var kind := Kind.TALK
## What to do next, in the quests tracker ("Retrouve Volamena du côté du
## vieil amontana.").
@export_multiline var objective := ""
## TALK / BRING: who (a villager id: "rakoto"...).
@export var villager := ""
## REACH / INTERACT: which QuestTarget (its target_id, in some zone).
@export var target := ""
## BRING, INTERACT: the item needed, and how many.
@export var item_id := ""
@export var quantity := 1
## DISCOVER: the notebook page needed.
@export var discovery_id := ""
## The action shown on the villager or the target ("Donner des brèdes à
## Volamena"). Empty: a default one.
@export var prompt := ""
## Said once it's done - by the villager (TALK, BRING), else told to the
## player.
@export_multiline var line := ""
## INTERACT / BRING tried without the items.
@export_multiline var waiting_line := ""

## Whether it takes items.
func needs_items() -> bool:
	return not item_id.is_empty() and kind in [Kind.BRING, Kind.INTERACT]
