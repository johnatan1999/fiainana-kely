class_name House
extends Node2D

@export_group("Data & Visuals")
## La ressource .tres contenant l'apparence et les formes de la maison
@export var data: HouseData:
	set(value):
		data = value
		if is_node_ready():
			_update_house()

@export_group("Zone transition (Teleportation)")
@export var target_zone: String = "interior_house_01"
@export var target_spawn: String = "door_inside"

@onready var wall_sprite: Sprite2D = $WallSprite
@onready var roof_sprite: Sprite2D = $RoofSprite
@onready var collision_node: CollisionShape2D = $StaticBody2D/CollisionShape2D

func _ready() -> void:
	_update_house()

func _update_house() -> void:
	if data == null:
		return

	# 1. Mise à jour des visuels (Murs et Toit)
	if wall_sprite and data.wall_texture:
		wall_sprite.texture = data.wall_texture
		if data.wall_region != Rect2():
			wall_sprite.region_enabled = true
			wall_sprite.region_rect = data.wall_region

	if roof_sprite and data.roof_texture:
		roof_sprite.texture = data.roof_texture
		if data.roof_region != Rect2():
			roof_sprite.region_enabled = true
			roof_sprite.region_rect = data.roof_region

	# 2. Adaptation dynamique de la forme de collision
	if collision_node and data.collision_shape:
		# Important : duplicate() évite que modifier la collision d'une maison
		# n'impacte toutes les autres maisons partageant la même Resource
		collision_node.shape = data.collision_shape.duplicate()
		collision_node.position = data.collision_offset
