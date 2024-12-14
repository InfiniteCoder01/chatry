extends RigidBody2D
class_name Bone

@onready var fire: GPUParticles2D = $Fire
var plushie: Plushie
var drop := false

func _ready():
	plushie = get_parent().get_parent()

func _process(_delta: float) -> void:
	var rb: SoftBody2D.SoftBodyChild = plushie.soft_body._soft_body_rigidbodies_dict[self]
	if rb.joints.is_empty():
		if fire.emitting:
			fire.emitting = false
		await get_tree().create_timer(3.0).timeout
		queue_free()
	elif drop:
		plushie.soft_body.remove_joint(rb, rb.joints[0])

func set_on_fire():
	fire.emitting = true
	await get_tree().create_timer(4.0).timeout
	var rb: SoftBody2D.SoftBodyChild = plushie.soft_body._soft_body_rigidbodies_dict[self]
	drop = true
