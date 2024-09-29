class_name ChatMessageLabel
extends RichTextLabel

var data: GMessageData

func _init(message: GMessageData) -> void:
	data = message
	fit_content = true
	selection_enabled = true

	#for badge: GBadge in message.badges:
		#pass

	append_text("[b][color=%s]%s[/color]: [/b]" % [message.colour, message.chatter.name]);
	for fragment: GFragments in message.message.fragments:
		if fragment.kind == "text": add_text(fragment.text)
		if fragment.kind == "cheermote": add_text(fragment.text)
		if fragment.kind == "emote":
			for emote: GEmote in fragment.emote:
				var emote_path := await Twitch.cache(Bot.twitch_bot.get_emote_url_1x(emote), ".gif" if emote.has_animation() else ".png")
				if emote.has_animation():
					add_image(GifManager.animated_texture_from_file(emote_path))
				else:
					var img := Image.new()
					img.load(emote_path)
					add_image(ImageTexture.create_from_image(img))
		elif fragment.kind == "mention": append_text("[b][color=green]%s[/color][/b]" % fragment.text)

func _ready() -> void:
	await get_tree().create_timer(20.0).timeout
	queue_free()
