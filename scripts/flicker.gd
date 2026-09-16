class_name FlickerLight
extends OmniLight3D
## Omni light with a gentle noise-driven flicker (fire, candles).

var base_energy := 2.0
var amount := 0.35
var speed := 7.0
var _t := 0.0
var _seed := randf() * 100.0

func _ready() -> void:
	base_energy = light_energy

func _process(delta: float) -> void:
	_t += delta * speed
	var n := sin(_t + _seed) * 0.5 + sin(_t * 2.3 + _seed * 1.7) * 0.3 + sin(_t * 5.1 + _seed * 0.3) * 0.2
	light_energy = base_energy * (1.0 + n * amount)
