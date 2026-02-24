class_name Plushie
extends RefCounted

var wild := true
var name := ""
var id := ""
var xp := 0

class Stats:
	extends RefCounted
	var attack := 1
	var defense := 1

	static func random() -> Stats:
		var stats := Stats.new()
		stats.attack = randi_range(1, 3)
		stats.defense = randi_range(1, 3)
		return stats

	func sum() -> int:
		return attack + defense
	
var stats := Stats.random()

# -------------------------------------------------------------------- Sugar
func config() -> PlushieConfig:
	return PlushieLib.config(id)

func get_available_moves() -> PackedStringArray:
	return config().get_available_moves(level())

func get_move(name: String) -> PlushieLib.Move:
	return config().get_move(name, level())

# -------------------------------------------------------------------- Leveling
func level() -> int:
	return int(pow(stats.sum(), 0.7))

func xp_to_level_up() -> int:
	return int(stats.sum() * 2.5)

func level_up() -> void:
	var req := ceili(pow(level() + 1, 1 / 0.7)) - stats.sum()
	stats.attack += req - req / 2
	stats.defense += req / 2

func gain_xp(xp: int) -> void:
	self.xp += xp
	var levels := 0
	var moves: Array[String] = []
	var config := PlushieLib.config(id)
	while true:
		if self.xp >= xp_to_level_up():
			self.xp -= xp_to_level_up()
			level_up()
			if config.moves.has(level()):
				moves.append(config.moves[level()])
			levels += 1
			continue
		break
	Store.save()

	var msg := "%s recieved %d XP." % [name, xp]
	if levels > 0:
		msg += " It got to level %d!" % level()
	for move in moves:
		msg += " Learned new move: %s!" % move
	await Twitch.get_tree().create_timer(0.3).timeout
	Twitch.chat.send_message(msg)

# ----------------------------------------------------------------------- Instance
var nosave_instance: PlushieInstance = null
func instantiate() -> PlushieInstance:
	if nosave_instance == null or not is_instance_valid(nosave_instance):
		nosave_instance = preload("res://screen/plushie/plushie.tscn").instantiate()
		nosave_instance.load(self)
	return nosave_instance

func name_matches(name: String) -> bool:
	if wild:
		name = PlushieLib.strip(name)
		if name == PlushieLib.strip(config().name): return true
		for cname: String in config().aliases:
			if name == PlushieLib.strip(cname): return true

	return name.to_lower() == self.name.to_lower()
