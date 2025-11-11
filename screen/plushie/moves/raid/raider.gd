extends RigidBody2D

var chatter: TwitchUser = null
var caster: Plushie = null
var charges := 5

func _ready() -> void:
	await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
	charges = 0

func _process(_delta: float) -> void:
	for rb in get_colliding_bodies():
		if rb is Bone:
			if rb.alive: continue
			if chatter != null && rb.plushie.chatter == chatter: continue
			if is_instance_valid(caster): rb.plushie.last_damage_dealt_by = caster
			if randf() < 3.0 / max(rb.plushie.plushie.stats.defense, 1): rb.alive = false
			charges -= 1
			if charges <= 0: break
	if charges <= 0:
		queue_free()
