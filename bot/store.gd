extends Node

class Viewer:
	extends RefCounted
	var team: Array[Plushie] = []
	var plushiedex: Dictionary[String, bool] = {}
	
	func get_team_member(name: String) -> Plushie:
		for i in range(team.size()):
			var plushie := team[team.size() - i - 1]
			if plushie.name_matches(name): return plushie
		return null
	
	func receive(plushie: Plushie) -> void:
		plushie.wild = false
		team.append(plushie)
		plushiedex[plushie.id] = true

var viewers: Dictionary[String, Viewer] = {}

func viewer(login: String, create: bool = false) -> Viewer:
	if login not in viewers:
		if !create: return Viewer.new()
		viewers[login] = Viewer.new()
	return viewers[login]

# ---------------------------------------------- Formatting functions
func format_strings(strings: PackedStringArray) -> String:
	var result := ""
	for i in range(strings.size()):
		if i > 0:
			if i == strings.size() - 1: result += " and "
			else: result += ", "
		result += strings[i]
	return result

# ---------------------------------------------- Store
const STORE_PATH := "store.json"

func _ready() -> void:
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	Serializer.deserialize(self, JSON.parse_string(file.get_as_text()))
	
	for viewer: Viewer in viewers.values():
		for plushie: Plushie in viewer.team:
			plushie.wild = false
			while plushie.xp >= plushie.xp_to_level_up():
				plushie.xp -= plushie.xp_to_level_up()
				plushie.level_up()

	Twitch.connect_command("Team", func _on_plushiedex(from_username: String, info: TwitchCommandInfo, args: PackedStringArray) -> void:
		var chatter := viewer(from_username)
		
		if !args.is_empty():
			var plushie := chatter.get_team_member(args[0])
			if plushie == null:
				Twitch.chat.send_message("%s is not in your team!" % args[0], info.original_message.message_id)
				return
			var msg := "Team member %s: LVL %d, %d ATK, %d DFN! XP: %d/%d" % [
				plushie.name,
				#PlushieLib.config(plushie.id).name,
				plushie.level(),
				plushie.stats.attack,
				plushie.stats.defense,
				plushie.xp, plushie.xp_to_level_up(),
			]
			var moves := plushie.get_available_moves()
			if !moves.is_empty():
				msg += ". Learned moves: %s" % format_strings(moves)
			Twitch.chat.send_message(msg, info.original_message.message_id)
			return
		
		var msg := "Your team consists of %d plushies" % chatter.team.size()
		if !chatter.team.is_empty():
			msg += ": %s" % format_strings(chatter.team.map(func (plushie: Plushie) -> String:
				return "%s (LVL %s)" % [plushie.name, plushie.level()]
			))
		msg += "! Use !team <team member> to see stats of a plushie. See !help for more."

		Twitch.chat.send_message(msg, info.original_message.message_id)
	)

	Twitch.connect_command("Rename", func _on_rename(from_username: String, info: TwitchCommandInfo, args: PackedStringArray) -> void:
		var chatter := viewer(from_username)
		if chatter.team.is_empty(): return
		args[0] = args[0].replace("_", " ")
		if args.size() > 1: args[1] = args[1].replace("_", " ")
		
		if args.size() == 1: chatter.team.back().name = args[0]
		else:
			var plushie := chatter.get_team_member(args[0])
			if plushie == null:
				Twitch.chat.send_message("%s is not in your team!" % args[0], info.original_message.message_id)
				return
			plushie.name = args[1]
		save()
	)

	Twitch.connect_command("PlushieDex", func _on_plushiedex(from_username: String, info: TwitchCommandInfo, _args: PackedStringArray) -> void:
		var chatter := viewer(from_username)
		Twitch.chat.send_message("You have caught %d/%d plushies!" % [chatter.plushiedex.size(), PlushieLib.all.size()], info.original_message.message_id)
	)

	Twitch.connect_command("Gift", func _on_gift(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
		var recipient_login := args[0].to_lower()
		if !Twitch.recent_chatters.has(recipient_login) && !viewers.has(recipient_login): return
		
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
