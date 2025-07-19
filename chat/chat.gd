class_name ChatOverlay
extends Control

func _ready() -> void:
	Twitch.chat.message_received.connect(_on_message_recieved)
	Twitch.broadcaster_eventsub.event.connect(_on_twitch_eventsub_event)

func _on_message_recieved(message: TwitchChatMessage) -> void:
	if !message.channel_points_custom_reward_id.is_empty(): return
	if message.message.text.begins_with('!punch') || message.message.text.begins_with('!catch'): return
	if message.chatter_user_login == "coderschatry" && message.message.text.contains("You couldn't catch"): return
	print("[%s] %s" % [message.chatter_user_name, message.message.text])
	$Messages.add_child(await ChatMessageLabel.new(message))

func _on_twitch_eventsub_event(type: StringName, data: Dictionary) -> void:
	var create_alert := func () -> Alert:
		var alert: Alert = preload("res://chat/alert/alert.tscn").instantiate()
		$Messages.add_child(alert)
		return alert

	if type == "channel.follow":
		create_alert.call().play(
			"follow",
			"[b][color=red]%s[/color][/b] joined the community! Thank you!" % data.user_name
		)
	elif type == "channel.raid":
		create_alert.call().play(
			"raid",
			"[b][color=red]%s[/color][/b] is raiding with [b][color=blue]%d[/color][/b] viewers!"
			% [data.from_broadcaster_user_name, data.viewers]
		)
	elif type == "channel.subscribe":
		create_alert.call().play(
			"sub",
			"[b][color=red]%s[/color][/b] subscribed as Tier %s! Thank you!" % [data.user_name, data.tier]
		)
	elif type == "channel.subscription.gift":
		create_alert.call().play(
			"sub",
			"[b][color=red]%s[/color][/b] was gifted a Tier %s sub! Thank you!" % [data.user_name, data.tier]
		)
	elif type == "channel.channel_points_custom_reward_redemption.add":
		var opt := TwitchGetCustomReward.Opt.create()
		opt.id = [data.reward.id]
		var reward: TwitchGetCustomReward.Response = await Twitch.broadcaster_api.get_custom_reward(opt, Twitch.chat.broadcaster_user.id)
		
		var image_url := reward.data[0].image.url_4x if reward.data[0].image != null else reward.data[0].default_image.url_4x
		var image := ImageTexture.create_from_image(Image.load_from_file(await Cache.cache(image_url)))
		var sprite_frames := SpriteFrames.new()
		sprite_frames.set_animation_speed("default", 1.0 / 8.0)
		sprite_frames.add_frame("default", image)

		var sound := preload("res://assets/alerts/redeem.wav")
		if data.reward.title == "\"Ok, let\'s go!\"":
			sound = preload("res://assets/sounds/ok_lets_go.wav")

		create_alert.call().play_raw(
			sprite_frames,
			sound,
			(
				"[b][color=red]%s[/color][/b]" +
				" redeemed [b][color=blue]%s[/color][/b]" +
				" for [b][color=blue]%d[/color][/b] strings.\n%s"
			) % [
				data.user_name,
				data.reward.title,
				data.reward.cost,
				data.user_input,
			],
			3.0
		)
