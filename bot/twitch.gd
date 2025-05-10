extends Node

@onready var bot: TwitchService = $Bot
@onready var broadcaster: TwitchService = $Broadcaster

@onready var chat: TwitchChat = $Bot/TwitchChat
@onready var media_loader: TwitchMediaLoader = $Bot/TwitchMediaLoader

@onready var broadcaster_api: TwitchAPI = $Broadcaster/TwitchAPI
@onready var broadcaster_chat: TwitchChat = $Broadcaster/TwitchChat
@onready var broadcaster_eventsub: TwitchEventsub = $Broadcaster/TwitchEventsub

@onready var sound_blaster: AudioStreamPlayer = %SoundBlaster

var plushies: Dictionary[String, PlushieProto] = {}
var all_plushies: Array[PlushieProto] = []
var plushie_groups: Dictionary = {}

var simple_commands: Dictionary = {}

func strip_special_characters(args: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9#+]")
	return regex.sub(args, "", true)

func find_plushie(plushie_name: String) -> PlushieProto:
	plushie_name = strip_special_characters(plushie_name).to_lower()
	print(plushie_name)
	var plushie: PlushieProto
	var best_score := 0
	for id: String in plushies.keys():
		if plushie_name.contains(id):
			var score := id.length()
			if score > best_score:
				plushie = plushies[id]
				best_score = score
	return plushie

func _ready() -> void:
	print("Authorize bot")
	await bot.setup()
	print("Authorize broadcaster")
	await broadcaster.setup()
	Plushie.connect_heat()
	
	var config_file := ConfigFile.new()
	if config_file.load("res://config.toml") != OK:
		print("Failed to load config file")
		return

	for cmd: String in config_file.get_section_keys("simple_commands"):
		simple_commands[cmd] = config_file.get_value("simple_commands", cmd)

	#for sound: String in config_file.get_section_keys("redeem_sounds"):
		#redeem_sounds[strip_special_characters(sound)] = config_file.get_value("redeem_sounds", sound)

	# * Load plushies
	var plushie_dir := DirAccess.open("res://assets/plushies")
	if plushie_dir:
		plushie_dir.list_dir_begin()
		var file_name := plushie_dir.get_next()
		while file_name != "":
			if plushie_dir.current_is_dir():
				var plushie_config := ConfigFile.new()
				if plushie_config.load("res://assets/plushies/" + file_name + "/config.toml") != OK:
					print("Failed to load config file for plushie '" + file_name + "', skipping")

				var proto := PlushieProto.new(file_name, plushie_config)
				all_plushies.append(proto)

				var names := [file_name]
				names.append_array(plushie_config.get_value("", "aliases", []))
				for i in range(names.size()):
					names[i] = strip_special_characters(names[i]).to_lower()
					plushies[names[i]] = proto

				for group: String in plushie_config.get_value("", "groups", []):
					group = strip_special_characters(group).to_lower()
					if !plushie_groups.has(group): plushie_groups[group] = []
					plushie_groups[group].append(proto)
			file_name = plushie_dir.get_next()
	else:
		print("Plushie directory not found!")

var timeouts := {}
func timeout(author: String, topic: String, time: float) -> bool:
	if !timeouts.has(topic): timeouts[topic] = {}
	if timeouts[topic].has(author) && timeouts[topic][author].time_left > 0.0: return true
	timeouts[topic][author] = get_tree().create_timer(time)
	return false

const MOD_STREAMER_VIP := TwitchCommand.PermissionFlag.MOD | TwitchCommand.PermissionFlag.STREAMER | TwitchCommand.PermissionFlag.VIP

func connect_command(name: String, callback: Callable) -> void:
	$Bot/Commands.find_child(name).command_received.connect(callback)

func _on_twitch_eventsub_event(type: StringName, data: Dictionary) -> void:
	if type == "channel.raid":
		await bot.shoutout(await bot.get_user_by_id(data.from_broadcaster_user_id))
	elif type == "channel.chat.message" && data.message.text.begins_with("!") && simple_commands.has(data.message.text.substr(1)):
		var resp: String = simple_commands[data.message.text.substr(1)]
		resp = resp.replace("@user", "@%s" % data.chatter_user_name)
		chat.send_message(resp, data.message_id)

func _on_readchat(_from_username: String, _info: TwitchCommandInfo, _args: PackedStringArray) -> void:
	sound_blaster.stream = preload("res://assets/readchat.wav")
	sound_blaster.play()
