extends Node

class Viewer:
	extends RefCounted
	var team: Array[CaughtPlushie]
	
	func get_team_member(name: String) -> CaughtPlushie:
		for i in range(team.size()):
			var plushie := team[team.size() - i - 1]
			if plushie.name.to_lower() == name.to_lower():
				return plushie
		return null

class CaughtPlushie:
	extends RefCounted
	var name: String = ""
	var proto_name: String = ""

	func _init(proto_name: String = "") -> void:
		self.proto_name = proto_name
		self.name = proto_name

var viewers: Dictionary[String, Viewer] = {}

func viewer(login: String) -> Viewer:
	if login not in viewers:
		viewers[login] = Viewer.new()
	return viewers[login]

# ----------------------------------------------
const STORE_PATH := "/mnt/D/Channel/store.json"
func _ready() -> void:
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	Serializer.deserialize(self, JSON.parse_string(file.get_as_text()))

	Twitch.connect_command("PlushieDex", func _on_plushiedex(from_username: String, info: TwitchCommandInfo, _args: PackedStringArray) -> void:
		var team := viewer(from_username).team
		var msg := "You have caught %d plushies" % team.size()
		if team.is_empty(): msg += "!"
		else:
			msg += ": "
			for plushie in team:
				if !msg.ends_with(" "): msg += ", "
				msg += plushie.name
			msg += "!"
		Twitch.chat.send_message(msg, info.original_message.message_id)
	)

	Twitch.connect_command("Catch", func _on_catch(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
		# FIXME: For whatever reason godot errors out here and tells me that Twitch.find_plushie doesn't have
		# a static return type\
		var proto: PlushieProto = Twitch.find_plushie(" ".join(args))
		if proto == null: return
		viewer(from_username).team.append(CaughtPlushie.new(proto.name))
		save()
	)

	Twitch.connect_command("Rename", func _on_catch(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
		var chatter := viewer(from_username)
		if chatter.team.is_empty(): return
		
		if args.size() == 1: chatter.team.back().name = args[0]
		else:
			var plushie := chatter.get_team_member(args[0])
			if plushie == null: return
			plushie.name = args[1]
		save()
	)

func save() -> void:
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(Serializer.serialize(self), "  "))
