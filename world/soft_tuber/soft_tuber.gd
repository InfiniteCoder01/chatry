extends Node2D

@onready var softbody: SoftBody2D = $SoftBody2D

var decay := 0.0
func _process(delta: float) -> void:
	var analyzer: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(1, 0)
	var magnitude := analyzer.get_magnitude_for_frequency_range(100, 1000)
	# print(magnitude.length_squared() * 1e6)
	if magnitude.length_squared() * 1e6 > 0.5: decay = 0.4

	if decay > 0.0: decay = max(decay - delta, 0.0)

	var value := 0.4;
	if decay > 0.0: value = 1.0
	else: value = 0.4
	softbody.modulate = Color(value, value, value, 1.0)
