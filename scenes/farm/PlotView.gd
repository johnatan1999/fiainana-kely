class_name PlotView
extends Node2D

const CELL_SIZE := 64.0

const COLOR_UNTILLED := Color(0.35, 0.55, 0.25)
const COLOR_TILLED := Color(0.45, 0.3, 0.15)
const COLOR_WATERED := Color(0.25, 0.18, 0.1)

const COLOR_SEED := Color(0.6, 0.5, 0.2)
const COLOR_SPROUT := Color(0.55, 0.8, 0.35)
const COLOR_GROWING := Color(0.3, 0.6, 0.25)
const COLOR_MATURE := Color(0.95, 0.75, 0.1)

@onready var soil: ColorRect = $Soil
@onready var crop: ColorRect = $Crop

func update_view(plot: PlotState) -> void:
	if plot.watered:
		soil.color = COLOR_WATERED
	elif plot.tilled:
		soil.color = COLOR_TILLED
	else:
		soil.color = COLOR_UNTILLED

	if plot.crop == null:
		crop.visible = false
		return

	crop.visible = true
	match plot.crop.get_stage():
		CropState.Stage.MATURE:
			crop.color = COLOR_MATURE
			crop.size = Vector2(44, 44)
		CropState.Stage.GROWING:
			crop.color = COLOR_GROWING
			crop.size = Vector2(34, 34)
		CropState.Stage.SPROUT:
			crop.color = COLOR_SPROUT
			crop.size = Vector2(24, 24)
		CropState.Stage.SEED:
			crop.color = COLOR_SEED
			crop.size = Vector2(14, 14)
	crop.position = (Vector2(CELL_SIZE, CELL_SIZE) - crop.size) / 2.0
