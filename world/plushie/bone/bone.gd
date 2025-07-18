extends RigidBody2D
class_name Bone

@onready var fire: GPUParticles2D = $Fire
var plushie: PlushieInstance
var temperature := 0.0
var alive := true

func _ready() -> void:
	plushie = get_parent().get_parent()

func _process(_delta_time: float) -> void:
	if !alive:
		var rb: SoftBody2D.SoftBodyChild = plushie.soft_body._soft_body_rigidbodies_dict[self]
		for joint in rb.joints:
			if is_instance_valid(joint):
				plushie.soft_body.remove_joint(rb, joint)
				return

func set_on_fire(temperature: float) -> void:
	if self.temperature > 0.0: return
	self.temperature = temperature
	fire.emitting = true
	await get_tree().create_timer(max(plushie.plushie.stats.defense / temperature * 0.3, 0.1) + randf() * 0.3).timeout
	if !fire.emitting:
		self.temperature = 0.0
		return

	var rb: SoftBody2D.SoftBodyChild = plushie.soft_body._soft_body_rigidbodies_dict[self]
	for joint in rb.joints:
		var bone_b: Bone = joint.get_node(joint.node_b)
		bone_b.set_on_fire(self.temperature)

	fire.emitting = false
	await get_tree().create_timer(2.0).timeout
	alive = false
