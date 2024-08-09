extends Area2D

var timeout: SceneTreeTimer = null
var score := 0

func _on_body_entered(body: RigidBody2D) -> void:
	if body.name.contains("Bone"):
		if timeout && timeout.time_left > 0.0:
			return
		score += 1
		Bot.world.label.text = "Score: %d" % score
		timeout = get_tree().create_timer(2.0)
		$AudioStreamPlayer.stream = preload("res://world/basketball/score.wav")
		$AudioStreamPlayer.play()
		await get_tree().create_timer(1.0).timeout
		var plushie: Plushie = body.get_parent().get_parent()
		Bot.random_plushie().viewer_id = plushie.viewer_id
		plushie.queue_free()
