extends Node2D
class_name Court

enum Game {
	None,
	Basketball,
	BasketballTournament,
}

@onready var timer_label: RichTextLabel = %Timer
var timer: SceneTreeTimer
var positions: Dictionary = {}
var game: Game

func _ready() -> void:
	timer = get_tree().create_timer(120.0)
	await timer.timeout

	if game == Game.Basketball:
		var hoop = get_node(^"Hoop")
		timer_label.text = "[center]You scored %d[/center]" % hoop.score
		remove_node(hoop)
	if game == Game.BasketballTournament:
		game = Game.None
		var hoop1: Hoop = get_node(^"Hoop1")
		var hoop2: Hoop = get_node(^"Hoop2")
		var message = "Left won!" if hoop1.score > hoop2.score else "Right won!" if hoop1.score < hoop2.score else "Draw!"
		timer_label.text = "[center]%d:%d\n%s[/center]" % [hoop1.score, hoop2.score, message]
		remove_node(hoop1)
		remove_node(hoop2)

	game = Game.None
	await get_tree().create_timer(5.0).timeout
	self.queue_free()

func remove_node(node: Node):
	positions.erase(node.get_index())
	node.queue_free()

func _process(delta: float) -> void:
	for node in positions:
		get_child(node).position = get_viewport_rect().size * positions[node]
	if game != Game.None:
		timer_label.text = "[center]%02d:%02d[/center]" % [int(timer.time_left / 60), int(timer.time_left) % 60]

func basketball(tournament: bool) -> void:
	var make_hoop = func make_hoop(position: Vector2, name: String):
		var hoop := preload("res://world/basketball/hoop.tscn").instantiate()
		hoop.name = name
		add_child(hoop)
		positions[hoop.get_index()] = position

	if tournament:
		make_hoop.call(Vector2(0.1, 0.5), "Hoop1")
		make_hoop.call(Vector2(0.9, 0.5), "Hoop2")
		game = Game.BasketballTournament
	else:
		make_hoop.call(Vector2(0.9, 0.5), "Hoop")
		game = Game.Basketball
