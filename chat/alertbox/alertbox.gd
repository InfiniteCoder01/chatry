class_name AlertBox
extends Control

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: RichTextLabel = $RichTextLabel
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

var alerts := {}

func _ready() -> void:
	var reader := GifReader.new()

	var alerts_dir := DirAccess.open("res://assets/alerts")
	if alerts_dir:
		alerts_dir.list_dir_begin()
		var alert := alerts_dir.get_next()
		while alert != "":
			if alerts_dir.current_is_dir():
				alerts[alert] = {
					animation = reader.read("res://assets/alerts/%s/%s.gif" % [alert, alert]),
					sound = load("res://assets/alerts/%s/%s.wav" % [alert, alert])
				}
			alert = alerts_dir.get_next()
	else:
		print("Alerts directory not found!")


func play(alert: String, message: String) -> void:
	play_raw(alerts[alert].animation, alerts[alert].sound, message, 10.0)

func play_raw(sprite_frames: SpriteFrames, sound: AudioStream, message: String, sprite_scale: float = 1.0) -> void:
	sprite.scale = Vector2(sprite_scale, sprite_scale)

	sprite_frames.set_animation_loop("default", false)
	sprite.sprite_frames = sprite_frames
	sprite.frame = 0
	sprite.play("default")

	var alert_size := sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size() * sprite.scale
	label.position.y = alert_size.y
	label.size.x = alert_size.x
	label.text = "[center]%s[/center]" % message

	audio.stream = sound
	audio.play()

	await audio.finished
	await sprite.animation_finished
	sprite.sprite_frames = null
	label.text = ""
