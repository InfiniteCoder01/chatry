extends Node2D
class_name World

@onready var chat_overlay := $CanvasLayer/Control/MarginContainer/VBoxContainer/Chat
@onready var sound_blaster: AudioStreamPlayer = $SoundBlaster

func _ready() -> void:
	Bot.instance.world = self
	get_window().mouse_passthrough = true

func _process(_delta: float) -> void:
	if Input.is_action_pressed("basketball"):
		Bot.instance.quick_command("basketball", "")

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			get_window().mouse_passthrough = false
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			get_window().mouse_passthrough = true
