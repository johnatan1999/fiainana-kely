class_name FarmingController
extends Node

## Translates player interactions into FarmSimulation commands.
## Holds no farming rules itself - it only decides *which* simulation call to make.
##
## Two buttons, never ambiguous (like Stardew):
## - "use_item" (Space / left click / gamepad X) acts with the item selected
##   in the Hotbar, by its FarmAction (ItemDatabase.get_use_action): a TILL
##   tool (starter hoe, Angady...) tills, a WATER tool waters, a seed stack
##   plants that crop, the zebu plough (PLOUGH) tills a whole furrow ahead,
##   zebu manure (FERTILIZE) is spread on the plot -
##   even on a ripe crop, the watering can only ever waters;
## - "interact" (E / gamepad A) is the bare-hands action: harvest a ripe crop.

## Where the player's feet end up when stepping up to a plot: this many
## pixels outside the plot's edge on their side.
const APPROACH_GAP := 6.0
## Gives up stepping up after this long (path blocked, e.g. by a solid crop)
## and acts from wherever the player got to.
const APPROACH_MAX_DURATION := 0.5

## What the two buttons would do on the plot in front, for on-screen button
## prompts: `use_action` is what "use_item" would do (FarmAction.Type.NONE
## if nothing), `can_harvest` whether "interact" would harvest. `anchor` is
## the top-center of that plot in world coordinates. Only emitted on change;
## NONE + false means "nothing to prompt".
signal target_actions_changed(anchor: Vector2, use_action: FarmAction.Type, can_harvest: bool)

var simulation: FarmSimulation
var player: PlayerController
var hotbar: Hotbar
var farm_view: FarmView # null while the player is outside the farm zone
var _world_manager: WorldManager
## Set by _perform() for HARVEST, consumed by
## _on_action_animation_finished() - -1 means no harvest is pending.
var _pending_harvest_plot_id := -1
## Last state sent through target_actions_changed, to only emit on change.
var _last_prompt := []
## A furrow is being ploughed: the player follows the team, no other action.
var _ploughing := false

## Where the share stands in a plot, from its center: near the bottom, so
## the team is drawn over the plot it's turning.
const PLOUGH_SHARE_OFFSET := Vector2(0, 14)
## How far behind the share the player walks.
const PLOUGH_FOLLOW_DISTANCE := 56.0

func setup(p_simulation: FarmSimulation, p_player: PlayerController, p_world_manager: WorldManager, p_hotbar: Hotbar) -> void:
	simulation = p_simulation
	player = p_player
	hotbar = p_hotbar
	player.interact_requested.connect(_on_interact_requested)
	player.use_item_requested.connect(_on_use_item_requested)
	player.action_animation_finished.connect(_on_action_animation_finished)
	_world_manager = p_world_manager
	p_world_manager.zone_loaded.connect(_on_zone_loaded)
	p_world_manager.zone_unloading.connect(_on_zone_unloading)

func set_farm_view(p_farm_view: FarmView) -> void:
	farm_view = p_farm_view

## Keeps the target outline live, using the same rules as the two buttons:
## white when the held item can act, a hand when "interact" would harvest,
## red when neither button would do anything.
func _process(_delta: float) -> void:
	if farm_view == null:
		_publish_prompt(Vector2.ZERO, FarmAction.Type.NONE, false)
		return
	var plot_id := _get_target_plot_id()
	var use_action := _item_action_for(plot_id) if plot_id != -1 else FarmAction.Type.NONE
	var can_harvest := plot_id != -1 and simulation.fields.can_harvest(plot_id)
	farm_view.show_highlight_for_plot(plot_id, use_action != FarmAction.Type.NONE, can_harvest)
	var anchor := Vector2.ZERO
	if plot_id != -1:
		var rect := farm_view.get_plot_global_rect(plot_id)
		anchor = Vector2(rect.get_center().x, rect.position.y)
	_publish_prompt(anchor, use_action, can_harvest)

func _publish_prompt(anchor: Vector2, use_action: FarmAction.Type, can_harvest: bool) -> void:
	var state := [anchor, use_action, can_harvest]
	if state == _last_prompt:
		return
	_last_prompt = state
	target_actions_changed.emit(anchor, use_action, can_harvest)

## The plot in the cell right in front of the player (see
## FarmView.get_plot_id_in_front_of), or -1.
func _get_target_plot_id() -> int:
	return farm_view.get_plot_id_in_front_of(player.global_position, player.last_facing_direction)

func _on_zone_loaded(zone: ZoneRoot) -> void:
	var found: FarmView = zone.get_node_or_null("FarmView")
	if found:
		found.setup(simulation, _world_manager.current_zone_id)
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
	if not simulation.fields.can_harvest(plot_id):
		AudioManager.play_action_denied_sfx()
		return
	_perform(plot_id, FarmAction.Type.HARVEST, "")

## "use_item": the held item's action, nothing else.
func _on_use_item_requested() -> void:
	var plot_id := _target_for_action()
	if plot_id == -1:
		return
	var action := _item_action_for(plot_id)
	if action == FarmAction.Type.NONE:
		AudioManager.play_action_denied_sfx()
		if hotbar.get_selected_action() == FarmAction.Type.PLOUGH and simulation.zebus.is_ploughable(plot_id):
			_explain_no_plough()
		return
	# Captured now: the player may change slot while stepping up to the plot.
	_perform(plot_id, action, hotbar.get_selected_seed_crop_id())

## The plot a button press applies to, or -1 (no farm here, the player is
## already stepping up to a plot, or nothing in front).
func _target_for_action() -> int:
	if farm_view == null or player.is_auto_walking() or _ploughing:
		return -1
	return _get_target_plot_id()

## Tool animations only play once the underlying action is confirmed
## possible (the callers check first) - swinging the hoe on unplowable ground
## does nothing and plays nothing, and the player doesn't step up to the plot
## for nothing either.
func _perform(plot_id: int, action: FarmAction.Type, crop_id: String) -> void:
	await _approach_plot(plot_id)
	if farm_view == null: # zone changed while walking
		return
	match action:
		FarmAction.Type.TILL:
			if simulation.fields.till(plot_id):
				AudioManager.play_till_sfx()
				player.play_tool_animation(action)
				farm_view.react_to_action(plot_id, action)
		FarmAction.Type.PLOUGH:
			await _plough_furrow(plot_id)
		FarmAction.Type.FERTILIZE:
			if simulation.fields.fertilize(plot_id):
				AudioManager.play_plant_sfx()
				player.play_tool_animation(FarmAction.Type.PLANT)
				farm_view.react_to_action(plot_id, action)
		FarmAction.Type.WATER:
			if simulation.fields.water(plot_id):
				AudioManager.play_watering_sfx()
				player.play_tool_animation(action)
				farm_view.react_to_action(plot_id, action)
		FarmAction.Type.PLANT:
			if simulation.fields.plant(plot_id, crop_id):
				AudioManager.play_plant_sfx()
				player.play_tool_animation(action)
				farm_view.react_to_action(plot_id, action)
		FarmAction.Type.HARVEST:
			# The actual harvest() call is applied in
			# _on_action_animation_finished() instead of right here, so the
			# crop sprite only disappears once the harvest swing animation
			# actually completes, not the instant the button is pressed.
			if simulation.fields.can_harvest(plot_id):
				_pending_harvest_plot_id = plot_id
				player.play_tool_animation(action)

## What the item selected in the Hotbar would do on plot_id, or NONE if it
## can't act there. Single source of truth for both "use_item" and the
## highlight. Harvesting is never an item action.
func _item_action_for(plot_id: int) -> FarmAction.Type:
	var action := hotbar.get_selected_action()
	var possible := false
	match action:
		FarmAction.Type.TILL:
			possible = simulation.fields.can_till(plot_id)
		FarmAction.Type.PLOUGH:
			possible = simulation.zebus.can_plough(plot_id)
		FarmAction.Type.FERTILIZE:
			possible = simulation.fields.can_fertilize(plot_id)
		FarmAction.Type.WATER:
			possible = simulation.fields.can_water(plot_id)
		FarmAction.Type.PLANT:
			possible = simulation.fields.can_plant(plot_id, hotbar.get_selected_seed_crop_id())
	return action if possible else FarmAction.Type.NONE

# --- the zebu plough ---------------------------------------------------------------

## The furrow from `first_plot_id` on, the way the player faces: the plots
## the team can till in a row, up to PLOUGH_REACH and what's left of its day.
func get_furrow(first_plot_id: int, step: Vector2i) -> Array[int]:
	var furrow: Array[int] = []
	var limit := mini(ZebuRules.PLOUGH_REACH, simulation.zebus.get_plough_cells_left())
	var zone_id := simulation.fields.get_plot_zone(first_plot_id)
	var cell := simulation.fields.get_plot_position(first_plot_id)
	while furrow.size() < limit:
		var plot_id := simulation.fields.get_plot_id_at(cell.x, cell.y, zone_id)
		if plot_id == -1 or not simulation.zebus.is_ploughable(plot_id):
			break
		furrow.append(plot_id)
		cell += step
	return furrow

## The team pulls the plough along the furrow, the player walking behind
## holding it; each plot is tilled as the share reaches it.
func _plough_furrow(first_plot_id: int) -> void:
	var step := FarmView.facing_step(player.last_facing_direction)
	var furrow := get_furrow(first_plot_id, step)
	if furrow.is_empty():
		return
	_ploughing = true
	player.input_enabled = false
	var view := farm_view
	var team := PloughTeam.new()
	team.name = "PloughTeam"
	var facing_left := step.x < 0 or (step.x == 0 and player.last_facing_direction.x < 0)
	team.setup(_team_coats(), facing_left)
	view.get_parent().add_child(team)
	var first := view.get_plot_global_rect(furrow[0])
	team.global_position = first.get_center() + PLOUGH_SHARE_OFFSET - Vector2(step) * first.size.x / 2.0
	for plot_id in furrow:
		var share := view.get_plot_global_rect(plot_id).get_center() + PLOUGH_SHARE_OFFSET
		player.auto_walk_to(share - Vector2(step) * PLOUGH_FOLLOW_DISTANCE, 3.0, Vector2(step))
		team.walk_to(share)
		await team.arrived
		if farm_view != view or not simulation.zebus.plough(plot_id):
			break
		AudioManager.play_till_sfx()
		view.react_to_action(plot_id, FarmAction.Type.PLOUGH)
	if is_instance_valid(team) and team.is_inside_tree():
		team.leave()
	player.input_enabled = true
	_ploughing = false

func is_ploughing() -> bool:
	return _ploughing

## The coats of the team: the first zebus strong enough to pull.
func _team_coats() -> Array:
	var coats := []
	for zebu_id: String in simulation.zebus.get_zebu_ids():
		var zebu := simulation.zebus.get_zebu(zebu_id)
		if int(zebu["grown_days"]) >= ZebuRules.ZEBU_WORK_MIN_DAYS:
			coats.append(zebu["coat"])
	return coats if not coats.is_empty() else [0]

func _explain_no_plough() -> void:
	match simulation.zebus.check_plough():
		ZebuRules.PloughCheck.NO_TEAM:
			UIEvents.notify(tr("Il faut deux zébus d'au moins %d jours de croissance pour tirer la charrue.")
				% ZebuRules.ZEBU_WORK_MIN_DAYS)
		ZebuRules.PloughCheck.TIRED:
			UIEvents.notify(tr("Tes zébus sont fatigués : ils ont assez labouré pour aujourd'hui."))

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
func _on_action_animation_finished(action: FarmAction.Type) -> void:
	if action != FarmAction.Type.HARVEST or _pending_harvest_plot_id == -1:
		return
	var plot_id := _pending_harvest_plot_id
	_pending_harvest_plot_id = -1
	# Before harvest(): the crop must be plucked out, not just vanish.
	if farm_view != null and simulation.fields.can_harvest(plot_id):
		farm_view.react_to_action(plot_id, FarmAction.Type.HARVEST)
	if simulation.fields.harvest(plot_id):
		AudioManager.play_harvest_sfx()
