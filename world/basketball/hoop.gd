extends Node2D

func _ready() -> void:
	await get_tree().create_timer(60.0).timeout
	self.queue_free()
