extends Node2D

func _ready():
    await get_tree().create_timer(30.0).timeout
    self.queue_free()
