class_name ChatOverlay
extends Control

func add_message(from_user: String, message: String, tags: TwitchTags.Message) -> void:
	print("[%s] %s" % [from_user, message])
	var badges := await tags.get_badges() as Array[SpriteFrames];
	var emotes := await tags.get_emotes() as Array[TwitchIRC.EmoteLocation];
	var color := tags.get_color();

	var label := ChatMessageLabel.new()
	label.message_id = tags.raw.id
	label.bbcode_enabled = true
	label.fit_content = true

	var sprite_effect := SpriteFrameEffect.new();
	label.install_effect(sprite_effect)

	var badge_id := 0;
	var result_message := ""
	for badge: SpriteFrames in badges:
		result_message += "[sprite id='b-%s']%s[/sprite]" % [badge_id, badge.resource_path];
		badge_id += 1;
	result_message += "[b][color=%s]%s[/color]: [/b]" % [color, from_user];

	var start := 0;
	for emote in emotes:
		result_message += message.substr(start, emote.start - start);
		result_message += "[sprite id='%s']%s[/sprite]" % [emote.start, emote.sprite_frames.resource_path];
		start = emote.end + 1;

	result_message += message.substr(start, message.length() - start);
	label.text = sprite_effect.prepare_message(result_message, label);

	$Messages.add_child(label)

func _on_send_text_submitted(message: String) -> void:
	Bot.chat.chat(message)
