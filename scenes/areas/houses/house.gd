class_name House
extends Node2D

## Configuration exposée dans l’éditeur
@export var house_id: String = "house_01"
@export var house_name: String = "Maison"
@export var target_zone: String = "interior_house_01"
@export var target_spawn: String = "door_inside"
@export var house_scale: float = 1.0
@export var collision_size: Vector2 = Vector2(128, 64)

func _ready():
	# Appliquer l’échelle configurée
	$Sprite2D.scale = Vector2(house_scale, house_scale)

	# Ajuster la collision automatiquement
	$StaticBody2D/CollisionShape2D.shape.size = collision_size
