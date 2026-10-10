extends SceneTree

## The forest (zone "forest", ala), east of the village: a big, closed
## woodland to get lost in a little - a maze of narrow paths between walls of
## thicket, opening onto glades. Builds:
## 1. world/areas/exterior/forest.tscn, from the tables and a seeded maze:
##    - the walls: a maze (MAZE_*) of winding corridors, a few loops and dead
##      ends; then the open places carved into it (REGIONS: the forest's edge
##      by the village, the clearing, the spring, the old sacred fig, small
##      glades), and the stream from the spring to the south edge, crossed
##      only at the ford;
##    - ThicketLayer: a clump of leaves on every wall cell (collision,
##      y-sorted - tools/placeholder_art/gen_thicket.gd), trees along the
##      walls' edges;
##    - the trail (bare ground): the beaten path from the village to the
##      clearing, the ford and the sacred fig, and on to the spring - the
##      shortest way through the maze - with a branch to every glade and
##      the spring, signboards where they fork, and signs home (TANÀNA);
##    - the animals to watch (WildAnimal), the wild plants (ForageSpot), the
##      places to find (DiscoveryPlace) - some at the end of dead ends;
##    - sunlight in the glades (Sunbeam), the canopy's shade (ZoneRoot.shade);
##    - Anchors: markers for what other tools place (the quests' targets);
##    - the way back west to the village; and its ZoneData;
## 2. in the village, the way east to the forest (ToForest,
##    SpawnFrom_FOREST) and its signboard, if they aren't there yet.
## The scene is built once: afterwards it's edited in the editor, and this
## refuses to overwrite it - unless run with "-- --force" (which rebuilds it,
## losing editor changes; then run tools/place_quest_targets.gd again). See
## docs/forest.md. Run with --editor (see CLAUDE.md):
##   godot --headless --editor --path . --script res://tools/build_forest.gd

const FOREST := "res://world/areas/exterior/forest.tscn"
const VILLAGE := "res://world/areas/exterior/player_village.tscn"
const ZONE_DATA := "res://data/world_zones/forest.tres"
const ZONE_SCRIPT := "res://world/zone_root.gd"
const GROUND_SCRIPT := "res://environment/ground/ground_layer.gd"
const GROUND_TEXTURE := "res://assets/tileset/farm01_48.png"
const FARM_TILESET := "res://assets/tileset/farm_tileset.tres"
const WATER_TILESET := "res://assets/tileset/water_tileset.tres"
const THICKET_TEXTURE := "res://assets/tileset/thicket.png"
const THICKET_TILESET := "res://assets/tileset/thicket_tileset.tres"
const STREAM_MATERIAL := "res://environment/water/stream_water_material.tres"
const TALL_GRASS_TILESET := "res://assets/tileset/tall_grass_tileset.tres"
const TALL_GRASS_MATERIAL := "res://environment/grass/tall_grass_material.tres"
const TALL_GRASS_SCRIPT := "res://environment/grass/tall_grass_layer.gd"
const TRANSITION_SCRIPT := "res://components/zone_transition.gd"
const AMBIENT_SCRIPT := "res://environment/ambient/ambient_life.gd"
const SUNBEAM_SCRIPT := "res://environment/lighting/sunbeam.gd"
const WORLD_TREE := "res://entities/trees/world_tree.tscn"
const EUCALYPTUS := "res://data/trees/eucalyptus.tres"
const MANGO := "res://data/trees/mango_tree.tres"
## The forest's broad-leaved trees: a mango tree's look, no fruit - decor
## (written here). The old sacred fig too: nobody picks its fruit (fady).
const FOREST_TREE := "res://data/trees/forest_tree.tres"
const MANGO_VISUAL := "res://entities/trees/mango/mango_visual.tscn"
## The only fruit trees: a mango tree in each of these glades - about what
## the old, small forest had.
const FRUIT_MANGOS := ["clearing", "glade_south", "edge"]
const SIGNBOARD := "res://entities/props/signboard.tscn"
const REEDS := "res://entities/props/reeds.tscn"
const WILD_ANIMAL := "res://entities/forest/wild_animal.gd"
const FORAGE_SPOT := "res://entities/forest/forage_spot.gd"
const DISCOVERY_PLACE := "res://entities/forest/discovery_place.gd"
const TILE := 48
const GRASS_TERRAIN := 1
const STREAM_TILE := Vector2i(1, 0)
const THICKET_VARIANTS := 10
## Clumps from this variant on are smaller and rounder: for the walls' edges
## and corners, so their outline isn't square.
const THICKET_SMALL_FROM := 6
## Each clump drawn a little off its cell (px, at random): no grid lines.
const THICKET_JITTER := [Vector2i(0, 0), Vector2i(-7, 3), Vector2i(6, -2), Vector2i(-4, -5), Vector2i(5, 4)]
## Under the leaves: the daylight dimmed and green (ZoneRoot.shade).
const SHADE := Color(0.74, 0.84, 0.76)

## The map, in cells: 96 x 72 (4608 x 3456 px).
const SIZE := Vector2i(96, 72)
const SEED := 2024

## The maze: corridors MAZE_PATH cells wide between walls MAZE_WALL thick,
## on a grid of MAZE_CELLS rooms from MAZE_ORIGIN. A random spanning tree
## (every room reachable, one way), then BRAID of its dead ends opened onto
## a neighbour (loops: lost, but never for long), then EROSION of the
## walls' edges (no straight lines in a forest).
const MAZE_PATH := 3
const MAZE_WALL := 2
const MAZE_ORIGIN := Vector2i(2, 2)
const MAZE_CELLS := Vector2i(18, 14)
const BRAID := 0.9
const EROSION := 0.3
## Then the thicket swells into the corridors here and there (where a noise
## is over BULGE): never narrower than two cells, so a way stays a way.
const BULGE := 0.35
## Lone clumps of thicket in the open (glades, wide corridors): where a
## noise is over SHRUBS, away from the trail.
const SHRUBS := 0.42

## Open places carved into the maze: [name, center (cells), radii (cells)].
const REGIONS := {
	"edge": [Vector2(3, 36), Vector2(6, 4.5)],
	"clearing": [Vector2(34, 35), Vector2(8, 6)],
	"spring": [Vector2(60, 9), Vector2(7, 5)],
	"ford": [Vector2(62.5, 36.5), Vector2(5, 3)],
	"sacred_fig": [Vector2(83, 58), Vector2(7, 6)],
	"glade_west": [Vector2(18, 13), Vector2(4.5, 3.5)],
	"glade_hive": [Vector2(80, 18), Vector2(4.5, 3.5)],
	"glade_south": [Vector2(36, 61), Vector2(4.5, 3.5)],
}
## The spring's pool, then the stream from it down to the south edge; the
## ford where the trail crosses it.
const SPRING_POOL := Rect2i(58, 5, 6, 3)
const STREAM_COLUMNS := [61, 62]
const STREAM_FROM_ROW := 8
const FORD_ROWS := [36, 37]
## The way in from the village (west edge).
const ARRIVAL_CELL := Vector2i(1, 36)
## The beaten path: from the village to each of these, in turn...
const TRAIL_STOPS := ["clearing", "ford", "sacred_fig"]
## ...then a branch to each of these, from the nearest of the trail - with
## a signboard where it forks (no text: none).
const TRAIL_BRANCHES := {"spring": "LOHARANO", "glade_west": "SIMPONA", "glade_hive": "TANTELY", "glade_south": ""}
## Signboards beside the trail in these places: [text, region]. TANÀNA (the
## village): the trail leads back home.
const SIGNS := [["AMONTANA", "ford"], ["TANÀNA", "clearing"], ["TANÀNA", "spring"], ["TANÀNA", "sacred_fig"],
	["TANÀNA", "glade_hive"]]
## Sunlight: [region, energy]. The edge, by the village, is lit too.
const SUNBEAMS := [["clearing", 0.5], ["glade_west", 0.45], ["glade_hive", 0.45], ["glade_south", 0.45],
	["sacred_fig", 0.4], ["spring", 0.4], ["edge", 0.3]]

## The animals: [name, Discovery id, where]. "where": a region's name, or
## "dead_end:<n>" (the n-th dead end, nearest the village first), or
## "stream" (by the water).
const ANIMALS := [
	["Sifaka", "sifaka", "glade_west"],
	["Maki", "maki", "clearing"],
	["Chameleon", "chameleon", "dead_end:2"],
	["Tenrec", "tenrec", "dead_end:5"],
	["Kingfisher", "kingfisher", "stream"],
]
## The wild plants: [name (its id in the save), Discovery id, where].
const PLANTS := [
	["Greens_1", "wild_greens", "edge"],
	["Greens_2", "wild_greens", "clearing"],
	["Greens_3", "wild_greens", "dead_end:7"],
	["Hive", "honey", "glade_hive"],
	["Spring_Ravintsara", "ravintsara", "spring"],
	["Mushrooms_1", "mushroom", "dead_end:0"],
	["Mushrooms_2", "mushroom", "dead_end:9"],
]
## The places to find: [name, Discovery id, region].
const PLACES := [
	["Place_Spring", "forest_spring", "spring"],
	["Place_SacredFig", "sacred_fig", "sacred_fig"],
	["Place_Clearing", "clearing", "clearing"],
]

## The way between them: the forest's west edge <-> the village's east edge.
const VILLAGE_EXIT := Rect2(2328, 880, 25, 220)
const VILLAGE_ARRIVAL := Vector2(2268, 990)
const VILLAGE_SIGN := Vector2(2222, 900)

enum { WALL, OPEN, WATER }

var _grid := PackedByteArray()
var _trail := {} # Vector2i -> true
var _rng := RandomNumberGenerator.new()
## Dead ends of the maze, nearest the village first (their middle cell).
var _dead_ends: Array[Vector2i] = []
var _taken := {} # cells already given to something

func _initialize() -> void:
	if ResourceLoader.exists(FOREST) and not "--force" in OS.get_cmdline_user_args():
		print("%s exists - left alone (-- --force to rebuild it)" % FOREST)
	else:
		_write_forest_tree()
		_build_forest()
	var zone := ZoneData.new()
	zone.id = "forest"
	zone.display_name = "Forêt"
	zone.scene = load(FOREST)
	print("%s %s" % [ZONE_DATA, "written" if ResourceSaver.save(zone, ZONE_DATA) == OK else "- SAVE FAILED"])
	_open_village()
	quit()

# --- the map ---------------------------------------------------------------------------------

func _cell(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= SIZE.x or c.y >= SIZE.y:
		return WALL
	return _grid[c.y * SIZE.x + c.x]

func _put(c: Vector2i, value: int) -> void:
	if c.x >= 0 and c.y >= 0 and c.x < SIZE.x and c.y < SIZE.y:
		_grid[c.y * SIZE.x + c.x] = value

static func _px(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) / 2.0

func _make_map() -> void:
	_rng.seed = SEED
	_grid.resize(SIZE.x * SIZE.y)
	_grid.fill(WALL)
	var links := _maze()
	_carve_maze(links)
	_erode()
	_bulge()
	_round_corners()
	for region: String in REGIONS:
		var r: Array = REGIONS[region]
		_carve_ellipse(r[0], r[1])
	_carve_ellipse(Vector2(ARRIVAL_CELL), Vector2(3, 2.5))
	# The water last: it cuts the maze, but for the ford.
	for y in SIZE.y:
		for x in SIZE.x:
			var c := Vector2i(x, y)
			if SPRING_POOL.has_point(c) or (x in STREAM_COLUMNS and y >= STREAM_FROM_ROW and not y in FORD_ROWS):
				_put(c, WATER)
	_check_reachable()

## A random spanning tree of the maze's rooms (depth first), then braided:
## room -> the rooms it opens onto.
func _maze() -> Dictionary:
	var links := {}
	for y in MAZE_CELLS.y:
		for x in MAZE_CELLS.x:
			links[Vector2i(x, y)] = []
	var stack: Array[Vector2i] = [Vector2i(0, MAZE_CELLS.y / 2)]
	var seen := {stack[0]: true}
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	while not stack.is_empty():
		var room: Vector2i = stack[-1]
		var next := []
		for d: Vector2i in dirs:
			var n: Vector2i = room + d
			if links.has(n) and not seen.has(n):
				next.append(n)
		if next.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = next[_rng.randi() % next.size()]
		links[room].append(n)
		links[n].append(room)
		seen[n] = true
		stack.append(n)
	for room: Vector2i in links:
		if links[room].size() == 1 and _rng.randf() < BRAID:
			var closed := []
			for d: Vector2i in dirs:
				var n: Vector2i = room + d
				if links.has(n) and not n in links[room]:
					closed.append(n)
			if not closed.is_empty():
				var n: Vector2i = closed[_rng.randi() % closed.size()]
				links[room].append(n)
				links[n].append(room)
	for room: Vector2i in links:
		if links[room].size() == 1:
			_dead_ends.append(_room_origin(room) + Vector2i(MAZE_PATH / 2, MAZE_PATH / 2))
	return links

func _room_origin(room: Vector2i) -> Vector2i:
	return MAZE_ORIGIN + room * (MAZE_PATH + MAZE_WALL)

func _carve_maze(links: Dictionary) -> void:
	for room: Vector2i in links:
		var o := _room_origin(room)
		for dy in MAZE_PATH:
			for dx in MAZE_PATH:
				_put(o + Vector2i(dx, dy), OPEN)
		for n: Vector2i in links[room]:
			if n.x > room.x or n.y > room.y:
				var d := n - room
				for k in MAZE_WALL:
					for w in MAZE_PATH:
						var step := Vector2i(MAZE_PATH + k, w) if d.x != 0 else Vector2i(w, MAZE_PATH + k)
						_put(o + step, OPEN)

## The walls' edges eaten a little at random: winding paths, uneven walls.
func _erode() -> void:
	var bites: Array[Vector2i] = []
	for y in range(1, SIZE.y - 1):
		for x in range(1, SIZE.x - 1):
			var c := Vector2i(x, y)
			if _cell(c) != WALL or _rng.randf() >= EROSION:
				continue
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				# Only a wall's surface: never through it (the cell behind
				# stays wall).
				if _cell(c + d) == OPEN and _cell(c - d) == WALL and _cell(c - d * 2) == WALL:
					bites.append(c)
					break
	for c in bites:
		_put(c, OPEN)

## The thicket swelling into the corridors: wavy paths, narrowing and
## widening. A cell turns to thicket only with two open cells beyond it.
func _bulge() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEED + 1
	noise.frequency = 0.22
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for y in range(1, SIZE.y - 1):
		for x in range(1, SIZE.x - 1):
			var c := Vector2i(x, y)
			if _cell(c) != OPEN or noise.get_noise_2d(x, y) < BULGE:
				continue
			for d: Vector2i in dirs:
				if _cell(c - d) == WALL and _cell(c + d) == OPEN and _cell(c + d * 2) == OPEN and _can_close(c):
					_put(c, WALL)
					break

## Whether `c` can turn to thicket without cutting a way: the open cells
## around it stay joined to each other, around it.
func _can_close(c: Vector2i) -> bool:
	var ring := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
	var open := {}
	for d: Vector2i in ring:
		if _cell(c + d) == OPEN:
			open[c + d] = true
	if open.is_empty():
		return true
	var start: Vector2i = open.keys()[0]
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var n: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var m := n + d
			if open.has(m) and not seen.has(m):
				seen[m] = true
				queue.append(m)
	return seen.size() == open.size()

## Corners of thicket sticking out into the open (more open than thicket
## around them) are cleared: rounder walls, wider turns.
func _round_corners() -> void:
	var cleared: Array[Vector2i] = []
	for y in range(2, SIZE.y - 2):
		for x in range(2, SIZE.x - 2):
			var c := Vector2i(x, y)
			if _cell(c) != WALL:
				continue
			var open := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if _cell(c + Vector2i(dx, dy)) == OPEN:
						open += 1
			if open >= 5:
				cleared.append(c)
	for c in cleared:
		_put(c, OPEN)

func _carve_ellipse(center: Vector2, radii: Vector2) -> void:
	for y in range(int(center.y - radii.y) - 1, int(center.y + radii.y) + 2):
		for x in range(int(center.x - radii.x) - 1, int(center.x + radii.x) + 2):
			# A ragged rim: a glade isn't a perfect oval.
			var wobble := 1.0 + _rng.randf_range(-0.12, 0.12)
			if pow((x - center.x) / radii.x, 2) + pow((y - center.y) / radii.y, 2) <= wobble:
				_put(Vector2i(x, y), OPEN)

## Shortest ways over open ground, from `from`: cell -> the cell before it.
## `diagonal`: across open ground too (a trail cuts corners, never through
## thicket).
func _paths_from(from: Vector2i, diagonal := false) -> Dictionary:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	if diagonal:
		dirs.append_array([Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in dirs:
			var n := c + d
			if d.x != 0 and d.y != 0 and (_cell(c + Vector2i(d.x, 0)) != OPEN or _cell(c + Vector2i(0, d.y)) != OPEN):
				continue
			if _cell(n) == OPEN and not came.has(n):
				came[n] = c
				queue.append(n)
	return came

func _path(came: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not came.has(to):
		return path
	var c := to
	while came[c] != c:
		path.push_front(c)
		c = came[c]
	path.push_front(c)
	return path

func _region_cell(region: String) -> Vector2i:
	return _nearest_open(Vector2i(REGIONS[region][0].round()))

## The open cell nearest `c` (itself if it's open).
func _nearest_open(c: Vector2i, avoid_trail := false) -> Vector2i:
	for r in 20:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if _cell(n) == OPEN and not _taken.has(n) and not (avoid_trail and _trail.has(n)):
					return n
	return c

## Everything that matters can be walked to from the village - or the
## build says so.
func _check_reachable() -> void:
	var came := _paths_from(ARRIVAL_CELL)
	var unreachable := 0
	for y in SIZE.y:
		for x in SIZE.x:
			var c := Vector2i(x, y)
			if _cell(c) == OPEN and not came.has(c):
				# A pocket cut off by the stream or the erosion: filled in.
				_put(c, WALL)
				unreachable += 1
	for region: String in REGIONS:
		assert(came.has(_region_cell(region)), "forest: %s can't be reached" % region)
	print("forest: %d cut-off cells filled in" % unreachable)
	# Dead ends: nearest the village first, those still open.
	_dead_ends.assign(_dead_ends.filter(func(c: Vector2i) -> bool: return came.has(c)))
	var dist := {}
	for c in _dead_ends:
		dist[c] = _path(came, c).size()
	_dead_ends.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return dist[a] < dist[b])

## The beaten path: the shortest way from the village to each stop in turn,
## then a branch to each of TRAIL_BRANCHES from the nearest of it; two cells
## wide. Returns the forks: [cell, the sign's text].
func _lay_trail() -> Array:
	var forks := []
	var from := ARRIVAL_CELL
	for stop: String in TRAIL_STOPS:
		var to := _region_cell(stop)
		for c in _path(_paths_from(from, true), to):
			_trail[c] = true
		from = to
	for region: String in TRAIL_BRANCHES:
		# From the glade, the shortest way back to the trail; the fork is
		# where it meets it.
		var came := _paths_from(_region_cell(region), true)
		var best := Vector2i(-1, -1)
		var best_length := 1 << 30
		for c: Vector2i in _trail:
			if came.has(c):
				var length := _path(came, c).size()
				if length < best_length:
					best_length = length
					best = c
		if best.x < 0:
			continue
		var branch := _path(came, best)
		for c in branch:
			_trail[c] = true
		if not TRAIL_BRANCHES[region].is_empty() and branch.size() > 3:
			forks.append([branch[-3], TRAIL_BRANCHES[region]])
	# Two cells wide where the ground allows.
	for c: Vector2i in _trail.keys():
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if _cell(c + d) == OPEN:
				_trail[c + d] = true
	return forks

## Lone clumps in the open, here and there - never next to another, nor on
## or by the trail: they can't close a way.
func _scatter_shrubs() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEED + 2
	noise.frequency = 0.3
	for y in range(1, SIZE.y - 1):
		for x in range(1, SIZE.x - 1):
			var c := Vector2i(x, y)
			if _cell(c) != OPEN or noise.get_noise_2d(x, y) < SHRUBS or _rng.randf() < 0.5:
				continue
			var clear := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					if _cell(n) != OPEN or _trail.has(n):
						clear = false
			if clear:
				_put(c, WALL)

# --- the scene -------------------------------------------------------------------------------

func _build_forest() -> void:
	_make_map()
	var forks := _lay_trail()
	_scatter_shrubs()
	var forest := Node2D.new()
	forest.name = "Forest"
	forest.set_script(load(ZONE_SCRIPT))
	forest.y_sort_enabled = true
	forest.set("bgm", ZoneRoot.BGM.EXTERIOR)
	forest.set("shade", SHADE)

	var spawns := _group(forest, forest, "Spawns", false)
	for spawn_name in ["SpawnDefault", "SpawnFrom_VILLAGE"]:
		var spawn := Marker2D.new()
		spawn.name = spawn_name
		spawn.position = _px(ARRIVAL_CELL + Vector2i(1, 0))
		_add(forest, spawns, spawn)

	_paint_layers(forest)
	_plant_trees(forest)
	_place_props(forest, forks)
	_place_life(forest)

	var ambient := _group(forest, forest, "AmbientLife")
	ambient.set_script(load(AMBIENT_SCRIPT))
	var light := _group(forest, forest, "Sunlight", false)
	for entry: Array in SUNBEAMS:
		var beam := Node2D.new()
		beam.name = "Sun_" + entry[0].to_pascal_case()
		beam.set_script(load(SUNBEAM_SCRIPT))
		var r: Array = REGIONS[entry[0]]
		beam.position = r[0] * TILE + Vector2(TILE, TILE) / 2.0
		beam.set("radius", r[1] * TILE)
		beam.set("energy", entry[1])
		beam.set("shafts", clampi(int(r[1].x / 2.0), 2, 5))
		_add(forest, light, beam)

	var arrival := _px(ARRIVAL_CELL)
	_add_way(forest, "ToVillage", Rect2(0, arrival.y - 110, 24, 220), "village", "SpawnFrom_FOREST")
	_save(forest, FOREST)

func _group(owner_node: Node, parent: Node, group_name: String, y_sort := true) -> Node2D:
	var group := Node2D.new()
	group.name = group_name
	group.y_sort_enabled = y_sort
	_add(owner_node, parent, group)
	return group

func _paint_layers(forest: Node) -> void:
	var ground := TileMapLayer.new()
	ground.name = "GroundLayer"
	ground.z_index = -10
	ground.tile_set = _ground_tileset()
	ground.set_script(load(GROUND_SCRIPT))
	_add(forest, forest, ground)
	var grass := TileMapLayer.new()
	grass.name = "GrassLayer"
	grass.z_index = -9
	grass.tile_set = load(FARM_TILESET)
	_add(forest, forest, grass)
	var stream := TileMapLayer.new()
	stream.name = "StreamLayer"
	stream.z_index = -8
	stream.material = load(STREAM_MATERIAL)
	stream.tile_set = load(WATER_TILESET)
	_add(forest, forest, stream)
	var tall := TileMapLayer.new()
	tall.name = "TallGrassLayer"
	tall.y_sort_enabled = true
	tall.material = load(TALL_GRASS_MATERIAL)
	tall.tile_set = load(TALL_GRASS_TILESET)
	tall.set_script(load(TALL_GRASS_SCRIPT))
	_add(forest, forest, tall)
	var thicket := TileMapLayer.new()
	thicket.name = "ThicketLayer"
	thicket.y_sort_enabled = true
	thicket.tile_set = _thicket_tileset()
	_add(forest, forest, thicket)

	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.frequency = 0.08
	var grass_cells: Array[Vector2i] = []
	var tall_cells: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			var c := Vector2i(x, y)
			ground.set_cell(c, 1, Vector2i(1, 3))
			match _cell(c):
				WATER:
					stream.set_cell(c, 0, STREAM_TILE)
				WALL:
					grass_cells.append(c)
					# Its edges and corners (open on two sides or more): a smaller
					# clump. Each drawn a little off its cell.
					var exposed := 0
					for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
						if _cell(c + d) == OPEN:
							exposed += 1
					var variant := THICKET_SMALL_FROM + _rng.randi() % (THICKET_VARIANTS - THICKET_SMALL_FROM) \
						if exposed >= 2 else _rng.randi() % THICKET_SMALL_FROM
					thicket.set_cell(c, 0, Vector2i(variant, 0), _rng.randi() % THICKET_JITTER.size())
				OPEN:
					if _trail.has(c):
						continue
					grass_cells.append(c)
					if noise.get_noise_2d(x, y) > 0.3:
						tall_cells.append(c)
	grass.set_cells_terrain_connect(grass_cells, 0, GRASS_TERRAIN)
	for cell in tall_cells:
		for dy in 3:
			for dx in 3:
				if _rng.randf() < 0.8:
					tall.set_cell(cell * 3 + Vector2i(dx, dy), 0, Vector2i(_rng.randi_range(0, 5), 0))

## Big trees along the walls, where the player sees their foot: the wall's
## face toward the south (most of them), and its sides. A few in the glades.
func _plant_trees(forest: Node) -> void:
	var trees := _group(forest, forest, "Trees")
	var tree_scene: PackedScene = load(WORLD_TREE)
	var count := 0
	var last_row := {} # y -> last x with a tree on that row
	for y in SIZE.y:
		for x in SIZE.x:
			var c := Vector2i(x, y)
			if _cell(c) != WALL:
				continue
			var faces_south := _cell(c + Vector2i.DOWN) == OPEN
			var faces_side := _cell(c + Vector2i.LEFT) == OPEN or _cell(c + Vector2i.RIGHT) == OPEN
			var chance := 0.32 if faces_south else (0.1 if faces_side else 0.0)
			if _rng.randf() >= chance or x - int(last_row.get(y, -9)) < 2:
				continue
			last_row[y] = x
			count += 1
			var tree: Node2D = tree_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			tree.name = "Tree_%03d" % count
			tree.position = _px(c) + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(8, 20))
			var broadleaf := _rng.randf() < 0.18
			tree.set("tree_data", load(FOREST_TREE if broadleaf else EUCALYPTUS))
			tree.set("tree_id", "Trees/" + tree.name)
			tree.set("size_scale", snappedf(_rng.randf_range(0.9, 1.25), 0.05))
			tree.set("flip", _rng.randf() < 0.5)
			_add(forest, trees, tree)
	# The old sacred fig (a big mango tree for now), alone in its glade.
	var fig: Node2D = tree_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	fig.name = "SacredFig"
	fig.position = _px(_region_cell("sacred_fig") + Vector2i(0, -2))
	fig.set("tree_data", load(FOREST_TREE))
	fig.set("tree_id", "Trees/SacredFig")
	fig.set("size_scale", 1.4)
	_add(forest, trees, fig)
	_taken[_region_cell("sacred_fig") + Vector2i(0, -2)] = true
	for region: String in FRUIT_MANGOS:
		var c := _nearest_open(Vector2i(REGIONS[region][0].round()) + Vector2i(-3, -2), true)
		var mango: Node2D = tree_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		mango.name = "Mango_" + region.to_pascal_case()
		mango.position = _px(c) + Vector2(0, 12)
		mango.set("tree_data", load(MANGO))
		mango.set("tree_id", "Trees/" + mango.name)
		_add(forest, trees, mango)
		_taken[c] = true
	print("forest: %d trees" % (count + 1))

func _place_props(forest: Node, forks: Array) -> void:
	var props := _group(forest, forest, "Props")
	var reeds_count := 0
	for y in range(STREAM_FROM_ROW, SIZE.y, 4):
		for x in [STREAM_COLUMNS[0] - 1, STREAM_COLUMNS[-1] + 1]:
			var c := Vector2i(x, y)
			if _cell(c) != OPEN or _trail.has(c) or _rng.randf() < 0.4:
				continue
			reeds_count += 1
			var reeds: Node2D = (load(REEDS) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			reeds.name = "Reeds_%02d" % reeds_count
			reeds.position = _px(c) + Vector2(0, 16)
			_add(forest, props, reeds)
			_taken[c] = true
	# Signboards beside the trail: where it forks, and in the places.
	var boards := []
	for fork: Array in forks:
		boards.append([fork[1], fork[0], "Fork"])
	for entry: Array in SIGNS:
		boards.append([entry[0], _region_cell(entry[1]), entry[1].to_pascal_case()])
	for i in boards.size():
		var spot := _nearest_open(boards[i][1], true)
		var board: Node2D = (load(SIGNBOARD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		board.name = "Sign_%02d_%s" % [i + 1, boards[i][2]]
		board.position = _px(spot) + Vector2(0, 18)
		board.set("text", boards[i][0])
		_add(forest, props, board)
		_taken[spot] = true
	# Anchors for the quests' targets (tools/place_quest_targets.gd).
	var anchors := _group(forest, forest, "Anchors", false)
	var ford := _region_cell("ford")
	var on_trail_before_ford := ford
	for x in range(ford.x - 1, 0, -1):
		if _trail.has(Vector2i(x, ford.y)):
			on_trail_before_ford = Vector2i(x - 3, ford.y)
			break
	_anchor(forest, anchors, "Tracks", _nearest_open(on_trail_before_ford))
	_anchor(forest, anchors, "LostZebu", _nearest_open(_region_cell("sacred_fig") + Vector2i(4, 2), true))
	_anchor(forest, anchors, "SpringJar", _nearest_open(Vector2i(SPRING_POOL.position.x - 1, SPRING_POOL.end.y), true))

func _anchor(forest: Node, parent: Node, anchor_name: String, c: Vector2i) -> void:
	var marker := Marker2D.new()
	marker.name = anchor_name
	marker.position = _px(c) + Vector2(0, 12)
	_add(forest, parent, marker)
	_taken[c] = true

func _place_life(forest: Node) -> void:
	var wildlife := _group(forest, forest, "Wildlife")
	for entry: Array in ANIMALS:
		var animal := Node2D.new()
		animal.name = entry[0]
		animal.set_script(load(WILD_ANIMAL))
		animal.set("discovery_id", entry[1])
		animal.position = _px(_spot(entry[2])) + Vector2(0, 12)
		_add(forest, wildlife, animal)
	var plants := _group(forest, forest, "WildPlants")
	for entry: Array in PLANTS:
		var plant := Node2D.new()
		plant.name = entry[0]
		plant.set_script(load(FORAGE_SPOT))
		plant.set("discovery_id", entry[1])
		plant.position = _px(_spot(entry[2])) + Vector2(0, 12)
		_add(forest, plants, plant)
	var places := _group(forest, forest, "Places", false)
	for entry: Array in PLACES:
		var place := Area2D.new()
		place.name = entry[0]
		place.set_script(load(DISCOVERY_PLACE))
		place.set("discovery_id", entry[1])
		var r: Array = REGIONS[entry[2]]
		place.set("size", r[1] * TILE * 1.4)
		place.position = r[0] * TILE + Vector2(TILE, TILE) / 2.0
		_add(forest, places, place)

## A free cell for something: in a region (off the trail), at a dead end,
## or by the stream.
func _spot(where: String) -> Vector2i:
	var c: Vector2i
	if where.begins_with("dead_end:"):
		var i := int(where.get_slice(":", 1))
		# Spread over the dead ends, nearest (0) to furthest (9).
		c = _nearest_open(_dead_ends[i * _dead_ends.size() / 10], true)
	elif where == "stream":
		c = _nearest_open(Vector2i(STREAM_COLUMNS[0] - 1, FORD_ROWS[0] - 7), true)
	else:
		var r: Array = REGIONS[where]
		c = _nearest_open(Vector2i(r[0].round()) + Vector2i(_rng.randi_range(-2, 2), _rng.randi_range(-1, 1)), true)
	_taken[c] = true
	return c

func _write_forest_tree() -> void:
	var data: TreeData = load(FOREST_TREE) if ResourceLoader.exists(FOREST_TREE) else TreeData.new()
	data.id = "forest_tree"
	data.display_name = "Arbre de la forêt"
	data.malagasy_name = "Hazo an'ala"
	data.visual_scene = load(MANGO_VISUAL)
	data.fruit_item_id = ""
	print("%s %s" % [FOREST_TREE, "written" if ResourceSaver.save(data, FOREST_TREE) == OK else "- SAVE FAILED"])

func _ground_tileset() -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = load(GROUND_TEXTURE)
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i(1, 3))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 1)
	return tileset

## The thicket: a clump of leaves twice a cell wide on each wall cell, its
## foot at the cell's bottom (sorted there with the player), solid.
func _thicket_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	var source := TileSetAtlasSource.new()
	source.texture = load(THICKET_TEXTURE)
	source.texture_region_size = Vector2i(TILE * 2, TILE * 2)
	tileset.add_source(source, 0)
	var half := TILE / 2.0
	for v in THICKET_VARIANTS:
		var coords := Vector2i(v, 0)
		source.create_tile(coords)
		# Alternative 0 drawn on its cell, the others a little off it
		# (THICKET_JITTER) - the collision stays on the cell.
		for alt in THICKET_JITTER.size():
			if alt > 0:
				source.create_alternative_tile(coords, alt)
			var data := source.get_tile_data(coords, alt)
			# The art's foot (y = 84 of 96) on the cell's bottom edge.
			data.texture_origin = Vector2i(0, 12) + THICKET_JITTER[alt]
			data.y_sort_origin = int(half)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	ResourceSaver.save(tileset, THICKET_TILESET)
	return load(THICKET_TILESET)

## The village's way east, its arrival spot and its signboard, once.
func _open_village() -> void:
	var village: Node = (load(VILLAGE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if village.has_node("ToForest"):
		print("%s already has ToForest" % VILLAGE)
		village.free()
		return
	_add_way(village, "ToForest", VILLAGE_EXIT, "forest", "SpawnFrom_VILLAGE")
	var spawn := Marker2D.new()
	spawn.name = "SpawnFrom_FOREST"
	spawn.position = VILLAGE_ARRIVAL
	_add(village, village.get_node("Spawns"), spawn)
	var sign_node: Node2D = (load(SIGNBOARD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	sign_node.name = "Sign_Forest"
	sign_node.position = VILLAGE_SIGN
	sign_node.set("text", "ALA")
	_add(village, village, sign_node)
	_save(village, VILLAGE)

func _add_way(zone: Node, exit_name: String, rect: Rect2, target_zone: String, target_spawn: String) -> void:
	var exit := Area2D.new()
	exit.name = exit_name
	exit.set_script(load(TRANSITION_SCRIPT))
	exit.set("target_zone", target_zone)
	exit.set("target_spawn", target_spawn)
	_add(zone, zone, exit)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	_add(zone, exit, shape)

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func _save(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	root.free()
