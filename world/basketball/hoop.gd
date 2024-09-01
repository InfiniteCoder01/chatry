class_name Hoop
extends Node2D

@onready var label: RichTextLabel = %Label
@onready var aduio_player: AudioStreamPlayer = %AudioPlayer
var timeout: SceneTreeTimer = null
var score := 0

func _on_area_2d_body_entered(body: RigidBody2D) -> void:
	if body.name.contains("Bone"):
		if timeout && timeout.time_left > 0.0:
			return
		score += 1
		label.text = "[center]Score: %d[/center]" % score
		timeout = get_tree().create_timer(2.0)
		aduio_player.stream = preload("res://world/basketball/score.wav")
		aduio_player.play()
		await get_tree().create_timer(1.0).timeout
		var plushie: Plushie = body.get_parent().get_parent()
		Bot.random_plushie().viewer_id = plushie.viewer_id
		plushie.queue_free()
