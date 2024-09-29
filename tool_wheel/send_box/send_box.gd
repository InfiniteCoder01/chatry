extends HBoxContainer

func _on_text_edit_text_submitted(message: String) -> void:
	Bot.twitch_broadcaster.send_chat_message(message)
	queue_free()

func _on_cancel_pressed() -> void:
	queue_free()
