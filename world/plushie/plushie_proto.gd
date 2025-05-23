extends RefCounted
class_name PlushieProto

var name: String
var aliases: Array[String]
var groups: Array[String]

class Stats:
	extends RefCounted
	var attack := 1
	var defense := 1

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
