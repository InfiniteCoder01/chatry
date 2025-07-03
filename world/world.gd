extends Node2D
class_name World

@onready var control: Control = %Control
@onready var alertbox: AlertBox = %AlertBox
@onready var plushies: Node = %Plushies
var owners: Dictionary[String, Plushie]

var followers: Array[SoftBody2D.SoftBodyChild] = []

func _ready() -> void:
	get_window().mouse_passthrough = true
	Twitch.broadcaster_eventsub.event.connect(_on_twitch_eventsub_event)
	Twitch.connect_command("Plushie", _on_plushie)
	Twitch.connect_command("Pick", _on_pick)

func _process(_delta: float) -> void:
	var mouse := get_global_mouse_position()
	if Input.is_action_just_pressed("tool wheel"):
		var tool_wheel := preload("res://tool_wheel/tool_wheel.tscn").instantiate()
		tool_wheel.world = self
		tool_wheel.global_position = mouse
		add_child(tool_wheel)

	if Input.is_action_just_pressed("follow"):
		followers = []
		var best_distance := 0.0
		for plushie in get_plushies():
			var rigid_bodies := plushie.closest_rbs(mouse)
			var distance := rigid_bodies[0].rigidbody.global_position.distance_squared_to(mouse)
			if followers.is_empty() || distance < best_distance:
				best_distance = distance
				followers = rigid_bodies
	if Input.is_action_pressed("follow"):
		for follower in followers:
			if !is_instance_valid(follower.rigidbody):
				followers.clear()
				break
			follower.rigidbody.apply_force((mouse - follower.rigidbody.global_position) * 30.0 / followers.size())

	if Input.is_action_just_pressed("attack"):
		var fireball := preload("res://world/plushie/moves/fire/fireball.tscn").instantiate()
		fireball.position = mouse
		add_child(fireball)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			get_window().mouse_passthrough = false
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			get_window().mouse_passthrough = true

# -------------------------------------------------------------------------- Twitch
func _on_twitch_eventsub_event(type: StringName, data: Dictionary) -> void:
	if type == "channel.raid":
		var plushie := PlushieLib.find(data.from_broadcaster_user_login)
		if plushie == null: return

		for i in range(5):
			var plushie_instance: Plushie = plushie.instantiate()
			plushie_instance.chatter = await Twitch.bot.get_user_by_id(data.from_broadcaster_user_id);
			plushie_instance.position_randomly(get_viewport_rect())
			plushies.add_child(plushie_instance)
			await get_tree().create_timer(1.0).timeout
	elif type == "channel.chat.message":
		# Plushie commands
		if !owners.has(data.chatter_user_login) || !is_instance_valid(owners[data.chatter_user_login]): return
		if data.message.text.begins_with("!"):
			var args: PackedStringArray = data.message.text.split(' ')
			var plushie := owners[data.chatter_user_login]
			var move := plushie.proto.get_move(args[0].substr(1), plushie.stats().level())
			args.remove_at(0)
			if move == null: return
			var plushies := non_viewer_plushies(data.chatter_user_login)
			var victim := closest_plushie(plushies, plushie.soft_body.get_bones_center_position()) if args.is_empty() else find_plushie(plushies, " ".join(args))
			if victim == null: return
			move.perform(self, plushie, victim)

func _on_plushie(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
	if owners.has(from_username) && is_instance_valid(owners[from_username]): return

	var plushie: Plushie = null
	if !args.is_empty():
		var chatter := Store.viewer(from_username)
		if !chatter.team.is_empty():
			var member := chatter.get_team_member(args[0])
			if member: plushie = member.instantiate()
	
	if !plushie:
		var proto: PlushieProto = PlushieLib.all.pick_random() if args.is_empty() else PlushieLib.find(" ".join(args))
		if proto == null: return
		plushie = proto.instantiate()

	plushie.chatter = await Twitch.bot.get_user(from_username)
	plushie.position_randomly(get_viewport_rect())
	plushies.add_child(plushie)
	owners[from_username] = plushie

func _on_pick(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
	if owners.has(from_username) && is_instance_valid(owners[from_username]): return
	var name := PlushieLib.strip(" ".join(args))
	if !PlushieLib.groups.has(name): return
	var proto: PlushieProto = PlushieLib.groups[name].pick_random()
	var plushie := proto.instantiate()
	plushie.chatter = await Twitch.bot.get_user(from_username)
	plushie.position_randomly(get_viewport_rect())
	plushies.add_child(plushie)
	owners[from_username] = plushie

# -------------------------------------------------------------------------- Plushies
func get_plushies() -> Array[Plushie]:
	var arr: Array[Plushie]
	arr.assign(plushies.get_children())
	return arr

func non_viewer_plushies(viewer_login: String) -> Array[Plushie]:
	return get_plushies().filter(func pred(plushie: Plushie) -> bool:
		return plushie.chatter == null || plushie.chatter.login != viewer_login
	)

func find_plushie(plushies: Array[Plushie], name: String) -> Plushie:
	plushies = plushies.filter(func pred(plushie: Plushie) -> bool:
		return plushie.name_matches(name)
	)
	if plushies.is_empty(): return null
	return plushies.pick_random()

func closest_plushie(plushies: Array[Plushie], to: Vector2) -> Plushie:
	var closest: Plushie = null
	for plushie in plushies:
		if closest == null || plushie.soft_body.get_bones_center_position().distance_squared_to(to) < closest.soft_body.get_bones_center_position().distance_squared_to(to):
			closest = plushie
	return closest

func plushieball(tournament: bool) -> void:
	if has_node(^"Court"):
		get_node(^"Court").queue_free()
	
	var court: Court = preload("res://world/plushieball/court.tscn").instantiate()
	court.plushieball(tournament, self)
	add_child(court)
