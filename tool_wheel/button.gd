class_name ToolWheelButton
extends Button

signal activated()

var target: Vector2
var enabled := false

func _input(event: InputEvent) -> void:
	if !enabled:
		release_focus()
		return

	if event is InputEventMouse:
		var hovered := Rect2(global_position, size).has_point(event.global_position)
		if hovered: grab_focus()
		else: release_focus()
		if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT && !event.pressed && hovered:
			activated.emit()

func _process(delta: float) -> void:
	global_position = global_position.move_toward(target, delta * 500)
	enabled = global_position.distance_squared_to(target) < 300
