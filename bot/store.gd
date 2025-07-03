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
	
	func receive(plushie: CaughtPlushie) -> void:
		team.append(plushie)
		plushiedex[plushie.proto_name] = true

class CaughtPlushie:
	extends RefCounted
	var name: String = ""
	var proto_name: String = ""
	var xp: int = 0
	
	var stats := PlushieProto.Stats.new()
	
	func instantiate() -> Plushie:
		var proto := PlushieLib.proto(proto_name)
		var plushie := proto.instantiate()
		plushie.caught = self
		plushie.name = self.name
		plushie.lifetime_remaining = INF
		return plushie

	func gain_xp(xp: int) -> void:
		self.xp += xp
		var levels := 0
		var moves: Array[String] = []
		var proto := PlushieLib.proto(proto_name)
		while true:
			if self.xp >= stats.xp_to_level():
				self.xp -= stats.xp_to_level()
				stats.level_up()
				if proto.moves.has(stats.level()):
					moves.append(proto.moves[stats.level()])
				levels += 1
				continue
			break
		Store.save()
	
		var msg := "%s recieved %d XP." % [name, xp]
		if levels > 0:
			msg += " It got to level %d!" % stats.level()
		for move in moves:
			msg += " Learned new move: %s!" % move
		await Twitch.get_tree().create_timer(0.3).timeout
		Twitch.chat.send_message(msg)

var viewers: Dictionary[String, Viewer] = {}

func viewer(login: String, create: bool = false) -> Viewer:
	if login not in viewers:
		if !create: return Viewer.new()
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
			var msg := "Team member %s: LVL %d, %d ATK, %d DFN! XP: %d/%d" % [
				plushie.name,
				plushie.stats.level(),
				plushie.stats.attack,
				plushie.stats.defense,
				plushie.xp, plushie.stats.xp_to_level(),
			]
			Twitch.chat.send_message(msg, info.original_message.message_id)
			return
		
		var msg := "Your team consists of %d plushies" % chatter.team.size()
		if !chatter.team.is_empty():
			msg += ": "
			for plushie in chatter.team:
				if !msg.ends_with(" "): msg += ", "
				msg += plushie.name
		msg += "! Use !team <team member> to see stats of a plushie. See !help for more."

		Twitch.chat.send_message(msg, info.original_message.message_id)
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

	Twitch.connect_command("PlushieDex", func _on_plushiedex(from_username: String, info: TwitchCommandInfo, _args: PackedStringArray) -> void:
		var chatter := viewer(from_username)
		Twitch.chat.send_message("You have caught %d/%d plushies!" % [chatter.plushiedex.size(), PlushieLib.all.size()], info.original_message.message_id)
	)

	Twitch.connect_command("Gift", func _on_gift(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
		var recipient_login := args[0].to_lower()
		if !Twitch.recent_chatters.has(recipient_login): return
		
		var chatter := viewer(from_username)
		var plushie := chatter.get_team_member(args[1])
		if plushie == null: return
		
		var recipient := viewer(recipient_login, true)
		recipient.receive(plushie)
		chatter.team.erase(plushie)
		save()

		Twitch.chat.send_message("@%s now got %s!" % [args[0], plushie.name])
	)

func save() -> void:
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(Serializer.serialize(self), "  "))
