class_name ChatOverlay
extends Control

func add_message(message: GMessageData) -> void:
	print("[%s] %s" % [message.chatter.name, message.message.text])
	$Messages.add_child(await ChatMessageLabel.new(message))

func _on_send_text_submitted(message: String) -> void:
	Bot.twitch_broadcaster.send_chat_message(message)
