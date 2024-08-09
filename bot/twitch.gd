class_name Twitch

static func setup_twitch(config_file: ConfigFile) -> void:
	var private_info := ConfigFile.new()
	if private_info.load("/mnt/D/Channel/Private/chatry.toml") != OK:
		print("Failed to load private info file")
		return

	# * Setup twitch settings
	TwitchSetting.broadcaster_id = config_file.get_value("", "broadcaster_user_id")
	TwitchSetting.irc_username = config_file.get_value("", "bot_name")
	TwitchSetting.client_id = private_info.get_value("", "client_id")
	TwitchSetting.client_secret = private_info.get_value("", "client_secret")

	# * Setup EventSub broadcaster auth
	var broadcaster_auth := await TwitchAuth.new()
	var broadcaster_auth_setting := await broadcaster_auth._get_setting()
	broadcaster_auth_setting.authorization_flow = OAuth.AuthorizationFlow.AUTHORIZATION_CODE_FLOW
	broadcaster_auth_setting.cache_file = TwitchSetting.auth_cache.replace("auth", "broadcaster_auth")

	broadcaster_auth.auth = OAuth.new(broadcaster_auth_setting)
	var broadcaster_api := TwitchRestAPI.new(broadcaster_auth)
	TwitchService.api = broadcaster_api
	#TwitchService.eventsub = TwitchService.eventsub_debug
	TwitchService.eventsub.api = broadcaster_api

	# * Setup eventsub subscribtions
	TwitchService.eventsub.event.connect(Bot._on_eventsub_message)
	TwitchService.eventsub.session_id_received.connect(func _eventsub_ws_connected(_id: String) -> void:
		TwitchService.eventsub.subscriptions.clear()
		TwitchService.eventsub.create_subscription("channel.chat.message_delete", "1", {
			"broadcaster_user_id": TwitchSetting.broadcaster_id,
			"user_id": TwitchSetting.broadcaster_id
		})
		TwitchService.eventsub.create_subscription("channel.follow", "2", {
			"broadcaster_user_id": TwitchSetting.broadcaster_id,
			"moderator_user_id": TwitchSetting.broadcaster_id
		})
		TwitchService.eventsub.create_subscription("channel.raid", "1", {
			"to_broadcaster_user_id": TwitchSetting.broadcaster_id,
		})
		TwitchService.eventsub.create_subscription("channel.channel_points_custom_reward_redemption.add", "1", {
			"broadcaster_user_id": TwitchSetting.broadcaster_id,
		})
		TwitchService.eventsub.create_subscription("channel.ad_break.begin", "1", {
			"broadcaster_user_id": TwitchSetting.broadcaster_id,
		})
		TwitchService.eventsub.create_subscription("channel.subscribe", "1", {
			"broadcaster_user_id": TwitchSetting.broadcaster_id,
		})
		TwitchService.eventsub.create_subscription("channel.subscription.gift", "1", {
			"broadcaster_user_id": TwitchSetting.broadcaster_id,
		})
		TwitchService.eventsub.create_subscription("channel.chat.notification", "1", {
			"broadcaster_user_id": TwitchSetting.broadcaster_id,
			"user_id": TwitchSetting.broadcaster_id,
		})
		TwitchService.eventsub.log.i("Registered eventsub")
	)

	# * Setup twitch
	print("Log in as bot")
	await TwitchService.setup()
	print("Log in as broadcaster")
	await TwitchService.api.auth.ensure_authentication()

	# * Setup IRC
	Bot.chat = TwitchIrcChannel.new()
	Bot.chat.channel_name = config_file.get_value("", "channel")
	Bot.chat.message_received.connect(Bot._on_chat_message);
	Bot.world.add_child(Bot.chat);

	# * Print notification
	var notification_format: String = config_file.get_value("", "notification_format", "Live on twitch! Streaming {title}")
	var channel_information := await TwitchService.api.get_channel_information()
	for item: TwitchChannelInformation in channel_information.data:
		print(notification_format.replace("{title}", item.title))

	# for reward in (await TwitchService.api.get_custom_reward_opt({})).data:
	#     print("%s: %s" % [reward.title, reward.id])

static func download(url: String, file_path: String) -> void:
	var http := HTTPRequest.new()
	Bot.world.add_child(http)
	http.set_download_file(file_path)
	http.request(url)
	await http.request_completed

static func cache(url: String) -> String:
	var file_path := "user://cache/%s" % [url.replace("http://", "").replace("https://", "")]
	if FileAccess.file_exists(file_path): return file_path
	DirAccess.make_dir_recursive_absolute(file_path.substr(0, file_path.rfind('/')))
	await Twitch.download(url, file_path)
	return file_path

static func monitor_ads() -> void:
	while true:
		var ad_scedule := await TwitchService.api.get_ad_schedule()
		if ad_scedule.data.size() < 1 || !ad_scedule.data[0].next_ad_at:
			await Bot.world.get_tree().create_timer(20.0).timeout
			continue

		var next_ad_in := ad_scedule.data[0].next_ad_at as float - Time.get_unix_time_from_system()
		if next_ad_in > 60.0 * 3.0:
			await Bot.world.get_tree().create_timer(next_ad_in - 60.0 * 3.0).timeout
			Bot.chat.chat("Ad break is coming in 3 minutes!")

			ad_scedule = await TwitchService.api.get_ad_schedule()
			if ad_scedule.data.size() < 1 || !ad_scedule.data[0].next_ad_at:
				await Bot.world.get_tree().create_timer(20.0).timeout
				continue
			next_ad_in = ad_scedule.data[0].next_ad_at as float - Time.get_unix_time_from_system()

		if next_ad_in > 60.0:
			await Bot.world.get_tree().create_timer(next_ad_in - 60.0).timeout
			Bot.chat.chat("Ad break is coming in 1 minute!")

		await Bot.world.get_tree().create_timer(5 * 60.0).timeout
