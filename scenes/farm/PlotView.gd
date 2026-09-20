class_name PlotView
extends Node2D

const CELL_SIZE := 64.0

const COLOR_SEED := Color(0.6, 0.5, 0.2)
const COLOR_SPROUT := Color(0.55, 0.8, 0.35)
const COLOR_GROWING := Color(0.3, 0.6, 0.25)
const COLOR_MATURE := Color(0.95, 0.75, 0.1)

@onready var crop_placeholder: ColorRect = $Crop
@onready var crop_sprite: TextureRect = $CropSprite

## crop_data is null when the plot is empty, or briefly while a crop_id
## isn't in the registry (shouldn't happen, but PlotView stays defensive
## rather than crash the whole farm view over one bad plot). Soil itself is
## drawn by FarmView's shared TileMapLayer, not here.
func update_view(plot: PlotState, crop_data: CropData) -> void:
	if plot.crop == null:
		crop_placeholder.visible = false
		crop_sprite.visible = false
		return

	var stage := plot.crop.get_stage()
	var stage_texture := _get_stage_specific_texture(crop_data, stage)

	if stage_texture != null:
		crop_sprite.texture = stage_texture
		crop_sprite.visible = true
		crop_placeholder.visible = false
		_layout_sprite(_get_stage_specific_scale(crop_data, stage))
	elif crop_data != null and crop_data.icon != null:
		# Only one generic sprite for the whole crop - fake growth by scaling
		# it up as the stage advances.
		crop_sprite.texture = crop_data.icon
		crop_sprite.visible = true
		crop_placeholder.visible = false
		_layout_sprite(_stage_scale(stage))
	else:
		# No art at all yet for this crop - original placeholder behavior,
		# unchanged.
		crop_sprite.visible = false
		crop_placeholder.visible = true
		_layout_placeholder(stage)

func _get_stage_specific_texture(crop_data: CropData, stage: CropState.Stage) -> Texture2D:
	if crop_data == null:
		return null
	match stage:
		CropState.Stage.SEED:
			return crop_data.sprite_seed
		CropState.Stage.SPROUT:
			return crop_data.sprite_sprout
		CropState.Stage.GROWING:
			return crop_data.sprite_growing
		CropState.Stage.MATURE:
			return crop_data.sprite_mature
	return null

func _get_stage_specific_scale(crop_data: CropData, stage: CropState.Stage) -> float:
	match stage:
		CropState.Stage.SEED:
			return crop_data.sprite_seed_scale
		CropState.Stage.SPROUT:
			return crop_data.sprite_sprout_scale
		CropState.Stage.GROWING:
			return crop_data.sprite_growing_scale
		CropState.Stage.MATURE:
			return crop_data.sprite_mature_scale
	return 1.0

## Fallback scaling used only when a crop has no dedicated per-stage art -
## _get_stage_specific_scale() above is used instead once art exists.
func _stage_scale(stage: CropState.Stage) -> float:
	match stage:
		CropState.Stage.MATURE:
			return 1.0
		CropState.Stage.GROWING:
			return 0.75
		CropState.Stage.SPROUT:
			return 0.5
		_:
			return 0.3

func _layout_sprite(scale_factor: float) -> void:
	var size := Vector2(CELL_SIZE, CELL_SIZE) * scale_factor
	crop_sprite.size = size
	crop_sprite.position = (Vector2(CELL_SIZE, CELL_SIZE) - size) / 2.0

func _layout_placeholder(stage: CropState.Stage) -> void:
	match stage:
		CropState.Stage.MATURE:
			crop_placeholder.color = COLOR_MATURE
			crop_placeholder.size = Vector2(44, 44)
		CropState.Stage.GROWING:
			crop_placeholder.color = COLOR_GROWING
			crop_placeholder.size = Vector2(34, 34)
		CropState.Stage.SPROUT:
			crop_placeholder.color = COLOR_SPROUT
			crop_placeholder.size = Vector2(24, 24)
		CropState.Stage.SEED:
			crop_placeholder.color = COLOR_SEED
			crop_placeholder.size = Vector2(14, 14)
	crop_placeholder.position = (Vector2(CELL_SIZE, CELL_SIZE) - crop_placeholder.size) / 2.0
