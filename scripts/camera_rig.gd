class_name CameraRig
extends Node3D
## Camera holder with tweened moves. The Camera3D child sits at the rig origin.

var cam: Camera3D
var _tween: Tween
var moving := false

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 78.0
	cam.near = 0.03
	cam.far = 60.0
	cam.current = true
	add_child(cam)

func snap(pos: Vector3, basis: Basis, fov: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = pos
	quaternion = basis.get_rotation_quaternion()
	cam.fov = fov
	moving = false

func go_to(pos: Vector3, basis: Basis, fov: float, duration := 0.6) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	moving = true
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", pos, duration)
	_tween.tween_property(self, "quaternion", basis.get_rotation_quaternion(), duration)
	_tween.tween_property(cam, "fov", fov, duration)
	_tween.chain().tween_callback(func(): moving = false)

static func look_basis(from: Vector3, to: Vector3) -> Basis:
	var dir := (to - from)
	if dir.length() < 0.0001:
		return Basis.IDENTITY
	return Basis.looking_at(dir.normalized(), Vector3.UP)
