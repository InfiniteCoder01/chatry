extends RefCounted
class_name PlushieProto

var name: String
var aliases: Array[String] = []
var groups: Array[String] = []
var moves: Dictionary[int, String] = {}

class Stats:
	extends RefCounted
	var attack := 1
	var defense := 1

	func total() -> int:
		return attack + defense

	func level() -> int:
		return int(sqrt(total()))

	func xp_to_level() -> int:
		return 50 + level() * 10

	func level_up() -> void:
		var req := int(pow(level() + 1, 2) - total())
		attack += req - req / 2
		defense += req / 2

var stats := Stats.new()

func _init(name: String, config: ConfigFile) -> void:
	self.name = name
	aliases.assign(config.get_value("", "aliases", []))
	groups.assign(config.get_value("", "groups", []))
	moves.assign(config.get_value("", "moves", {}))
	moves[0] = "punch"

func instantiate() -> Plushie:
	var plushie: Plushie = preload("res://world/plushie/plushie.tscn").instantiate()
	plushie.proto = self
	plushie.load()
	return plushie

func get_move(name: String, level: int) -> PlushieLib.Move:
	for move_level: int in moves.keys():
		if move_level <= level && moves[move_level] == name:
			return PlushieLib.moves[moves[move_level]]
	return null
