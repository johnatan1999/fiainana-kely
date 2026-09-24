class_name CropData
extends Resource

## Static definition of one crop. Runtime state (age, watering history) lives
## in CropState - this Resource never changes once loaded.

enum Category { VIVRIER, RENTE, EXPORT }
enum Season { ASARA, ASOTRY, TOUTE_SAISON }
enum WaterNeed { LOW, MEDIUM, HIGH }

## Which point of the plot cell the in-field sprite is pinned to.
## CENTER = sprite centered in the cell (good for flat/round crops).
## BOTTOM = sprite's bottom edge sits on the cell's bottom edge and it grows
## upward, overflowing the tile above (good for tall crops like corn).
enum SpriteAnchor { CENTER, BOTTOM }

@export var id: String
@export var display_name: String
@export var malagasy_name: String = ""
@export var category: Category = Category.VIVRIER
@export var tier: int = 1

@export var seed_price: int = 0
@export var sell_price: int = 0

@export var growth_days: int = 1
@export var yield_min: int = 1
@export var yield_max: int = 1

@export var ideal_season: Season = Season.TOUTE_SAISON
## Multiplier applied to the harvested quantity when harvested outside ideal_season.
@export var off_season_yield_multiplier: float = 0.6

@export var water_need: WaterNeed = WaterNeed.MEDIUM
## Minimum CropState.get_watered_ratio() required to avoid the quality penalty at harvest.
@export var min_watered_ratio_for_quality: float = 0.75

## Vision only for now: perennial crops (coffee/clove/vanilla) should eventually
## survive harvest instead of clearing the plot. Not yet consumed by FarmSimulation.
@export var is_perennial: bool = false

## Day (FarmState.day) from which this crop can be bought in the shop. 0 = always available.
@export var unlock_day: int = 0

## Shown in the Shop/Inventory. Also used as a generic in-field sprite
## (scaled by growth stage) for crops that don't have dedicated per-stage art.
@export var icon: Texture2D

## Optional dedicated in-field sprites for PlotView, one per CropState.Stage.
## Any left unset falls back to `icon` for that stage; if `icon` is also
## unset, PlotView falls back to its placeholder colored square. So a crop
## with zero art still renders exactly as before.
@export var sprite_seed: Texture2D
@export var sprite_sprout: Texture2D
@export var sprite_growing: Texture2D
@export var sprite_mature: Texture2D

## How much of the plot cell each dedicated stage sprite fills (aspect
## preserved, positioned per `sprite_anchor`). 1.0 = fills the cell. Tune
## per crop from the Inspector - a wide sprite sheet crop like corn's tiny
## seedling can look oversized at 1.0, so these default smaller for the
## early stages.
@export_range(0.1, 1.5, 0.05) var sprite_seed_scale: float = 0.4
@export_range(0.1, 1.5, 0.05) var sprite_sprout_scale: float = 0.55
@export_range(0.1, 1.5, 0.05) var sprite_growing_scale: float = 0.8
@export_range(0.1, 1.5, 0.05) var sprite_mature_scale: float = 1.0

@export_group("Placement")
## Applies to every stage (and to the `icon` fallback).
@export var sprite_anchor: SpriteAnchor = SpriteAnchor.CENTER
## Extra nudge in pixels, applied after the anchor, per stage. Positive x =
## right, positive y = down (e.g. y = -4 lifts the sprite 4px up).
@export var sprite_seed_offset: Vector2 = Vector2.ZERO
@export var sprite_sprout_offset: Vector2 = Vector2.ZERO
@export var sprite_growing_offset: Vector2 = Vector2.ZERO
@export var sprite_mature_offset: Vector2 = Vector2.ZERO

@export_group("Collision")
## When true, the crop gets a solid box at its base (the "foot" of the drawn
## sprite) - the part of the art above that box stays walk-through, and the
## player is y-sorted behind it when standing higher up the screen.
@export var blocks_movement: bool = false
## First growth stage that blocks (values match CropState.Stage) - seeds and
## sprouts usually shouldn't stop the player.
@export_enum("Seed", "Sprout", "Growing", "Mature") var collision_min_stage: int = 2
## Solid box size in pixels. Its bottom-center sits on the sprite's foot.
@export var collision_size: Vector2 = Vector2(16, 8)
## Extra nudge of the solid box in pixels (positive y = down).
@export var collision_offset: Vector2 = Vector2.ZERO
