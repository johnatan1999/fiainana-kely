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
	await _test_grazing_zebus()
	await _test_villager_visual()
	await _test_villagers()
	await _test_orders()
	await _test_friendship()
	await _test_inventory_villagers()
	await _test_tilling_repaints_one_field()
	await _test_farm_and_village_paths()
	await _test_family()
	await _test_school_fees()
	await _test_cockfight()
	await _test_evening_meal()
	await _test_save_at_bedtime()
	await _test_market_town()
	await _test_zebu_market()
	await _test_zebu_plough()
	await _test_zebu_manure()
	await _test_family_projects()
	await _test_forest()
	await _test_quests()
	await _test_more_quests()
	await _test_chicken_thieves()
	# Last: it takes over the camera.
	await _test_home_screen()

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

## Moves the clock to `weekday` within the current week (the zone loads
## and the CALENDAR_GROUP pick it up). Returns the day it was, to restore.
func _set_weekday(weekday: GameClock.Weekday) -> int:
	var clock := _sim.state.clock
	var day := clock.current_day
	clock.current_day = day - clock.get_weekday() + weekday + (7 if day - clock.get_weekday() + weekday < 1 else 0)
	get_tree().call_group(DayNightController.CALENDAR_GROUP, "set_weekday", clock.get_weekday())
	return day

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
	await _go_to_zone("farm")
	_player.global_position = Vector2(1300, 1500) # out of their way
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
		[Vector2(1560, 600), Vector2(1610, 610), true, "hides in a nearby tree"],
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
	await _go_to_zone("farm")
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
	await _go_to_zone("farm")
	var plot_id := _sim.get_plot_id_at(0, 1, "farm")
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
	await _go_to_zone("farm")
	_set_time(12 * 60)
	var weather: WeatherController = _world.get_node("Gameplay/WeatherController")
	var dn: DayNightController = _world.get_node("Gameplay/DayNightController")
	var life: AmbientLife = _zone().get_node("AmbientLife")
	var plot_id := _sim.get_plot_id_at(1, 1, "farm")
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
	await _go_to_zone("farm")
	await _frames(150)
	_check(not rain.visible and dn.get_overcast() < 0.05, "rain: stops when the weather clears")

# --- zebu cart -------------------------------------------------------------------

func _test_zebu_cart() -> void:
	await _go_to_zone("village")
	_sim.set_weather(FarmState.Weather.CLEAR)
	var cart: ZebuCart = _zone().get_node("CartRoute_East/ZebuCart")
	_player.global_position = Vector2(300, 300) # well out of the way
	_set_time(22 * 60)
	cart._go_away()
	cart._timer = 0.0
	await _frames(30)
	_check(not cart.is_driving(), "zebu cart: doesn't set off at night")
	_set_time(10 * 60)
	cart._timer = 0.0
	await _frames(3)
	var ground: TileMapLayer = _zone().get_node("GroundLayer")
	var map_right := ground.to_global(Vector2(ground.get_used_rect().end * 48)).x
	var nearest_x := INF
	for sprite in cart.get_node("Visual").get_children():
		if sprite is Sprite2D:
			nearest_x = minf(nearest_x, (sprite.get_global_transform() * sprite.get_rect()).position.x)
	_check(cart.is_driving() and nearest_x > map_right,
		"zebu cart: sets off from beyond the map's edge, not popping up on it (%d > %d)" % [nearest_x, map_right])
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

# --- grazing zebus ----------------------------------------------------------------

func _test_grazing_zebus() -> void:
	await _go_to_zone("village")
	_player.global_position = Vector2(300, 300) # far from the herd
	_set_time(10 * 60)
	var herd: Array = _zone().get_node("ZebuHerd").get_children()
	# The day may have started in the pen (before 6:30): let them get out first.
	var commuting := [GrazingZebu.Activity.GO_IN, GrazingZebu.Activity.PENNED, GrazingZebu.Activity.GO_OUT]
	var out_grazing := func() -> bool: return herd.all(func(z): return z._activity not in commuting)
	await _wait_for(out_grazing, 40.0)
	await _frames(600)
	var stray := herd.filter(func(z): return z.global_position.distance_to(z._home) > z.wander_radius + 8.0).size()
	_check(herd.size() >= 3 and stray == 0, "zebus: the herd wanders around its pasture, not off it")
	var zebu: GrazingZebu = herd[0]
	zebu._start(GrazingZebu.Activity.GRAZE)
	_player.global_position = zebu.global_position + Vector2(-50, 0)
	await _frames(5)
	var sprite: Sprite2D = zebu.get_node("Sprite2D")
	_check(sprite.frame == GrazingZebu.FRAME_WATCH and sprite.flip_h,
		"zebus: one raises its head and watches the player who comes close")
	var end := await _walk(zebu.global_position + Vector2(-60, 0), zebu.global_position + Vector2(60, 0), 3.0)
	_check(end.x < zebu.global_position.x, "zebus: solid, the player can't walk through one")
	_player.global_position = Vector2(300, 300)
	# Village herd: into the pen at dusk, out in the morning.
	_check(herd.all(func(z): return z.has_pen()), "zebus: the village herd has its pen")
	_set_time(GrazingZebu.PEN_FROM)
	var all_penned := func() -> bool: return herd.all(func(z): return z.is_penned())
	_check(await _wait_for(all_penned, 40.0), "zebus: the herd walks into its pen at dusk")
	await _frames(2)
	var pen: ZebuPen = _zone().get_node("ZebuPen")
	var pen_area := Rect2(pen.global_position, Vector2(6, 4) * 48.0)
	var lying_inside := func(z) -> bool:
		return pen_area.has_point(z.global_position) and z.get_node("Sprite2D").frame == GrazingZebu.FRAME_REST
	_check(herd.all(lying_inside), "zebus: they lie down inside the fence for the night")
	_set_time(GrazingZebu.PEN_UNTIL)
	var all_out := func() -> bool: return herd.all(func(z): return not pen_area.has_point(z.global_position))
	_check(await _wait_for(all_out, 40.0), "zebus: they walk back out to the pasture in the morning")
	# Arriving at night: already in.
	_set_time(22 * 60)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	herd = _zone().get_node("ZebuHerd").get_children()
	_check(herd.all(func(z): return z.is_penned()), "zebus: arriving at night, the herd is already in its pen")
	# A herd without a pen sleeps in the field.
	await _go_to_zone("rice_fields")
	await _frames(3)
	var field_herd: Array = _zone().get_node("ZebuHerd").get_children()
	_check(field_herd.all(func(z): return not z.has_pen() and z.get_node("Sprite2D").frame == GrazingZebu.FRAME_REST),
		"zebus: a herd without a pen lies down in the field for the night")
	_set_time(10 * 60)
	await _frames(90)
	_check(field_herd.all(func(z): return z.get_node("Sprite2D").frame != GrazingZebu.FRAME_REST),
		"zebus: back up in the morning")

# --- villager visual ---------------------------------------------------------------

func _test_villager_visual() -> void:
	var shirt := VillagerLayer.new()
	shirt.texture = load("res://assets/sprites/characters/villager/example_shirt.png")
	shirt.color = Color.RED
	var look := VillagerLook.new()
	var layers: Array[VillagerLayer] = [shirt]
	look.layers = layers
	var visual := VillagerVisual.new()
	add_child(visual)
	visual.look = look
	await _frames(1)
	var sprites := visual.get_children().filter(func(c): return c is Sprite2D and not c.is_queued_for_deletion())
	_check(sprites.size() == 2 and sprites[0].self_modulate == look.skin_color and sprites[1].self_modulate == Color.RED,
		"villager visual: the body tinted with the skin color, each layer with its color")
	visual.play(Vector2.LEFT, true)
	await _frames(2)
	var frame: int = sprites[0].frame
	_check(frame / VillagerVisual.COLUMNS == VillagerVisual.Facing.LEFT and frame % VillagerVisual.COLUMNS >= 2
			and sprites.all(func(s): return s.frame == frame),
		"villager visual: walking left plays the walk row, every layer on the same frame")
	shirt.color = Color.BLUE
	await _frames(1)
	var recolored := visual.get_children().filter(func(c): return c is Sprite2D and not c.is_queued_for_deletion())
	_check(recolored.size() == 2 and recolored[1].self_modulate == Color.BLUE,
		"villager visual: editing the look updates the sprite")
	visual.queue_free()

# --- villagers ------------------------------------------------------------------------

func _villager(villager_name: String) -> Villager:
	return _zone().get_node("Villagers/" + villager_name)

func _test_villagers() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_player.global_position = Vector2(300, 300)
	_set_time(10 * 60)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	var roads := VillagerRoads.of_zone(_zone())
	var ravao := _villager("Ravao")
	var rakoto := _villager("Rakoto")
	_check(not ravao.is_inside() and ravao.global_position.distance_to(roads.get_spot("Market")) < 60.0
			and rakoto.is_inside(),
		"villagers: arriving at 10:00, the merchant is at her stall and the farmer is away in the rice fields")
	# Off home at the end of the day, along the roads.
	_set_time(17 * 60 + 30)
	await _frames(30)
	_check(ravao.is_walking() and not ravao.is_inside(), "villagers: she sets off home when her day at the market ends")
	var home := func() -> bool: return ravao.is_inside()
	_check(await _wait_for(home, 60.0), "villagers: she walks home and goes in")
	# The player in the way: she waits, and says hello.
	_set_time(10 * 60)
	await _frames(30)
	var direction := (ravao._path[0] - ravao.global_position).normalized() if ravao.is_walking() else Vector2.LEFT
	_player.global_position = ravao.global_position + direction * 20.0
	await _frames(5)
	var stopped_at := ravao.global_position
	await _frames(60)
	_check(ravao.global_position.distance_to(stopped_at) < 1.0 and ravao.get_node("Bubble").visible,
		"villagers: one waits for the player in the way, and greets them")
	_player.global_position = Vector2(300, 300)
	# Rain: home, unless the step is rain-proof.
	_set_time(9 * 60)
	var today := _set_weekday(GameClock.Weekday.SUNDAY)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	_check(_villager("Koto").get_spot_name() == "Pitch",
		"villagers: no school on Sunday - the child plays football")
	_set_weekday(GameClock.Weekday.TUESDAY)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	var koto := _villager("Koto")
	var grandmother := _villager("NenySoa")
	_check(koto.get_spot_name() == "School" and not grandmother.is_inside(),
		"villagers: on a school day morning the child is at school, the grandmother strolls on the square")
	_sim.state.clock.current_day = today
	_sim.set_weather(FarmState.Weather.RAIN)
	var sheltered := func() -> bool: return grandmother.is_inside()
	_check(await _wait_for(sheltered, 60.0) and not _villager("Ravao").is_inside() and not koto.is_inside(),
		"villagers: when it rains the grandmother goes home; the merchant (covered stall) and the child (school) stay")
	_sim.set_weather(FarmState.Weather.CLEAR)
	# Night: everyone's in.
	_set_time(22 * 60)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	var villagers := _zone().get_node("Villagers").get_children()
	_check(villagers.size() >= 5 and villagers.all(func(v): return v.is_inside()),
		"villagers: arriving at night, everyone is in")
	_set_time(10 * 60)
	await _test_farmers_in_the_rice_fields()
	await _test_neighbours_harvest()

func _test_neighbours_harvest() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	var clock := _sim.state.clock
	var day_before := clock.current_day
	clock.current_day = 27
	_set_time(10 * 60)
	await _go_to_zone("village")
	await _go_to_zone("rice_fields")
	await _frames(3)
	var paddy: VillagePaddy = _zone().get_node("NeighbourPaddies/Paddy1")
	var interactable: InteractableComponent = paddy._interactable
	_check(not interactable.get_prompt().is_empty() and paddy.get_sheaf_count() > 0,
		"neighbours' harvest: half cut on day 27, sheaves drying, and the player is offered to help")
	_player.global_position = paddy.get_tuft_position(Vector2i(paddy.size.x - 1, paddy.size.y - 1))
	var seeds := _sim.state.get_inventory_count("rice_seed")
	var sheaves := paddy.get_sheaf_count()
	var cell := paddy.tuft_near(_player.global_position)
	interactable.interact()
	await _frames(3)
	_check(_sim.state.get_inventory_count("rice_seed") == seeds + 1 and paddy._cut.has(cell),
		"neighbours' harvest: the player cuts the tuft next to them and gets seed rice")
	var callers := _zone().get_node("Villagers").get_children().filter(func(v): return not v.call_out.is_empty())
	_check(callers.size() == 2, "neighbours' harvest: the farmers call out for help")
	clock.current_day = 29
	_set_time(10 * 60)
	await _frames(2)
	_check(interactable.get_prompt().is_empty() and paddy._cut.size() == paddy.size.x * paddy.size.y
			and paddy.get_sheaf_count() >= sheaves,
		"neighbours' harvest: all cut by day 29, nothing left to help with")
	clock.current_day = day_before
	_set_time(10 * 60)

func _test_farmers_in_the_rice_fields() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(9 * 60)
	await _go_to_zone("village")
	await _go_to_zone("rice_fields")
	await _frames(3)
	_player.global_position = Vector2(300, 300) # off their road (the spawn is on it)
	var paddy: VillagePaddy = _zone().get_node("NeighbourPaddies/Paddy1")
	var area := paddy.get_rect().grow(4.0)
	var farmers: Array = _zone().get_node("Villagers").get_children()
	var at_work := func() -> bool:
		return farmers.all(func(f): return area.has_point(f.global_position) and not f.is_inside())
	_check(farmers.size() == 2 and at_work.call(), "farmers: at 9:00 they're in the neighbours' paddy")
	var bent := func() -> bool: return farmers.any(func(f): return f.is_working() and f._visual.working)
	_check(await _wait_for(bent, 5.0), "farmers: bent over, planting rice")
	_sim.set_weather(FarmState.Weather.RAIN)
	await _frames(30)
	_check(at_work.call(), "farmers: they keep working in the rain")
	_sim.set_weather(FarmState.Weather.CLEAR)
	# Home time: off by the road to the village.
	_set_time(16 * 60)
	var gone := func() -> bool: return farmers.all(func(f): return f.is_inside())
	_check(await _wait_for(gone, 60.0), "farmers: at 16:00 they walk off towards the village")
	# ...and in the village, they come in by the north road, after the trip.
	_set_time(15 * 60 + 55)
	await _go_to_zone("village")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	var rakoto := _villager("Rakoto")
	_check(rakoto.is_inside(), "farmers: in the village at 15:55, Rakoto is still away")
	_set_time(16 * 60)
	await _frames(30)
	_check(rakoto.is_inside(), "farmers: ...and not back yet right at 16:00 (the trip takes a while)")
	var back := func() -> bool: return not rakoto.is_inside()
	_check(await _wait_for(back, Villager.ARRIVAL_DELAY + 2.0)
			and rakoto.global_position.distance_to(VillagerRoads.of_zone(_zone()).get_spot("To_rice_fields")) < 80.0,
		"farmers: he comes in by the road from the rice fields")
	_set_time(10 * 60)

# --- orders ----------------------------------------------------------------------------

func _test_orders() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(10 * 60)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	var ravao := _villager("Ravao")
	var panel: OrderPanel = _world.get_node("UI/OrderPanel")
	var tracker: OrdersTracker = _world.get_node("UI/OrdersTracker")
	# Ravao offers 2 corn (her second order: corn).
	_sim.state.orders.clear()
	_sim.state.orders["ravao"] = {"item": "corn", "quantity": 2, "reward": 3400, "template": 1,
		"since": _sim.state.day, "deadline": -1}
	_sim.order_changed.emit("ravao")
	await _frames(2)
	var mark: Label = ravao.get_node("Mark")
	_check(mark.visible and mark.text == "!", "orders: a '!' over the villager who has an order to offer")
	_sim.state.inventory.erase("corn") # none yet: the order isn't deliverable
	_sim.inventory_changed.emit("corn", 0)
	ravao.interacted.emit()
	await _frames(2)
	_check(panel.is_open() and get_tree().paused and panel._item.text.contains("2"),
		"orders: talking to her opens the order (2 corn), the game paused")
	panel._accept.pressed.emit()
	await _frames(2)
	_check(not panel.is_open() and not get_tree().paused and _sim.is_order_active("ravao") and tracker.visible
			and not mark.visible,
		"orders: accepted - the panel closes, the order shows in the tracker, the '!' goes")
	_sim.state.inventory.erase("corn")
	_sim.state.add_inventory("corn", 2)
	_sim.inventory_changed.emit("corn", 2)
	await _frames(2)
	_check(mark.visible and mark.text == "?", "orders: a '?' over her once the player has the 2 corn")
	var money := _sim.state.money
	ravao.interacted.emit()
	await _frames(2)
	_check(_sim.state.money == money + 3400 and _sim.state.get_inventory_count("corn") == 0
			and not _sim.is_order_active("ravao") and not mark.visible and ravao.get_node("Bubble").visible
			and not tracker.visible,
		"orders: talking to her again delivers - 3 400 Ar, a thank-you, the tracker empties")
	_sim.state.order_cooldowns.clear()

# --- friendship -------------------------------------------------------------------------

func _test_friendship() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(10 * 60)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	var ravao := _villager("Ravao")
	_sim.state.orders.erase("ravao")
	_sim.state.friendship["ravao"] = 195 # 5 points short of 2 hearts
	_sim.state.friendship_talk_day.erase("ravao")
	var seeds := _sim.state.get_inventory_count("tomato_seed")
	ravao.interacted.emit()
	await _frames(3)
	var hearts: HeartsDisplay = ravao.get_node("Hearts")
	_check(hearts.visible and hearts.hearts == 2 and _sim.get_hearts("ravao") == 2,
		"friendship: talking to her shows the hearts over her head - now 2")
	_check(_sim.state.get_inventory_count("tomato_seed") == seeds + 5 and ravao.get_node("Bubble").visible,
		"friendship: at 2 hearts she gives the player tomato seeds, with a word")

func _test_inventory_villagers() -> void:
	var inventory: InventoryUI = _world.get_node("UI/InventoryUI")
	_sim.state.friendship["ravao"] = 235
	inventory.open()
	await _frames(3)
	inventory._select_category(InventoryCatalog.Category.VILLAGERS)
	await _frames(2)
	inventory._select_item("villager:ravao")
	await _frames(2)
	var card: ItemInfoCard = inventory.info_card
	var texts := card.find_children("*", "Label", true, false).map(func(label): return label.text)
	_check(inventory._order.size() == VillagerData.load_all().size() and inventory._entries["villager:ravao"].info.icon != null
			and texts.has("Ravao") and texts.has("2/5 cœurs") and texts.has("35 %"),
		"inventory: the Villageois tab lists every villager (family and market town included) with their portrait; Ravao's card shows 2/5 hearts, 35 %")
	inventory.close()
	await _frames(15)

# --- performance: soil ------------------------------------------------------------------

## Tilling one plot used to repaint every field's soil (terrain autotiling)
## and froze the game for 250-450 ms. Now: only its field, only the layer
## that changed.
func _test_tilling_repaints_one_field() -> void:
	await _go_to_zone("farm")
	await _frames(2)
	var farm_view: FarmView = _world.get_node("Gameplay/FarmingController").farm_view
	var plot_id := -1
	for id in _sim.state.plots:
		if _sim.can_till(id):
			plot_id = id
			break
	_sim.till(plot_id)
	var dirty := farm_view._dirty_fields.size()
	await _frames(2)
	var shop: ShopUI = _world.get_node("UI/ShopUI")
	var rebuilt := [false]
	var watcher := func(_child): rebuilt[0] = true
	shop.item_grid.child_entered_tree.connect(watcher)
	_sim.state.add_inventory("corn", 1)
	_sim.inventory_changed.emit("corn", _sim.state.get_inventory_count("corn"))
	await _frames(2)
	shop.item_grid.child_entered_tree.disconnect(watcher)
	_check(farm_view.get_fields().size() > 1 and dirty == 1 and not rebuilt[0],
		"performance: tilling repaints only its own field, and the closed shop isn't rebuilt on an inventory change")

# --- farm <-> village -------------------------------------------------------------------

func _test_farm_and_village_paths() -> void:
	await _go_to_zone("village")
	_player.global_position = Vector2(300, 505)
	_player.auto_walk_to(Vector2(-60, 505), 6.0)
	var at_farm := func() -> bool: return _wm.current_zone_id == "farm"
	_check(await _wait_for(at_farm, 7.0), "farm: the village's west road leads to the farm")
	await _frames(30)
	_player.global_position = Vector2(1250, 560)
	_player.auto_walk_to(Vector2(1500, 560), 6.0)
	var at_village := func() -> bool: return _wm.current_zone_id == "village"
	_check(await _wait_for(at_village, 7.0), "farm: its east road leads back to the village")
	await _frames(30)
	_check(_zone().get_node_or_null("FarmView") == null and _zone().get_node_or_null("Villagers") != null,
		"farm: the fields are on the farm now, the villagers in the village")

# --- family ----------------------------------------------------------------------------

func _test_family() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(8 * 60)
	var today := _set_weekday(GameClock.Weekday.WEDNESDAY)
	await _go_to_zone("village")
	await _go_to_zone("farm")
	await _frames(3)
	_player.global_position = Vector2(700, 1500)
	var mother: Villager = _zone().get_node("Villagers/Mother")
	var father: Villager = _zone().get_node("Villagers/Father")
	var sister: Villager = _zone().get_node("Villagers/Fara")
	_check(not mother.is_inside() and mother.get_spot_name() == "Mortar" and father.get_spot_name() == "Orchard"
			and sister.is_inside(),
		"family: at 8:00 the mother pounds rice, the father works the orchard, the sister is off to school")
	var points := _sim.get_friendship("mother")
	mother.interacted.emit()
	await _frames(3)
	_check(mother.get_node("Bubble").visible and not mother.get_node("Hearts").visible
			and _sim.get_friendship("mother") == points,
		"family: talking to the mother gives a tip - no friendship hearts with family")
	_set_time(9 * 60)
	await _go_to_zone("farm")
	await _go_to_zone("village")
	await _frames(3)
	var at_school: Villager = _zone().get_node("Villagers/Fara")
	_check(not at_school.is_inside() and at_school.get_spot_name() == "School",
		"family: in the village at 9:00, the sister is at school")
	_sim.state.clock.current_day = today
	_set_time(10 * 60)

# --- Fara's school fees ----------------------------------------------------------------------

func _test_school_fees() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(8 * 60)
	var today := _set_weekday(GameClock.Weekday.WEDNESDAY)
	var state := _sim.state
	var money := state.money
	state.school_debt = FarmSimulation.SCHOOL_FEE
	state.school_due_day = state.day - 1
	_sim.school_fees_changed.emit()
	await _go_to_zone("village")
	await _go_to_zone("farm")
	await _frames(3)
	_player.global_position = Vector2(700, 1500)
	var sister: Villager = _zone().get_node("Villagers/Fara")
	var tracker: OrdersTracker = _world.get_node("UI/OrdersTracker")
	_check(not sister.is_inside() and sister.get_spot_name() == "Mortar" and not sister.call_out.is_empty()
			and not _zone().get_node("Villagers/Mother").call_out.is_empty()
			and tracker.visible and tracker._reminders.get_child_count() == 1,
		"school: fees overdue, Fara stays home at the mortar on a school day - the family speaks of it, the tracker reminds")
	_set_time(9 * 60)
	await _go_to_zone("village")
	await _frames(3)
	_player.global_position = Vector2(950, 700)
	var teacher := _villager("Hanta")
	var panel: SchoolPanel = _world.get_node("UI/SchoolPanel")
	state.money = FarmSimulation.SCHOOL_FEE + 500
	teacher.interacted.emit()
	await _frames(3)
	var opened := panel.visible and not teacher.is_inside() and teacher.get_spot_name() == "School" 		and teacher.talk_prompt == tr("Payer l'écolage de Fara")
	panel.pay_money_requested.emit()
	await _frames(3)
	var paid := not _sim.is_school_fee_due() and state.money == 500 and panel.visible
	panel.close()
	await _frames(3)
	teacher.interacted.emit()
	await _frames(3)
	_check(opened and paid and not panel.visible and teacher.talk_prompt.is_empty()
			and tracker._reminders.get_child_count() == 0,
		"school: Ramatoa Hanta, at the school, takes the fees - once paid, talking to her is just a chat")
	await _go_to_zone("farm")
	await _frames(3)
	_check(_zone().get_node("Villagers/Fara").get_spot_name() != "Mortar",
		"school: the fees paid, Fara goes back to school")
	state.money = money
	state.clock.current_day = today
	_set_time(10 * 60)

# --- fighting rooster and Sunday tournament ---------------------------------------------

func _test_cockfight() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	var state := _sim.state
	var money := state.money
	var today := state.clock.current_day
	# A Tuesday past Rakoto's first days (day 1 is a Monday): day 9.
	state.clock.current_day = 9
	get_tree().call_group(DayNightController.CALENDAR_GROUP, "set_weekday", state.clock.get_weekday())
	state.orders.erase("rakoto")
	_sim.order_changed.emit("rakoto")
	_set_time(16 * 60 + 30)
	await _go_to_zone("farm")
	await _go_to_zone("village")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	var rakoto := _villager("Rakoto")
	var offered := rakoto.talk_prompt == tr("Écouter Rakoto") and rakoto.call_out == tr(CockfightManager.GIFT_CALL)
	rakoto.interacted.emit()
	await _frames(3)
	_check(offered and _sim.has_rooster() and rakoto.call_out.is_empty() and rakoto.get_node("Bubble").visible,
		"cockfight: Rakoto calls out to the player, and gives them a young fighting rooster")

	await _go_to_zone("farm")
	await _frames(3)
	var rooster := _zone().get_node_or_null("PlayerRooster") as TetheredRooster
	var stake: Marker2D = _zone().get_node("RoosterStake")
	await _frames(120)
	var tethered := rooster != null and rooster.get_rooster_position().distance_to(stake.global_position) <= TetheredRooster.TETHER + 2.0
	var panel: RoosterPanel = _world.get_node("UI/RoosterPanel")
	state.add_inventory("corn", 2)
	_sim.inventory_changed.emit("corn", state.get_inventory_count("corn"))
	rooster.interacted.emit()
	await _frames(3)
	var opened := panel.visible
	panel.feed_requested.emit("corn")
	panel.train_requested.emit()
	await _frames(3)
	var cared := _sim.is_rooster_fed_today() and _sim.is_rooster_trained_today() and panel.visible \
		and not rooster._bubble.visible
	panel.close()
	_check(tethered and opened and cared,
		"cockfight: the rooster is tied at its stake on the farm - fed and trained from its panel")

	_set_weekday(GameClock.Weekday.SUNDAY)
	_set_time(14 * 60 + 30)
	await _go_to_zone("village")
	await _go_to_zone("market_town")
	await _frames(3)
	_player.global_position = Vector2(1056, 900)
	var ring: CockfightRing = _zone().get_node("CockfightRing")
	var crowd := _villager("Rabe").get_spot_name() == "Cockfight_East" and _villager("Ratsimba").get_spot_name() == "Cockfight_West"
	var show_on: bool = ring._show[0].visible and ring._interactable.prompt_message == tr("Inscrire ton coq au tournoi")
	var fight: CockfightPanel = _world.get_node("UI/CockfightPanel")
	money = state.money
	ring.interacted.emit()
	await _frames(3)
	var playing := fight.visible and fight.is_playing()
	await _frames(90) # a blow or two, for real
	fight.skip()
	var done := func() -> bool: return not fight.is_playing()
	var finished := await _wait_for(done, 10.0)
	_check(crowd and show_on and playing and finished and fight._summary.visible
			and _sim.get_cockfight_points("player") >= FarmSimulation.COCKFIGHT_BOUTS
			and state.money == money + FarmSimulation.COCKFIGHT_ENTRY_PRIZE,
		"cockfight: on Sunday afternoon the amateurs gather at the ring - the player's rooster fights 3 bouts, played out")
	fight.close()
	await _frames(3)
	ring.interacted.emit()
	await _frames(3)
	_check(not fight.is_playing() and fight.visible and not fight._fight_box.visible
			and ring._interactable.prompt_message == tr("Voir le classement des coqs"),
		"cockfight: once a Sunday - afterwards, the ring shows the ranking")
	fight.close()

	state.rooster = {}
	state.cockfight_points.clear()
	state.cockfight_entered_day = 0
	state.money = money
	state.clock.current_day = today
	_set_time(10 * 60)

# --- the evening meal ------------------------------------------------------------------------

func _test_evening_meal() -> void:
	var state := _sim.state
	var day := state.day
	await _go_to_zone("player_house")
	await _frames(3)
	# The room's picture is the floor: the player is drawn over it wherever
	# they stand - even in the top half of the room, above its origin.
	var room: Sprite2D = _zone().get_node("Sprite2D")
	_player.global_position = Vector2(60, -110)
	await _frames(2)
	_check(room.z_index < _player.z_index and _zone().y_sort_enabled,
		"house: the player stays in sight at the top of the room (the room's picture is under them)")
	# A day of its own (the tests before filled today's log).
	_sim.day_log = DayLog.new()
	_sim.day_log.add_harvest("bean", 6)
	_sim.day_log.add_money(4500)
	var panel: EveningPanel = _world.get_node("UI/EveningPanel")
	var sleep_spot := _zone().get_node("SleepSpot")
	sleep_spot.sleep_requested.emit()
	await _frames(3)
	var texts := panel._lines.get_children().map(func(row: Node) -> String:
		return " ".join(row.find_children("*", "Label", true, false).map(func(l: Label): return l.text)))
	var told := texts.any(func(text: String): return text.contains("Dada") and text.contains("6 haricots"))
	var at_dinner := panel.visible and get_tree().paused and state.day == day and panel._dish.text.contains("tsaramaso") \
		and told and panel._money.text.contains("4")
	panel._not_yet.pressed.emit()
	await _frames(3)
	var not_yet := not panel.visible and not get_tree().paused and state.day == day
	sleep_spot.sleep_requested.emit()
	await _frames(3)
	panel._sleep.pressed.emit()
	await _frames(3)
	_check(at_dinner and not_yet and not panel.visible and state.day == day + 1 and _sim.day_log.is_quiet(),
		"evening meal: going to bed, the family talks about the day over its dish - 'Pas encore' goes back, 'Dormir' sleeps")
	await _go_to_zone("farm")

# --- saving at bedtime, save slots, title screen -------------------------------------------

const TEST_SAVES := "user://test_saves_behaviour/"

func _test_save_at_bedtime() -> void:
	# Never the player's saves: a test folder, slot 1.
	SaveSlots.dir = TEST_SAVES
	SaveSlots.legacy_path = TEST_SAVES + "savegame.json"
	var save: SaveController = _world.get_node("Gameplay/SaveController")
	save.slot = 0
	SaveSlots.delete(0)
	SaveSlots.delete(1)
	var state := _sim.state
	var day := state.day
	await _go_to_zone("player_house")
	await _frames(3)
	var notified := [""]
	var watch := func(text: String): notified[0] = text
	UIEvents.notification_requested.connect(watch)
	_zone().get_node("SleepSpot").sleep_requested.emit()
	await _frames(3)
	# The evening meal first: "Dormir".
	(_world.get_node("UI/EveningPanel") as EveningPanel).sleep_confirmed.emit()
	await _frames(3)
	UIEvents.notification_requested.disconnect(watch)
	var saved := SaveSlots.read(0)
	_check(state.day == day + 1 and saved.get("day", 0) == day + 1 and saved.get("zone_id", "") == "player_house"
			and notified[0] == tr("Bonne nuit ! La partie est sauvegardée."),
		"save: going to bed saves the new morning in the slot - and says so")
	var money := state.money
	state.money += 777
	save.load_game()
	await _frames(3)
	_check(state.money == money and state.day == day + 1,
		"save: leaving during the day goes back to that morning")

	var layer := CanvasLayer.new()
	add_child(layer)
	var list := SaveSlotsPanel.new()
	layer.add_child(list)
	list.open()
	await _frames(2)
	var cards := list._slots.get_children()
	var first_text := (cards[0].find_children("*", "Label", true, false) as Array).map(func(l): return l.text)
	var shows: bool = cards.size() == SaveSlots.SLOT_COUNT \
		and cards[0].find_child("Play", true, false).text == tr("Continuer") \
		and cards[1].find_child("Play", true, false).text == tr("Nouvelle partie") \
		and first_text.any(func(text: String): return text.contains("jour %d" % state.clock.get_day_of_season()))
	var delete: Button = cards[0].find_child("Delete", true, false)
	delete.pressed.emit()
	var asked := SaveSlots.exists(0)
	delete.pressed.emit()
	await _frames(2)
	_check(shows and asked and not SaveSlots.exists(0)
			and list._slots.get_child(0).find_child("Play", true, false).text == tr("Nouvelle partie"),
		"saves list: a card per slot - the date reached, continue or new game; deleting asks first")
	layer.queue_free()

	var pause: PauseMenu = _world.get_node("UI/PauseMenu")
	pause._open()
	var left := [false]
	var on_leave := func(): left[0] = true
	pause.title_requested.connect(on_leave)
	pause.title_button.pressed.emit()
	var warned := pause.title_button.text == tr(PauseMenu.LEAVE_WARNING)
	pause._close()
	pause.title_requested.disconnect(on_leave)
	_check(warned and not left[0] and pause.title_button.text == tr("Menu principal")
			and not pause.has_node("Panel/VBoxContainer/SaveButton"),
		"pause menu: no save button - leaving for the title screen asks first (the day isn't saved)")

	save.slot = -1
	SaveSlots.delete(0)
	DirAccess.remove_absolute(TEST_SAVES)
	SaveSlots.dir = "user://saves/"
	SaveSlots.legacy_path = "user://savegame.json"
	await _go_to_zone("farm")

# --- family projects ------------------------------------------------------------------------

func _test_family_projects() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(10 * 60)
	var state := _sim.state
	var money := state.money
	var had_coop := state.has_coop
	state.money = 200000
	state.has_coop = true
	await _go_to_zone("village")
	await _go_to_zone("farm")
	await _frames(3)
	_player.global_position = Vector2(700, 1500)
	var father: Villager = _zone().get_node("Villagers/Father")
	var panel: FamilyProjectsPanel = _world.get_node("UI/FamilyProjectsPanel")
	father.interacted.emit()
	await _frames(3)
	var opened := panel.visible and father.talk_prompt == tr("Parler des projets de la famille")
	panel.start_requested.emit("coop_2")
	await _frames(3)
	var started := _sim.get_project_state("coop_2") == FarmSimulation.ProjectState.BUILDING \
		and _zone().get_node_or_null("ConstructionSite") != null and state.money == 200000 - 15000
	panel.close()
	_check(opened and started,
		"family projects: Dada shows the family's projects - starting one puts up a building site at the coop")
	# The work done; on the farm again, the buildings at their new level.
	state.construction["done_day"] = state.day
	_sim._advance_projects()
	state.building_levels["zebu_pen"] = 2
	var granary_before: HouseAnnex = _zone().get_node("Granary")
	var unbuilt := not granary_before.is_built() and not granary_before._sprite.visible
	state.building_levels["granary"] = 1
	state.building_levels["kitchen"] = 1
	await _go_to_zone("village")
	await _go_to_zone("farm")
	await _frames(3)
	var coop: Coop = _zone().get_node("ChickenCoopBuilding")
	var pen: ZebuPen = _zone().get_node("ZebuPen")
	_check(_sim.get_building_level("coop") == 2 and state.coop_capacity == 8 and coop._level_sprite != null
			and coop._level_sprite.visible and not coop.get_node("WallSprite").visible
			and pen.scene_file_path.ends_with("zebu_pen_2.tscn") and pen.get_node("Spots").get_child_count() == 6
			and _zone().get_node_or_null("ConstructionSite") == null,
		"family projects: done - the coop rebuilt bigger, the zebu pen grown to its level's size")
	# The house's annexes: the kitchen cooks.
	var kitchen: HouseAnnex = _zone().get_node("Kitchen")
	var cooking: CookingPanel = _world.get_node("UI/CookingPanel")
	state.add_inventory("corn", 3)
	_sim.inventory_changed.emit("corn", state.get_inventory_count("corn"))
	var dishes := state.get_inventory_count("food_grilled_corn")
	kitchen.interacted.emit()
	await _frames(3)
	var opened_kitchen := cooking.visible
	cooking.cook_requested.emit("grilled_corn", 1)
	await _frames(3)
	cooking.close()
	_check(unbuilt and kitchen.is_built() and (_zone().get_node("Granary") as HouseAnnex).is_built()
			and opened_kitchen and state.get_inventory_count("food_grilled_corn") == dishes + 1,
		"family projects: the granary and the kitchen appear once built - the kitchen cooks the harvest")
	# Inside the enlarged coop: a bigger room, everything placed from its size.
	await _go_to_zone("chicken_coop")
	await _frames(3)
	var room: CoopInterior = _zone().get_node("CoopInterior")
	var floor_rect := room.get_floor()
	var hens: Control = _zone().get_node("ChickenArea")
	var door: Node2D = _zone().get_node("ExitDoor")
	_check(floor_rect.size == Vector2(CoopInterior.LEVELS[2]["cells"] * CoopInterior.TILE)
			and floor_rect.encloses(hens.get_rect()) and door.position.y > floor_rect.end.y
			and (_zone() as ZoneRoot).camera_limit_right >= floor_rect.end.x
			and floor_rect.size.x > Vector2(CoopInterior.LEVELS[1]["cells"] * CoopInterior.TILE).x,
		"family projects: the coop's inside grows with it - a bigger room, its door, bowls and hens' area placed from its size")
	await _go_to_zone("farm")
	state.building_levels.clear()
	state.construction = {}
	state.coop_capacity = FarmSimulation.COOP_CAPACITY_BY_LEVEL[1]
	state.has_coop = had_coop
	CoopInterior.level = _sim.get_building_level("coop")
	state.money = money
	await _go_to_zone("village")

# --- the forest and the notebook ------------------------------------------------------------

func _test_forest() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	var state := _sim.state
	var day := state.clock.current_day
	state.clock.current_day = 1 # Asara
	_set_time(7 * 60 + 30)
	await _go_to_zone("village")
	_player.global_position = Vector2(2240, 990)
	_player.auto_walk_to(Vector2(2400, 990), 4.0)
	var in_forest := func() -> bool: return _wm.current_zone_id == "forest"
	_check(await _wait_for(in_forest, 5.0),
		"forest: the village's east edge leads into the forest")
	var walk_done := func() -> bool: return not _player.is_auto_walking()
	await _wait_for(walk_done, 5.0)
	await _frames(5)
	_player.global_position = Vector2(700, 1300)
	var sifaka: WildAnimal = _zone().get_node("Wildlife/Sifaka")
	var tenrec: WildAnimal = _zone().get_node("Wildlife/Tenrec")
	var dawn := sifaka.is_present() and not tenrec.is_present()
	_set_time(23 * 60)
	await _frames(3)
	var night := not sifaka.is_present() and tenrec.is_present()
	_set_time(7 * 60 + 30)
	await _frames(3)
	var pages := _sim.get_notebook_progress().x
	sifaka.observed.emit()
	var greens: ForageSpot = _zone().get_node("WildPlants/Greens_2")
	var bag := state.get_inventory_count("wild_greens")
	greens.gathered.emit()
	await _frames(3)
	_check(dawn and night and _sim.is_discovered("sifaka") and state.get_inventory_count("wild_greens") > bag
			and _sim.is_discovered("wild_greens") and not greens._interactable.is_interactable
			and _sim.get_notebook_progress().x == pages + 2,
		"forest: the sifaka at dawn, the tenrec at night - watching one, gathering greens: new pages in the notebook")
	_player.global_position = Vector2(840, 700)
	var clearing := func() -> bool: return _sim.is_discovered("clearing")
	_check(await _wait_for(clearing, 2.0), "forest: walking into the clearing finds it")
	var inventory: InventoryUI = _world.get_node("UI/InventoryUI")
	inventory.open()
	await _frames(20)
	inventory._select_category(InventoryCatalog.Category.NOTEBOOK)
	await _frames(5)
	var notebook: Array = inventory._collect_items()[InventoryCatalog.Category.NOTEBOOK]
	var named: Array = notebook.map(func(entry): return entry.info["name"])
	inventory.close()
	await _frames(20)
	_check(notebook.size() == _sim.get_notebook_progress().y and named.has("Sifaka · Simpona") and named.has("???"),
		"notebook: the inventory's Carnet tab - every page, the found ones drawn, the others still '???'")
	for id in ["sifaka", "wild_greens", "clearing"]:
		state.discoveries.erase(id)
	state.forage.clear()
	state.clock.current_day = day
	_set_time(10 * 60)
	await _go_to_zone("village")

# --- side quests ----------------------------------------------------------------------------

func _test_quests() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	var state := _sim.state
	var money := state.money
	var friendship := _sim.get_friendship("rakoto")
	var greens := state.get_inventory_count("wild_greens")
	var today := _set_weekday(GameClock.Weekday.TUESDAY)
	state.clock.current_day = maxi(state.clock.current_day, 3)
	_sim.day_log = DayLog.new()
	_set_time(10 * 60)
	await _go_to_zone("rice_fields")
	_sim.quest_changed.emit("") # the morning's new quests
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	var rakoto := _villager("Rakoto")
	var offered := rakoto._mark.visible and rakoto._mark.text == "!" \
		and rakoto._mark.label_settings.font_color == QuestManager.MARK_COLOR
	var panel: QuestPanel = _world.get_node("UI/QuestPanel")
	rakoto.interacted.emit()
	await _frames(2)
	var panel_open := panel.is_open() and get_tree().paused and panel._title.text == "Le zébu perdu"
	panel._accept.pressed.emit()
	await _frames(2)
	var tracker: OrdersTracker = _world.get_node("UI/OrdersTracker")
	_check(offered and panel_open and not get_tree().paused and _sim.is_quest_active("rakoto_lost_zebu")
			and tracker._quests.get_child_count() == 2 and tracker.visible
			# His quest mark gone (an order's gold "!" may show again).
			and not (rakoto._mark.visible and rakoto._mark.label_settings.font_color == QuestManager.MARK_COLOR),
		"quests: a cyan '!' over Rakoto - talking to him tells his lost zebu, accepted: in the tracker with its first step")

	await _go_to_zone("forest")
	await _frames(3)
	var tracks: QuestTarget = _zone().get_node("QuestTargets/ZebuTracks")
	var zebu: QuestTarget = _zone().get_node("QuestTargets/LostZebu")
	var first := tracks.visible and not zebu.visible
	_player.global_position = tracks.global_position
	var at_tracks := func() -> bool: return _sim.get_quest_step_index("rakoto_lost_zebu") == 1
	var followed := await _wait_for(at_tracks, 2.0)
	await _frames(2)
	_check(first and followed and zebu.visible and not tracks.visible,
		"quests: in the forest, hoof prints by the ford - walking over them, the zebu appears by the old amontana")
	state.inventory.erase("wild_greens")
	zebu.triggered.emit()
	await _frames(2)
	zebu.triggered.emit() # no greens yet
	await _frames(2)
	var waiting := _sim.get_quest_step_index("rakoto_lost_zebu") == 2
	state.add_inventory("wild_greens", 2)
	_sim.inventory_changed.emit("wild_greens", 2)
	zebu.triggered.emit()
	await _frames(2)
	_check(waiting and _sim.get_quest_step_index("rakoto_lost_zebu") == 3 and not zebu.visible
			and state.get_inventory_count("wild_greens") == 0,
		"quests: the zebu shies away until it's given 2 wild greens - then it goes home")

	await _go_to_zone("rice_fields")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	rakoto = _villager("Rakoto")
	var ready := rakoto._mark.visible and rakoto._mark.text == "?"
	rakoto.interacted.emit()
	await _frames(2)
	var evening: EveningManager = _world.get_node("Gameplay/EveningManager")
	var told := evening.get_lines().any(func(line: Dictionary) -> bool: return "Volamena" in line["text"])
	_check(ready and _sim.is_quest_done("rakoto_lost_zebu") and state.money == money + 10000
			and rakoto._bubble.visible and tracker._quests.get_child_count() == 0 and told,
		"quests: back to Rakoto ('?'): 10 000 Ar, his thanks - and Dada tells it at dinner")
	await _go_to_zone("village")
	await _frames(3)
	_check((_zone().get_node("QuestTargets/Volamena") as QuestTarget).visible,
		"quests: once found, Volamena grazes by Rakoto's house in the village")

	state.quests_done.erase("rakoto_lost_zebu")
	state.friendship["rakoto"] = friendship
	state.money = money
	state.inventory.erase("wild_greens")
	if greens > 0:
		state.add_inventory("wild_greens", greens)
	_sim.day_log = DayLog.new()
	state.clock.current_day = today
	_sim.quest_changed.emit("")
	_set_time(10 * 60)
	await _frames(3)

func _test_more_quests() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	var state := _sim.state
	var friendship := _sim.get_friendship("neny_soa")
	var koto_friendship := _sim.get_friendship("koto")
	var had_sifaka := _sim.is_discovered("sifaka")
	var today := _set_weekday(GameClock.Weekday.SATURDAY)
	state.clock.current_day = maxi(state.clock.current_day, 6)
	state.friendship["neny_soa"] = maxi(friendship, 100)
	_sim.day_log = DayLog.new()
	_set_time(10 * 60)
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	_sim.quest_changed.emit("")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	var grandmother := _villager("NenySoa")
	var koto := _villager("Koto")
	var marks := grandmother._mark.text == "!" and koto._mark.text == "!" \
		and grandmother._mark.label_settings.font_color == QuestManager.MARK_COLOR
	var panel: QuestPanel = _world.get_node("UI/QuestPanel")
	grandmother.interacted.emit()
	await _frames(2)
	var told := panel.is_open() and panel._title.text == "La tisane de Neny Soa"
	panel._accept.pressed.emit()
	await _frames(2)
	_check(marks and told and _sim.is_quest_active("neny_soa_remedy"),
		"quests: Neny Soa (a heart of friendship) and Koto each have a quest - Neny Soa tells hers: her remedy")

	await _go_to_zone("forest")
	await _frames(3)
	var jar: QuestTarget = _zone().get_node("QuestTargets/NenySoaJar")
	var base: CollisionShape2D = jar.get_node("WaterJar/Base/CollisionShape2D")
	var there := jar.visible and not base.disabled
	jar.triggered.emit()
	await _frames(3)
	_check(there and not jar.visible and base.disabled and _sim.get_quest_waiting_on("neny_soa") == "neny_soa_remedy",
		"quests: Neny Soa's jar by the forest spring - filled, it's gone, and its base no longer in the way")

	await _go_to_zone("village")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	grandmother = _villager("NenySoa")
	state.inventory.erase("ravintsara")
	grandmother.interacted.emit()
	await _frames(2)
	var waiting := _sim.is_quest_active("neny_soa_remedy") and grandmother._bubble.visible
	state.add_inventory("ravintsara", 1)
	_sim.inventory_changed.emit("ravintsara", 1)
	await _frames(2)
	var ready := grandmother._mark.text == "?"
	grandmother.interacted.emit()
	await _frames(2)
	_check(waiting and ready and _sim.is_quest_done("neny_soa_remedy") and state.get_inventory_count("food_mofo_gasy") >= 3,
		"quests: without a ravintsara leaf she waits for one - with it ('?'), the remedy's made: 3 mofo gasy")

	_sim.discover("sifaka")
	_sim.start_quest("koto_dancing_sifaka")
	await _go_to_zone("farm")
	await _frames(3)
	_player.global_position = Vector2(300, 300)
	var fara := _villager("Fara")
	var asked := fara._mark.text == "?" and fara._mark.label_settings.font_color == QuestManager.MARK_COLOR
	fara.interacted.emit()
	await _frames(2)
	await _go_to_zone("village")
	await _frames(3)
	koto = _villager("Koto")
	var to_koto := koto._mark.text == "?"
	koto.interacted.emit()
	await _frames(2)
	_check(asked and to_koto and _sim.is_quest_done("koto_dancing_sifaka") and koto._bubble.visible,
		"quests: Koto's sifaka seen - Fara draws it for him ('?' over her at the farm), Koto gets the drawing")

	for quest_id in ["neny_soa_remedy", "koto_dancing_sifaka"]:
		state.quests_done.erase(quest_id)
	state.friendship["neny_soa"] = friendship
	state.friendship["koto"] = koto_friendship
	if not had_sifaka:
		state.discoveries.erase("sifaka")
	state.inventory.erase("ravintsara")
	_sim.day_log = DayLog.new()
	state.clock.current_day = today
	_sim.quest_changed.emit("")
	_set_time(10 * 60)
	await _frames(3)

# --- chicken thieves ----------------------------------------------------------------------------

func _test_chicken_thieves() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	var state := _sim.state
	var day := state.clock.current_day
	var money := state.money
	var had_coop := state.has_coop
	var animals := state.animals.duplicate()
	state.has_coop = true
	state.animals.clear()
	for i in 3:
		var hen_id := state.generate_animal_id(AnimalData.Species.CHICKEN)
		state.animals[hen_id] = AnimalState.new(hen_id, AnimalData.Species.CHICKEN)
	state.clock.current_day = maxi(day, 20)
	state.thief_next_alert_day = 0
	_sim.thief_alert_chance = 1.0
	_sim.thief_night_chance = 1.0
	_set_time(10 * 60)
	await _go_to_zone("farm")
	await _frames(3)
	_sim.day_log = DayLog.new()
	_sim._advance_thieves() # the morning's rumour
	var evening: EveningManager = _world.get_node("Gameplay/EveningManager")
	var warned := _sim.is_thief_alert() and evening.get_lines().any(
		func(line: Dictionary) -> bool: return "cadenas" in line["text"])
	state.clock.current_day += 1
	_sim.day_log = DayLog.new()
	_sim._advance_thieves() # the night
	_sim.day_changed.emit(state.clock.current_day)
	await _frames(3)
	var coop: Coop = get_tree().get_first_node_in_group(Coop.GROUP)
	var told := evening.get_lines().any(func(line: Dictionary) -> bool: return "voleur" in line["text"])
	_check(warned and _sim.get_hen_ids().size() == 2 and coop.get_node_or_null("Feathers") is ScatteredFeathers and told,
		"chicken thieves: a rumour (Neny talks of a padlock at dinner) - the night after, a hen gone, feathers by the coop, Dada tells it")

	var shop: ShopUI = _world.get_node("UI/ShopUI")
	shop._selected_category = ItemData.Category.TOOLS
	shop._rebuild_item_grid()
	await _frames(1)
	var on_shelf := func() -> bool:
		return shop.item_grid.get_children().any(func(card) -> bool:
			return not card.is_queued_for_deletion() and card._item.id == FarmSimulation.PADLOCK_ITEM)
	var offered: bool = on_shelf.call()
	state.money = maxi(state.money, 10000)
	_world.get_node("Gameplay/ShopController").buy_item(FarmSimulation.PADLOCK_ITEM, 5000)
	await _frames(2)
	_check(offered and not on_shelf.call() and coop.get_node_or_null("Padlock") is CoopPadlock,
		"chicken thieves: a padlock on the market's shelf - bought, it's on the coop's door and off the shelf")

	state.thief_next_alert_day = 0
	_sim._advance_thieves()
	state.clock.current_day += 1
	_sim.day_log = DayLog.new()
	_sim._advance_thieves()
	_sim.day_changed.emit(state.clock.current_day)
	await _frames(3)
	_check(_sim.get_hen_ids().size() == 2 and _sim.day_log.thieves_foiled and coop.get_node_or_null("Feathers") == null,
		"chicken thieves: they come back - the padlock holds, no hen lost")

	_sim.thief_alert_chance = FarmSimulation.THIEF_ALERT_CHANCE
	_sim.thief_night_chance = FarmSimulation.THIEF_NIGHT_CHANCE
	state.animals = animals
	state.has_coop = had_coop
	state.coop_padlock = false
	state.thief_alert_until = 0
	state.thief_next_alert_day = 0
	state.thief_stolen_day = 0
	state.thief_rumour = ""
	state.money = money
	state.clock.current_day = day
	_sim.day_log = DayLog.new()
	_sim.day_changed.emit(day)
	_set_time(10 * 60)
	await _go_to_zone("village")

# --- home screen ----------------------------------------------------------------------------

func _test_home_screen() -> void:
	SaveSlots.dir = TEST_SAVES
	SaveSlots.legacy_path = TEST_SAVES + "savegame.json"
	for slot in SaveSlots.SLOT_COUNT:
		SaveSlots.delete(slot)
	SaveSlots.write(1, {"day": 12, "money": 100})
	var home: HomeScreen = load("res://ui/home/home_screen.tscn").instantiate()
	add_child(home)
	await _frames(5)
	var scene_ok := home.find_child("Campfire", true, false) is Campfire \
		and home.find_child("FiresidePlayer", true, false) is FiresidePlayer \
		and get_viewport().get_camera_2d().get_parent() == home
	var lanterns := get_tree().get_nodes_in_group(DayNightController.LIGHT_GROUP).filter(
		func(node): return node is NightLight and home.is_ancestor_of(node))
	var lit := lanterns.all(func(light: NightLight): return light.visible)
	var menu := not home._continue.disabled and home.first_free_slot() == 0
	home._continue.pressed.emit()
	await _frames(2)
	var saves_open := home._saves.visible and not home._menu.visible
	home._saves.close()
	await _frames(2)
	home.find_child("Settings", true, false).pressed.emit()
	await _frames(2)
	var settings_open := home._settings.visible and not home._menu.visible
	home._settings.close()
	SaveSlots.delete(1)
	home._refresh()
	_check(scene_ok and lit and menu and saves_open and settings_open and home._menu.visible
			and home._continue.disabled,
		"home screen: night in the village, the player by a campfire - Continuer (the games), Nouveau jeu, Paramètres")
	home.queue_free()
	DirAccess.remove_absolute(TEST_SAVES)
	SaveSlots.dir = "user://saves/"
	SaveSlots.legacy_path = "user://savegame.json"
	await _frames(2)

# --- market town and weekly market ---------------------------------------------------------

func _test_market_town() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(10 * 60)
	var today := _set_weekday(GameClock.Weekday.TUESDAY)
	await _go_to_zone("village")
	_player.global_position = Vector2(1585, 1480)
	_player.auto_walk_to(Vector2(1585, 1720), 6.0)
	var in_market_town := func() -> bool: return _wm.current_zone_id == "market_town"
	var market_town_loaded := func() -> bool: return _wm.current_zone_id == "market_town" and _zone().name == "MarketTown"
	_check(await _wait_for(in_market_town, 7.0) and await _wait_for(market_town_loaded, 5.0),
		"market town: the village's south road leads to the market town")
	# Let the walk that brought the player here run out.
	var walk_done := func() -> bool: return not _player.is_auto_walking()
	await _wait_for(walk_done, 8.0)
	await _frames(5)
	# The river stops the player; the bridge crosses it.
	_player.global_position = Vector2(600, 250)
	_player.auto_walk_to(Vector2(600, 560), 2.0)
	await _frames(130)
	var stopped_y := _player.global_position.y
	_player.global_position = Vector2(1056, 250)
	_player.auto_walk_to(Vector2(1056, 600), 3.0)
	await _frames(190)
	_check(stopped_y < 340.0 and _player.global_position.y > 560.0,
		"market town: the river can't be waded across, the bridge crosses it")
	_player.global_position = Vector2(300, 1500)
	# Not market day: the collector's stall is shut, the merchants about.
	var stall: Shop = _zone().get_node("Props/Market_Collector")
	var shop_ui: ShopUI = _world.get_node("UI/ShopUI")
	stall.get_node("InteractableComponent").interacted.emit()
	await _frames(3)
	_check(not stall.is_open() and not shop_ui.visible and _villager("Rabe").get_spot_name() == "Taxi"
			and _villager("Lalao").get_spot_name() == "WashingStones" and _villager("Ravao").is_inside(),
		"market town: on Tuesday the weekly market is shut, Rabe waits at the taxi, Lalao washes at the river, Ravao is in the village")
	# Market day.
	_set_weekday(GameClock.Weekday.FRIDAY)
	await _go_to_zone("village")
	await _go_to_zone("market_town")
	await _frames(3)
	_check(_villager("Rabe").get_spot_name() == "Market_Collector" and _villager("Lalao").get_spot_name() == "Market_Vegetables_1"
			and not _villager("Ravao").is_inside() and _villager("Ravao").get_spot_name() == "Market_Cloth_1",
		"market town: on market day, the merchants are at their stalls - Ravao came down from the village")
	stall = _zone().get_node("Props/Market_Collector")
	stall.get_node("InteractableComponent").interacted.emit()
	await _frames(3)
	var seeds: Array = shop_ui._catalog[ItemData.Category.SEEDS]
	var tools_button: CategoryButton = shop_ui.category_row.get_child(1)
	_check(shop_ui.visible and shop_ui.get_profile().sell_multiplier > 1.0
			and seeds.any(func(item: ItemData) -> bool: return item.crop_id == "vanilla")
			and not tools_button.visible,
		"weekly market: it opens on market day, with the export crops' seeds and no tools")
	_sim.state.add_inventory("corn", 2)
	var money := _sim.state.money
	var corn_seed: ItemData = seeds.filter(func(item: ItemData) -> bool: return item.crop_id == "corn")[0]
	shop_ui._on_sell_requested(corn_seed, 2)
	_check(_sim.state.money - money == 2 * roundi(_sim.get_crop_data("corn").sell_price * 1.25),
		"weekly market: harvests sell for 25 % more")
	shop_ui.close()
	await _frames(20)
	# The village grocery doesn't take export crops.
	shop_ui.open(Shop.DEFAULT_PROFILE)
	await _frames(3)
	var village_seeds: Array = shop_ui._catalog[ItemData.Category.SEEDS]
	_check(not village_seeds.any(func(item: ItemData) -> bool: return item.crop_id == "vanilla")
			and village_seeds.any(func(item: ItemData) -> bool: return item.crop_id == "rice"),
		"village shop: everyday seeds only - vanilla and cloves are bought and sold at the weekly market")
	shop_ui.close()
	await _frames(20)
	_sim.state.clock.current_day = today
	await _go_to_zone("village")

# --- zebu market and the player's zebus ------------------------------------------

func _test_zebu_market() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(10 * 60)
	var today := _set_weekday(GameClock.Weekday.WEDNESDAY)
	await _go_to_zone("village")
	await _go_to_zone("market_town")
	await _frames(5)
	# The village's hill walls overlap the market town's spawn: they must be gone
	# from the physics space the moment the market town is set up.
	_check(_wm.current_zone_id == "market_town"
			and _player.global_position.distance_to(_zone().get_node("Spawns/SpawnDefault").global_position) < 2.0,
		"zones: arriving in a zone, the player isn't pushed out by the walls of the zone left behind")
	var herd: MarketDayOnly = _zone().get_node("ZebuHerd")
	var stand: ZebuMarket = _zone().get_node("ZebuMarket")
	var panel: ZebuMarketPanel = _world.get_node("UI/ZebuMarketPanel")
	stand.get_node("InteractableComponent").interacted.emit()
	await _frames(3)
	_check(herd.get_child_count() == 0 and not herd.is_market_on() and not stand.is_open() and not panel.visible,
		"zebu market: on Wednesday the corral is empty and the dealer's stand shut")
	_set_weekday(GameClock.Weekday.FRIDAY)
	await _go_to_zone("village")
	await _go_to_zone("market_town")
	await _frames(5)
	herd = _zone().get_node("ZebuHerd")
	stand = _zone().get_node("ZebuMarket")
	_check(herd.get_child_count() == 3 and _villager("Ratsimba").get_spot_name() == "ZebuMarket",
		"zebu market: on market day, zebus for sale in the corral, Ratsimba at his stand")
	_sim.state.money = 100000
	stand.get_node("InteractableComponent").interacted.emit()
	await _frames(3)
	var opened := panel.visible
	panel.buy_requested.emit()
	await _frames(3)
	var ids := _sim.get_zebu_ids()
	_check(opened and ids.size() == 1 and _sim.state.money == 100000 - FarmSimulation.ZEBU_PRICE,
		"zebu market: the stand opens the market, and a young zebu is bought")
	panel.close()
	await _frames(3)
	# On the farm: in the pen's pasture, the trough to fill, penned at night.
	await _go_to_zone("farm")
	await _frames(5)
	var zebus: Node2D = _zone().get_node("PlayerZebus")
	var trough: ZebuTrough = _zone().get_node("ZebuTrough")
	var mine: GrazingZebu = zebus.get_child(0) if zebus.get_child_count() > 0 else null
	_check(zebus.get_child_count() == 1 and mine.coat == _sim.get_zebu(ids[0])["coat"]
			and not trough.is_full() and trough.get_node("InteractableComponent").is_interactable,
		"farm: the bought zebu grazes on the farm, its trough waiting to be filled")
	trough.interacted.emit()
	await _frames(3)
	_check(_sim.is_zebu_trough_full() and trough.is_full()
			and not trough.get_node("InteractableComponent").is_interactable,
		"farm: filling the trough shows it full, once for the day")
	_set_time(20 * 60)
	await _go_to_zone("village")
	await _go_to_zone("farm")
	await _frames(5)
	mine = _zone().get_node("PlayerZebus").get_child(0)
	_check(mine.has_pen() and mine.is_penned(), "farm: at night the player's zebu sleeps in the farm pen")
	# Sold back at market day.
	_set_time(10 * 60)
	await _go_to_zone("market_town")
	await _frames(3)
	var money := _sim.state.money
	var value := _sim.get_zebu_value(ids[0])
	panel.sell_requested.emit(ids[0])
	await _frames(3)
	_check(_sim.get_zebu_ids().is_empty() and _sim.state.money == money + value,
		"zebu market: a zebu sells back at its worth")
	if panel.visible:
		panel.close()
	_sim.state.clock.current_day = today
	await _go_to_zone("village")

func _test_zebu_plough() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(9 * 60)
	await _go_to_zone("farm")
	await _frames(3)
	var controller: FarmingController = _world.get_node("Gameplay/FarmingController")
	var hotbar: Hotbar = _world.get_node("Gameplay/Hotbar")
	_sim.state.add_inventory("tool_plough", 1)
	hotbar.assign("tool_plough", 7)
	hotbar.select(7)
	# Four fallow plots in a row, west to east.
	var first := -1
	for plot_id: int in _sim.get_all_plot_ids():
		if _sim.get_plot_zone(plot_id) != "farm":
			continue
		var cell := _sim.get_plot_position(plot_id)
		var row_ok := true
		for dx in 4:
			var other := _sim.get_plot_id_at(cell.x + dx, cell.y, "farm")
			row_ok = row_ok and other != -1 and _sim.is_ploughable(other)
		if row_ok:
			first = plot_id
			break
	var view := controller.farm_view
	var rect := view.get_plot_global_rect(first)
	_player.global_position = Vector2(rect.position.x - 20, rect.get_center().y + 10)
	_player.last_facing_direction = Vector2.RIGHT
	await _frames(2)
	# Without a team: refused.
	controller._on_use_item_requested()
	await _frames(3)
	_check(first != -1 and not controller.is_ploughing() and not _sim.get_plot(first).tilled,
		"plough: refused without a pair of strong zebus")
	_sim.state.money = 100000
	for coat in [0, 3]:
		var zebu_id := _sim.buy_zebu(coat)
		_sim.state.zebus[zebu_id]["grown_days"] = FarmSimulation.ZEBU_WORK_MIN_DAYS
	_player.global_position = Vector2(rect.position.x - 20, rect.get_center().y + 10)
	_player.last_facing_direction = Vector2.RIGHT
	await _frames(2)
	controller._on_use_item_requested()
	await _frames(10)
	var team := _zone().get_node_or_null("PloughTeam")
	var started := controller.is_ploughing() and team != null
	var done := func() -> bool: return not controller.is_ploughing()
	await _wait_for(done, 15.0)
	var cell := _sim.get_plot_position(first)
	var tilled := 0
	for dx in 4:
		if _sim.get_plot(_sim.get_plot_id_at(cell.x + dx, cell.y, "farm")).tilled:
			tilled += 1
	await _frames(40)
	_check(started and tilled == 4 and _sim.state.plough_cells_today == 4
			and _zone().get_node_or_null("PloughTeam") == null and _player.input_enabled,
		"plough: the zebu team tills four plots in a row, the player following, then leaves")
	for zebu_id: String in _sim.get_zebu_ids():
		_sim.sell_zebu(zebu_id)
	hotbar.select(0)

func _test_zebu_manure() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(9 * 60)
	await _go_to_zone("farm")
	await _frames(3)
	var heap: ManureHeap = _zone().get_node("ManureHeap")
	var empty_at_first: bool = heap.get_amount() == 0 and not heap.get_node("Sprite2D").visible
	_sim.state.money = 100000
	_sim.buy_zebu(0)
	_sim.buy_zebu(4)
	_sim.fill_zebu_trough()
	_sim.advance_day()
	_set_time(9 * 60)
	await _frames(3)
	_check(empty_at_first and heap.get_amount() == 2 and heap.get_node("Sprite2D").visible
			and heap.get_node("InteractableComponent").is_interactable,
		"manure: the cared-for zebus leave a heap by the pen overnight")
	var before := _sim.state.get_inventory_count(FarmSimulation.MANURE_ITEM)
	heap.interacted.emit()
	await _frames(3)
	_check(_sim.state.get_inventory_count(FarmSimulation.MANURE_ITEM) == before + 2 and heap.get_amount() == 0
			and not heap.get_node("Sprite2D").visible,
		"manure: picking up the heap takes it all")
	# Spread on a tilled plot, from the hotbar.
	var controller: FarmingController = _world.get_node("Gameplay/FarmingController")
	var hotbar: Hotbar = _world.get_node("Gameplay/Hotbar")
	hotbar.assign(FarmSimulation.MANURE_ITEM, 6)
	hotbar.select(6)
	var target := -1
	for plot_id: int in _sim.get_all_plot_ids():
		var plot := _sim.get_plot(plot_id)
		if _sim.get_plot_zone(plot_id) == "farm" and plot.tilled and plot.crop == null and not plot.fertilized:
			target = plot_id
			break
	var view := controller.farm_view
	var rect := view.get_plot_global_rect(target)
	_player.global_position = Vector2(rect.position.x - 20, rect.get_center().y + 10)
	_player.last_facing_direction = Vector2.RIGHT
	await _frames(2)
	controller._on_use_item_requested()
	await _frames(20)
	var plot_view: PlotView = view._plot_views[target]
	_check(_sim.get_plot(target).fertilized and plot_view.is_manure_shown()
			and _sim.state.get_inventory_count(FarmSimulation.MANURE_ITEM) == before + 1,
		"manure: spread on a tilled plot, it shows on the soil")
	for zebu_id: String in _sim.get_zebu_ids():
		_sim.sell_zebu(zebu_id)
	hotbar.select(0)

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
