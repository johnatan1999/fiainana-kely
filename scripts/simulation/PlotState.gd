class_name PlotState
extends RefCounted

var tilled: bool = false
var watered: bool = false
var crop: CropState = null

## Vision only for now: meant to fall with monoculture and recover with
## rotation/fallow. Not yet consumed by FarmSimulation.
var soil_fertility: float = 1.0

func is_empty() -> bool:
	return crop == null
