extends RigidBody2D

var chatter: TwitchUser = null
var caster: Plushie = null
var drop := false

func _ready() -> void:
	await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
	drop = true

func _process(_delta: float) -> void:
	for rb in get_colliding_bodies():
		if rb is Bone:
			if is_instance_valid(caster):
				if chatter != null && rb.plushie.chatter == chatter: return
				rb.plushie.last_damage_dealt_by = caster
			if randf() < 3.0 / max(rb.plushie.plushie.stats.defense, 1): rb.alive = false
			drop = true
	if drop:
		queue_free()
