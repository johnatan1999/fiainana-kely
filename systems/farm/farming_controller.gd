class_name FarmingController
extends Node

## Translates player interactions into FarmSimulation commands.
## Holds no farming rules itself - it only decides *which* simulation call to make.
##
## Two buttons, never ambiguous (like Stardew):
## - "use_item" (Space / left click / gamepad X) acts with the item selected
##   in the Hotbar: hoe tills, watering can waters, a seed stack plants that
##   crop - even on a ripe crop, the watering can only ever waters;
## - "interact" (E / gamepad A) is the bare-hands action: harvest a ripe crop.

## Where the player's feet end up when stepping up to a plot: this many
## pixels outside the plot's edge on their side.
const APPROACH_GAP := 6.0
## Gives up stepping up after this long (path blocked, e.g. by a solid crop)
## and acts from wherever the player got to.
const APPROACH_MAX_DURATION := 0.5

## No action possible on the targeted plot with what the player holds.
const NO_ACTION := -1

var simulation: FarmSimulation
var player: PlayerController
var hotbar: Hotbar
var farm_view: FarmView # null while the player is outside the farm zone
## Set by _perform() for HARVEST, consumed by
## _on_action_animation_finished() - -1 means no harvest is pending.
var _pending_harvest_plot_id := -1

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_world_manager: WorldManager, p_hotbar: Hotbar) -> void:
	simulation = p_simulation
	player = p_player
	hotbar = p_hotbar
	player.interact_requested.connect(_on_interact_requested)
	player.use_item_requested.connect(_on_use_item_requested)
	player.action_animation_finished.connect(_on_action_animation_finished)
	p_world_manager.zone_loaded.connect(_on_zone_loaded)
	p_world_manager.zone_unloading.connect(_on_zone_unloading)

func set_farm_view(p_farm_view: FarmView) -> void:
	farm_view = p_farm_view

## Keeps the target outline live, using the same rules as the two buttons:
## white when the held item can act, a hand when "interact" would harvest,
## red when neither button would do anything.
func _process(_delta: float) -> void:
	if farm_view:
		var plot_id := _get_target_plot_id()
		var can_use := plot_id != -1 and _item_action_for(plot_id) != NO_ACTION
		var can_harvest := plot_id != -1 and simulation.can_harvest(plot_id)
		farm_view.show_highlight_for_plot(plot_id, can_use, can_harvest)

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

## "interact": harvest by hand - the only farming action that needs no item.
func _on_interact_requested() -> void:
	var plot_id := _target_for_action()
	if plot_id == -1:
		return
	if not simulation.can_harvest(plot_id):
		AudioManager.play_action_denied_sfx()
		return
	_perform(plot_id, PlayerController.Tool.HARVEST, "")

## "use_item": the held item's action, nothing else.
func _on_use_item_requested() -> void:
	var plot_id := _target_for_action()
	if plot_id == -1:
		return
	var action := _item_action_for(plot_id)
	if action == NO_ACTION:
		AudioManager.play_action_denied_sfx()
		return
	# Captured now: the player may change slot while stepping up to the plot.
	_perform(plot_id, action as PlayerController.Tool, _selected_seed_crop_id())

## The plot a button press applies to, or -1 (no farm here, the player is
## already stepping up to a plot, or nothing in front).
func _target_for_action() -> int:
	if farm_view == null or player.is_auto_walking():
		return -1
	return _get_target_plot_id()

## Tool animations only play once the underlying action is confirmed
## possible (the callers check first) - swinging the hoe on unplowable ground
## does nothing and plays nothing, and the player doesn't step up to the plot
## for nothing either.
func _perform(plot_id: int, tool: PlayerController.Tool, crop_id: String) -> void:
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
			if simulation.plant(plot_id, crop_id):
				AudioManager.play_plant_sfx()
				player.play_tool_animation(tool)
		PlayerController.Tool.HARVEST:
			# The actual harvest() call is applied in
			# _on_action_animation_finished() instead of right here, so the
			# crop sprite only disappears once the harvest swing animation
			# actually completes, not the instant the button is pressed.
			if simulation.can_harvest(plot_id):
				_pending_harvest_plot_id = plot_id
				player.play_tool_animation(tool)

## What the item selected in the Hotbar would do on plot_id, as a
## PlayerController.Tool, or NO_ACTION. Single source of truth for both
## "use_item" and the highlight. Harvesting is never an item action.
func _item_action_for(plot_id: int) -> int:
	var item_id := hotbar.get_selected_item()
	if item_id == Hotbar.HOE and simulation.can_till(plot_id):
		return PlayerController.Tool.HOE
	if item_id == Hotbar.WATERING_CAN and simulation.can_water(plot_id):
		return PlayerController.Tool.WATERING_CAN
	if Hotbar.is_seed_id(item_id) and simulation.can_plant(plot_id, _selected_seed_crop_id()):
		return PlayerController.Tool.SEEDS
	return NO_ACTION

## Crop id of the seed stack in the selected slot, "" if it isn't one.
func _selected_seed_crop_id() -> String:
	var item_id := hotbar.get_selected_item()
	return item_id.trim_suffix(Hotbar.SEED_SUFFIX) if Hotbar.is_seed_id(item_id) else ""

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

## PlayerController guarantees this fires exactly once per tool animation
## (even with no animation), so this can't soft-lock a pending harvest.
func _on_action_animation_finished(tool: PlayerController.Tool) -> void:
	if tool != PlayerController.Tool.HARVEST or _pending_harvest_plot_id == -1:
		return
	var plot_id := _pending_harvest_plot_id
	_pending_harvest_plot_id = -1
	if simulation.harvest(plot_id):
		AudioManager.play_harvest_sfx()
