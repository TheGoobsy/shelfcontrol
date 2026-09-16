class_name Breather
extends Node3D
## Gentle breathing: scales the node's height by a few percent on a slow sine.

var amount := 0.035
var speed := 1.6
var _t := randf() * TAU

func _process(delta: float) -> void:
	_t += delta * speed
	scale = Vector3(1.0, 1.0 + sin(_t) * amount, 1.0 - sin(_t) * amount * 0.4)
