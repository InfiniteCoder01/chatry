extends Node2D
class_name World

@onready var chat_overlay := $CanvasLayer/Control/MarginContainer/VBoxContainer/Chat
@onready var sound_blaster: AudioStreamPlayer = $SoundBlaster

var followers: Array[SoftBody2D.SoftBodyChild] = []

func _ready() -> void:
	Bot.instance.world = self
	get_window().mouse_passthrough = true

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("plushie"):
		Bot.instance.quick_command("plushie", "")
	if Input.is_action_just_pressed("basketball"):
		Bot.instance.quick_command("basketball", "")

	var mouse := get_global_mouse_position()
	if Input.is_action_just_pressed("follow"):
		followers = []
		var best_distance := 0.0
		for child in $Plushies.get_children():
			var plushie: SoftBody2D = child.get_child(0)
			var rigid_bodies := plushie.get_rigid_bodies()
			var indices := range(rigid_bodies.size())
			indices.sort_custom(func ord(a: int, b: int) -> bool:
				return (rigid_bodies[a].rigidbody.global_position.distance_squared_to(mouse) <
						rigid_bodies[b].rigidbody.global_position.distance_squared_to(mouse))
			)
			var distance := rigid_bodies[indices[0]].rigidbody.global_position.distance_squared_to(mouse)
			if followers.is_empty() || distance < best_distance:
				best_distance = distance
				followers = []
				for i in range(min(indices.size(), 3)):
					followers.append(rigid_bodies[indices[i]])
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
