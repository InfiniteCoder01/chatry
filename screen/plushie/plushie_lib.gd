extends Node

var lib: Dictionary[String, PlushieConfig] = {}
var all: Array[PlushieConfig] = []
var groups: Dictionary[String, Array] = {}
var moves: Dictionary[String, Move] = {}

func _ready() -> void:
	var plushie_dir := DirAccess.open("res://assets/plushies")
	if plushie_dir:
		plushie_dir.list_dir_begin()
		var file_name := plushie_dir.get_next()
		while file_name != "":
			if plushie_dir.current_is_dir():
				var config_file := ConfigFile.new()
				if config_file.load("res://assets/plushies/" + file_name + "/config.toml") != OK:
					print("Failed to load config file for plushie '" + file_name + "', using default")

				var config := PlushieConfig.new(file_name, config_file)
				all.append(config)

				var names := [config.name]
				names.append_array(config.aliases)
				for i in range(names.size()):
					names[i] = strip(names[i])
					lib[names[i]] = config

				for group: String in config.groups:
					group = strip(group)
					if !groups.has(group): groups[group] = []
					groups[group].append(config)
			file_name = plushie_dir.get_next()
	else:
		print("Plushie directory not found!")

	print("loaded %d plushies" % all.size())
	print("discovered groups:")
	for group: String in groups: print(group)
	
	moves["punch"] = Punch.new(["attack", "fight", "physical"])
	moves["fire"] = Fire.new()
	moves["raid"] = Raid.new()

func strip_special_characters(name: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9#+†\\-]")
	return regex.sub(name, "", true)

func strip(name: String) -> String:
	return strip_special_characters(name).to_lower()

func config(id: String) -> PlushieConfig:
	return lib[strip(id)]

func find(plushie_name: String) -> PlushieConfig:
	var stripped_name := strip(plushie_name)
	var plushie: PlushieConfig
	var best_score := 0
	for id: String in lib.keys():
		if stripped_name.contains(id):
			var score := id.length()
			if score > best_score:
				plushie = lib[id]
				best_score = score
		if plushie_name.to_lower().contains(id.to_lower()):
			var score := id.length()
			if score > best_score:
				plushie = lib[id]
				best_score = score
	return plushie

# ------------------------------------------- Moves
class Move:
	var aliases: PackedStringArray = []
	
	func _init(aliases: PackedStringArray = []) -> void:
		self.aliases = aliases
	
	static func launch_projectile(
		screen: Screen,
		plushie: PlushieInstance,
		victim: PlushieInstance,
		projectile: PackedScene,
		range: int = 0,
		apply_gravity: bool = true,
	) -> Node2D:
		var instance: Node2D = projectile.instantiate()
		instance.caster = plushie.plushie
		instance.chatter = plushie.chatter
		instance.position = plushie.soft_body.get_bones_center_position() + Vector2(0, -150)
		instance.position += Vector2(randi_range(0, range), 0).rotated(randf_range(0, TAU))
		
		var impulse := victim.soft_body.get_bones_center_position() - instance.position
		if apply_gravity: impulse.y -= 300
		instance.apply_impulse(impulse)
		screen.add_child(instance)
		return instance
	
	func perform(_screen: Screen, _plushie: PlushieInstance, _victim: PlushieInstance) -> void:
		pass

class Punch:
	extends Move

	func perform(_screen: Screen, plushie: PlushieInstance, victim: PlushieInstance) -> void:
		plushie.attack(victim)

class Fire:
	extends Move

	func perform(screen: Screen, plushie: PlushieInstance, victim: PlushieInstance) -> void:
		var fireball := preload("res://screen/plushie/moves/fire/fireball.tscn")
		Move.launch_projectile(screen, plushie, victim, fireball)

class Raid:
	extends Move

	func perform(screen: Screen, plushie: PlushieInstance, victim: PlushieInstance) -> void:
		var viewer := preload("res://screen/plushie/moves/raid/raider.tscn")

		for i in range(ceili(plushie.plushie.stats.attack / 10.0)):
			if !is_instance_valid(victim): return
			Move.launch_projectile(screen, plushie, victim, viewer, 50, false)
			await screen.get_tree().create_timer(0.1).timeout
