class_name ChatMessageLabel
extends RichTextLabel

var message: TwitchChatMessage

func _ready() -> void:
	await get_tree().create_timer(20.0).timeout
	queue_free()

func _init(message: TwitchChatMessage) -> void:
	self.message = message
	bbcode_enabled = true
	fit_content = true
	selection_enabled = true
	context_menu_enabled = true
	var sprite_frame_effect: SpriteFrameEffect = SpriteFrameEffect.new()
	install_effect(sprite_frame_effect)

	var bbcode := ""

	# Get all badges from the user that sends the message
	var badges_dict : Dictionary = await message.get_badges(Twitch.media_loader)
	var badges : Array[SpriteFrames] = []
	badges.assign(badges_dict.values())

	# Add all badges to the message
	var badge_id : int = 0
	for badge: SpriteFrames in badges:
		bbcode += "[sprite id='b-%s']%s[/sprite]" % [badge_id, badge.resource_path]
		badge_id += 1
	
	if badge_id > 0: bbcode += " "

	# Add the user with their color to the message
	bbcode += "[color=%s]%s[/color] " % [message.get_color(), message.chatter_user_name]

	# Show different effects depending on the message types
	match message.message_type:
		TwitchChatMessage.MessageType.text:
			bbcode += await render_message_content()
		TwitchChatMessage.MessageType.power_ups_gigantified_emote:
			bbcode += "\n"
			bbcode += await render_message_content(3)
		TwitchChatMessage.MessageType.channel_points_highlighted:
			bbcode += "[bgcolor=#755ebc][color=#e9fffb]"
			bbcode += await render_message_content()
			bbcode += "[/color][/bgcolor]"
		TwitchChatMessage.MessageType.power_ups_message_effect:
			bbcode += "[shake rate=20.0 level=5 connected=1]"
			bbcode += await render_message_content()
			bbcode += "[/shake]"
			
	text = sprite_frame_effect.prepare_message(bbcode, self)

func render_message_content(emote_scale: int = 1) -> String:
	# Load emotes and badges in parallel to improve the speed
	await message.load_emotes_from_fragment(Twitch.media_loader)

	var bbcode := ""
	# Unique Id for the spriteframes to identify them
	var fragment_id : int = 0
	for fragment : TwitchChatMessage.Fragment in message.message.fragments:
		fragment_id += 1
		match fragment.type:
			TwitchChatMessage.FragmentType.text:
				bbcode += fragment.text
			TwitchChatMessage.FragmentType.cheermote:
				var definition : TwitchCheermoteDefinition = TwitchCheermoteDefinition.new(fragment.cheermote.prefix, "%s" % fragment.cheermote.tier)
				var cheermote : SpriteFrames = await fragment.cheermote.get_sprite_frames(Twitch.media_loader, definition)
				bbcode += "[sprite id='f-%s']%s[/sprite]" % [fragment_id, cheermote.resource_path]
			TwitchChatMessage.FragmentType.emote:
				var emote : SpriteFrames = await fragment.emote.get_sprite_frames(Twitch.media_loader, "", emote_scale)
				bbcode += "[sprite id='f-%s']%s[/sprite]" % [fragment_id, emote.resource_path]
			TwitchChatMessage.FragmentType.mention:
				bbcode += "[color=#00a0b6]%s[/color]" % fragment.mention.user_name
	return bbcode
