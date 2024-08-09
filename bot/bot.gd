extends Node

var all_plushies := []
var plushies := {}
var groups := {}
var plushie: PackedScene = preload("res://world/plushie/plushie.tscn")

var world: World
var chat: TwitchIrcChannel

var qotd: String
var admins := PackedStringArray()
var simple_commands := {}
var redeem_sounds := {}

func strip_special_characters(args: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9#+]")
	return regex.sub(args, "", true)

func log_message(message: String) -> void:
	print_rich("[color=lightblue][b][LOG][/b] %s[/color]" % message)
	var log_file: FileAccess
	if FileAccess.file_exists("user://bot_log.log"):
		log_file = FileAccess.open("user://bot_log.log", FileAccess	.READ_WRITE)
	else:
		log_file = FileAccess.open("user://bot_log.log", FileAccess.WRITE)
	if log_file:
		log_file.seek_end()
		log_file.store_line(message)
		log_file.close()

func _ready() -> void:
	var config_file := ConfigFile.new()
	if config_file.load("res://config.toml") != OK:
		print("Failed to load confi	g file")
		return

	qotd = config_file.get_value("", "qotd")
	for admin: String in config_file.get_value("", "admins"):
		admins.append(admin.to_lower())

	for cmd: String in config_file.get_section_keys("simple_commands"):
		simple_commands[cmd] = config_file.get_value("simple_commands", cmd)

	for sound: String in config_file.get_section_keys("redeem_sounds"):
		redeem_sounds[strip_special_characters(sound)] = config_file.get_value("redeem_sounds", sound)

	Twitch.setup_twitch(config_file)
	Plushie.connect_heat()

	# * Load plushies
	var plushie_dir := DirAccess.open("res://assets/plushies")
	if plushie_dir:
		plushie_dir.list_dir_begin()
		var file_name := plushie_dir.get_next()
		while file_name != "":
			if plushie_dir.current_is_dir():
				all_plushies.append(file_name)

				var plushie_config := ConfigFile.new()
				if plushie_config.load("res://assets/plushies/" + file_name + "/config.toml") != OK:
					print("Failed to load config file for plushie '" + file_name + "', skipping")

				var names := [file_name]
				names.append_array(plushie_config.get_value("", "aliases", []))
				for i in range(names.size()): names[i] = strip_special_characters(names[i]).to_lower()
				plushies[file_name] = names

				for group: String in plushie_config.get_value("", "groups", []):
					group = strip_special_characters(group).to_lower()
					if !groups.has(group): groups[group] = []
					groups[group].append(file_name)
			file_name = plushie_dir.get_next()
	else:
		print("Plushie directory not found!")
	
	Twitch.monitor_ads()

func _on_eventsub_message(type: String, data: Dictionary) -> void:
	log_message("Event '%s': %s" % [type, data])
	if type == "channel.chat.message_delete":
		for message: ChatMessageLabel in world.chat_overlay.get_child(0).get_children():
			if message.message_id == data.message_id:
				message.queue_free()
	elif type == "channel.follow":
		world.alertbox.play("follow", "[b][color=red]%s[/color][/b] joined the community! Thank you!" % data.user_name)
	elif type == "channel.raid":
		world.alertbox.play(
			"raid",
			"[b][color=red]%s[/color][/b] is raiding with [b][color=blue]%d[/color][/b] viewers!"
			% [data.from_broadcaster_user_name, data.viewers]
		)
		TwitchService.api.send_a_shoutout(data.to_broadcaster_user_id, data.from_broadcaster_user_id, TwitchSetting.broadcaster_id)
		var plushie_id := find_plushie(data.from_broadcaster_user_name)
		if !plushie_id.is_empty():
			for i in range(10):
				var plushie_instance: Plushie = plushie.instantiate()
				plushie_instance.assign(plushie_id)
				plushie_instance.position_randomly(world.get_viewport_rect())
				world.get_node(^"Plushies").add_child(plushie_instance)
				await world.get_tree().create_timer(1.0).timeout
	elif type == "channel.subscribe":
		world.alertbox.play("sub", "[b][color=red]%s[/color][/b] subscribed as Tier %s! Thank you!" % [data.user_name, data.tier])
	elif type == "channel.channel_points_custom_reward_redemption.add":
		var reward_info := (await TwitchService.api.get_custom_reward([data.reward.id], false)).data[0]
		var title_id := strip_special_characters(reward_info.title).to_lower()
		if reward_info.title == "Basketball!":
			basketball(true)
		else:
			if redeem_sounds.has(title_id):
				world.sound_blaster.stream = load(redeem_sounds[title_id])
				world.sound_blaster.play()
				return
		var image: String = reward_info.image.url_4x if reward_info.image else reward_info.default_image.url_4x
		var sprite_frames := SpriteFrames.new()
		sprite_frames.set_animation_speed("default", 1.0 / 8.0)
		sprite_frames.add_frame("default", ImageTexture.create_from_image(Image.load_from_file(await Twitch.cache(image))))
		world.alertbox.play_raw(
			sprite_frames,
			preload("res://assets/alerts/redeem.wav"),
			(
				"[b][color=red]%s[/color][/b]" +
				" redeemed [b][color=blue]%s[/color][/b]" +
				" for [b][color=blue]%d[/color][/b] strings.\n%s"
			) % [
				data.user_name,
				reward_info.title,
				reward_info.cost,
				data.user_input
			],
			3.0
		)
	elif type == "channel.ad_break.begin":
		chat.chat("%d second AD has started!" % data.duration_seconds)
		await get_tree().create_timer(data.duration_seconds).timeout
		chat.chat("The AD is done!")
	else: print("Unknown message: %s" % type)

func _on_chat_message(from_user: String, message: String, tags: TwitchTags.Message) -> void:
	world.chat_overlay.add_message(from_user, message, tags)
	if message[0] == '!':
		var raw_args: PackedStringArray = message.substr(1).split(' ', true, 1)
		var command: String = raw_args[0]
		var args: String = "" if raw_args.size() < 2 else raw_args[1]
		on_command(command, args, from_user, tags)

# ******************************************************************** On Command
func on_command(command: String, args: String, author: String, tags: TwitchTags.Message) -> void:
	var admin: bool = admins.has(author.to_lower())
	var privmsg: TwitchTags.PrivMsg = tags.raw
	if command == "label":
		if !admin: return

	elif command == "plushie":
		if !admin && timeout(author, "plushies", 10.0): return
		args = find_plushie(args)
		if args.is_empty():
			if timeouts.has("plushies"): timeouts["plushies"].erase(author)
			return

		var plushie_instance: Plushie = plushie.instantiate()
		plushie_instance.assign(args)
		plushie_instance.position_randomly(world.get_viewport_rect())
		plushie_instance.viewer_id = privmsg.user_id
		world.get_node(^"Plushies").add_child(plushie_instance)
	elif command == "pick":
		if !admin && timeout(author, "plushies", 10.0): return

		args = strip_special_characters(args).to_lower()
		if !groups.has(args):
			if timeouts.has("plushies"): timeouts["plushies"].erase(author)
			return

		var plushie_instance: Plushie = plushie.instantiate()
		plushie_instance.assign(groups[args].pick_random())
		plushie_instance.position_randomly(world.get_viewport_rect())
		plushie_instance.viewer_id = privmsg.user_id
		world.get_node(^"Plushies").add_child(plushie_instance)
	elif command == "readchat":
		world.sound_blaster.stream = preload("res://assets/readchat.wav")
		world.sound_blaster.play()
	elif command == "qotd":
		chat.chat("@%s %s" % [author, qotd])
	elif command == "orco":
		OrCo.execute(args, world.get_node(^"%Terminal"))
	elif command == "lurk":
		chat.chat("Have a nice lurk, @%s. Lurkers are a power of Software and Game development streams!" % [author])
	elif command == "unlurk":
		chat.chat("Welcome back, @%s!" % [author])
	else:
		for cmd: String in simple_commands.keys():
			if command == cmd:
				chat.chat("@%s %s" % [author, simple_commands[cmd]])
	# TODO: !jail

var timeouts := {}
func timeout(author: String, topic: String, time: float) -> bool:
	if !timeouts.has(topic): timeouts[topic] = {}
	if timeouts[topic].has(author) && timeouts[topic][author].time_left > 0.0: return true
	timeouts[topic][author] = world.get_tree().create_timer(time)
	return false

func find_plushie(args: String) -> String:
	var plushie_id := ""
	args = strip_special_characters(args).to_lower()
	if args.is_empty():
		plushie_id = all_plushies.pick_random()
	else:
		var best_score := 0
		for id: String in plushies.keys():
			var score := 0
			for plushie_name: String in plushies[id]:
				if args.contains(plushie_name):
					score += plushie_name.length()
			if score > best_score:
				plushie_id = id
				best_score = score
	return plushie_id

func random_plushie() -> Plushie:
	var plushie_instance: Plushie = plushie.instantiate()
	plushie_instance.assign(plushies.keys().pick_random())
	plushie_instance.position_randomly(world.get_viewport_rect())
	world.get_node(^"Plushies").add_child(plushie_instance)
	return plushie_instance

func basketball(setup: bool) -> void:
	var hoop := preload("res://world/basketball/hoop.tscn").instantiate()
	hoop.position = world.get_viewport_rect().size * Vector2(0.9, 0.5)
	world.add_child(hoop)
	if setup:
		Bot.random_plushie()
