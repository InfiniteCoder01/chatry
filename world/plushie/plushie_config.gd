extends RefCounted
class_name PlushieConfig

var name: String
var aliases: Array[String] = []
var groups: Array[String] = []
var moves: Dictionary[int, String] = {}

func _init(name: String, config: ConfigFile) -> void:
	self.name = name
	aliases.assign(config.get_value("", "aliases", []))
	groups.assign(config.get_value("", "groups", []))
	moves.assign(config.get_value("", "moves", {}))
	if !moves.has(0): moves[0] = "punch"
	moves.sort()

func create() -> Plushie:
	var plushie := Plushie.new()
	plushie.id = name
	plushie.name = name
	return plushie

func get_available_moves(level: int) -> PackedStringArray:
	var moves_available: PackedStringArray = []
	for move_level: int in moves.keys():
		if move_level <= level:
			moves_available.append(moves[move_level])
	return moves_available

func get_move(name: String, level: int) -> PlushieLib.Move:
	for move: String in get_available_moves(level):
		if move == name:
			return PlushieLib.moves[move]
	return null
