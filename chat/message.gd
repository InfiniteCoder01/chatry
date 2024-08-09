class_name ChatMessageLabel
extends RichTextLabel

var message_id: String

func _ready() -> void:
    await get_tree().create_timer(20.0).timeout
    self.queue_free()
