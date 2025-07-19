class_name Alert
extends Control

@onready var sprite: AnimatedSprite2D = $MarginContainer/AnimatedSprite2D
@onready var sprite_container: Container = $MarginContainer
@onready var label: RichTextLabel = $RichTextLabel
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

func play(alert: String, message: String) -> void:
	play_raw(
		load("res://assets/alerts/%s/%s.gif" % [alert, alert]),
		load("res://assets/alerts/%s/%s.wav" % [alert, alert]),
		message,
		10.0
	)

func play_raw(sprite_frames: SpriteFrames, sound: AudioStream, message: String, sprite_scale: float = 1.0) -> void:
	sprite.scale = Vector2(sprite_scale, sprite_scale)

	sprite_frames.set_animation_loop("default", false)
	sprite.sprite_frames = sprite_frames
	sprite.frame = 0
	
	sprite_container.custom_minimum_size = sprite_frames.get_frame_texture("default", 0).get_size() * sprite_scale
	sprite.position = sprite_container.position
	audio.stream = sound

	var alert_size := sprite_frames.get_frame_texture("default", sprite.frame).get_size() * sprite.scale
	label.position.y = alert_size.y
	label.size.x = alert_size.x
	label.text = "[center]%s[/center]" % message

	audio.play()
	sprite.play()

	await audio.finished
	await sprite.animation_finished
	queue_free()
