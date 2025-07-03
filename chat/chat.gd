class_name ChatOverlay
extends Control

func _ready() -> void:
	Twitch.chat.message_received.connect(_on_message_recieved)

func _on_message_recieved(message: TwitchChatMessage) -> void:
	if message.message.text.begins_with('!'): return
	if message.chatter_user_login == "coderschatry" && message.message.text.contains("You couldn't catch"): return
	print("[%s] %s" % [message.chatter_user_name, message.message.text])
	$Messages.add_child(await ChatMessageLabel.new(message))
