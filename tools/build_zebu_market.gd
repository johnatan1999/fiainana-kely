extends SceneTree

## The player's zebus' scenes, from the sheet assets/sprites/props/
## zebu_market.png (tools/placeholder_art/gen_zebu_market.gd):
## - entities/zebu/zebu_trough.tscn: the farm pen's trough (ZebuTrough);
## - entities/zebu/zebu_market.tscn: the zebu dealer's stand (ZebuMarket):
##   his post and a signboard, opening as data/shops/zebu_market.tres says
##   (written here too);
## - data/items/tool_plough.tres: the zebu plough (FarmAction.PLOUGH), its
##   icon from the same sheet;
## - entities/zebu/manure_heap.tscn (ManureHeap) and data/items/manure.tres
##   (FarmAction.FERTILIZE), from assets/sprites/props/manure.png
##   (tools/placeholder_art/gen_manure.gd).
## Placing them, with the pens and herds: tools/place_zebu_herds.gd.
##   godot --headless --editor --path . --script res://tools/build_zebu_market.gd

const SHEET := "res://assets/sprites/props/zebu_market.png"
const INTERACTABLE := "res://components/interaction/interactable_component.tscn"
const SIGNBOARD := "res://entities/props/signboard.tscn"
const PROFILE := "res://data/shops/zebu_market.tres"
const PLOUGH_ITEM := "res://data/items/tool_plough.tres"
const PLOUGH_PRICE := 15000
const MANURE_SHEET := "res://assets/sprites/props/manure.png"
const MANURE_ITEM := "res://data/items/manure.tres"
const MANURE_SELL_PRICE := 200
const CELL := 192
const SCALE := 0.5

func _initialize() -> void:
	var profile: ShopProfile = load(PROFILE) if ResourceLoader.exists(PROFILE) else ShopProfile.new()
	profile.title = "Tsena omby"
	profile.open_days = 1 << GameClock.Weekday.ZOMA
	profile.opens_at = 6 * 60
	profile.closes_at = 17 * 60
	profile.closed_message = "Le tsena omby n'ouvre que le zoma, de 6:00 à 17:00."
	print("%s %s" % [PROFILE, "written" if ResourceSaver.save(profile, PROFILE) == OK else "- SAVE FAILED"])

	var trough := Node2D.new()
	trough.name = "ZebuTrough"
	trough.set_script(load("res://entities/zebu/zebu_trough.gd"))
	_add(trough, trough, _sprite(0))
	_add_base(trough, Vector2(170, 24) * SCALE)
	_add(trough, trough, _interactable())
	_save(trough, "res://entities/zebu/zebu_trough.tscn")

	var market := Node2D.new()
	market.name = "ZebuMarket"
	market.y_sort_enabled = true
	market.set_script(load("res://entities/zebu/zebu_market.gd"))
	market.set("profile", profile)
	var post := _sprite(2)
	post.centered = true
	post.offset = Vector2(0, -CELL / 2.0)
	_add(market, market, post)
	_add_base(market, Vector2(24, 12))
	var sign_node: Node2D = (load(SIGNBOARD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	sign_node.name = "Panneau"
	sign_node.position = Vector2(50, 6)
	sign_node.set("text", "OMBY")
	_add(market, market, sign_node)
	_add(market, market, _interactable())
	_save(market, "res://entities/zebu/zebu_market.tscn")
	_write_plough()

	var heap := Node2D.new()
	heap.name = "ManureHeap"
	heap.set_script(load("res://entities/zebu/manure_heap.gd"))
	var heap_sprite := _sprite(0)
	heap_sprite.texture = load(MANURE_SHEET)
	_add(heap, heap, heap_sprite)
	_add(heap, heap, _interactable())
	_save(heap, "res://entities/zebu/manure_heap.tscn")
	_write_manure()
	quit()

func _write_manure() -> void:
	var item: ItemData = load(MANURE_ITEM) if ResourceLoader.exists(MANURE_ITEM) else ItemData.new()
	item.id = FarmSimulation.MANURE_ITEM
	item.display_name = "Fumier de zébu"
	item.malagasy_name = "Zezik'omby"
	item.description = ("Ramassé au parc des zébus. Épandu sur une parcelle labourée ou plantée, "
		+ "il donne une récolte plus grosse de moitié.")
	item.category = ItemData.Category.ANIMALS
	item.price = 0
	item.sell_price = MANURE_SELL_PRICE
	item.tool_action = FarmAction.Type.FERTILIZE
	var icon := AtlasTexture.new()
	icon.atlas = load(MANURE_SHEET)
	icon.region = Rect2(2 * CELL + 16, 70, CELL - 32, CELL - 70)
	item.icon = icon
	print("%s %s" % [MANURE_ITEM, "written" if ResourceSaver.save(item, MANURE_ITEM) == OK else "- SAVE FAILED"])

func _write_plough() -> void:
	var item: ItemData = load(PLOUGH_ITEM) if ResourceLoader.exists(PLOUGH_ITEM) else ItemData.new()
	item.id = "tool_plough"
	item.display_name = "Charrue à zébus"
	item.malagasy_name = "Angadin'omby"
	item.description = ("Tirée par une paire de zébus forts (%d jours de croissance), elle laboure "
		+ "%d cases d'un coup. Les zébus se fatiguent après %d cases par jour.") \
		% [FarmSimulation.ZEBU_WORK_MIN_DAYS, FarmSimulation.PLOUGH_REACH, FarmSimulation.PLOUGH_CELLS_PER_DAY]
	item.category = ItemData.Category.TOOLS
	item.price = PLOUGH_PRICE
	item.tool_action = FarmAction.Type.PLOUGH
	var icon := AtlasTexture.new()
	icon.atlas = load(SHEET)
	icon.region = Rect2(3 * CELL, 40, CELL, CELL - 40)
	item.icon = icon
	print("%s %s" % [PLOUGH_ITEM, "written" if ResourceSaver.save(item, PLOUGH_ITEM) == OK else "- SAVE FAILED"])

func _sprite(cell: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(SHEET)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(cell * CELL, 0, CELL, CELL)
	sprite.scale = Vector2.ONE * SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite

func _interactable() -> Node:
	var interactable: Node = (load(INTERACTABLE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	interactable.name = "InteractableComponent"
	return interactable

## A StaticBody2D at the foot, `size` wide.
func _add_base(root: Node, size: Vector2) -> void:
	var base := StaticBody2D.new()
	base.name = "Base"
	_add(root, root, base)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector2(0, -size.y / 2.0)
	_add(root, base, shape)

func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node

func _save(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(root)
	var error := ResourceSaver.save(scene, path)
	print("%s %s" % [path, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	root.free()
