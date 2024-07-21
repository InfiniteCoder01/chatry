class_name Plushie
extends Node

func _ready() -> void:
	await get_tree().create_timer(30.0).timeout
	self.queue_free()

func assign(id: String) -> void:
	var soft_body: SoftBody2D = get_child(0)
	soft_body.texture = load("res://assets/plushies/" + id + "/image.png") as Texture2D
	soft_body.create_softbody2d(true)

func position_randomly(rect: Rect2) -> void:
	var soft_body: SoftBody2D = get_child(0)
	soft_body.global_position = Vector2(
		randf_range(
			10,
			rect.size.x - soft_body.texture.get_width() * soft_body.scale.x - 10
		),
		10
	)
