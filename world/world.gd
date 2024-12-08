extends Node2D
class_name World

@onready var control: Control = %Control

@onready var chat_overlay: ChatOverlay = %Chat
@onready var sound_blaster: AudioStreamPlayer = $SoundBlaster
@onready var alertbox: AlertBox = %AlertBox
@onready var plushies: Node = $Plushies

var followers: Array[SoftBody2D.SoftBodyChild] = []

func _ready() -> void:
	get_window().mouse_passthrough = true
	Bot.world = self
	Bot.twitch_broadcaster = %TwitchBroadcaster
	Bot.twitch_bot = %TwitchBot
	Bot.setup()

func _process(_delta: float) -> void:
	var mouse := get_global_mouse_position()
	if Input.is_action_just_pressed("tool wheel"):
		var tool_wheel := preload("res://tool_wheel/tool_wheel.tscn").instantiate()
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
			follower.rigidbody.apply_force((mouse - follower.rigidbody.global_position) * 100.0 / followers.size())

	if Input.is_action_just_pressed("attack"):
		var closest: Plushie = null
		for victim: Plushie in plushies.get_children():
			if closest == null || mouse.distance_squared_to(victim.soft_body.get_bones_center_position()) < mouse.distance_squared_to(closest.soft_body.get_bones_center_position()):
				closest = victim
		for plushie: Plushie in plushies.get_children():
			if plushie.viewer_id != "STREAMER": continue
			if plushie == closest: continue
			plushie.attack(closest)
			break

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			get_window().mouse_passthrough = false
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			get_window().mouse_passthrough = true
