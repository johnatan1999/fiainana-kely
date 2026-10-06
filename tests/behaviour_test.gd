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
	_check(not ravao.is_inside() and ravao.global_position.distance_to(roads.get_spot("Marche")) < 60.0
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
	await _go_to_zone("rice_fields")
	await _go_to_zone("village")
	await _frames(3)
	var koto := _villager("Koto")
	_check(not koto.is_inside(), "villagers: the child plays on the square in the morning")
	_sim.set_weather(FarmState.Weather.RAIN)
	var sheltered := func() -> bool: return koto.is_inside()
	_check(await _wait_for(sheltered, 60.0) and not _villager("Ravao").is_inside(),
		"villagers: when it rains the child runs home, the merchant keeps her (covered) stall")
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

func _test_farmers_in_the_rice_fields() -> void:
	_sim.set_weather(FarmState.Weather.CLEAR)
	_set_time(9 * 60)
	await _go_to_zone("village")
	await _go_to_zone("rice_fields")
	await _frames(3)
	_player.global_position = Vector2(300, 300) # off their road (the spawn is on it)
	var paddy: VillagePaddy = _zone().get_node("RizieresVoisins/Riziere1")
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
	paddy.set_date(3, GameClock.Season.ASARA)
	var young := paddy.get_stage()
	paddy.set_date(25, GameClock.Season.ASARA)
	_check(young == 1 and paddy.get_stage() == 3, "farmers: the neighbours' rice grows over the season")
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
			and rakoto.global_position.distance_to(VillagerRoads.of_zone(_zone()).get_spot("Vers_rice_fields")) < 80.0,
		"farmers: he comes in by the road from the rice fields")
	_set_time(10 * 60)

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
