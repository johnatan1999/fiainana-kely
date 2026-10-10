class_name PlotState
extends RefCounted

var tilled: bool = false
var watered: bool = false
var crop: CropState = null
## Paddy plot (a FarmField with `flooded`): always irrigated - it never needs
## watering - and only takes crops that grow in paddies (CropData.grows_in_paddy).
## A property of the land, not of what's growing: reset() keeps it.
var flooded: bool = false
## Zebu manure spread on it (FieldRules.fertilize): the next harvest
## here is bigger, and uses it up.
var fertilized: bool = false

## Vision only for now: meant to fall with monoculture and recover with
## rotation/fallow. Not yet consumed by FarmSimulation.
var soil_fertility: float = 1.0

func is_empty() -> bool:
	return crop == null

## Clears the plot back to empty/untilled without removing it from the grid -
## used by FieldRules.clear_tile() when reorganizing without changing shape.
func reset() -> void:
	tilled = false
	watered = false
	crop = null
	fertilized = false
	soil_fertility = 1.0
