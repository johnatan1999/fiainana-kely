class_name CropData
extends Resource

## Static definition of one crop. Runtime state (age, watering history) lives
## in CropState - this Resource never changes once loaded.

enum Category { VIVRIER, RENTE, EXPORT }
enum Season { ASARA, ASOTRY, TOUTE_SAISON }
enum WaterNeed { LOW, MEDIUM, HIGH }

@export var id: String
@export var display_name: String
@export var malagasy_name: String = ""
## Name of this crop's seed item, in French (a translation key, see
## localization/translations.csv). Written per crop rather than composed
## from display_name, because each language builds it differently
## ("Graine d'arachide", "Voam-bary", "Rice seed"). Empty = the generic
## "Graine de %s" template.
@export var seed_display_name: String = ""
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

## Shown in the Shop/Inventory.
@export var icon: Texture2D

## In-field look: a CropVisual scene (see entities/crops/crop_visual.gd) with
## one child per growth stage, each placed visually in the editor relative
## to the plot cell's bottom-center, and carrying its own collision if the
## crop should block the player at that stage. Unset = PlotView shows its
## placeholder colored square.
@export var visual_scene: PackedScene
