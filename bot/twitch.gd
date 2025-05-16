extends Node

@onready var bot: TwitchService = $Bot
@onready var broadcaster: TwitchService = $Broadcaster

@onready var chat: TwitchChat = $Bot/TwitchChat
@onready var media_loader: TwitchMediaLoader = $Bot/TwitchMediaLoader

@onready var broadcaster_api: TwitchAPI = $Broadcaster/TwitchAPI
@onready var broadcaster_chat: TwitchChat = $Broadcaster/TwitchChat
@onready var broadcaster_eventsub: TwitchEventsub = $Broadcaster/TwitchEventsub

@onready var sound_blaster: AudioStreamPlayer = %SoundBlaster

var simple_commands: Dictionary[String, String] = {}
var recent_chatters: Dictionary[String, bool]

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
	elif type == "channel.chat.message":
		recent_chatters[data.chatter_user_login] = true
		if data.message.text.begins_with("!") && simple_commands.has(data.message.text.substr(1)):
			var resp := simple_commands[data.message.text.substr(1)]
			resp = resp.replace("@user", "@%s" % data.chatter_user_name)
			chat.send_message(resp, data.message_id)

func _on_readchat(_from_username: String, _info: TwitchCommandInfo, _args: PackedStringArray) -> void:
	sound_blaster.stream = preload("res://assets/readchat.wav")
	sound_blaster.play()
