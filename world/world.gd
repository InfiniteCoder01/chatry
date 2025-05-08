extends Node2D
class_name World

@onready var control: Control = %Control
@onready var alertbox: AlertBox = %AlertBox
@onready var plushies: Node = %Plushies

var followers: Array[SoftBody2D.SoftBodyChild] = []

func _ready() -> void:
	get_window().mouse_passthrough = true
	Twitch.broadcaster_eventsub.event.connect(_on_twitch_eventsub_event)
	Twitch.connect_command("Plushie", _on_plushie)
	Twitch.connect_command("Pick", _on_pick)
	Twitch.connect_command("Punch", _on_punch)

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
		for plushie: Plushie in $Plushies.get_children():
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
			follower.rigidbody.apply_force((mouse - follower.rigidbody.global_position) * 10.0 / followers.size())

	if Input.is_action_just_pressed("attack"):
		var fireball := preload("res://world/plushie/projectiles/fireball.tscn").instantiate()
		fireball.position = mouse
		add_child(fireball)
			
		#var closest: Plushie = null
		#for victim: Plushie in plushies.get_children():
			#if closest == null || mouse.distance_squared_to(victim.soft_body.get_bones_center_position()) < mouse.distance_squared_to(closest.soft_body.get_bones_center_position()):
				#closest = victim
		#for plushie: Plushie in plushies.get_children():
			#if plushie.viewer_id != "STREAMER": continue
			#if plushie == closest: continue
			#plushie.attack(closest)
			#break

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			get_window().mouse_passthrough = false
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			get_window().mouse_passthrough = true

func _on_twitch_eventsub_event(type: StringName, data: Dictionary) -> void:
	if type == "channel.raid":
		var plushie := Twitch.find_plushie(data.from_broadcaster_user_name)
		print(plushie)
		if plushie == null: return
		for i in range(10):
			var plushie_instance: Plushie = plushie.instantiate()
			plushie_instance.position_randomly(get_viewport_rect())
			plushies.add_child(plushie_instance)
			await get_tree().create_timer(1.0).timeout

func _on_plushie(from_username: String, info: TwitchCommandInfo, args: PackedStringArray) -> void:
	var flags := info.command._get_perm_flag_from_tags(info.original_message)
	if flags & Twitch.MOD_STREAMER_VIP == 0 && Twitch.timeout(from_username, "plushies", 10.0): return

	var proto: PlushieProto = Twitch.all_plushies.pick_random() if args.is_empty() else Twitch.find_plushie(" ".join(args))
	if proto == null: return
	var plushie := proto.instantiate()
	plushie.chatter = await Twitch.bot.get_user(from_username)
	plushie.position_randomly(get_viewport_rect())
	plushies.add_child(plushie)

func _on_pick(from_username: String, info: TwitchCommandInfo, args: PackedStringArray) -> void:
	var flags := info.command._get_perm_flag_from_tags(info.original_message)
	if flags & Twitch.MOD_STREAMER_VIP == 0 && Twitch.timeout(from_username, "plushies", 10.0): return

	var name := Twitch.strip_special_characters(" ".join(args)).to_lower()
	if !Twitch.plushie_groups.has(name):
		if Twitch.timeouts.has("plushies"): Twitch.timeouts["plushies"].erase(from_username)
		return
	var proto: PlushieProto = Twitch.plushie_groups[name].pick_random()
	var plushie := proto.instantiate()
	plushie.chatter = await Twitch.bot.get_user(from_username)
	plushie.position_randomly(get_viewport_rect())
	plushies.add_child(plushie)

func _on_punch(from_username: String, _info: TwitchCommandInfo, args: PackedStringArray) -> void:
	var target: Plushie = attack_targets(" ".join(args), from_username).pick_random()
	if target != null:
		var target_center := target.soft_body.get_bones_center_position()
		var plushie := closest_plushie(viewer_plushies(from_username), target_center)
		if plushie != null: plushie.attack(target)

func viewer_plushies(viewer_login: String) -> Array[Plushie]:
	var viewer_plushies: Array[Plushie] = []
	for plushie: Plushie in plushies.get_children():
		if plushie.chatter != null && plushie.chatter.login == viewer_login:
			viewer_plushies.append(plushie)
	return viewer_plushies

func attack_targets(target: String, viewer_login: String) -> Array[Plushie]:
	var target_proto := null if target.is_empty() else Twitch.find_plushie(target)
	var targets: Array[Plushie] = []
	for victim: Plushie in plushies.get_children():
		if victim.chatter != null && victim.chatter.login == viewer_login: continue
		if target_proto != null && victim.proto.name != target_proto.name: continue
		targets.append(victim)
	return targets

func closest_plushie(plushies_list: Array[Plushie], to: Vector2) -> Plushie:
	var closest: Plushie = null
	for plushie in plushies_list:
		if closest == null || plushie.soft_body.get_bones_center_position().distance_squared_to(to) < closest.soft_body.get_bones_center_position().distance_squared_to(to):
			closest = plushie
	return closest

func plushieball(tournament: bool) -> void:
	if has_node(^"Court"):
		get_node(^"Court").queue_free()
	
	var court: Court = preload("res://world/plushieball/court.tscn").instantiate()
	court.plushieball(tournament)
	add_child(court)
