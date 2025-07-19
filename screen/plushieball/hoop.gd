class_name Hoop
extends Node2D

@onready var label: RichTextLabel = %Label
@onready var aduio_player: AudioStreamPlayer = %AudioPlayer

var screen: Screen
var timeout: SceneTreeTimer = null
var score := 0

func _on_area_2d_body_entered(body: RigidBody2D) -> void:
	if body is Bone:
		if timeout && timeout.time_left > 0.0:
			return
		score += 1
		label.text = "[center]Score: %d[/center]" % score
		timeout = get_tree().create_timer(2.0)
		aduio_player.stream = preload("res://screen/plushieball/score.wav")
		aduio_player.play()

		await get_tree().create_timer(1.0).timeout
		var plushie: PlushieInstance = body.plushie
		var chatter := plushie.chatter
		plushie.queue_free()
		plushie = PlushieLib.all.pick_random().create().instantiate()
		screen.add_plushie(plushie, chatter)
