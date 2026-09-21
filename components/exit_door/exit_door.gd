extends Area2D
class_name ExitDoor

## La scène destination vers laquelle changer (ex: res://scenes/FarmExterior.tscn)
@export_file("*.tscn") var target_scene: String

## Optionnel: L'identifiant du point de réapparition (ex: "FromCoop", "MainEntrance")
@export var target_spawn_id: String = ""

func _ready() -> void:
	# Connecter automatiquement le signal body_entered
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Vérifier si c'est bien le joueur
	if body.is_in_group("player"):
		_change_scene()

func _change_scene() -> void:
	if target_scene.is_empty():
		push_warning("ExitDoor: Aucune 'target_scene' spécifiée dans l'inspecteur !")
		return
	get_tree().change_scene_to_file(target_scene)
