extends SceneTree

## Bakes house models from their high-resolution master art:
##   godot --headless --path . --script res://tools/bake_house.gd            (all)
##   godot --headless --path . --script res://tools/bake_house.gd -- <id>    (one)
## then open the editor (or run --import) so the new PNGs get imported.
##
## One JSON per model in tools/house_models/ - the single place a model is
## described, every rect measured in *master* pixels (read them off the
## master in any image editor):
##   crop        building bounds, roof overhang to foundations
##   width_tiles in-game width, in 48 px tiles - sets the scale
##   footprint   solid base on the ground
##   entrance    walkable porch cut out of the footprint ([] if none)
##   door        door frame; its bottom edge is the threshold/depth line
##   door_leaf   the wooden leaf inside the frame (painted open)
##   interior_zone/interior_spawn, behind_alpha: see HouseData
##
## Produces <out_dir>/body.png and door_open.png at their exact in-game size
## (the game never scales them), and writes <data_path>, the HouseData .tres,
## with every rect converted to baked pixels. Don't edit that .tres: the next
## bake overwrites it - edit the JSON.
##
## Why bake instead of scaling a Sprite2D: every house of every village keeps
## the same proportions to the player and the grid, and VRAM only holds the
## pixels actually shown. Masters stay untouched, at full resolution.

const TILE := 48
const MODELS_DIR := "res://tools/house_models/"
## Master pixels below this alpha are noise from the source export.
const ALPHA_CUTOFF := 0.5

func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	for file in DirAccess.get_files_at(MODELS_DIR):
		if not file.ends_with(".json"):
			continue
		if not only.is_empty() and not file.get_basename() in only:
			continue
		var model = JSON.parse_string(FileAccess.get_file_as_string(MODELS_DIR + file))
		if not model is Dictionary:
			push_error("bake_house: %s is not valid JSON." % file)
			continue
		_bake(model)
	quit()

func _bake(model: Dictionary) -> void:
	var master := Image.load_from_file(model["master"])
	master.convert(Image.FORMAT_RGBA8)
	_clean_alpha(master)
	var crop := _rect(model["crop"])
	var scale := float(model["width_tiles"] * TILE) / crop.size.x
	var out_size := Vector2i(model["width_tiles"] * TILE, roundi(crop.size.y * scale))
	# Master pixels -> baked pixels. `outward` rounds to cover every touched
	# pixel (the door overlay must hide the whole closed door).
	var bake_rect := func(r: Rect2i, outward := false) -> Rect2i:
		if r.size == Vector2i.ZERO:
			return Rect2i()
		var p0 := Vector2(r.position - crop.position) * scale
		var p1 := Vector2(r.end - crop.position) * scale
		var out := Rect2i()
		out.position = Vector2i(floori(p0.x), floori(p0.y)) if outward else Vector2i(p0.round())
		out.end = Vector2i(ceili(p1.x), ceili(p1.y)) if outward else Vector2i(p1.round())
		return out

	var body := _resample(master.get_region(crop), out_size)
	var open_master := master.duplicate() as Image
	_paint_open_door(open_master, _rect(model["door_leaf"]))
	var body_open := _resample(open_master.get_region(crop), out_size)
	var door: Rect2i = bake_rect.call(_rect(model["door"]), true)

	var out_dir: String = model["out_dir"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	body.save_png(out_dir + "/body.png")
	body_open.get_region(door).save_png(out_dir + "/door_open.png")
	_write_data(model, out_dir, door, bake_rect.call(_rect(model["footprint"])), bake_rect.call(_rect(model.get("entrance", []))))
	print("%s: body %s (scale %.4f), door %s -> %s" % [model["id"], out_size, scale, door, model["data_path"]])

## Written as text rather than through ResourceSaver: the PNGs were just
## created and aren't imported yet, so they can't be loaded as textures -
## referencing them by path is enough, the editor resolves them on import.
func _write_data(model: Dictionary, out_dir: String, door: Rect2i, footprint: Rect2i, entrance: Rect2i) -> void:
	var lines := [
		'[gd_resource type="Resource" script_class="HouseData" load_steps=4 format=3]',
		'',
		'[ext_resource type="Script" path="res://core/data/structures/house_data.gd" id="1_data"]',
		'[ext_resource type="Texture2D" path="%s/body.png" id="2_body"]' % out_dir,
		'[ext_resource type="Texture2D" path="%s/door_open.png" id="3_door"]' % out_dir,
		'',
		'[resource]',
		'script = ExtResource("1_data")',
		'id = %s' % JSON.stringify(model["id"]),
		'display_name = %s' % JSON.stringify(model.get("display_name", "")),
		'body_texture = ExtResource("2_body")',
		'door_open_texture = ExtResource("3_door")',
		'door_open_position = Vector2(%d, %d)' % [door.position.x, door.position.y],
		'footprint = %s' % _rect_text(footprint),
		'entrance = %s' % _rect_text(entrance),
		'door = %s' % _rect_text(door),
		'interior_zone = %s' % JSON.stringify(model.get("interior_zone", "")),
		'interior_spawn = %s' % JSON.stringify(model.get("interior_spawn", "")),
		'behind_alpha = %s' % var_to_str(float(model.get("behind_alpha", 0.45))),
		'',
	]
	var path: String = model["data_path"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))

static func _rect(values: Array) -> Rect2i:
	if values.size() != 4:
		return Rect2i()
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))

static func _rect_text(r: Rect2i) -> String:
	return "Rect2(%d, %d, %d, %d)" % [r.position.x, r.position.y, r.size.x, r.size.y]

func _clean_alpha(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < ALPHA_CUTOFF:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.a < 1.0:
				c.a = 1.0
				img.set_pixel(x, y, c)

## Lanczos on premultiplied colors, then back to straight alpha: transparent
## pixels (black) must not bleed into the edges while shrinking.
func _resample(img: Image, size: Vector2i) -> Image:
	var out := img.duplicate() as Image
	out.premultiply_alpha()
	out.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a <= 0.0:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				out.set_pixel(x, y, Color(c.r / c.a, c.g / c.a, c.b / c.a, c.a).clamp())
	return out

## The leaf swung inward: a dark room seen through the frame, warmer and
## lighter toward the floor (daylight coming in), with the leaf's edge still
## showing against the left jamb.
func _paint_open_door(img: Image, leaf: Rect2i) -> void:
	const TOP := Color(0.07, 0.04, 0.03)
	const BOTTOM := Color(0.24, 0.14, 0.08)
	const LEAF_EDGE := 0.14 # fraction of the leaf width still visible
	var edge_w := roundi(leaf.size.x * LEAF_EDGE)
	for y in range(leaf.position.y, leaf.end.y):
		var t := float(y - leaf.position.y) / leaf.size.y
		var room := TOP.lerp(BOTTOM, t * t)
		for x in range(leaf.position.x, leaf.end.x):
			var dx := x - leaf.position.x
			if dx < edge_w:
				# Leaf seen edge-on: its own wood, darkened by the shadow.
				var wood := img.get_pixel(leaf.position.x + dx * 3, y)
				img.set_pixel(x, y, wood.darkened(0.45))
			else:
				img.set_pixel(x, y, room)
