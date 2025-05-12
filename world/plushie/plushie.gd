class_name Plushie
extends Node

# ******************************************************************** Heat
static var heat_websocket := WebSocketPeer.new()
static var heat_message: Signal

static func _static_init() -> void:
	(Plushie as Object).add_user_signal("heat_message", [{ "name": "message", "type": TYPE_DICTIONARY }])
	heat_message = Signal(Plushie as Object, "heat_message")

static func connect_heat() -> void:
	heat_websocket.connect_to_url("wss://heat-api.j38.net/channel/%s" % Twitch.chat.broadcaster_user.id)
	Engine.get_main_loop().process_frame.connect(func _process() -> void:
		heat_websocket.poll()
		while heat_websocket.get_available_packet_count() > 0:
			var data := heat_websocket.get_packet()
			var message: Dictionary = JSON.parse_string(data.get_string_from_utf8())
			heat_message.emit(message)
			if message.type == "click": pass
			elif message.type == "system":
				print("Heat system message: %s" % message.message)
				if message.has("version:"): print("Heat API version: %s" % message["version:"])
			else: printerr("Unknown heat message: %s" % message)
	)

func _on_heat_message(message: Dictionary) -> void:
	if message.type == "click" && message.id == chatter.id:
		var target := Vector2(message.x.to_float(), message.y.to_float()) * Vector2(get_viewport().size)
		soft_body.apply_impulse((target - soft_body.get_bones_center_position()) * 2.0)

## ******************************************************************** Creation
@onready var soft_body: SoftBody2D = $SoftBody2D

var proto: PlushieProto
var chatter: TwitchUser = null
var caught: Store.CaughtPlushie = null

#func stats() -> PlushieProto.Stats:
	#if member != null:
		#return member.stats
	#return proto.default_stats

var lifetime_remaining: float

func load() -> void:
	if proto == null: return
	name = proto.name
	print("Plushie %s" % proto.name)
	soft_body = $SoftBody2D
	soft_body.texture = load("res://assets/plushies/" + proto.name + "/image.png") as Texture2D
	soft_body.create_softbody2d(true)
	lifetime_remaining = 60.0

func position_randomly(rect: Rect2) -> void:
	soft_body.global_position = Vector2(
		randf_range(
			10,
			rect.size.x - soft_body.texture.get_width() * soft_body.scale.x - 10
		),
		10
	)

func _ready() -> void:
	heat_message.connect(_on_heat_message)
	Twitch.connect_command("AddForce", func _on_add_force(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
		if chatter == null || chatter.login != from_username: return
		var force := Vector2(float(args[0]), float(args[1])).limit_length(5.0) * 2000
		soft_body.apply_force(force)
	)
	Twitch.connect_command("PutOut", func _on_put_out(from_username: String, _info: TwitchCommandInfo, _args: PackedStringArray) -> void:
		if chatter == null || chatter.login != from_username: return
		put_out()
	)

# ******************************************************************** Utility
func name_matches(name: String) -> bool:
	name = PlushieLib.strip(name)
	var names: Array[String] = proto.aliases.duplicate()
	names.append(proto.name)
	for this_name in names:
		if name == PlushieLib.strip(this_name): return true
	return false

func closest_rbs(target: Vector2) -> Array[SoftBody2D.SoftBodyChild]:
	var rigid_bodies := soft_body.get_rigid_bodies()
	var indices := range(rigid_bodies.size())
	indices.sort_custom(func ord(a: int, b: int) -> bool:
		return (rigid_bodies[a].rigidbody.global_position.distance_squared_to(target) <
				rigid_bodies[b].rigidbody.global_position.distance_squared_to(target))
	)
	var closest: Array[SoftBody2D.SoftBodyChild] = []
	for i in range(min(indices.size(), 3)):
		closest.append(rigid_bodies[indices[i]])
	return closest

## ******************************************************************** Functionality
var attack_target: Plushie
var attack_hits: int
func attack(target: Plushie) -> void:
	var target_pos := target.soft_body.get_bones_center_position()
	var impulse := (target_pos - soft_body.get_bones_center_position()) * 0.6
	impulse = impulse.limit_length(300.0)
	soft_body.apply_impulse(impulse)
	attack_target = target
	attack_hits = (impulse.length() / 60) as int
	for pb in soft_body.get_rigid_bodies():
		var rb := pb.rigidbody as RigidBody2D
		rb.contact_monitor = true
		rb.max_contacts_reported = 5

func put_out() -> void:
	for rb in soft_body.get_rigid_bodies():
		rb.rigidbody.fire.emitting = false

## ******************************************************************** Process
func _process(delta: float) -> void:
	if soft_body.get_rigid_bodies().is_empty():
		queue_free()
		return

	lifetime_remaining -= delta
	if lifetime_remaining < 0:
		queue_free()
		return
	
	if attack_target != null && attack_hits > 0:
		var collisions: Array[Bone] = []
		for pb in soft_body.get_rigid_bodies():
			var rb := pb.rigidbody as RigidBody2D
			for collision in rb.get_colliding_bodies():
				if collision is Bone:
					collisions.append(collision)
		
		var joints_removed := 0
		var max_joints_per_frame: int = min(attack_hits, 30)
		for collision in collisions:
			if collision.plushie != self:
				var rb: SoftBody2D.SoftBodyChild = collision.plushie.soft_body._soft_body_rigidbodies_dict[collision]
				for joint in rb.joints:
					collision.plushie.soft_body.remove_joint(rb, joint)
					joints_removed += 1
					if joints_removed >= max_joints_per_frame:
						attack_target = null
						break
				if joints_removed >= max_joints_per_frame: break
		attack_hits -= joints_removed
