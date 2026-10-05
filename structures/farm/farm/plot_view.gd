class_name PlotView
extends Node2D

## Plot cell size in pixels - single source of truth, FarmView, PlotHighlight
## and CropVisual read it from here. Must match farm_tileset.tres tile_size
## (FarmView warns at _ready() if it doesn't).
const CELL_SIZE := 48.0
## PlotView's origin is the bottom-center of its cell (so FarmView's y-sort
## orders crops by where they touch the ground) - this is the cell's top-left
## relative to that origin. CropVisual scenes share the same origin.
const CELL_TOP_LEFT := Vector2(-CELL_SIZE / 2.0, -CELL_SIZE)

const COLOR_SEED := Color(0.6, 0.5, 0.2)
const COLOR_SPROUT := Color(0.55, 0.8, 0.35)
const COLOR_GROWING := Color(0.3, 0.6, 0.25)
const COLOR_MATURE := Color(0.95, 0.75, 0.1)

## Action feedback (react()).
const DIRT_PUFF_COLOR := Color(0.45, 0.3, 0.18)
const WATER_PUFF_COLOR := Color(0.55, 0.78, 1.0)
const PLUCK_DURATION := 0.28

@onready var crop_placeholder: ColorRect = $Crop

## -1 sentinel = no crop yet, never matches a real CropState.Stage value -
## tracks the last stage actually rendered so update_view() (called on every
## plot_changed, including daily ticks where the stage didn't move) only
## pops when the crop genuinely advanced a stage, not on every watering.
var _last_stage: int = -1
## Instance of the current crop's CropData.visual_scene, or null (empty plot,
## or a crop without a visual scene yet).
var _visual: CropVisual
var _visual_scene: PackedScene
## What currently shows the crop: a CropVisual stage node or the placeholder.
var _crop_node: CanvasItem
## Set by react(HARVEST): the next update_view() without a crop plucks the
## old one out instead of just removing it.
var _harvesting := false
var _reaction_tween: Tween

## crop_data is null when the plot is empty, or briefly while a crop_id
## isn't in the registry (shouldn't happen, but PlotView stays defensive
## rather than crash the whole farm view over one bad plot). Soil itself is
## drawn by the FarmField the plot belongs to, not here.
func update_view(plot: PlotState, crop_data: CropData) -> void:
	if plot.crop == null:
		if _harvesting and _visual != null:
			_pluck_out(_visual)
			_visual = null
			_visual_scene = null
		_harvesting = false
		crop_placeholder.visible = false
		_set_visual_scene(null)
		_crop_node = null
		_last_stage = -1
		return
	_harvesting = false

	var stage := plot.crop.get_stage()
	var stage_changed := stage != _last_stage
	_last_stage = stage

	_set_visual_scene(crop_data.visual_scene if crop_data != null else null)
	var stage_node: Node2D = _visual.show_stage(stage) if _visual != null else null
	if stage_node != null:
		crop_placeholder.visible = false
		_crop_node = stage_node
	else:
		# No art yet for this crop (or this stage) - colored square placeholder.
		crop_placeholder.visible = true
		_layout_placeholder(stage)
		_crop_node = crop_placeholder
	if stage_changed:
		_play_growth_pop(_crop_node)

## Feedback for a farming action that just succeeded here (FarmingController
## via FarmView). Presentation only - the simulation already changed. Call
## it for HARVEST *before* the harvest itself, so the crop gets plucked out
## rather than just disappearing.
func react(action: FarmAction.Type) -> void:
	match action:
		FarmAction.Type.TILL, FarmAction.Type.PLANT:
			# A planted seed also pops in, through its new growth stage.
			_puff(DIRT_PUFF_COLOR, 8, 90.0)
		FarmAction.Type.WATER:
			_puff(WATER_PUFF_COLOR, 7, 70.0)
			_squash(_crop_node)
		FarmAction.Type.HARVEST:
			_harvesting = true

## Squash then stretch then settle, from the foot - a crop that just drank.
func _squash(node: CanvasItem) -> void:
	if node == null:
		return
	if _reaction_tween:
		_reaction_tween.kill()
	_reaction_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_reaction_tween.tween_property(node, "scale", Vector2(1.15, 0.85), 0.07)
	_reaction_tween.tween_property(node, "scale", Vector2(0.93, 1.1), 0.1)
	_reaction_tween.tween_property(node, "scale", Vector2.ONE, 0.12)

## The harvested crop jumps up out of the ground, stretched, and fades.
## `visual` is no longer this plot's crop - it frees itself when done.
func _pluck_out(visual: CropVisual) -> void:
	var tween := visual.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual, "position:y", visual.position.y - 14.0, PLUCK_DURATION)
	tween.tween_property(visual, "scale", Vector2(0.8, 1.25), PLUCK_DURATION)
	tween.tween_property(visual, "modulate:a", 0.0, PLUCK_DURATION).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(visual.queue_free)
	_puff(DIRT_PUFF_COLOR, 6, 70.0)

## A small burst of bits from the middle of the cell, then freed.
func _puff(color: Color, amount: int, speed: float) -> void:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.amount = amount
	puff.lifetime = 0.4
	puff.position = Vector2(0, -CELL_SIZE * 0.35)
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	puff.emission_rect_extents = Vector2(CELL_SIZE * 0.3, CELL_SIZE * 0.15)
	puff.direction = Vector2.UP
	puff.spread = 60.0
	puff.gravity = Vector2(0, 300)
	puff.initial_velocity_min = speed * 0.6
	puff.initial_velocity_max = speed
	puff.scale_amount_min = 1.5
	puff.scale_amount_max = 3.0
	puff.color = color
	puff.z_index = 1
	puff.finished.connect(puff.queue_free)
	add_child(puff)
	puff.emitting = true

## Swaps the instanced CropVisual only when the scene actually changes (a new
## crop planted), not on every update_view().
func _set_visual_scene(scene: PackedScene) -> void:
	if scene == _visual_scene:
		return
	if _visual != null:
		_visual.queue_free()
		_visual = null
	_visual_scene = scene
	if scene != null:
		_visual = scene.instantiate() as CropVisual
		if _visual == null:
			push_error("PlotView: visual_scene %s has no CropVisual root" % scene.resource_path)
			return
		add_child(_visual)

## Quick overshoot-then-settle scale bounce whenever a crop advances to a new
## growth stage (including first appearing as a seed) - nothing plays on a
## plot_changed that doesn't actually move the stage (e.g. watering, or the
## daily tick for an already-mature crop), so it never feels spammy.
## Scales around the node's own origin/pivot - the foot for CropVisual stages,
## so crops sprout up from the ground. `node` is a Node2D or a Control.
func _play_growth_pop(node: CanvasItem) -> void:
	node.set("scale", Vector2(0.3, 0.3))
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2.ONE, 0.35)

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
