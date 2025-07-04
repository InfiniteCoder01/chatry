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
	
	moves["punch"] = Punch.new()
	moves["fire"] = Fire.new()

func strip_special_characters(name: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9#+\\-]")
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
		if plushie_name.contains(id):
			var score := id.length()
			if score > best_score:
				plushie = lib[id]
				best_score = score
	return plushie

# ------------------------------------------- Moves
class Move:
	func perform(_world: World, _plushie: PlushieInstance, _victim: PlushieInstance) -> void:
		pass

class Punch:
	extends Move

	func perform(_world: World, plushie: PlushieInstance, victim: PlushieInstance) -> void:
		plushie.attack(victim)

class Fire:
	extends Move

	func perform(world: World, plushie: PlushieInstance, victim: PlushieInstance) -> void:
		var fireball := preload("res://world/plushie/moves/fire/fireball.tscn").instantiate()
		fireball.position = plushie.soft_body.get_bones_center_position() + Vector2(0, -150)
		var impulse := victim.soft_body.get_bones_center_position() - plushie.soft_body.get_bones_center_position()
		impulse.y -= 300
		fireball.apply_impulse(impulse)
		fireball.caster = plushie
		world.add_child(fireball)
