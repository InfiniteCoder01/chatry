class_name Hoop
extends Node2D

@onready var label: RichTextLabel = %Label
@onready var aduio_player: AudioStreamPlayer = %AudioPlayer

var world: World
var timeout: SceneTreeTimer = null
var score := 0

func _on_area_2d_body_entered(body: RigidBody2D) -> void:
	if body.name.contains("Bone"):
		if timeout && timeout.time_left > 0.0:
			return
		score += 1
		label.text = "[center]Score: %d[/center]" % score
		timeout = get_tree().create_timer(2.0)
		aduio_player.stream = preload("res://world/plushieball/score.wav")
		aduio_player.play()

		await get_tree().create_timer(1.0).timeout
		var plushie: Plushie = body.get_parent().get_parent()
		var chatter := plushie.chatter
		plushie.queue_free()
		plushie = PlushieLib.all.pick_random().instantiate()
		plushie.chatter = chatter
		plushie.position_randomly(get_viewport_rect())
		world.plushies.add_child(plushie)
