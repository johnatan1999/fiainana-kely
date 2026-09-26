class_name CloseButton
extends TextureButton

## The carved wooden cross (assets/sprites/menu/close.png) used to close a
## window or remove an entry. Just a TextureButton with hover/press
## feedback - whoever places it connects `pressed` to what it closes.

const HOVER_TINT := Color(1.25, 1.15, 1.0)
const PRESSED_TINT := Color(0.8, 0.7, 0.6)
const HOVER_SCALE := Vector2(1.1, 1.1)
const ANIM_TIME := 0.08

var _tween: Tween

func _ready() -> void:
	resized.connect(func(): pivot_offset = size / 2.0)
	pivot_offset = size / 2.0
	mouse_entered.connect(func(): _animate(HOVER_TINT, HOVER_SCALE))
	mouse_exited.connect(func(): _animate(Color.WHITE, Vector2.ONE))
	button_down.connect(func(): _animate(PRESSED_TINT, Vector2.ONE))
	button_up.connect(func(): _animate(HOVER_TINT if is_hovered() else Color.WHITE, HOVER_SCALE if is_hovered() else Vector2.ONE))

func _animate(tint: Color, target_scale: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "self_modulate", tint, ANIM_TIME)
	_tween.tween_property(self, "scale", target_scale, ANIM_TIME)
