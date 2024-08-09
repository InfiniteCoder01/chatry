extends Node2D

func _physics_process(_delta: float) -> void:
    #position = get_global_mouse_position() - $SoftBody2DRigidBody/ColorRect.get_rect().size / 2
    $SoftBody2DRigidBody.apply_force(((get_global_mouse_position() - $SoftBody2DRigidBody.global_position) * 50 - $SoftBody2DRigidBody.linear_velocity) * 500)
