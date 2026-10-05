@tool
class_name TreeData
extends Resource

## Static definition of one kind of tree (mango, litchi, decorative...).
## Runtime state (fruit ripeness) lives in TreeState - this Resource never
## changes once loaded. A WorldTree placed in a zone scene points at one of
## these; FarmSimulation reads them through its tree registry (see World.gd
## TREE_RESOURCES), so a new species is a new .tres, not new code.
##
## @tool so the editor sees its real values and methods: WorldTree previews
## the species there, and a non-tool script's resource is only a placeholder
## in the editor.

@export var id: String
@export var display_name: String
@export var malagasy_name: String = ""

## How it looks: a TreeVisual scene (see entities/trees/tree_visual.gd) with
## its sprites per state, trunk collision and foliage fade area, placed in
## the editor relative to the foot of the trunk. Unset = WorldTree shows a
## placeholder tree with no collision.
@export var visual_scene: PackedScene

@export_group("Fruits")
## Item added to the inventory on harvest. Empty = decorative tree: never
## registered in the simulation, not interactable.
@export var fruit_item_id: String = ""
## Days in season for a new batch of fruit to ripen after a harvest.
@export var fruit_cycle_days: int = 4
@export var yield_min: int = 2
@export var yield_max: int = 4
## Fruits only grow in this season; unpicked fruit rots when it ends.
## Same enum as crops, so both follow the GameClock seasons the same way.
@export var fruit_season: CropData.Season = CropData.Season.TOUTE_SAISON

func bears_fruit() -> bool:
	return fruit_item_id != ""

func is_in_season(season: GameClock.Season) -> bool:
	return fruit_season == CropData.Season.TOUTE_SAISON or int(fruit_season) == int(season)
