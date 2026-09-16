class_name Decor

const BreatherScript := preload("res://scripts/breather.gd")
## Procedural room props. Every builder returns a Node3D with its origin on the floor.

static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, pos, mat, rot)

static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 24
	return _mesh(parent, cm, pos, mat, rot)

static func sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	return _mesh(parent, sm, pos, mat, rot, scl)

# ---------------------------------------------------------------- plants

static func _leaf(parent: Node3D, mat: Material, base: Vector3, yaw: float, tilt: float, length: float, width: float, thickness := 0.012) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt)
	mi.transform = Transform3D(rot * Basis.from_scale(Vector3(width, thickness, length)), base + rot * Vector3(0, 0, length / 2.0))
	parent.add_child(mi)
	return mi

static func plant(style: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var pot_col: Color = style.get("pot", Color(0.6, 0.35, 0.25))
	var pot := Materials.std(pot_col, 0.85)
	var soil := Materials.std(Color(0.16, 0.11, 0.07), 1.0)
	var kind := rng.randi() % 3
	if kind == 0:
		# bushy floor plant with broad leaves
		cyl(root, 0.19, 0.14, 0.34, Vector3(0, 0.17, 0), pot)
		cyl(root, 0.17, 0.17, 0.02, Vector3(0, 0.345, 0), soil)
		var n := 11
		for i in n:
			var g := Color(0.16 + rng.randf() * 0.1, 0.42 + rng.randf() * 0.18, 0.18 + rng.randf() * 0.08)
			var leaf := Materials.double_sided(g, 0.75)
			var ang := i * TAU / n + rng.randf() * 0.3
			var tilt := 0.55 + rng.randf() * 0.6
			var length := 0.36 + rng.randf() * 0.18
			_leaf(root, leaf, Vector3(0, 0.36, 0), ang, tilt, length, 0.14 + rng.randf() * 0.06)
	elif kind == 1:
		# small tree
		cyl(root, 0.21, 0.16, 0.40, Vector3(0, 0.20, 0), pot)
		cyl(root, 0.19, 0.19, 0.02, Vector3(0, 0.405, 0), soil)
		var trunk := Materials.std(Color(0.35, 0.25, 0.15), 0.9)
		cyl(root, 0.03, 0.045, 0.9, Vector3(0, 0.85, 0), trunk)
		for i in 7:
			var g := Color(0.14 + rng.randf() * 0.1, 0.38 + rng.randf() * 0.2, 0.16 + rng.randf() * 0.1)
			var m := Materials.std(g, 0.85)
			var off := Vector3(rng.randf_range(-0.2, 0.2), 1.3 + rng.randf_range(-0.1, 0.32), rng.randf_range(-0.2, 0.2))
			sphere(root, 0.2 + rng.randf() * 0.1, off, m)
	else:
		# tall grass / palm fronds
		cyl(root, 0.15, 0.12, 0.28, Vector3(0, 0.14, 0), pot)
		cyl(root, 0.13, 0.13, 0.02, Vector3(0, 0.285, 0), soil)
		var n := 16
		for i in n:
			var g := Color(0.22 + rng.randf() * 0.1, 0.52 + rng.randf() * 0.15, 0.24 + rng.randf() * 0.1)
			var leaf := Materials.double_sided(g, 0.7)
			var ang := i * TAU / n + rng.randf() * 0.2
			var length := 0.5 + rng.randf() * 0.3
			_leaf(root, leaf, Vector3(0, 0.3, 0), ang, 0.95 + rng.randf() * 0.45, length, 0.03 + rng.randf() * 0.02, 0.006)
	return root

# ---------------------------------------------------------------- rug

static func rug(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var rs: Dictionary = style.get("rug", {})
	var size := Vector2(3.2, 2.2)
	var mat := Materials.from_spec({
		"shader": "rug",
		"field": rs.get("field", Color(0.5, 0.2, 0.15)),
		"border": rs.get("border", Color(0.3, 0.1, 0.08)),
		"accent": rs.get("accent", Color(0.85, 0.7, 0.45)),
		"rug_size": size,
		"border_w": 0.25,
		"pattern_scale": 0.35,
	})
	var mi := box(root, Vector3(size.x, 0.014, size.y), Vector3(0, 0.007, 0), mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

# ---------------------------------------------------------------- fireplace

static func fireplace(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var stone := Materials.from_spec({
		"shader": "brick",
		"brick_a": Color(0.52, 0.50, 0.47), "brick_b": Color(0.38, 0.36, 0.34), "mortar": Color(0.28, 0.27, 0.25),
		"brick_w": 0.34, "brick_h": 0.14, "mortar_w": 0.02, "jitter": 0.03,
	})
	var wood := Materials.std(style.get("trim", Color(0.3, 0.18, 0.1)), 0.5)
	var soot := Materials.std(Color(0.05, 0.045, 0.04), 1.0)
	var h := 1.25
	var d := 0.5
	# firebox cavity: 0.95 wide, 0.72 high, 0.42 deep, open to the front (+z)
	var cw := 0.95
	var ch := 0.72
	var cd := 0.42
	var hearth := 0.05
	var side_w := (1.7 - cw) / 2.0
	box(root, Vector3(side_w, h, d), Vector3(-(cw / 2.0 + side_w / 2.0), h / 2.0, 0), stone)
	box(root, Vector3(side_w, h, d), Vector3(cw / 2.0 + side_w / 2.0, h / 2.0, 0), stone)
	box(root, Vector3(cw, h - ch - hearth, d), Vector3(0, hearth + ch + (h - ch - hearth) / 2.0, 0), stone)
	box(root, Vector3(cw, hearth, d), Vector3(0, hearth / 2.0, 0), stone)
	box(root, Vector3(cw, ch, d - cd), Vector3(0, hearth + ch / 2.0, -d / 2.0 + (d - cd) / 2.0), soot)
	# soot liners on the cavity walls
	box(root, Vector3(0.01, ch, cd), Vector3(-cw / 2.0 + 0.005, hearth + ch / 2.0, d / 2.0 - cd / 2.0), soot)
	box(root, Vector3(0.01, ch, cd), Vector3(cw / 2.0 - 0.005, hearth + ch / 2.0, d / 2.0 - cd / 2.0), soot)
	box(root, Vector3(cw, 0.01, cd), Vector3(0, hearth + ch - 0.005, d / 2.0 - cd / 2.0), soot)
	box(root, Vector3(cw, 0.01, cd), Vector3(0, hearth + 0.005, d / 2.0 - cd / 2.0), Materials.std(Color(0.12, 0.10, 0.09), 1.0))
	# mantel and chimney
	box(root, Vector3(1.9, 0.08, d + 0.12), Vector3(0, h + 0.04, 0.02), wood)
	var room_h: float = Styles.ROOM_H
	box(root, Vector3(1.2, room_h - h - 0.08, 0.42), Vector3(0, h + 0.08 + (room_h - h - 0.08) / 2.0, -0.04), stone)
	# grate and logs
	var iron := Materials.std(Color(0.08, 0.08, 0.08), 0.6, 0.5)
	for x in [-0.3, 0.0, 0.3]:
		cyl(root, 0.012, 0.012, 0.3, Vector3(x, hearth + 0.06, 0.05), iron, Vector3(PI / 2.0, 0, 0))
	box(root, Vector3(0.7, 0.02, 0.02), Vector3(0, hearth + 0.12, -0.1), iron)
	box(root, Vector3(0.7, 0.02, 0.02), Vector3(0, hearth + 0.12, 0.2), iron)
	var log_mat := Materials.std(Color(0.14, 0.09, 0.06), 0.95)
	var log_hot := Materials.std(Color(0.16, 0.09, 0.05), 0.95, 0.0, Color(1.0, 0.22, 0.03), 0.35)
	cyl(root, 0.05, 0.05, 0.62, Vector3(0, hearth + 0.18, 0.12), log_hot, Vector3(0, 0, PI / 2.0))
	cyl(root, 0.045, 0.045, 0.56, Vector3(0.04, hearth + 0.18, -0.02), log_mat, Vector3(0, 0, PI / 2.0))
	cyl(root, 0.04, 0.04, 0.5, Vector3(-0.05, hearth + 0.26, 0.05), log_hot, Vector3(0.35, 0, PI / 2.0))
	# embers
	var ember := Materials.std(Color(0.4, 0.1, 0.02), 1.0, 0.0, Color(1.0, 0.3, 0.05), 2.5)
	box(root, Vector3(0.55, 0.03, 0.3), Vector3(0, hearth + 0.02, 0.05), ember)
	# flames: crossed planes so they read from any angle
	var fire := Materials.from_spec({"shader": "fire", "color_a": Color(1.0, 0.32, 0.04), "color_b": Color(1.0, 0.85, 0.35), "speed": 1.7, "intensity": 2.4})
	var flame_specs := [
		[Vector2(0.66, 0.66), Vector3(0.0, hearth + 0.22 + 0.32, 0.05), 0.0],
		[Vector2(0.58, 0.60), Vector3(0.0, hearth + 0.22 + 0.29, 0.05), PI / 2.0],
		[Vector2(0.45, 0.42), Vector3(0.12, hearth + 0.22 + 0.21, 0.08), 0.7],
		[Vector2(0.42, 0.40), Vector3(-0.12, hearth + 0.22 + 0.20, 0.0), -0.8],
	]
	for spec in flame_specs:
		var q := QuadMesh.new()
		q.size = spec[0]
		var fm := _mesh(root, q, spec[1], fire, Vector3(0, spec[2], 0))
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := FlickerLight.new()
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 3.2
	light.omni_range = 6.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0, 0.55, 0.55)
	root.add_child(light)
	var inner := FlickerLight.new()
	inner.light_color = Color(1.0, 0.45, 0.12)
	inner.light_energy = 0.7
	inner.omni_range = 1.1
	inner.shadow_enabled = false
	inner.speed = 11.0
	inner.amount = 0.5
	inner.position = Vector3(0, hearth + 0.5, 0.15)
	root.add_child(inner)
	return root

# ---------------------------------------------------------------- cat

## A cat curled up asleep. Origin on the floor at the centre of the body; the head rests toward +x.
static func cat(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var fur_col: Color = style.get("cat_color", Color(0.45, 0.42, 0.40))
	var fur := Materials.std(fur_col, 0.95)
	var fur_dark := Materials.std(fur_col.darkened(0.25), 0.95)
	var fur_light := Materials.std(fur_col.lightened(0.28), 0.95)
	var pink := Materials.std(Color(0.85, 0.55, 0.55), 0.8)
	var dark := Materials.std(Color(0.08, 0.06, 0.06), 0.7)
	var body: Node3D = BreatherScript.new()
	root.add_child(body)
	# curled body: a flattened blob plus a ring to suggest the curl
	sphere(body, 0.19, Vector3(0, 0.09, 0), fur, Vector3(1.0, 0.5, 0.85))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.09
	ring.outer_radius = 0.2
	ring.rings = 24
	ring.ring_segments = 12
	_mesh(body, ring, Vector3(0, 0.06, 0), fur_dark, Vector3.ZERO, Vector3(1.0, 0.55, 0.85))
	# head resting on the body's side
	var head := Vector3(0.14, 0.13, 0.07)
	sphere(body, 0.085, head, fur, Vector3(1.0, 0.85, 0.95))
	sphere(body, 0.045, head + Vector3(0.05, -0.02, 0.03), fur_light, Vector3(1.0, 0.7, 0.9))  # muzzle
	sphere(body, 0.012, head + Vector3(0.085, -0.01, 0.045), pink)  # nose
	# closed eyes: thin dark slits
	box(body, Vector3(0.028, 0.004, 0.006), head + Vector3(0.06, 0.02, 0.07), dark, Vector3(0, -0.3, 0.15))
	box(body, Vector3(0.028, 0.004, 0.006), head + Vector3(0.075, 0.02, 0.0), dark, Vector3(0, 0.6, 0.15))
	# ears
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.026
		ear.height = 0.055
		ear.radial_segments = 8
		_mesh(body, ear, head + Vector3(0.0, 0.075, side * 0.05), fur_dark, Vector3(side * 0.35, 0, -0.25))
		var inner_ear := CylinderMesh.new()
		inner_ear.top_radius = 0.0
		inner_ear.bottom_radius = 0.014
		inner_ear.height = 0.035
		inner_ear.radial_segments = 8
		_mesh(body, inner_ear, head + Vector3(0.008, 0.078, side * 0.05), pink, Vector3(side * 0.35, 0, -0.25))
	# front paws tucked under the chin
	sphere(body, 0.026, Vector3(0.17, 0.03, 0.10), fur_light, Vector3(1.5, 0.7, 1.0))
	sphere(body, 0.026, Vector3(0.175, 0.03, 0.045), fur_light, Vector3(1.5, 0.7, 1.0))
	# tail: a smooth tube curling around the front of the body
	var pts: Array = []
	var n := 26
	for i in n:
		var t := float(i) / float(n - 1)
		var ang := -0.35 - t * 2.6
		var r := 0.15 + t * 0.10
		pts.append(Vector3(cos(ang) * r, 0.035 + (1.0 - t) * 0.03, sin(ang) * r * 0.9))
	tube(body, pts, 0.032, 0.018, fur)
	sphere(body, 0.019, pts[n - 1], fur_dark)
	return root

## Builds a tapered tube along a polyline (clockwise winding, outward normals).
static func tube(parent: Node3D, pts: Array, r0: float, r1: float, mat: Material, segs := 10) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var tangent: Vector3
		if i == 0:
			tangent = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			tangent = (pts[i] - pts[i - 1]).normalized()
		else:
			tangent = (pts[i + 1] - pts[i - 1]).normalized()
		var up := Vector3.UP if abs(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var nrm := tangent.cross(up).normalized()
		var bin := tangent.cross(nrm).normalized()
		var rad: float = lerp(r0, r1, float(i) / float(pts.size() - 1))
		var ring: Array = []
		for k in segs:
			var a := TAU * k / segs
			ring.append(p + (nrm * cos(a) + bin * sin(a)) * rad)
		rings.append(ring)
	for i in rings.size() - 1:
		for k in segs:
			var k2 := (k + 1) % segs
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k2]
			var d: Vector3 = rings[i + 1][k]
			var centre: Vector3 = (pts[i] + pts[i + 1]) * 0.5
			var outward := ((a + b + c + d) * 0.25 - centre).normalized()
			BookMesh._quad(st, a, b, c, d, outward)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- window

static func window(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var frame := Materials.std(style.get("trim", Color(0.9, 0.9, 0.9)), 0.5)
	var glass := Materials.from_spec({
		"shader": "sky_glass",
		"sky_top": Color(0.35, 0.55, 0.85), "sky_bottom": Color(0.85, 0.82, 0.72), "brightness": 1.3,
	})
	var w := 1.3
	var h := 1.5
	var y0 := 0.95
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var g := _mesh(root, q, Vector3(0, y0 + h / 2.0, -0.02), glass)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t := 0.07
	box(root, Vector3(w + 2 * t, t, 0.1), Vector3(0, y0 - t / 2.0, 0), frame)
	box(root, Vector3(w + 2 * t, t, 0.1), Vector3(0, y0 + h + t / 2.0, 0), frame)
	box(root, Vector3(t, h, 0.1), Vector3(-w / 2.0 - t / 2.0, y0 + h / 2.0, 0), frame)
	box(root, Vector3(t, h, 0.1), Vector3(w / 2.0 + t / 2.0, y0 + h / 2.0, 0), frame)
	box(root, Vector3(0.035, h, 0.04), Vector3(0, y0 + h / 2.0, 0.0), frame)
	box(root, Vector3(w, 0.035, 0.04), Vector3(0, y0 + h / 2.0, 0.0), frame)
	box(root, Vector3(w + 2 * t + 0.1, 0.05, 0.22), Vector3(0, y0 - t - 0.025, 0.06), frame)
	var light := OmniLight3D.new()
	light.light_color = Color(0.80, 0.88, 1.0)
	light.light_energy = 1.6
	light.omni_range = 6.5
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position = Vector3(0, y0 + h / 2.0, 0.9)
	root.add_child(light)
	return root

# ---------------------------------------------------------------- furniture

static func floor_lamp(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var metal := Materials.std(Color(0.15, 0.14, 0.13), 0.4, 0.6)
	var shade := Materials.double_sided(style.get("fabric", Color(0.8, 0.75, 0.65)).lightened(0.25), 0.9)
	cyl(root, 0.15, 0.16, 0.03, Vector3(0, 0.015, 0), metal)
	cyl(root, 0.014, 0.014, 1.5, Vector3(0, 0.78, 0), metal)
	cyl(root, 0.15, 0.23, 0.3, Vector3(0, 1.62, 0), shade)
	var bulb := Materials.std(Color(1, 0.95, 0.85), 0.5, 0.0, Color(1.0, 0.9, 0.7), 3.0)
	sphere(root, 0.035, Vector3(0, 1.55, 0), bulb)
	var light := OmniLight3D.new()
	light.light_color = style.get("lamp", Color(1, 0.8, 0.6))
	light.light_energy = float(style.get("lamp_energy", 2.0))
	light.omni_range = 5.5
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(0, 1.5, 0)
	root.add_child(light)
	return root

static func armchair(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var fabric_col: Color = style.get("fabric", Color(0.4, 0.25, 0.18))
	var fabric := Materials.std(fabric_col, 0.95)
	var cushion := Materials.std(fabric_col.lightened(0.12), 0.95)
	var leg := Materials.std(Color(0.2, 0.13, 0.08), 0.6)
	box(root, Vector3(0.66, 0.36, 0.72), Vector3(0, 0.30, 0.04), fabric)
	box(root, Vector3(0.62, 0.10, 0.62), Vector3(0, 0.53, 0.08), cushion)
	box(root, Vector3(0.66, 0.55, 0.20), Vector3(0, 0.70, -0.30), fabric)
	box(root, Vector3(0.17, 0.62, 0.78), Vector3(-0.415, 0.43, 0.02), fabric)
	box(root, Vector3(0.17, 0.62, 0.78), Vector3(0.415, 0.43, 0.02), fabric)
	for sx in [-0.4, 0.4]:
		for sz in [-0.3, 0.32]:
			cyl(root, 0.025, 0.02, 0.12, Vector3(sx, 0.06, sz), leg)
	return root

static func side_table(style: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var wood := Materials.std(style.get("trim", Color(0.3, 0.18, 0.1)).lightened(0.1), 0.5)
	cyl(root, 0.27, 0.27, 0.03, Vector3(0, 0.555, 0), wood)
	cyl(root, 0.025, 0.035, 0.53, Vector3(0, 0.27, 0), wood)
	cyl(root, 0.17, 0.19, 0.025, Vector3(0, 0.0125, 0), wood)
	var y := 0.57
	for i in 3:
		var c := Color.html(Library.SPINE_PALETTE[rng.randi() % Library.SPINE_PALETTE.size()])
		var t := 0.025 + rng.randf() * 0.02
		box(root, Vector3(0.14, t, 0.2), Vector3(-0.07, y + t / 2.0, 0), Materials.std(c, 0.7), Vector3(0, rng.randf_range(-0.25, 0.25), 0))
		y += t
	var mug := Materials.std(Color(0.92, 0.88, 0.80), 0.4)
	cyl(root, 0.04, 0.036, 0.09, Vector3(0.12, 0.615, 0.05), mug)
	return root

static func pendant(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var metal := Materials.std(Color(0.12, 0.11, 0.10), 0.35, 0.7)
	var shade := Materials.double_sided(style.get("trim", Color(0.2, 0.2, 0.2)), 0.6)
	cyl(root, 0.005, 0.005, 0.5, Vector3(0, -0.25, 0), metal)
	cyl(root, 0.06, 0.18, 0.2, Vector3(0, -0.6, 0), shade)
	var bulb := Materials.std(Color(1, 0.95, 0.85), 0.5, 0.0, Color(1.0, 0.92, 0.75), 3.0)
	sphere(root, 0.04, Vector3(0, -0.6, 0), bulb)
	var light := OmniLight3D.new()
	light.light_color = style.get("lamp", Color(1, 0.85, 0.7))
	light.light_energy = float(style.get("lamp_energy", 2.0)) * 0.8
	light.omni_range = 9.0
	light.omni_attenuation = 1.1
	light.shadow_enabled = true
	light.position = Vector3(0, -0.72, 0)
	root.add_child(light)
	return root

static func globe(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var wood := Materials.std(style.get("trim", Color(0.3, 0.18, 0.1)), 0.5)
	var brass := Materials.std(Color(0.75, 0.6, 0.3), 0.35, 0.8)
	cyl(root, 0.2, 0.24, 0.03, Vector3(0, 0.015, 0), wood)
	cyl(root, 0.02, 0.03, 0.75, Vector3(0, 0.39, 0), wood)
	var ocean := Materials.std(Color(0.16, 0.30, 0.45), 0.4)
	sphere(root, 0.24, Vector3(0, 1.02, 0), ocean)
	var land := Materials.std(Color(0.55, 0.45, 0.28), 0.8)
	sphere(root, 0.12, Vector3(0.14, 1.10, 0.14), land, Vector3(1.2, 0.8, 1.0))
	sphere(root, 0.10, Vector3(-0.15, 0.95, 0.12), land, Vector3(1.0, 1.3, 0.8))
	sphere(root, 0.08, Vector3(0.05, 1.12, -0.2), land)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.255
	ring.outer_radius = 0.27
	_mesh(root, ring, Vector3(0, 1.02, 0), brass, Vector3(0, 0, 0.4))
	return root
