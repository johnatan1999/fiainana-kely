extends SceneTree

## The family dog's scenes, from the sheets assets/sprites/animals/dog.png and
## assets/sprites/props/dog_props.png (tools/placeholder_art/gen_dog.gd):
## - entities/dog/dog.tscn: the dog (Dog), its sprite and "pet it";
## - entities/dog/dog_house.tscn: its doghouse and bowl (DogHouse);
## - entities/dog/puppy_basket.tscn: Rakoto's basket of puppies, the mother
##   lying by it - the look of a quest target (tools/place_quest_targets.gd);
## then puts the DogHouse in the farm scene at DOG_HOUSE_POSITION (replacing
## the one there), leaving the rest of the scene alone. See docs/dog.md.
##   godot --headless --editor --path . --script res://tools/build_dog.gd

const DOG_SHEET := "res://assets/sprites/animals/dog.png"
const PROPS_SHEET := "res://assets/sprites/props/dog_props.png"
const INTERACTABLE := "res://components/interaction/interactable_component.tscn"
const FARM := "res://world/areas/exterior/player_farm.tscn"
## By the house, left of its door, between the field and the yard's fence.
const DOG_HOUSE_POSITION := Vector2(712, 594)
const CELL := 192
const SCALE := 0.5

func _initialize() -> void:
	_build_dog()
	_build_dog_house()
	_build_puppy_basket()
	_place_dog_house()
	quit()

func _build_dog() -> void:
	var dog := Node2D.new()
	dog.name = "Dog"
	dog.set_script(load("res://entities/dog/dog.gd"))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(DOG_SHEET)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.hframes = 4
	sprite.vframes = 3
	sprite.scale = Vector2.ONE * 0.62 # Dog.SPRITE_SCALE
	sprite.offset = Vector2(0, -46) # the paws on y = 92 of a 96 px cell
	_add(dog, dog, sprite)
	_add(dog, dog, _interactable(Vector2(0, -18)))
	_save(dog, "res://entities/dog/dog.tscn")

func _build_dog_house() -> void:
	var house := Node2D.new()
	house.name = "DogHouse"
	house.set_script(load("res://entities/dog/dog_house.gd"))
	var hut := _prop_sprite(0)
	hut.name = "House"
	_add(house, house, hut)
	var bowl := _prop_sprite(1)
	bowl.name = "Bowl"
	bowl.position = Vector2(-52, 10)
	_add(house, house, bowl)
	_add_base(house, Vector2(56, 14))
	var bed := Marker2D.new()
	bed.name = "Bed"
	bed.position = Vector2(-2, 20)
	_add(house, house, bed)
	_add(house, house, _interactable(Vector2(-52, -8)))
	_save(house, "res://entities/dog/dog_house.tscn")

func _build_puppy_basket() -> void:
	var basket := Node2D.new()
	basket.name = "PuppyBasket"
	basket.set_script(load("res://entities/props/prop.gd"))
	var sprite := _prop_sprite(3)
	_add(basket, basket, sprite)
	var mother := Sprite2D.new()
	mother.name = "Mother"
	mother.texture = load(DOG_SHEET)
	mother.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mother.region_enabled = true
	mother.region_rect = Rect2(224, 96, 112, 96) # lying, head up
	mother.scale = Vector2.ONE * SCALE
	mother.position = Vector2(-66, 0)
	mother.self_modulate = Color(0.88, 0.63, 0.36)
	_add(basket, basket, mother)
	_add_base(basket, Vector2(56, 12))
	_save(basket, "res://entities/dog/puppy_basket.tscn")

func _place_dog_house() -> void:
	var zone: Node = (load(FARM) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if zone.has_node("DogHouse"):
		var old := zone.get_node("DogHouse")
		zone.remove_child(old)
		old.free()
	var house: Node2D = (load("res://entities/dog/dog_house.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	house.name = "DogHouse"
	house.position = DOG_HOUSE_POSITION
	zone.add_child(house)
	house.owner = zone
	var scene := PackedScene.new()
	scene.pack(zone)
	var error := ResourceSaver.save(scene, FARM)
	print("%s %s" % [FARM, "written" if error == OK else "- SAVE FAILED (%d)" % error])
	zone.free()

func _prop_sprite(cell: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(PROPS_SHEET)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(cell * CELL, 0, CELL, CELL)
	sprite.scale = Vector2.ONE * SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite

## Its reach is set by the scene's script (an instance's inner shape isn't
## saved with the scene).
func _interactable(at: Vector2) -> Node:
	var interactable: Node = (load(INTERACTABLE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	interactable.name = "InteractableComponent"
	interactable.position = at
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
