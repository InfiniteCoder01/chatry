extends Node2D

var world: World

func _ready() -> void:
	if world.has_node("Court"):
		remove_child($Games)
	else:
		remove_child($GameManagement)

	for child in get_all_children():
		child.global_position = global_position - child.size / 2

func _process(_delta: float) -> void:
	if Input.is_action_just_released("tool wheel"):
		queue_free()
	
	var children := get_all_children()
	for i in range(children.size()):
		children[i].target = global_position + Vector2(0, -100).rotated(i * TAU / children.size()) - children[i].size / 2

func get_all_children() -> Array[ToolWheelButton]:
	var children: Array[ToolWheelButton] = []
	for child in get_children(true):
		if child is ToolWheelButton:
			children.append(child)
		else:
			for child2 in child.get_children(true):
				if child2 is ToolWheelButton:
					children.append(child2)
	return children
	
func random_plushie() -> void:
	var plushie: Plushie = Twitch.all_plushies.pick_random().instantiate()
	plushie.position_randomly(world.get_viewport_rect())
	world.plushies.add_child(plushie)

func plushieball() -> void:
	world.plushieball(false)

func plushieball_tournament() -> void:
	world.plushieball(true)
	
func cancel_current_game() -> void:
	world.get_node("Court").queue_free()

func extend_current_game() -> void:
	var court: Court = world.get_node("Court")
	court.timer.time_left += 120.0

func send_message() -> void:
	var send_box := preload("res://tool_wheel/send_box/send_box.tscn").instantiate()
	send_box.global_position = global_position - send_box.size / 2
	world.control.add_child(send_box)
