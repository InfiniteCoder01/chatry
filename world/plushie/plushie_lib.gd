extends Node

var plushies: Dictionary[String, PlushieProto] = {}
var all: Array[PlushieProto] = []
var groups: Dictionary[String, Array] = {}
var moves: Dictionary[String, Move] = {}

func _ready() -> void:
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
				all.append(proto)

				var names := [file_name]
				names.append_array(plushie_config.get_value("", "aliases", []))
				for i in range(names.size()):
					names[i] = strip(names[i])
					plushies[names[i]] = proto

				for group: String in plushie_config.get_value("", "groups", []):
					group = strip(group)
					if !groups.has(group): groups[group] = []
					groups[group].append(proto)
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

func proto(plushie_name: String) -> PlushieProto:
	plushie_name = strip(plushie_name)
	return plushies[plushie_name]

func find(plushie_name: String) -> PlushieProto:
	var stripped_name := strip(plushie_name)
	var plushie: PlushieProto
	var best_score := 0
	for id: String in plushies.keys():
		if stripped_name.contains(id):
			var score := id.length()
			if score > best_score:
				plushie = plushies[id]
				best_score = score
		if plushie_name.contains(id):
			var score := id.length()
			if score > best_score:
				plushie = plushies[id]
				best_score = score
	return plushie

# ------------------------------------------- Moves
class Move:
	func perform(_world: World, _plushie: Plushie, _victim: Plushie) -> void:
		pass

class Punch:
	extends Move

	func perform(_world: World, plushie: Plushie, victim: Plushie) -> void:
		plushie.attack(victim)

class Fire:
	extends Move

	func perform(world: World, plushie: Plushie, victim: Plushie) -> void:
		var fireball := preload("res://world/plushie/moves/fire/fireball.tscn").instantiate()
		fireball.position = plushie.soft_body.get_bones_center_position() + Vector2(0, -150)
		var impulse := victim.soft_body.get_bones_center_position() - plushie.soft_body.get_bones_center_position()
		impulse.y -= 300
		fireball.apply_impulse(impulse)
		fireball.caster = plushie
		world.add_child(fireball)
