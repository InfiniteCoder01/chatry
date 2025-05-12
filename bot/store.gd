extends Node

class Viewer:
	extends RefCounted
	var team: Array[CaughtPlushie] = []
	var plushiedex: Dictionary[String, bool] = {}
	
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
	
	var stats := PlushieProto.Stats.new()
	
	func instantiate() -> Plushie:
		var proto := PlushieLib.proto(proto_name)
		var plushie := proto.instantiate()
		plushie.caught = self
		return plushie

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

	Twitch.connect_command("Team", func _on_plushiedex(from_username: String, info: TwitchCommandInfo, args: PackedStringArray) -> void:
		var chatter := viewer(from_username)
		
		if !args.is_empty():
			var plushie := chatter.get_team_member(" ".join(args))
			if plushie == null: return
			var msg := "Team member %s has attack of %d and defense of %d!" % [
				plushie.name,
				plushie.stats.attack,
				plushie.stats.defense,
			]
			Twitch.chat.send_message(msg, info.original_message.message_id)
			return
		
		var msg := "Your team consists of %d plushies" % chatter.team.size()
		if chatter.team.is_empty(): msg += "!"
		else:
			msg += ": "
			for plushie in chatter.team:
				if !msg.ends_with(" "): msg += ", "
				msg += plushie.name
			msg += "!"
		Twitch.chat.send_message(msg, info.original_message.message_id)
	)
#
	#Twitch.connect_command("Catch", func _on_catch(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
		#var proto: PlushieProto = PlushieProto.find_plushie(" ".join(args))
		#if proto == null: return
		##viewer(from_username).team.append(CaughtPlushie.new(proto.name))
		#save()
	#)

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

	Twitch.connect_command("PlushieDex", func _on_plushiedex(from_username: String, info: TwitchCommandInfo, _args: PackedStringArray) -> void:
		var chatter := viewer(from_username)
		Twitch.chat.send_message("You have caught %d/%d plushies!" % [chatter.plushiedex.size(), PlushieLib.all.size()], info.original_message.message_id)
	)

func save() -> void:
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(Serializer.serialize(self), "  "))
