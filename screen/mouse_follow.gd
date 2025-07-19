extends RigidBody2D
class_name MouseFollower

func _physics_process(_delta: float) -> void:
	apply_central_impulse((get_global_mouse_position() - global_position) * 1000.0)
