extends RigidBody2D

@onready var fire: GPUParticles2D = $Fire
var caster: Plushie = null
var drop := false

func _ready() -> void:
	await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
	drop = true

func _process(_delta: float) -> void:
	for rb in get_colliding_bodies():
		if rb is Bone:
			if is_instance_valid(caster):
				if caster.chatter != null && rb.plushie.chatter == caster.chatter: return
				if caster.caught: rb.plushie.last_damage_dealt_by = caster.caught
			rb.set_on_fire()
			drop = true
	if drop:
		fire.emitting = false
		await get_tree().create_timer(1.0).timeout
		queue_free()
