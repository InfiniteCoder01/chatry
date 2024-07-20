extends Area2D

var timeout: SceneTreeTimer = null
func _on_body_entered(body: RigidBody2D) -> void:
    if body.name.contains("Bone"):
        if timeout && timeout.time_left > 0.0:
            return
        timeout = get_tree().create_timer(2.0)
        $AudioStreamPlayer.stream = preload("res://world/basketball/score.wav")
        $AudioStreamPlayer.play()
