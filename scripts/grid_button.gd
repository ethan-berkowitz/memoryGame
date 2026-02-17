extends Button

var correct := false
#var press_animation := false
#var size_changed := false
#var timer := 0.0
#var rate := 0.05

const NORMAL_SIZE := Vector2(64, 64)
const PRESSED_SIZE := Vector2(60, 60)

func _ready():
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down():
	_resize_from_center(PRESSED_SIZE)

func _on_button_up():
	_resize_from_center(NORMAL_SIZE)

func _resize_from_center(new_size: Vector2) -> void:
	var center := global_position + size * 0.5
	size = new_size
	global_position = center - size * 0.5
