class_name Bot

static var instance := await Bot.new()
var config: Dictionary
var all_plushies := []
var plushies := {}
var groups := {}
var plushie: PackedScene = preload("res://world/plushie/plushie.tscn")

var world: World
var chat: TwitchIrcChannel

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
	if plushie_dir:
		plushie_dir.list_dir_begin()
		var file_name := plushie_dir.get_next()
		while file_name != "":
			if plushie_dir.current_is_dir():
				all_plushies.append(file_name)
				var aliases := [file_name]
				var plushie_config := ConfigFile.new()
				if plushie_config.load("res://assets/plushies/" + file_name + "/config.toml") != OK:
					print("Failed to load config file for plushie '" + file_name + "', skipping")
				aliases.append_array(plushie_config.get_value("", "aliases", []))
				for alias: String in aliases:
					plushies[alias] = file_name
					plushies[alias.replace('-', "")] = file_name
					plushies[alias.replace('-', ' ')] = file_name
					plushies[alias.replace('-', '.')] = file_name
					plushies[alias.replace('-', '_')] = file_name
				for group: String in plushie_config.get_value("", "groups", []):
					if !groups.has(group): groups[group] = []
					groups[group].append(file_name)
			file_name = plushie_dir.get_next()
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
		var plushie_instance := plushie.instantiate()
		var soft_body: SoftBody2D = plushie_instance.get_child(0)
		if args.is_empty():
			args = all_plushies.pick_random()
		if plushies.has(args.strip_escapes().to_lower()):
			soft_body.texture = load("res://assets/plushies/" + plushies[args.strip_escapes().to_lower()] + "/image.png") as Texture2D
		soft_body.global_position = Vector2(
			randf_range(
				10,
				world.get_viewport_rect().size.x - soft_body.texture.get_width() * soft_body.scale.x - 10
			),
			10
		)
		soft_body.create_softbody2d(true)
		world.get_node(^"Plushies").add_child(plushie_instance)
	elif command == "pick":
		if !admin && plushie_timeouts.has(author) && plushie_timeouts[author].time_left > 0.0:
			return
		plushie_timeouts[author] = world.get_tree().create_timer(10.0)
		var plushie_instance := plushie.instantiate()
		var soft_body: SoftBody2D = plushie_instance.get_child(0)
		if args.is_empty():
			args = all_plushies.pick_random()
		if groups.has(args.strip_escapes().to_lower()):
			soft_body.texture = load("res://assets/plushies/" + groups[args.strip_escapes().to_lower()].pick_random() + "/image.png") as Texture2D
		soft_body.global_position = Vector2(
			randf_range(
				10,
				world.get_viewport_rect().size.x - soft_body.texture.get_width() * soft_body.scale.x - 10
			),
			10
		)
		soft_body.create_softbody2d(true)
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
