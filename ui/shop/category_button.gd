class_name CategoryButton
extends Button

## One tab in the category row. toggle_mode + a shared ButtonGroup (assigned
## by ShopUI at build time) gives radio-button behavior for free - only one
## CategoryButton is ever pressed at a time.

signal category_chosen(category: ItemData.Category)

@export var category: ItemData.Category = ItemData.Category.SEEDS

var _tween: Tween

func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	toggled.connect(_on_toggled)

func _on_toggled(is_pressed: bool) -> void:
	if not is_pressed:
		return
	AudioManager.play_click_menu_sfx()
	_play_pop()
	category_chosen.emit(category)

func _on_mouse_entered() -> void:
	_animate_scale(Vector2(1.08, 1.08), 0.12)

func _on_mouse_exited() -> void:
	_animate_scale(Vector2.ONE, 0.12)

func _play_pop() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.08)

func _animate_scale(target: Vector2, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, time).set_trans(Tween.TRANS_SINE)
