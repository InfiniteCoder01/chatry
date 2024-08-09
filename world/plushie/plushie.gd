class_name Plushie
extends Node

static var heat_websocket := WebsocketClient.new()

static func connect_heat() -> void:
	heat_websocket.connect_to("wss://heat-api.j38.net/channel/" + TwitchSetting.broadcaster_id)
	heat_websocket.message_received.connect(func _on_heat_message(data: PackedByteArray) -> void:
		var message: Dictionary = JSON.parse_string(data.get_string_from_utf8())
		if message.type == "click": pass
		elif message.type == "system":
			Bot.log_message("Heat system message: %s" % message.message)
			if message.has("version:"): Bot.log_message("Heat API version: %s" % message["version:"])
		else: Bot.log_message("Unknown heat message: %s" % message)
	)

var viewer_id: String

func _ready() -> void:
	heat_websocket.message_received.connect(_on_heat_message)
	await get_tree().create_timer(30.0).timeout
	self.queue_free()

func assign(id: String) -> void:
	if id.is_empty(): return
	print("Plushie %s" % id)
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

func closest_rbs(target: Vector2) -> Array[SoftBody2D.SoftBodyChild]:
	var plushie: SoftBody2D = $SoftBody2D
	var rigid_bodies := plushie.get_rigid_bodies()
	var indices := range(rigid_bodies.size())
	indices.sort_custom(func ord(a: int, b: int) -> bool:
		return (rigid_bodies[a].rigidbody.global_position.distance_squared_to(target) <
				rigid_bodies[b].rigidbody.global_position.distance_squared_to(target))
	)
	var closest: Array[SoftBody2D.SoftBodyChild] = []
	for i in range(min(indices.size(), 3)):
		closest.append(rigid_bodies[indices[i]])
	return closest

var followers: Array[SoftBody2D.SoftBodyChild] = []
var follow_target: Vector2
func _on_heat_message(data: PackedByteArray) -> void:
	var message: Dictionary = JSON.parse_string(data.get_string_from_utf8())
	Bot.log_message("Heat message: %s" % message)
	if message.type == "click" && message.id == viewer_id:
		follow_target = Vector2(message.x.to_float(), message.y.to_float()) * Vector2(get_viewport().size)
		followers = closest_rbs(follow_target)

func _process(_delta: float) -> void:
	for follower in followers:
		follower.rigidbody.apply_force((follow_target - follower.rigidbody.global_position) * 100.0 / followers.size())
