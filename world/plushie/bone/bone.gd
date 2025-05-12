extends RigidBody2D
class_name Bone

@onready var fire: GPUParticles2D = $Fire
var plushie: Plushie
var on_fire := false

func _ready() -> void:
	plushie = get_parent().get_parent()

func set_on_fire() -> void:
	if on_fire: return
	on_fire = true
	fire.emitting = true
	await get_tree().create_timer(1.0).timeout
	if !fire.emitting:
		on_fire = false
		return

	var rb: SoftBody2D.SoftBodyChild = plushie.soft_body._soft_body_rigidbodies_dict[self]
	for joint in rb.joints:
		var bone_b: Bone = joint.get_node(joint.node_b)
		bone_b.set_on_fire()

	fire.emitting = false
	await get_tree().create_timer(2.0).timeout
	while true:
		await get_tree().create_timer(0.1 + randf() * 0.2).timeout
		var removed := false
		for joint in rb.joints:
			if is_instance_valid(joint):
				plushie.soft_body.remove_joint(rb, joint)
				removed = true
				break
		if !removed: break
