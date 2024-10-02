class_name Twitch

static func setup_twitch() -> void:
	pass
	# * Print notification
	#var notification_format: String = config_file.get_value("", "notification_format", "Live on twitch! Streaming {title}")
	#var channel_information := await TwitchService.api.get_channel_information()
	#for item: TwitchChannelInformation in channel_information.data:
		#print(notification_format.replace("{title}", item.title))

	# for reward in (await TwitchService.api.get_custom_reward_opt({})).data:
	#     print("%s: %s" % [reward.title, reward.id])

static func download(url: String, file_path: String) -> void:
	var http := HTTPRequest.new()
	Bot.world.add_child(http)
	http.set_download_file(file_path)
	http.request(url)
	await http.request_completed

static func cache(url: String, ext: String) -> String:
	var file_path := "user://cache/%s" % [url.replace("http://", "").replace("https://", "")]
	if ext != null: file_path += ext
	if FileAccess.file_exists(file_path): return file_path
	DirAccess.make_dir_recursive_absolute(file_path.substr(0, file_path.rfind('/')))
	await Twitch.download(url, file_path)
	return file_path

static func monitor_ads() -> void:
	while true:
		var ad_scedule := Bot.twitch_broadcaster.get_ad_schedule()
		if ad_scedule.size() < 1 || !ad_scedule[0].next_ad_at:
			await Bot.world.get_tree().create_timer(20.0).timeout
			continue

		var next_ad_in := ad_scedule[0].next_ad_at as float - Time.get_unix_time_from_system()
		if next_ad_in > 60.0 * 3.0:
			await Bot.world.get_tree().create_timer(next_ad_in - 60.0 * 3.0).timeout
			Bot.twitch_bot.send_chat_message("Ad break is coming in 3 minutes!")

			ad_scedule = Bot.twitch_broadcaster.get_ad_schedule()
			if ad_scedule.size() < 1 || !ad_scedule[0].next_ad_at:
				await Bot.world.get_tree().create_timer(20.0).timeout
				continue
			next_ad_in = ad_scedule[0].next_ad_at as float - Time.get_unix_time_from_system()

		if next_ad_in > 60.0:
			await Bot.world.get_tree().create_timer(next_ad_in - 60.0).timeout
			Bot.twitch_bot.send_chat_message("Ad break is coming in 1 minute!")

		await Bot.world.get_tree().create_timer(5 * 60.0).timeout
