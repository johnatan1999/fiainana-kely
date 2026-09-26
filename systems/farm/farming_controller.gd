class_name FarmingController
extends Node

## Translates player interactions into FarmSimulation commands.
## Holds no farming rules itself - it only decides *which* simulation call to make.

const DEFAULT_CROP_ID := "corn"
## Where the player's feet end up when stepping up to a plot: this many
## pixels outside the plot's edge on their side.
const APPROACH_GAP := 6.0
## Gives up stepping up after this long (path blocked, e.g. by a solid crop)
## and acts from wherever the player got to.
const APPROACH_MAX_DURATION := 0.5

## Fired whenever the crop the SEEDS tool will plant changes, so HUD can relabel itself.
signal crop_selected(crop_id: String)

var simulation: FarmSimulation
var player: PlayerController
var farm_view: FarmView # null while the player is outside the farm zone
var selected_crop_id: String = DEFAULT_CROP_ID
## Set by _on_interact_requested() for HARVEST, consumed by
## _on_action_animation_finished() - -1 means no harvest is pending.
var _pending_harvest_plot_id := -1

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_world_manager: WorldManager) -> void:
	simulation = p_simulation
	player = p_player
	player.interact_requested.connect(_on_interact_requested)
	player.action_animation_finished.connect(_on_action_animation_finished)
	p_world_manager.zone_loaded.connect(_on_zone_loaded)
	p_world_manager.zone_unloading.connect(_on_zone_unloading)

func set_farm_view(p_farm_view: FarmView) -> void:
	farm_view = p_farm_view

## Keeps the "which plot will interact() affect" outline live - same
## _get_target_plot_id() that _on_interact_requested() uses below.
func _process(_delta: float) -> void:
	if farm_view:
		var plot_id := _get_target_plot_id()
		farm_view.show_highlight_for_plot(plot_id, plot_id != -1 and _can_use_tool(player.current_tool, plot_id))

## The plot in the cell right in front of the player (see
## FarmView.get_plot_id_in_front_of), or -1.
func _get_target_plot_id() -> int:
	return farm_view.get_plot_id_in_front_of(player.global_position, player.last_facing_direction)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	var found: FarmView = zone.get_node_or_null("FarmView")
	if found:
		found.setup(simulation)
		set_farm_view(found)

func _on_zone_unloading(_zone: ZoneRoot) -> void:
	set_farm_view(null)

func advance_day() -> void:
	simulation.advance_day()

## Kept out of the project's InputMap - see PlayerController.NUMBER_KEY_TOOLS
## for why raw keycodes are used here instead.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_cycle_selected_crop()
		get_viewport().set_input_as_handled()

## Cycles through the crops the player currently holds seeds for. Crops with
## zero seeds in inventory are skipped since planting them would just fail.
func _cycle_selected_crop() -> void:
	var owned_ids := _get_ownable_crop_ids()
	if owned_ids.is_empty():
		return
	var current_index := owned_ids.find(selected_crop_id)
	var next_index := (current_index + 1) % owned_ids.size()
	selected_crop_id = owned_ids[next_index]
	AudioManager.play_interact_sfx()
	crop_selected.emit(selected_crop_id)

func _get_ownable_crop_ids() -> Array:
	var result: Array = []
	for crop_id in simulation.get_all_crop_ids():
		if simulation.state.get_inventory_count(crop_id + "_seed") > 0:
			result.append(crop_id)
	return result

## Tool animations only play once the underlying action is confirmed
## possible - swinging the hoe on unplowable ground, or the sickle on a plot
## with nothing ready to harvest, does nothing and plays nothing (and the
## player doesn't step up to the plot for nothing either) - just the denied
## sound, matching the red highlight shown on that plot.
func _on_interact_requested(tool: PlayerController.Tool) -> void:
	if farm_view == null or player.is_auto_walking():
		return
	var plot_id := _get_target_plot_id()
	if plot_id == -1:
		return
	if not _can_use_tool(tool, plot_id):
		AudioManager.play_action_denied_sfx()
		return
	await _approach_plot(plot_id)
	if farm_view == null: # zone changed while walking
		return
	match tool:
		PlayerController.Tool.HOE:
			if simulation.till(plot_id):
				AudioManager.play_till_sfx()
				player.play_tool_animation(tool)
		PlayerController.Tool.WATERING_CAN:
			if simulation.water(plot_id):
				AudioManager.play_watering_sfx()
				player.play_tool_animation(tool)
		PlayerController.Tool.SEEDS:
			if simulation.plant(plot_id, selected_crop_id):
				AudioManager.play_plant_sfx()
				player.play_tool_animation(tool)
		PlayerController.Tool.HARVEST:
			# The actual harvest() call is applied in
			# _on_action_animation_finished() instead of right here, so the
			# crop sprite only disappears once the harvest swing animation
			# actually completes, not the instant E is pressed. can_harvest()
			# is the read-only check that gates whether the swing plays at all.
			if simulation.can_harvest(plot_id):
				_pending_harvest_plot_id = plot_id
				player.play_tool_animation(tool)

func _can_use_tool(tool: PlayerController.Tool, plot_id: int) -> bool:
	match tool:
		PlayerController.Tool.HOE:
			return simulation.can_till(plot_id)
		PlayerController.Tool.WATERING_CAN:
			return simulation.can_water(plot_id)
		PlayerController.Tool.SEEDS:
			return simulation.can_plant(plot_id, selected_crop_id)
		PlayerController.Tool.HARVEST:
			return simulation.can_harvest(plot_id)
	return false

## If the player stands at the far side of their own cell, walks them forward
## (along the facing axis only - never sideways or backwards) until their
## feet are just outside the plot, so the tool visibly reaches it.
func _approach_plot(plot_id: int) -> void:
	var step := FarmView.facing_step(player.last_facing_direction)
	var rect := farm_view.get_plot_global_rect(plot_id)
	var stand := player.global_position
	if step.x > 0:
		stand.x = maxf(stand.x, rect.position.x - APPROACH_GAP)
	elif step.x < 0:
		stand.x = minf(stand.x, rect.end.x + APPROACH_GAP)
	elif step.y > 0:
		stand.y = maxf(stand.y, rect.position.y - APPROACH_GAP)
	else:
		stand.y = minf(stand.y, rect.end.y + APPROACH_GAP)
	if stand.distance_to(player.global_position) > PlayerController.AUTO_WALK_ARRIVE_DISTANCE:
		await player.auto_walk_to(stand, APPROACH_MAX_DURATION, Vector2(step))

## PlayerController guarantees this fires exactly once per interact press
## (even with no animation), so this can't soft-lock a pending harvest.
func _on_action_animation_finished(tool: PlayerController.Tool) -> void:
	if tool != PlayerController.Tool.HARVEST or _pending_harvest_plot_id == -1:
		return
	var plot_id := _pending_harvest_plot_id
	_pending_harvest_plot_id = -1
	if simulation.harvest(plot_id):
		AudioManager.play_harvest_sfx()
