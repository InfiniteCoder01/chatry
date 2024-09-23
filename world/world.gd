extends Node2D
class_name World

@onready var chat_overlay: ChatOverlay = %Chat
@onready var sound_blaster: AudioStreamPlayer = $SoundBlaster
@onready var alertbox: AlertBox = %AlertBox

var followers: Array[SoftBody2D.SoftBodyChild] = []

func _ready() -> void:
	get_window().mouse_passthrough = true
	Bot.world = self
	Bot.twitch_broadcaster = %TwitchBroadcaster
	Bot.twitch_bot = %TwitchBot
	Bot.setup()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("plushie"):
		Bot.random_plushie()
	if Input.is_action_just_pressed("basketball"):
		Bot.basketball(false)
	if Input.is_action_just_pressed("tournament"):
		Bot.basketball(true)

	var mouse := get_global_mouse_position()
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

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			get_window().mouse_passthrough = false
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			get_window().mouse_passthrough = true
