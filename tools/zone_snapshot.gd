extends SceneTree

## Renders a zone scene to a PNG, with a grid of coordinates every 100 px -
## to pick where to place things (markers, props) without opening the
## editor. Needs a real renderer: run it WITHOUT --headless.
##   godot --path . --script res://tools/zone_snapshot.gd -- <res://zone.tscn> <out.png> [scale] [x y w h]
## e.g. -- res://world/areas/exterior/market_town.tscn C:/tmp/market_town.png 0.5
## The optional x y w h: only that region of the zone (in zone px), e.g. to
## look closely at a corner: -- <zone> <out.png> 1 800 900 700 450

const SIZE := Vector2(2304, 1728)
const GRID := 100.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("zone_snapshot: -- <zone.tscn> <out.png> [scale] [x y w h]")
		quit(2)
		return
	var scale := float(args[2]) if args.size() > 2 else 0.5
	var region := Rect2(Vector2.ZERO, SIZE)
	if args.size() > 6:
		region = Rect2(float(args[3]), float(args[4]), float(args[5]), float(args[6]))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(region.size * scale)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var zone: Node2D = (load(args[0]) as PackedScene).instantiate()
	zone.scale = Vector2(scale, scale)
	zone.position = -region.position * scale
	viewport.add_child(zone)
	var grid := _Grid.new()
	grid.scale = zone.scale
	grid.position = zone.position
	grid.z_index = 100
	viewport.add_child(grid)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(args[1])
	print("%s -> %s%s" % [args[0], args[1], "" if error == OK else " - SAVE FAILED (%d)" % error])
	quit()

class _Grid extends Node2D:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for x in range(0, int(SIZE.x), int(GRID)):
			draw_line(Vector2(x, 0), Vector2(x, SIZE.y), Color(1, 0, 0, 0.35), 1.0)
		for y in range(0, int(SIZE.y), int(GRID)):
			draw_line(Vector2(0, y), Vector2(SIZE.x, y), Color(1, 0, 0, 0.35), 1.0)
		for x in range(0, int(SIZE.x), int(GRID)):
			for y in range(0, int(SIZE.y), int(GRID)):
				draw_string(font, Vector2(x + 3, y + 16), "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.YELLOW)
