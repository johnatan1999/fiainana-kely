extends SceneTree

## Optional helper: turns a house's high-resolution master art into the two
## images its model scene uses. Nothing else - the scene itself is assembled
## and edited by hand (see structures/houses/house.gd).
##   godot --headless --path . --script res://tools/bake_house.gd -- <model>
## <model> is a JSON in tools/house_models/, rects in master pixels:
##   master, out_dir
##   crop        building bounds, roof overhang to foundations
##   width_tiles in-game width in 48 px tiles - pick it so the door ends up
##               about the player's height
##   bake_scale  image pixels per in-game pixel (2: sharp up to 1440p)
##   door        door frame      } for door_open.png
##   door_leaf   its wooden leaf }
##
## Writes <out_dir>/body.png (the building, bake_scale x its in-game size)
## and door_open.png (the doorway painted open, cut to the door), with
## mipmaps on, and prints where DoorOpen goes in the scene. In the scene,
## scale both sprites to 1 / bake_scale.
##
## Doing it by hand in an image editor is just as fine: resize so the door
## is ~150 px tall (2x), paint an open door, export both.

const TILE := 48
const MODELS_DIR := "res://tools/house_models/"
## Master pixels below this alpha are noise from the source export.
const ALPHA_CUTOFF := 0.5

func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	for file in DirAccess.get_files_at(MODELS_DIR):
		if file.ends_with(".json") and (only.is_empty() or file.get_basename() in only):
			var model = JSON.parse_string(FileAccess.get_file_as_string(MODELS_DIR + file))
			if model is Dictionary:
				_bake(model)
			else:
				push_error("bake_house: %s is not valid JSON." % file)
	quit()

func _bake(model: Dictionary) -> void:
	var master := Image.load_from_file(model["master"])
	master.convert(Image.FORMAT_RGBA8)
	_clean_alpha(master)
	var crop := _rect(model["crop"])
	var bake_scale := int(model.get("bake_scale", 2))
	# Master pixels -> in-game pixels; the images are exactly bake_scale times
	# the in-game size so in-game positions land on whole image pixels.
	var scale := float(model["width_tiles"] * TILE) / crop.size.x
	var world_size := Vector2i(model["width_tiles"] * TILE, roundi(crop.size.y * scale))
	var out_size := world_size * bake_scale

	var door := _rect(model["door"])
	var d0 := Vector2(door.position - crop.position) * scale
	var d1 := Vector2(door.end - crop.position) * scale
	var door_world := Rect2i(Vector2i(floori(d0.x), floori(d0.y)), Vector2i.ZERO)
	door_world.end = Vector2i(ceili(d1.x), ceili(d1.y))

	var body := _resample(master.get_region(crop), out_size)
	var open_master := master.duplicate() as Image
	_paint_open_door(open_master, _rect(model["door_leaf"]))
	var body_open := _resample(open_master.get_region(crop), out_size)

	var out_dir: String = model["out_dir"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	body.save_png(out_dir + "/body.png")
	body_open.get_region(Rect2i(door_world.position * bake_scale, door_world.size * bake_scale)).save_png(out_dir + "/door_open.png")
	for png in ["/body.png", "/door_open.png"]:
		_enable_mipmaps(out_dir + png)
	print("%s -> %s: in-game %s, images x%d" % [model["master"], out_dir, world_size, bake_scale])
	print("  DoorOpen: %s from the art's top-left corner (in-game px); threshold at y = %d" % [door_world.position, door_world.end.y])

## Drawn scaled down: without mipmaps the thatch and brick patterns would
## shimmer as the camera moves. Edits the existing .import, or writes a
## minimal one for a first bake - the editor fills in the rest on import.
func _enable_mipmaps(png: String) -> void:
	var import_path := png + ".import"
	var text := FileAccess.get_file_as_string(import_path) if FileAccess.file_exists(import_path) else ""
	if text.contains("mipmaps/generate=true"):
		return
	if text.contains("mipmaps/generate=false"):
		text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
	else:
		text = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\nmipmaps/generate=true\n'
	FileAccess.open(import_path, FileAccess.WRITE).store_string(text)

static func _rect(values: Array) -> Rect2i:
	if values.size() != 4:
		return Rect2i()
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))

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
