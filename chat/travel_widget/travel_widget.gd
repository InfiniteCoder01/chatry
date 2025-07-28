extends VBoxContainer

static var world: World = null

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:
	if !world:
		world = preload("res://world/world.tscn").instantiate()
	sub_viewport.add_child(world)
	sub_viewport.world_2d = world.get_world_2d()
	await get_tree().create_timer(10).timeout
	queue_free()
