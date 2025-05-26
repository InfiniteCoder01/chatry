extends RefCounted
class_name PlushieProto

var name: String
var aliases: Array[String]
var groups: Array[String]

class Stats:
	extends RefCounted
	var attack := 1
	var defense := 1

	func total() -> int:
		return attack + defense

	func level() -> int:
		return sqrt(total())

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

func instantiate() -> Plushie:
	var plushie: Plushie = preload("res://world/plushie/plushie.tscn").instantiate()
	plushie.proto = self
	plushie.load()
	return plushie
