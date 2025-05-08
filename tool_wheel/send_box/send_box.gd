extends HBoxContainer

func _on_text_edit_text_submitted(message: String) -> void:
	Twitch.broadcaster_chat.send_message(message)
	queue_free()

func _on_cancel_pressed() -> void:
	queue_free()
