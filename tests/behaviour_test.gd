extends Node

## Plays the real game and checks the world's behaviours that unit tests
## can't see: chickens keeping their hours, startled birds hiding in a tree
## or flying off-screen, fences and gates, the village hill and its gap to
## the rice fields, the rice terrace, lanterns at night, tall grass rustling.
## The player really walks (PlayerController.auto_walk_to), time really
## passes - so a broken collision, group or timing shows up here.
##
## Runs through tests/runner.tscn (full game environment, autoloads loaded):
##   godot --headless --path . res://tests/runner.tscn -- behaviour_test
## Never saves: whatever it changes in the loaded game stays in memory.

var _world: Node
var _wm: WorldManager
var _sim: FarmSimulation
var _player: PlayerController
var _pass_count := 0
var _fail_count := 0

func _ready() -> void:
	_world = load("res://world/world.tscn").instantiate()
	add_child(_world)
	await _frames(3)
	_wm = _world.get_node("Gameplay/WorldManager")
	_sim = _world.simulation
	_player = _world.player
	_wm.change_zone("village", "SpawnDefault")
	await _frames(3)

	await _test_chickens_keep_their_hours()
	await _test_startled_birds()
	await _test_fences()
	await _test_village_hill_and_gap()
	await _test_rice_terrace()
	await _test_lanterns()
	await _test_tall_grass_rustles()
	await _test_harvest_popup()
	await _test_rain()
	await _test_zebu_cart()

	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	get_tree().quit(1 if _fail_count > 0 else 0)

# --- helpers -------------------------------------------------------------------

func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

## Waits until `condition` holds, at most `seconds`. Returns whether it did.
func _wait_for(condition: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()

func _set_time(minute_of_day: int) -> void:
	_sim.state.clock.minute_of_day = minute_of_day
	_sim.time_changed.emit(minute_of_day)

func _go_to_zone(zone_id: String) -> void:
	if _wm.current_zone_id != zone_id:
		_wm.change_zone(zone_id, "SpawnDefault")
		await _frames(3)

## Puts the player at `from` and walks them towards `to` for up to `seconds`.
## Returns where they ended up.
func _walk(from: Vector2, to: Vector2, seconds: float) -> Vector2:
	_player.global_position = from
	await _frames(1)
	await _player.auto_walk_to(to, seconds)
	return _player.global_position

func _zone() -> ZoneRoot:
	return _wm.current_zone

# --- chickens ------------------------------------------------------------------

func _hens() -> Array:
	return _zone().find_children("*", "Chicken", true, false)

func _test_chickens_keep_their_hours() -> void:
	await _go_to_zone("village")
	_player.global_position = Vector2(2000, 1500) # out of their way
	_set_time(15 * 60)
	var all_out := func() -> bool: return _hens().all(func(h): return h.visible and h._state != Chicken.State.ROOSTING)
	_check(await _wait_for(all_out, 12.0), "chickens: out in the yard in the afternoon")
	_set_time(18 * 60 + 40)
	await _frames(60)
	_check(_hens().all(func(h): return not h._going_home and h._state != Chicken.State.ROOSTING),
		"chickens: still out at 18:40, whatever the light")
	_set_time(18 * 60 + 46)
	var all_in := func() -> bool: return _hens().all(func(h): return h._state == Chicken.State.ROOSTING)
	_check(await _wait_for(all_in, 10.0), "chickens: all gone into the coop after 18:45")
	_set_time(6 * 60 + 20)
	_check(await _wait_for(all_out, 12.0), "chickens: all back out by morning")

# --- birds ---------------------------------------------------------------------

func _test_startled_birds() -> void:
	await _go_to_zone("village")
	_set_time(12 * 60)
	await _frames(5)
	var bird: AmbientBird = null
	for child in _zone().get_node("AmbientLife").get_children():
		if child is AmbientBird:
			bird = child
			break
	_check(bird != null, "birds: the village has ground birds")
	if bird == null:
		return
	for case in [
		[Vector2(380, 1060), Vector2(430, 1070), true, "hides in a nearby tree"],
		[Vector2(1230, 640), Vector2(1280, 650), false, "flies off-screen when no tree is near"],
	]:
		bird._state = AmbientBird.State.GROUND
		bird.visible = true
		bird.modulate.a = 1.0
		bird._height = 0.0
		bird.position = bird.get_parent().to_local(case[0])
		_player.global_position = case[1]
		var gone := func() -> bool: return bird._state == AmbientBird.State.AWAY
		var vanished := await _wait_for(gone, 7.0)
		_check(vanished and bird._has_perch == case[2], "birds: a startled bird %s" % case[3])

# --- fences --------------------------------------------------------------------

func _test_fences() -> void:
	await _go_to_zone("village")
	var stopped := await _walk(Vector2(440, 900), Vector2(700, 900), 1.5)
	_check(stopped.x < 500.0, "fences: the west fence of the field blocks the player")
	var through := await _walk(Vector2(440, 1200), Vector2(700, 1200), 2.0)
	_check(through.x > 600.0, "fences: the west gate lets the player through")

# --- village hill --------------------------------------------------------------

func _test_village_hill_and_gap() -> void:
	await _go_to_zone("village")
	var stopped := await _walk(Vector2(1400, 450), Vector2(1400, 60), 3.0)
	_check(stopped.y > 230.0, "hill: the cliff stops the player")
	_player.global_position = Vector2(1505, 300)
	_player.auto_walk_to(Vector2(1505, -40), 4.0)
	var arrived := func() -> bool: return _wm.current_zone_id == "rice_fields"
	_check(await _wait_for(arrived, 5.0), "hill: the gap leads to the rice fields")
	await _frames(30) # let the transition's fade finish

# --- rice terrace --------------------------------------------------------------

func _test_rice_terrace() -> void:
	await _go_to_zone("rice_fields")
	var stopped := await _walk(Vector2(500, 590), Vector2(500, 400), 1.5)
	_check(stopped.y > 540.0, "terrace: its rock face can't be climbed from the lower paddies")
	var up := await _walk(Vector2(960, 330), Vector2(620, 330), 3.0)
	_check(up.x < 700.0, "terrace: reachable from its east side")

# --- lanterns ------------------------------------------------------------------

func _test_lanterns() -> void:
	await _go_to_zone("village")
	var lanterns := _zone().get_node("NightLights").get_children()
	var dn: DayNightController = _world.get_node("Gameplay/DayNightController")
	_set_time(22 * 60)
	dn._apply()
	await _frames(5)
	var lit := lanterns.filter(func(l): return l.visible and l._light.energy > 0.0).size()
	_check(lanterns.size() > 0 and lit == lanterns.size(),
		"lanterns: lit at night (%d/%d, night %.2f, zone %s)" % [lit, lanterns.size(), dn.get_night_amount(), _wm.current_zone_id])
	_set_time(12 * 60)
	dn._apply()
	await _frames(5)
	_check(lanterns.all(func(l): return not l.visible), "lanterns: out by day")

# --- harvest feedback ----------------------------------------------------------

func _test_harvest_popup() -> void:
	await _go_to_zone("village")
	var plot_id := _sim.get_plot_id_at(0, 1, "village")
	var plot := _sim.get_plot(plot_id)
	plot.crop = null
	_sim.till(plot_id)
	_sim.state.add_inventory("corn_seed", 1)
	_sim.plant(plot_id, "corn")
	plot.crop.age = plot.crop.growth_days
	_sim.harvest(plot_id)
	await _frames(2)
	var popups := _zone().find_children("*", "HarvestPopup", true, false)
	var texts: Array = []
	for popup in popups:
		for label in popup.find_children("*", "Label", true, false):
			texts.append(label.text)
	_check(popups.size() == 1 and texts.any(func(t): return t.begins_with("+")),
		"harvest: a \"+N\" popup shows over the harvested plot (%s)" % ", ".join(texts))

# --- rain ----------------------------------------------------------------------

func _test_rain() -> void:
	await _go_to_zone("village")
	_set_time(12 * 60)
	var weather: WeatherController = _world.get_node("Gameplay/WeatherController")
	var dn: DayNightController = _world.get_node("Gameplay/DayNightController")
	var life: AmbientLife = _zone().get_node("AmbientLife")
	var plot_id := _sim.get_plot_id_at(1, 1, "village")
	_sim.till(plot_id)
	_sim.get_plot(plot_id).watered = false
	_sim.set_weather(FarmState.Weather.RAIN)
	await _frames(150) # the sky clouds over in 2 s
	var rain: Node2D = weather.get_node("Rain")
	_check(rain.visible and weather._streaks.emitting and dn.get_overcast() > 0.95,
		"rain: falls outdoors under an overcast sky")
	_check(_sim.get_plot(plot_id).watered, "rain: the tilled plots are watered")
	_check(life._butterflies.all(func(b): return not b.visible), "rain: the butterflies take cover")
	_wm.change_zone("player_house", "SpawnDefault")
	await _frames(3)
	_check(not rain.visible and dn.get_overcast() < 0.5, "rain: not falling indoors, only a greyer light")
	_sim.set_weather(FarmState.Weather.CLEAR)
	await _go_to_zone("village")
	await _frames(150)
	_check(not rain.visible and dn.get_overcast() < 0.05, "rain: stops when the weather clears")

# --- zebu cart -------------------------------------------------------------------

func _test_zebu_cart() -> void:
	await _go_to_zone("village")
	_sim.set_weather(FarmState.Weather.CLEAR)
	var cart: ZebuCart = _zone().get_node("CartRoute_Est/ZebuCart")
	_player.global_position = Vector2(300, 300) # well out of the way
	_set_time(22 * 60)
	cart._go_away()
	cart._timer = 0.0
	await _frames(30)
	_check(not cart.is_driving(), "zebu cart: doesn't set off at night")
	_set_time(10 * 60)
	cart._timer = 0.0
	var started := func() -> bool: return cart.is_driving() and cart.progress_ratio > 0.1
	_check(await _wait_for(started, 8.0), "zebu cart: sets off by day and drives along its road")
	# Stand in its way, a little ahead of the zebus.
	var ahead: Vector2 = cart.get_node("Ahead/CollisionShape2D").global_position
	_player.global_position = ahead
	await _frames(10)
	var stopped_at := cart.progress
	await _frames(60)
	_check(cart.is_driving() and absf(cart.progress - stopped_at) < 0.5, "zebu cart: waits while the player is in its way")
	_player.global_position = Vector2(300, 300)
	await _frames(60)
	_check(cart.progress - stopped_at > 10.0, "zebu cart: drives on once the way is clear")

# --- tall grass ----------------------------------------------------------------

func _test_tall_grass_rustles() -> void:
	await _go_to_zone("village")
	var grass: TallGrassLayer = _zone().get_node("TallGrassLayer")
	# Walk one tuft to the next, like a player wading through a patch.
	var cells := grass.get_used_cells()
	cells.sort()
	var start: Vector2i = cells[cells.size() / 2]
	var stepped := 0
	for i in 6:
		var cell := start + Vector2i(i, 0)
		if grass.get_cell_source_id(cell) == -1:
			continue
		_player.global_position = grass.to_global(grass.map_to_local(cell))
		stepped += 1
		await _frames(12)
	var rustles: Array = grass.material.get_shader_parameter("rustles")
	var used := rustles.filter(func(r): return r.w > 0.5).size()
	_check(stepped > 1 and used >= 2, "tall grass: walking through it rustles it (%d rustles)" % used)
