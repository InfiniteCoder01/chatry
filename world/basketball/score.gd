extends Area2D

var timeout = null
func _on_body_entered(body: RigidBody2D):
    if body.name.contains("Bone"):
        if timeout && timeout.time_left > 0.0:
            return
        timeout = get_tree().create_timer(2.0)
        disable_mode
        await get_tree().create_timer(0.5).timeout
        $AudioStreamPlayer.stream = preload("res://assets/basketball-score.wav")
        $AudioStreamPlayer.play()
