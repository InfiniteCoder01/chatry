extends Node

func _ready() -> void:
	await get_tree().create_timer(30.0).timeout
	self.queue_free()
