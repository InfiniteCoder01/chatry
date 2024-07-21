class_name Bot

static var instance := await Bot.new()
var config: Dictionary
var all_plushies := []
var plushies := {}
var groups := {}
var plushie: PackedScene = preload("res://world/plushie/plushie.tscn")

var world: World
var chat: TwitchIrcChannel

func strip_special_characters(args: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9#]")
	return regex.sub(args, "", true)

func _init() -> void:
	var config_file := ConfigFile.new()
	if config_file.load("res://config.toml") != OK:
		print("Failed to load config file")
		return

	config.qotd = config_file.get_value("", "qotd")
	config.admins = PackedStringArray()
	for admin: String in config_file.get_value("", "admins"):
		config.admins.append(admin.to_lower())

	config.simple_commands = {}
	for cmd: String in config_file.get_section_keys("simple_commands"):
		config.simple_commands[cmd] = config_file.get_value("simple_commands", cmd)

	var private_info := ConfigFile.new()
	if private_info.load("/mnt/D/Channel/Private/chatry.toml") != OK:
		print("Failed to load private info file")
		return

	ProjectSettings.set_setting("twitch/auth/broadcaster_id", config_file.get_value("", "broadcaster_id"))
	ProjectSettings.set_setting("twitch/websocket/irc/username", config_file.get_value("", "bot_name"))
	ProjectSettings.set_setting("twitch/auth/client_id", private_info.get_value("", "client_id"))
	ProjectSettings.set_setting("twitch/auth/client_secret", private_info.get_value("", "client_secret"))
	await TwitchService.setup();

	chat = TwitchIrcChannel.new()
	chat.channel_name = config_file.get_value("", "channel")
	chat.message_received.connect(_on_chat_message);
	world.add_child(chat);
	# TwitchService.eventsub.event.connect(_on_eventsub_message);

	# * Load plushies
	var plushie_dir := DirAccess.open("res://assets/plushies")
	var test_groups := {}
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
				names.append_array(plushie_config.get_value("", "names", []))
				for i in range(names.size()): names[i] = strip_special_characters(names[i]).to_lower()
				plushies[file_name] = names

				for group: String in plushie_config.get_value("", "groups", []):
					if !test_groups.has(group): test_groups[group] = []
					test_groups[group].append(file_name)
					group = strip_special_characters(group).to_lower()
					if !groups.has(group): groups[group] = []
					groups[group].append(file_name)
			file_name = plushie_dir.get_next()
		print(JSON.stringify(test_groups, "\t"))
	else:
		print("An error occurred when loading plushies.")

func _on_chat_message(from_user: String, message: String, tags: TwitchTags.Message) -> void:
	world.chat_overlay.add_message(from_user, message, tags)
	if message[0] == '!':
		var raw_args: PackedStringArray = message.substr(1).split(' ', true, 1)
		var command: String = raw_args[0]
		var args: String = "" if raw_args.size() < 2 else raw_args[1]
		on_command(command, args, from_user)

func quick_command(command: String, args: String) -> void:
	on_command(command, args, "InfiniteCoder01")

var plushie_timeouts := {}
var basketball_timeout: SceneTreeTimer = null

func on_command(command: String, args: String, author: String) -> void:
	var admin: bool = config.admins.has(author.to_lower())
	if command == "plushie":
		if !admin && plushie_timeouts.has(author) && plushie_timeouts[author].time_left > 0.0:
			return
		plushie_timeouts[author] = world.get_tree().create_timer(10.0)
		var plushie_instance: Plushie = plushie.instantiate()
		var plushie_id: String
		args = strip_special_characters(args).to_lower()
		if args.is_empty():
			plushie_id = all_plushies.pick_random()
		else:
			var best_score := 0
			for id: String in plushies.keys():
				var score := 0
				for name: String in plushies[id]:
					if args.contains(name):
						score += name.length()
				if score > best_score:
					plushie_id = id
					best_score = score

		if !plushie_id.is_empty(): plushie_instance.assign(plushie_id)
		plushie_instance.position_randomly(world.get_viewport_rect())
		world.get_node(^"Plushies").add_child(plushie_instance)
	elif command == "pick":
		if !admin && plushie_timeouts.has(author) && plushie_timeouts[author].time_left > 0.0:
			return
		plushie_timeouts[author] = world.get_tree().create_timer(10.0)
		var plushie_instance: Plushie = plushie.instantiate()
		args = strip_special_characters(args).to_lower()
		if groups.has(args):
			plushie_instance.assign(groups[args].pick_random())
		plushie_instance.position_randomly(world.get_viewport_rect())
		world.get_node(^"Plushies").add_child(plushie_instance)
	elif command == "basketball":
		if !admin && basketball_timeout && basketball_timeout.time_left > 0.0:
			return
		basketball_timeout = world.get_tree().create_timer(120.0)
		var hoop := preload("res://world/basketball/hoop.tscn").instantiate()
		hoop.position = world.get_viewport_rect().size * Vector2(0.9, 0.5)
		world.add_child(hoop)
	elif command == "readchat":
		world.sound_blaster.stream = preload("res://assets/readchat.wav")
		world.sound_blaster.play()
	elif command == "qotd":
		chat.chat("@%s %s" % [author, config.qotd])
	elif command == "orco":
		var terminal: RichTextLabel = world.get_node(^"CanvasLayer/Control/MarginContainer/VBoxContainer/Terminal")
		terminal.clear()
		terminal.push_mono()

		var process := ProcessNode.new();
		process.cmd = "docker";
		process.args = PackedStringArray(["run", "--cpus", "0.5", "--memory", "20m", "--read-only", "-v", "/mnt/Twitch:/home", "-i", "twitch-linux", "./compile.sh"]);
		process.stdout.connect(
			func _on_stdout(data: PackedByteArray) -> void:
				terminal.append_text(data.get_string_from_utf8())
				terminal.add_text("\n")
		)
		process.stderr.connect(
			func _on_stderr(data: PackedByteArray) -> void:
				terminal.append_text("[color=yellow]%s[/color]" % data.get_string_from_utf8())
				terminal.add_text("\n")
		)
		process.finished.connect(
			func _on_finised(_exit_code: int) -> void:
				terminal.remove_child(process)
				process.queue_free()
		)

		process.start()
		terminal.add_child(process)
		process.write_stdin(args.to_utf8_buffer())
		process.eof_stdin()
	elif command == "lurk":
		chat.chat("Have a nice lurk, @%s. Lurkers are a power of Software and Game development streams!" % [author])
	for cmd: String in config.simple_commands.keys():
		if command == cmd:
			chat.chat("@%s %s" % [author, config.simple_commands[cmd]])
	# TODO: !jail
