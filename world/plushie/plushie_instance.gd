class_name PlushieInstance
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
			if message == null: return
			heat_message.emit(message)
			if message.type == "click": pass
			elif message.type == "system":
				print("Heat system message: %s" % message.message)
				if message.has("version:"): print("Heat API version: %s" % message["version:"])
			else: printerr("Unknown heat message: %s" % message)
	)

func _on_heat_message(message: Dictionary) -> void:
	if !message.has("type"): return
	if !message.has("id"): return
	if !chatter: return
	if message.id != chatter.id: return
	if message.type == "click":
		var cursor := Vector2(message.x.to_float(), message.y.to_float()) * Vector2(get_viewport().size)
		if world && plushie.get_move("punch"):
			for victim in world.non_viewer_plushies(chatter.login):
				if victim.soft_body.get_bones_center_position().distance_squared_to(cursor) < 130*130:
					attack(victim)
					return

		leap(cursor)

## ******************************************************************** Creation
var soft_body: SoftBody2D
var world: World

var chatter: TwitchUser = null
var plushie: Plushie
var joints_max: int

var lifetime_remaining: float
var last_damage_dealt_by: Plushie = null

func load(plushie: Plushie) -> void:
	self.plushie = plushie
	soft_body = $SoftBody2D
	soft_body.texture = load("res://assets/plushies/" + plushie.id + "/image.png") as Texture2D
	soft_body.create_softbody2d(true)
	lifetime_remaining = 60.0 if plushie.wild else INF
	joints_max = 0
	for pb in soft_body.get_rigid_bodies():
		joints_max += pb.joints.size()

func config() -> PlushieConfig:
	return plushie.config()

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
	Twitch.connect_command("Flee", func _on_flee(from_username: String, _info: TwitchCommandInfo, _args: PackedStringArray) -> void:
		if chatter == null || chatter.login != from_username: return
		Twitch.chat.send_message("%s fled!" % plushie.name)
		queue_free()
	)
	Twitch.connect_command("AddForce", func _on_add_force(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
		if chatter == null || chatter.login != from_username: return
		var force := Vector2(float(args[0]), float(args[1])).limit_length(5.0) * 2000
		soft_body.apply_force(force)
	)
	Twitch.connect_command("PutOut", func _on_put_out(from_username: String, _info: TwitchCommandInfo, _args: PackedStringArray) -> void:
		if chatter == null || chatter.login != from_username: return
		put_out()
	)
	Twitch.connect_command("Catch", func _on_catch(from_username: String, info: TwitchCommandInfo, args: PackedStringArray) -> void:
		if !plushie.wild: return
		if !plushie.name_matches(" ".join(args)): return
		if randf() <= 0.01 / health() / sqrt(plushie.stats.attack):
			Store.viewer(from_username, true).receive(plushie)
			Store.save()
			queue_free()
			Twitch.chat.send_message("%s was caught! You can see it in your !team. You can also name it with !name" % plushie.name, info.original_message.message_id)
		else:
			Twitch.chat.send_message("You couldn't catch %s!" % plushie.name, info.original_message.message_id)
	)

# ******************************************************************** Utility
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

func leap(target_position: Vector2):
	soft_body.apply_impulse((target_position - soft_body.get_bones_center_position()) * 0.3)

## ******************************************************************** Functionality
var attack_target: PlushieInstance
var attack_hits: int
func attack(target: PlushieInstance) -> void:
	var target_pos := target.soft_body.get_bones_center_position()
	var impulse := (target_pos - soft_body.get_bones_center_position())

	var power := float(plushie.stats.attack) / target.plushie.stats.defense

	if target.config().groups.has("cpus") || target.config().groups.has("embedded"):
		power *= 1.3

	impulse = impulse.normalized() * 400.0 * min(sqrt(power), 0.5)
	soft_body.apply_impulse(impulse)
	attack_target = target
	attack_hits = ceili(10 * power)
	for pb in soft_body.get_rigid_bodies():
		var rb := pb.rigidbody as RigidBody2D
		rb.contact_monitor = true
		rb.max_contacts_reported = 1

func put_out() -> void:
	for rb in soft_body.get_rigid_bodies():
		rb.rigidbody.fire.emitting = false

## ******************************************************************** Process
func health() -> float:
	var health := 0.0
	for pb in soft_body.get_rigid_bodies():
		health += float(pb.joints.size()) / joints_max
	return health

func alive() -> bool:
	return health() >= 0.001

func _process(delta: float) -> void:
	if !alive():
		queue_free()
		Twitch.chat.send_message("%s was defeated!" % plushie.name)
		if last_damage_dealt_by:
			var xp := (plushie.stats.attack + plushie.stats.defense) * 5 + 20
			last_damage_dealt_by.gain_xp(xp)
		return

	lifetime_remaining -= delta
	if lifetime_remaining < 0:
		Twitch.chat.send_message("%s magically disappeared! Fight & catch your own plushie!" % plushie.name)
		queue_free()
		return

	if !is_instance_valid(attack_target): attack_target = null
	if attack_target != null && attack_hits > 0:
		var collisions: Array[Bone] = []
		for pb in soft_body.get_rigid_bodies():
			var rb := pb.rigidbody as RigidBody2D
			collisions.append_array(rb.get_colliding_bodies().filter(func pred(collision: Node2D) -> bool:
				return collision is Bone and collision.plushie == attack_target
			))

		var joints_removed := 0
		var max_joints_per_frame: int = min(attack_hits, 30)
		for collision in collisions:
			var rb: SoftBody2D.SoftBodyChild = collision.plushie.soft_body._soft_body_rigidbodies_dict[collision]
			for joint in rb.joints:
				collision.plushie.soft_body.remove_joint(rb, joint)
				joints_removed += 1
				if joints_removed >= max_joints_per_frame: break
			if joints_removed >= max_joints_per_frame: break
		attack_hits -= joints_removed
		attack_target.last_damage_dealt_by = plushie
