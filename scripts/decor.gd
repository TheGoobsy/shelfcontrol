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
	var mi := _mesh(parent, bm, pos, mat, rot)
	mi.set_instance_shader_parameter("box_size", size)  # lets the wood shader run its grain along the board
	return mi

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
	# frame, mullions and sill in the style's board wood (grain follows each piece)
	var frame := Materials.shelf_wood(style)
	var night := bool(style.get("night", false))
	var glass := Materials.from_spec({
		"shader": "sky_glass",
		"sky_top": Color(0.02, 0.03, 0.10) if night else Color(0.35, 0.55, 0.85),
		"sky_bottom": Color(0.08, 0.09, 0.20) if night else Color(0.85, 0.82, 0.72),
		"brightness": 0.9 if night else 1.3,
		"stars": 1.0 if night else 0.0,
		"moon": 1.0 if night else 0.0,
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
	light.light_color = Color(0.55, 0.65, 1.0) if night else Color(0.80, 0.88, 1.0)
	light.light_energy = 0.5 if night else 1.6
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
	var fabric := Materials.fabric(style)
	var cushion := Materials.fabric(style, 0.12)
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
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_bias = 0.06
	light.shadow_normal_bias = 2.5
	light.shadow_blur = 2.4
	light.shadow_opacity = 0.9
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

# ---------------------------------------------------------------- reading table & archive box

static func _pick_body(root: Node3D, size: Vector3, pos: Vector3, prop: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	body.set_meta("prop", prop)
	root.add_child(body)

## Low coffee table on the rug. Books being read are stacked on it by Room3D (child "Stack").
static func reading_table(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var wood := Materials.shelf_wood(style)
	const TOP_Y := 0.42
	box(root, Vector3(0.96, 0.035, 0.54), Vector3(0, TOP_Y - 0.0175, 0), wood)
	box(root, Vector3(0.90, 0.05, 0.48), Vector3(0, TOP_Y - 0.06, 0), wood)
	for sx in [-0.42, 0.42]:
		for sz in [-0.21, 0.21]:
			box(root, Vector3(0.045, TOP_Y - 0.085, 0.045), Vector3(sx, (TOP_Y - 0.085) / 2.0, sz), wood)
	# a coaster with a mug on one end
	cyl(root, 0.055, 0.055, 0.006, Vector3(0.36, TOP_Y + 0.003, 0.14), Materials.std(Color(0.35, 0.22, 0.14), 0.9))
	var mug := Materials.std(Color(0.92, 0.88, 0.80), 0.55)
	cyl(root, 0.04, 0.036, 0.09, Vector3(0.36, TOP_Y + 0.051, 0.14), mug)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.012
	handle.outer_radius = 0.026
	_mesh(root, handle, Vector3(0.405, TOP_Y + 0.05, 0.14), mug, Vector3(0, 0, PI / 2.0))
	var stack := Node3D.new()
	stack.name = "Stack"
	stack.position = Vector3(-0.12, TOP_Y, 0)
	root.add_child(stack)
	_pick_body(root, Vector3(1.0, 0.7, 0.6), Vector3(0, 0.35, 0), "reading")
	return root

## Open cardboard box. Archived books stand inside it (child "Contents").
static func archive_box(_style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var card := Materials.std(Color(0.70, 0.53, 0.34), 0.95)
	var card_in := Materials.std(Color(0.60, 0.45, 0.29), 0.95)
	var tape := Materials.std(Color(0.78, 0.66, 0.45), 0.6)
	const W := 0.50
	const D := 0.36
	const H := 0.19
	const T := 0.008
	box(root, Vector3(W, T, D), Vector3(0, T / 2.0, 0), card_in)
	box(root, Vector3(W, H, T), Vector3(0, H / 2.0, -D / 2.0 + T / 2.0), card)
	box(root, Vector3(W, H, T), Vector3(0, H / 2.0, D / 2.0 - T / 2.0), card)
	box(root, Vector3(T, H, D), Vector3(-W / 2.0 + T / 2.0, H / 2.0, 0), card)
	box(root, Vector3(T, H, D), Vector3(W / 2.0 - T / 2.0, H / 2.0, 0), card)
	# four flaps hinged at the rim, leaning open outwards
	var fl := D * 0.46
	for sz in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(0, H, sz * D / 2.0)
		hinge.rotation = Vector3(-sz * 0.42, 0, 0)
		root.add_child(hinge)
		box(hinge, Vector3(W, T, fl), Vector3(0, 0, sz * fl / 2.0), card)
	for sx in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(sx * W / 2.0, H, 0)
		hinge.rotation = Vector3(0, 0, sx * 0.42)
		root.add_child(hinge)
		box(hinge, Vector3(fl * 0.55, T, D), Vector3(sx * fl * 0.275, 0, 0), card)
	box(root, Vector3(0.06, T * 1.1, D), Vector3(0, T, 0), tape)
	var lbl := Label3D.new()
	lbl.text = "ARCHIVE"
	lbl.font = Book3D._font()
	lbl.pixel_size = 0.0006
	lbl.font_size = 90
	lbl.modulate = Color(0.25, 0.17, 0.10)
	lbl.position = Vector3(0, H * 0.5, D / 2.0 + 0.002)
	lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	root.add_child(lbl)
	var contents := Node3D.new()
	contents.name = "Contents"
	contents.position = Vector3(0, T, 0)
	root.add_child(contents)
	_pick_body(root, Vector3(W + 0.1, 0.45, D + 0.1), Vector3(0, 0.22, 0), "archive")
	return root

# ---------------------------------------------------------------- office

static func desk(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var trim: Color = style.get("trim", Color(0.3, 0.18, 0.1))
	var wood := Materials.std(trim.lightened(0.15), 0.7)
	var dark := Materials.std(trim.darkened(0.15), 0.7)
	var brass := Materials.std(Color(0.75, 0.6, 0.3), 0.35, 0.8)
	const TOP := 0.76
	box(root, Vector3(1.5, 0.04, 0.72), Vector3(0, TOP - 0.02, 0), wood)
	# two drawer pedestals
	for sx in [-0.55, 0.55]:
		box(root, Vector3(0.38, TOP - 0.06, 0.66), Vector3(sx, (TOP - 0.06) / 2.0 + 0.02, 0), dark)
		for i in 3:
			var y := 0.14 + i * 0.22
			box(root, Vector3(0.34, 0.17, 0.01), Vector3(sx, y + 0.085, 0.335), wood)
			cyl(root, 0.012, 0.012, 0.03, Vector3(sx, y + 0.085, 0.35), brass, Vector3(PI / 2.0, 0, 0))
	# modesty panel at the back
	box(root, Vector3(0.75, 0.42, 0.02), Vector3(0, TOP - 0.25, -0.32), dark)
	# papers, pen cup, mug
	var paper := Materials.std(Color(0.95, 0.94, 0.90), 0.95)
	box(root, Vector3(0.21, 0.004, 0.30), Vector3(-0.05, TOP + 0.002, 0.08), paper, Vector3(0, -0.15, 0))
	box(root, Vector3(0.21, 0.004, 0.30), Vector3(-0.02, TOP + 0.006, 0.06), paper, Vector3(0, 0.08, 0))
	var cup := Materials.std(Color(0.18, 0.18, 0.2), 0.5)
	cyl(root, 0.035, 0.03, 0.1, Vector3(0.42, TOP + 0.05, -0.15), cup)
	for i in 3:
		cyl(root, 0.004, 0.004, 0.16, Vector3(0.42 + (i - 1) * 0.012, TOP + 0.12, -0.15 + (i % 2) * 0.012), Materials.std([Color(0.1, 0.2, 0.6), Color(0.7, 0.1, 0.1), Color(0.1, 0.1, 0.1)][i], 0.4), Vector3((i - 1) * 0.12, 0, 0.1))
	var mug := Materials.std(Color(0.90, 0.86, 0.78), 0.55)
	cyl(root, 0.04, 0.036, 0.09, Vector3(0.22, TOP + 0.045, 0.2), mug)
	# banker's lamp: brass stem, green shade, warm light
	var green := Materials.std(Color(0.10, 0.35, 0.22), 0.4)
	cyl(root, 0.06, 0.07, 0.02, Vector3(-0.55, TOP + 0.01, -0.18), brass)
	cyl(root, 0.008, 0.008, 0.3, Vector3(-0.55, TOP + 0.17, -0.18), brass)
	box(root, Vector3(0.3, 0.09, 0.13), Vector3(-0.55, TOP + 0.34, -0.14), green, Vector3(-0.35, 0, 0))
	var bulb := Materials.std(Color(1, 0.95, 0.85), 0.5, 0.0, Color(1.0, 0.9, 0.7), 2.5)
	sphere(root, 0.018, Vector3(-0.55, TOP + 0.3, -0.1), bulb)
	var light := OmniLight3D.new()
	light.light_color = style.get("lamp", Color(1, 0.85, 0.65))
	light.light_energy = float(style.get("lamp_energy", 2.0)) * 0.55
	light.omni_range = 2.6
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(-0.55, TOP + 0.27, -0.05)
	root.add_child(light)
	return root

static func office_chair(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var fabric := Materials.std(style.get("fabric", Color(0.3, 0.25, 0.22)).darkened(0.2), 0.9)
	var metal := Materials.std(Color(0.2, 0.2, 0.21), 0.4, 0.7)
	# five-star base with wheels
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var arm := box(root, Vector3(0.3, 0.025, 0.04), Vector3(cos(a) * 0.15, 0.06, sin(a) * 0.15), metal, Vector3(0, -a, 0))
		arm.rotation = Vector3(0, -a, 0)
		sphere(root, 0.028, Vector3(cos(a) * 0.29, 0.028, sin(a) * 0.29), metal)
	cyl(root, 0.03, 0.03, 0.36, Vector3(0, 0.25, 0), metal)
	box(root, Vector3(0.48, 0.09, 0.48), Vector3(0, 0.47, 0.02), fabric)
	box(root, Vector3(0.46, 0.55, 0.08), Vector3(0, 0.80, -0.22), fabric, Vector3(0.1, 0, 0))
	for sx in [-0.26, 0.26]:
		box(root, Vector3(0.05, 0.03, 0.3), Vector3(sx, 0.70, 0.0), metal)
		box(root, Vector3(0.05, 0.16, 0.05), Vector3(sx, 0.61, 0.1), metal)
	return root

# ---------------------------------------------------------------- bedroom

static func bed(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var trim: Color = style.get("trim", Color(0.3, 0.18, 0.1))
	var wood := Materials.std(trim.lightened(0.1), 0.7)
	var fabric_col: Color = style.get("fabric", Color(0.4, 0.25, 0.18))
	var duvet := Materials.std(fabric_col.lightened(0.25), 0.95)
	var sheet := Materials.std(Color(0.93, 0.91, 0.86), 0.95)
	var pillow := Materials.std(Color(0.96, 0.95, 0.92), 0.95)
	# footprint 1.5 x 2.0, headboard at +z
	box(root, Vector3(1.5, 0.22, 2.0), Vector3(0, 0.22, 0), wood)
	for sx in [-0.7, 0.7]:
		for sz in [-0.95, 0.95]:
			box(root, Vector3(0.08, 0.12, 0.08), Vector3(sx, 0.06, sz), wood)
	box(root, Vector3(1.42, 0.2, 1.92), Vector3(0, 0.43, 0), sheet)
	box(root, Vector3(1.48, 0.14, 1.35), Vector3(0, 0.56, -0.3), duvet)
	box(root, Vector3(1.48, 0.06, 0.3), Vector3(0, 0.52, 0.42), duvet, Vector3(0.6, 0, 0))
	for sx in [-0.36, 0.36]:
		var pl := sphere(root, 0.24, Vector3(sx, 0.60, 0.72), pillow, Vector3(1.3, 0.35, 0.8))
		pl.rotation = Vector3(-0.3, 0, 0)
	box(root, Vector3(1.5, 0.9, 0.06), Vector3(0, 0.7, 1.0), wood)
	return root

static func nightstand(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var trim: Color = style.get("trim", Color(0.3, 0.18, 0.1))
	var wood := Materials.std(trim.lightened(0.1), 0.7)
	var brass := Materials.std(Color(0.75, 0.6, 0.3), 0.35, 0.8)
	box(root, Vector3(0.42, 0.55, 0.4), Vector3(0, 0.3, 0), wood)
	box(root, Vector3(0.36, 0.14, 0.01), Vector3(0, 0.42, 0.205), Materials.std(trim.lightened(0.2), 0.7))
	cyl(root, 0.012, 0.012, 0.03, Vector3(0, 0.42, 0.22), brass, Vector3(PI / 2.0, 0, 0))
	# small lamp
	cyl(root, 0.07, 0.08, 0.02, Vector3(0, 0.585, 0), brass)
	cyl(root, 0.01, 0.01, 0.22, Vector3(0, 0.7, 0), brass)
	var shade := Materials.double_sided(style.get("fabric", Color(0.8, 0.75, 0.65)).lightened(0.35), 0.9)
	cyl(root, 0.09, 0.13, 0.16, Vector3(0, 0.86, 0), shade)
	var bulb := Materials.std(Color(1, 0.95, 0.85), 0.5, 0.0, Color(1.0, 0.9, 0.7), 2.5)
	sphere(root, 0.025, Vector3(0, 0.82, 0), bulb)
	var light := OmniLight3D.new()
	light.light_color = style.get("lamp", Color(1, 0.8, 0.6))
	light.light_energy = float(style.get("lamp_energy", 2.0)) * 0.6
	light.omni_range = 3.5
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(0, 0.82, 0)
	root.add_child(light)
	# a book left on top
	box(root, Vector3(0.13, 0.025, 0.19), Vector3(0.1, 0.5875, 0.08), Materials.std(Color(0.35, 0.15, 0.2), 0.7), Vector3(0, 0.3, 0))
	return root

# ---------------------------------------------------------------- fantasy library

static func _candle(parent: Node3D, pos: Vector3, h: float, r := 0.018) -> void:
	var wax := Materials.std(Color(0.94, 0.90, 0.78), 0.8)
	cyl(parent, r, r, h, pos + Vector3(0, h / 2.0, 0), wax)
	var flame := Materials.std(Color(1.0, 0.85, 0.5), 0.5, 0.0, Color(1.0, 0.7, 0.3), 5.0)
	sphere(parent, 0.012, pos + Vector3(0, h + 0.02, 0), flame, Vector3(0.7, 1.4, 0.7))

static func candelabra(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var iron := Materials.std(Color(0.12, 0.11, 0.10), 0.5, 0.6)
	cyl(root, 0.14, 0.17, 0.03, Vector3(0, 0.015, 0), iron)
	cyl(root, 0.018, 0.022, 1.15, Vector3(0, 0.6, 0), iron)
	sphere(root, 0.04, Vector3(0, 0.55, 0), iron)
	var top := 1.18
	_candle(root, Vector3(0, top + 0.02, 0), 0.16, 0.02)
	for i in 4:
		var a := float(i) / 4.0 * TAU
		var arm_end := Vector3(cos(a) * 0.17, top, sin(a) * 0.17)
		var arm := box(root, Vector3(0.17, 0.014, 0.014), arm_end * 0.5 + Vector3(0, top * 0.5 - 0.02, 0) * 0.0, iron)
		arm.position = Vector3(cos(a) * 0.085, top - 0.02, sin(a) * 0.085)
		arm.rotation = Vector3(0, -a, 0)
		cyl(root, 0.03, 0.02, 0.02, arm_end + Vector3(0, -0.01, 0), iron)
		_candle(root, arm_end, 0.12)
	var light := FlickerLight.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = float(style.get("lamp_energy", 2.0)) * 0.7
	light.amount = 0.18
	light.speed = 5.0
	light.omni_range = 4.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0, top + 0.3, 0)
	root.add_child(light)
	return root

static func lectern(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var trim: Color = style.get("trim", Color(0.3, 0.18, 0.1))
	var wood := Materials.std(trim.darkened(0.1), 0.7)
	cyl(root, 0.2, 0.26, 0.04, Vector3(0, 0.02, 0), wood)
	cyl(root, 0.045, 0.06, 1.0, Vector3(0, 0.54, 0), wood)
	var top := Node3D.new()
	top.position = Vector3(0, 1.1, 0)
	top.rotation = Vector3(-0.45, 0, 0)
	root.add_child(top)
	box(top, Vector3(0.6, 0.03, 0.45), Vector3.ZERO, wood)
	box(top, Vector3(0.6, 0.05, 0.03), Vector3(0, 0.025, 0.225), wood)
	# open tome: two leather covers, page blocks, a ribbon
	var leather := Materials.std(Color(0.35, 0.12, 0.10), 0.6)
	var pages := Materials.std(Color(0.93, 0.88, 0.76), 0.95)
	for sx in [-1.0, 1.0]:
		box(top, Vector3(0.22, 0.01, 0.32), Vector3(sx * 0.115, 0.02, 0.0), leather, Vector3(0, 0, sx * 0.05))
		box(top, Vector3(0.20, 0.035, 0.30), Vector3(sx * 0.11, 0.045, 0.0), pages, Vector3(0, 0, sx * 0.05))
	box(top, Vector3(0.02, 0.005, 0.36), Vector3(0.06, 0.065, 0.02), Materials.std(Color(0.7, 0.1, 0.15), 0.6))
	return root

static func crystal_ball(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var trim: Color = style.get("trim", Color(0.3, 0.18, 0.1))
	var wood := Materials.std(trim, 0.7)
	var brass := Materials.std(Color(0.75, 0.6, 0.3), 0.35, 0.8)
	cyl(root, 0.22, 0.22, 0.03, Vector3(0, 0.815, 0), wood)
	cyl(root, 0.03, 0.05, 0.78, Vector3(0, 0.41, 0), wood)
	cyl(root, 0.2, 0.24, 0.03, Vector3(0, 0.015, 0), wood)
	# claw base and the glass
	cyl(root, 0.07, 0.1, 0.05, Vector3(0, 0.855, 0), brass)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.75, 1.0, 0.45)
	glass.roughness = 0.05
	glass.emission_enabled = true
	glass.emission = Color(0.35, 0.55, 1.0)
	glass.emission_energy_multiplier = 1.6
	sphere(root, 0.13, Vector3(0, 1.0, 0), glass)
	var core := Materials.std(Color(0.6, 0.8, 1.0), 0.3, 0.0, Color(0.5, 0.7, 1.0), 4.0)
	sphere(root, 0.04, Vector3(0, 1.0, 0), core)
	var light := FlickerLight.new()
	light.light_color = Color(0.45, 0.65, 1.0)
	light.light_energy = 1.4
	light.amount = 0.3
	light.speed = 2.5
	light.omni_range = 3.5
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	return root

static func chandelier(style: Dictionary) -> Node3D:
	var root := Node3D.new()
	var iron := Materials.std(Color(0.12, 0.11, 0.10), 0.5, 0.6)
	cyl(root, 0.006, 0.006, 0.7, Vector3(0, -0.35, 0), iron)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.46
	ring.rings = 32
	_mesh(root, ring, Vector3(0, -0.72, 0), iron)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		var pos := Vector3(cos(a) * 0.44, -0.71, sin(a) * 0.44)
		cyl(root, 0.03, 0.02, 0.02, pos, iron)
		_candle(root, pos + Vector3(0, 0.01, 0), 0.11)
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.3
		var chain := cyl(root, 0.004, 0.004, 0.5, Vector3(cos(a) * 0.22, -0.5, sin(a) * 0.22), iron)
		chain.rotation = Vector3(sin(a) * 0.72, 0, -cos(a) * 0.72)
	var light := FlickerLight.new()
	light.light_color = Color(1.0, 0.74, 0.42)
	light.light_energy = float(style.get("lamp_energy", 2.0)) * 0.9
	light.amount = 0.15
	light.speed = 4.5
	light.omni_range = 9.0
	light.omni_attenuation = 1.1
	light.shadow_enabled = true
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_bias = 0.06
	light.shadow_normal_bias = 2.5
	light.shadow_blur = 2.4
	light.shadow_opacity = 0.9
	light.position = Vector3(0, -0.62, 0)
	root.add_child(light)
	return root

# ---------------------------------------------------------------- doors

## A closed panel door in a wall slot, origin on the floor at the wall, +z into the room.
## The slab hangs on the child "Hinge" so it can swing open; the plate names the room beyond.
static func door(style: Dictionary, plate_text: String, to_rid: String) -> Node3D:
	var root := Node3D.new()
	var wood := Materials.shelf_wood(style)
	var trim: Color = style.get("trim", Color(0.3, 0.18, 0.1))
	var slab_mat := Materials.std(trim.lightened(0.05), 0.6)
	var brass := Materials.std(Color(0.78, 0.62, 0.32), 0.3, 0.85)
	const W := 0.95
	const H := 2.05
	const J := 0.08
	# jambs and head, slightly proud of the wall
	box(root, Vector3(J, H + J, 0.14), Vector3(-W / 2.0 - J / 2.0, (H + J) / 2.0, 0.0), wood)
	box(root, Vector3(J, H + J, 0.14), Vector3(W / 2.0 + J / 2.0, (H + J) / 2.0, 0.0), wood)
	box(root, Vector3(W + 2.0 * J, J, 0.14), Vector3(0, H + J / 2.0, 0.0), wood)
	# dark reveal behind the slab so an open door shows depth, not the wall
	box(root, Vector3(W, H, 0.02), Vector3(0, H / 2.0, -0.05), Materials.std(Color(0.03, 0.02, 0.02), 1.0))
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-W / 2.0, 0, 0.02)
	root.add_child(hinge)
	var slab := box(hinge, Vector3(W - 0.01, H - 0.01, 0.045), Vector3(W / 2.0, H / 2.0, 0), slab_mat)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# two recessed panels
	var panel := Materials.std(trim.darkened(0.12), 0.65)
	box(hinge, Vector3(W - 0.24, 0.78, 0.012), Vector3(W / 2.0, 1.45, 0.028), panel)
	box(hinge, Vector3(W - 0.24, 0.62, 0.012), Vector3(W / 2.0, 0.52, 0.028), panel)
	# handle on the free edge
	cyl(hinge, 0.012, 0.012, 0.11, Vector3(W - 0.09, 1.02, 0.06), brass, Vector3(0, 0, PI / 2.0))
	sphere(hinge, 0.02, Vector3(W - 0.09, 1.02, 0.045), brass)
	# name plate above the door
	var plate := box(root, Vector3(0.74, 0.17, 0.02), Vector3(0, H + J + 0.15, 0.03), brass)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lbl := Label3D.new()
	lbl.text = plate_text if plate_text.length() <= 14 else plate_text.left(13).strip_edges() + "…"
	lbl.font = Book3D._font()
	lbl.pixel_size = 0.0005
	lbl.font_size = 150
	lbl.modulate = Color(0.16, 0.11, 0.06)
	lbl.position = Vector3(0, H + J + 0.15, 0.045)
	lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	root.add_child(lbl)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W + 2.0 * J, H + 0.5, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, (H + 0.5) / 2.0, 0.05)
	body.add_child(cs)
	body.set_meta("door_to", to_rid)
	root.add_child(body)
	return root
