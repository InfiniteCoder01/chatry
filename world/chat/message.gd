extends RichTextLabel

func _ready():
    await get_tree().create_timer(20.0).timeout
    self.queue_free()
