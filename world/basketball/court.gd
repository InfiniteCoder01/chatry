extends Node2D
class_name Court

@onready var timer_label: RichTextLabel = %Timer
var timer: SceneTreeTimer
var positions: Dictionary = {}

func _ready() -> void:
	timer = get_tree().create_timer(60.0)
	await timer.timeout
	self.queue_free()

func basketball(tournament: bool) -> void:
	var make_hoop = func make_hoop(position: Vector2):
		var hoop := preload("res://world/basketball/hoop.tscn").instantiate()
		add_child(hoop)
		positions[hoop.get_index()] = position
	make_hoop.call(Vector2(0.9, 0.5))
	if tournament: make_hoop.call(Vector2(0.1, 0.5))

func _process(delta: float) -> void:
	for node in positions:
		get_child(node).position = get_viewport_rect().size * positions[node]
	timer_label.text = "[center]%02d:%02d[/center]" % [int(timer.time_left / 60), int(timer.time_left) % 60]
