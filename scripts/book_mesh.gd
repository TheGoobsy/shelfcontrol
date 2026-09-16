class_name BookMesh
## Builds a closed book box as an ArrayMesh with two surfaces:
## 0 = covers + spine, 1 = page block (top, bottom, fore-edge).
## Origin at bottom centre; spine faces +z, front cover faces +x.

static var _cache: Dictionary = {}

static func get_mesh(t: float, h: float, w: float) -> ArrayMesh:
	var key := "%d_%d_%d" % [roundi(t * 1000.0), roundi(h * 1000.0), roundi(w * 1000.0)]
	if _cache.has(key):
		return _cache[key]
	var m := build(t, h, w)
	_cache[key] = m
	return m

static func build(t: float, h: float, w: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var hx := t / 2.0
	var hz := w / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(hx, h, -hz), Vector3(hx, h, hz), Vector3(1, 0, 0))
	_quad(st, Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(-hx, h, hz), Vector3(-hx, h, -hz), Vector3(-1, 0, 0))
	_quad(st, Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, h, hz), Vector3(-hx, h, hz), Vector3(0, 0, 1))
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st2, Vector3(-hx, h, hz), Vector3(hx, h, hz), Vector3(hx, h, -hz), Vector3(-hx, h, -hz), Vector3(0, 1, 0))
	_quad(st2, Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz), Vector3(0, -1, 0))
	_quad(st2, Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz), Vector3(-hx, h, -hz), Vector3(hx, h, -hz), Vector3(0, 0, -1))
	st2.commit(mesh)
	return mesh

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	# Godot front faces are clockwise as seen from outside, i.e. the CCW cross product points inward.
	var cn := (b - a).cross(c - a)
	if cn.dot(n) > 0.0:
		var tmp := b
		b = d
		d = tmp
	st.set_normal(n)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(c)
	st.set_normal(n)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(c)
	st.set_normal(n)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(d)
