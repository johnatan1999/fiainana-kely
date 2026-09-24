class_name PlotView
extends Node2D

## Plot cell size in pixels - single source of truth, FarmView and
## PlotHighlight read it from here. Must match farm_tileset.tres tile_size
## (FarmView warns at _ready() if it doesn't).
const CELL_SIZE := 48.0
## PlotView's origin is the bottom-center of its cell (so FarmView's y-sort
## orders crops by where they touch the ground) - this is the cell's top-left
## relative to that origin.
const CELL_TOP_LEFT := Vector2(-CELL_SIZE / 2.0, -CELL_SIZE)

const COLOR_SEED := Color(0.6, 0.5, 0.2)
const COLOR_SPROUT := Color(0.55, 0.8, 0.35)
const COLOR_GROWING := Color(0.3, 0.6, 0.25)
const COLOR_MATURE := Color(0.95, 0.75, 0.1)

@onready var crop_placeholder: ColorRect = $Crop
@onready var crop_sprite: TextureRect = $CropSprite

## -1 sentinel = no crop yet, never matches a real CropState.Stage value -
## tracks the last stage actually rendered so update_view() (called on every
## plot_changed, including daily ticks where the stage didn't move) only
## pops when the crop genuinely advanced a stage, not on every watering.
var _last_stage: int = -1

## Solid box at the crop's base, driven by CropData's Collision group.
## Built in code rather than in plot_view.tscn so every PlotView gets its own
## RectangleShape2D (a shape saved in the .tscn would be shared by all plots).
var _blocker_shape: CollisionShape2D

func _ready() -> void:
	var blocker := StaticBody2D.new()
	blocker.collision_layer = 1 # "World, decors, map limit" - what the player collides with
	blocker.collision_mask = 0
	_blocker_shape = CollisionShape2D.new()
	_blocker_shape.shape = RectangleShape2D.new()
	_blocker_shape.disabled = true
	blocker.add_child(_blocker_shape)
	add_child(blocker)

## crop_data is null when the plot is empty, or briefly while a crop_id
## isn't in the registry (shouldn't happen, but PlotView stays defensive
## rather than crash the whole farm view over one bad plot). Soil itself is
## drawn by FarmView's shared TileMapLayer, not here.
func update_view(plot: PlotState, crop_data: CropData) -> void:
	if plot.crop == null:
		crop_placeholder.visible = false
		crop_sprite.visible = false
		_last_stage = -1
		_update_blocker(null, 0, Vector2.ZERO)
		return

	var stage := plot.crop.get_stage()
	var stage_changed := stage != _last_stage
	_last_stage = stage
	var stage_texture := _get_stage_specific_texture(crop_data, stage)

	if stage_texture != null:
		crop_sprite.texture = stage_texture
		crop_sprite.visible = true
		crop_placeholder.visible = false
		_layout_sprite(_get_stage_specific_scale(crop_data, stage), crop_data, stage)
		if stage_changed:
			_play_growth_pop(crop_sprite)
	elif crop_data != null and crop_data.icon != null:
		# Only one generic sprite for the whole crop - fake growth by scaling
		# it up as the stage advances.
		crop_sprite.texture = crop_data.icon
		crop_sprite.visible = true
		crop_placeholder.visible = false
		_layout_sprite(_stage_scale(stage), crop_data, stage)
		if stage_changed:
			_play_growth_pop(crop_sprite)
	else:
		# No art at all yet for this crop - original placeholder behavior,
		# unchanged.
		crop_sprite.visible = false
		crop_placeholder.visible = true
		_layout_placeholder(stage)
		if stage_changed:
			_play_growth_pop(crop_placeholder)

	var shown: Control = crop_sprite if crop_sprite.visible else crop_placeholder
	_update_blocker(crop_data, stage, shown.position + Vector2(shown.size.x / 2.0, shown.size.y))

## `foot` is the bottom-center of the drawn crop, in PlotView-local pixels.
## Deferred because plot_changed can fire mid physics step (e.g. during a
## save load), where toggling a shape directly is not allowed.
func _update_blocker(crop_data: CropData, stage: int, foot: Vector2) -> void:
	var blocks := crop_data != null and crop_data.blocks_movement and stage >= crop_data.collision_min_stage
	_blocker_shape.set_deferred("disabled", not blocks)
	if not blocks:
		return
	var box := crop_data.collision_size
	(_blocker_shape.shape as RectangleShape2D).size = box
	_blocker_shape.position = foot - Vector2(0, box.y / 2.0) + crop_data.collision_offset

## Quick overshoot-then-settle scale bounce whenever a crop advances to a new
## growth stage (including first appearing as a seed) - nothing plays on a
## plot_changed that doesn't actually move the stage (e.g. watering, or the
## daily tick for an already-mature crop), so it never feels spammy.
## Scales around node.pivot_offset, which the _layout_*() functions set to the
## anchor point (so BOTTOM crops sprout up from the ground).
func _play_growth_pop(node: Control) -> void:
	node.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2.ONE, 0.35)

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

func _get_stage_specific_offset(crop_data: CropData, stage: CropState.Stage) -> Vector2:
	match stage:
		CropState.Stage.SEED:
			return crop_data.sprite_seed_offset
		CropState.Stage.SPROUT:
			return crop_data.sprite_sprout_offset
		CropState.Stage.GROWING:
			return crop_data.sprite_growing_offset
		CropState.Stage.MATURE:
			return crop_data.sprite_mature_offset
	return Vector2.ZERO

## Fits the texture (aspect preserved) inside a square of CELL_SIZE *
## scale_factor, then pins it to the cell per crop_data.sprite_anchor and
## nudges it by the stage's pixel offset. The rect is sized to the drawn
## texture exactly, so BOTTOM really means the art touches the cell bottom.
func _layout_sprite(scale_factor: float, crop_data: CropData, stage: CropState.Stage) -> void:
	var box := CELL_SIZE * scale_factor
	var tex_size := crop_sprite.texture.get_size()
	var size := tex_size * minf(box / tex_size.x, box / tex_size.y)
	crop_sprite.size = size
	var anchor := crop_data.sprite_anchor
	crop_sprite.position = _anchored_position(size, anchor) + _get_stage_specific_offset(crop_data, stage)
	crop_sprite.pivot_offset = _anchor_pivot(size, anchor)

func _anchored_position(size: Vector2, anchor: CropData.SpriteAnchor) -> Vector2:
	var cell := Vector2(CELL_SIZE, CELL_SIZE)
	if anchor == CropData.SpriteAnchor.BOTTOM:
		return CELL_TOP_LEFT + Vector2((cell.x - size.x) / 2.0, cell.y - size.y)
	return CELL_TOP_LEFT + (cell - size) / 2.0

func _anchor_pivot(size: Vector2, anchor: CropData.SpriteAnchor) -> Vector2:
	if anchor == CropData.SpriteAnchor.BOTTOM:
		return Vector2(size.x / 2.0, size.y)
	return size / 2.0

func _layout_placeholder(stage: CropState.Stage) -> void:
	match stage:
		CropState.Stage.MATURE:
			crop_placeholder.color = COLOR_MATURE
			crop_placeholder.size = Vector2.ONE * CELL_SIZE * 0.7
		CropState.Stage.GROWING:
			crop_placeholder.color = COLOR_GROWING
			crop_placeholder.size = Vector2.ONE * CELL_SIZE * 0.55
		CropState.Stage.SPROUT:
			crop_placeholder.color = COLOR_SPROUT
			crop_placeholder.size = Vector2.ONE * CELL_SIZE * 0.375
		CropState.Stage.SEED:
			crop_placeholder.color = COLOR_SEED
			crop_placeholder.size = Vector2.ONE * CELL_SIZE * 0.22
	crop_placeholder.position = CELL_TOP_LEFT + (Vector2(CELL_SIZE, CELL_SIZE) - crop_placeholder.size) / 2.0
	crop_placeholder.pivot_offset = crop_placeholder.size / 2.0
