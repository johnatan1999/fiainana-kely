class_name CharacterAnimator
extends Node

@onready var anim: AnimatedSprite2D = $"../AnimatedSprite2D"

func play(dir: Vector2, state: String):
	if anim.sprite_frames == null:
		return

	var anim_name := ""

	match state:
		"walk":
			anim_name = _get_walk_animation(dir)
		"idle":
			anim_name = _get_idle_animation(dir)
		_:
			anim_name = state  # eat, drink, sleep, talk, etc.

	if anim.sprite_frames.has_animation(anim_name):
		if anim.animation != anim_name:
			anim.animation = anim_name
			anim.play()

func _get_walk_animation(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "walk_right" if dir.x > 0  else "walk_left"
	else:
		return "walk_down" if dir.y > 0 else "walk_up"

func _get_idle_animation(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "idle_right" if dir.x > 0 else "idle_left"
	else:
		return "idle_down" if dir.y > 0 else "idle_up"
