class_name HouseData
extends Resource

@export var id: String = ""
@export var display_name: String = "House"

@export_group("Visuels")
@export var wall_texture: Texture2D
@export var roof_texture: Texture2D
## Si tu utilises un Atlas (AtlasTexture/Region)
@export var wall_region: Rect2 = Rect2()
@export var roof_region: Rect2 = Rect2()

@export_group("Collisions")
## Forme exacte du mur au sol (ex: RectangleShape2D ou ConvexPolygonShape2D)
@export var collision_shape: Shape2D
## Position relative du centre de la collision par rapport à la maison
@export var collision_offset: Vector2 = Vector2.ZERO
