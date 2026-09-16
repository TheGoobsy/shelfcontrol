class_name Room3D
extends Node3D
## Builds the room shell, lighting, decor and shelves for one room + style.

var room: Dictionary = {}
var style: Dictionary = {}
var shelves: Dictionary = {}   # sid -> Shelf3D
var env: WorldEnvironment
var table: Node3D
var archive: Node3D

const TABLE_POS := Vector3(0.35, 0, 0.15)
const ARCHIVE_POS := Vector3(-1.9, 0, 2.5)
const TABLE_STACK_MAX := 6
const ARCHIVE_SHOW_MAX := 10

const PLANT_CORNERS := [Vector3(-3.05, 0, -2.05), Vector3(3.05, 0, -2.05), Vector3(-3.05, 0, 2.1), Vector3(3.1, 0, 2.5)]
const CANDLE_SPOTS := [Vector3(-2.3, 0, 1.9), Vector3(2.3, 0, 1.9), Vector3(0, 0, -2.2)]

func build(r: Dictionary, st: Dictionary) -> void:
	room = r
	style = Styles.night_variant(st) if Settings.is_night() else st
	for c in get_children():
		remove_child(c)
		c.queue_free()
	shelves.clear()
	_build_environment()
	_build_shell()
	_build_lights()
	_build_shelves()
	_build_decor()
	_build_props()

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi

func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = style.get("background", Color(0.05, 0.03, 0.02))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = style.get("ambient", Color(1, 0.8, 0.6))
	e.ambient_light_energy = float(style.get("ambient_energy", 0.4))
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 4.0
	if bool(style.get("glow", false)):
		e.glow_enabled = true
		e.glow_intensity = 0.35
		e.glow_bloom = 0.05
		e.glow_hdr_threshold = 1.1
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.environment = e
	add_child(env)

func _build_shell() -> void:
	var W: float = Styles.ROOM_W
	var D: float = Styles.ROOM_D
	var H: float = Styles.ROOM_H
	var floor_mat := Materials.from_spec(style.get("floor", {"shader": "planks"}))
	var ceil_mat := Materials.from_spec(style.get("ceiling", {"shader": "plaster", "color": Color(0.9, 0.9, 0.9)}))
	var wall_mat := Materials.from_spec(style.get("wall", {"shader": "plaster"}))
	var accent_mat := wall_mat
	if style.has("wall_accent"):
		accent_mat = Materials.from_spec(style["wall_accent"])
	_box(Vector3(W + 0.4, 0.1, D + 0.4), Vector3(0, -0.05, 0), floor_mat)
	_box(Vector3(W + 0.4, 0.1, D + 0.4), Vector3(0, H + 0.05, 0), ceil_mat)
	_box(Vector3(W + 0.4, H + 0.2, 0.1), Vector3(0, H / 2.0, -D / 2.0 - 0.05), accent_mat)
	_box(Vector3(W + 0.4, H + 0.2, 0.1), Vector3(0, H / 2.0, D / 2.0 + 0.05), wall_mat)
	_box(Vector3(0.1, H + 0.2, D + 0.4), Vector3(W / 2.0 + 0.05, H / 2.0, 0), wall_mat)
	_box(Vector3(0.1, H + 0.2, D + 0.4), Vector3(-W / 2.0 - 0.05, H / 2.0, 0), wall_mat)
	# baseboards and crown trim
	var trim := Materials.std(style.get("trim", Color(0.3, 0.2, 0.1)), 0.5)
	for y in [0.05, H - 0.04]:
		var th := 0.1 if y < 1.0 else 0.08
		_box(Vector3(W, th, 0.03), Vector3(0, y, -D / 2.0 + 0.015), trim)
		_box(Vector3(W, th, 0.03), Vector3(0, y, D / 2.0 - 0.015), trim)
		_box(Vector3(0.03, th, D), Vector3(W / 2.0 - 0.015, y, 0), trim)
		_box(Vector3(0.03, th, D), Vector3(-W / 2.0 + 0.015, y, 0), trim)

func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = style.get("sun", Color(1, 0.9, 0.75))
	sun.light_energy = float(style.get("sun_energy", 1.2))
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.35
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 9.5
	sun.directional_shadow_fade_start = 0.9
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 2.0
	sun.shadow_opacity = 0.9
	sun.shadow_blur = 0.7
	add_child(sun)

func _build_shelves() -> void:
	for s in room.get("shelves", []):
		var sh := Shelf3D.new()
		add_child(sh)
		sh.transform = Styles.shelf_transform(int(s["wall"]), int(s["slot"]))
		sh.setup(s, style)
		shelves[str(s["id"])] = sh

func occupied(wall: int, slot: int) -> bool:
	for s in room.get("shelves", []):
		if int(s["wall"]) == wall and int(s["slot"]) == slot:
			return true
	return false

func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(room.get("id", "")) + str(style.get("name", "")))
	var plant_i := 0
	var candle_i := 0
	var has_fireplace := false
	var fire_pos := Vector3(0, 0, Styles.ROOM_D / 2.0)
	for d in Styles.room_decor(room, style):
		match str(d):
			"fireplace":
				var cs: int = Styles.center_slot(2)
				if cs >= 0 and not occupied(2, cs):
					var f := Decor.fireplace(style)
					add_child(f)
					f.transform = Styles.wall_transform(2, 0.0, 0.5)
					has_fireplace = true
			"window":
				var cs: int = Styles.center_slot(0)
				if cs >= 0 and not occupied(0, cs):
					var w := Decor.window(style)
					add_child(w)
					w.transform = Styles.wall_transform(0, 0.0, 0.1)
			"rug":
				var r := Decor.rug(style)
				add_child(r)
				r.position = Vector3(0, 0, 0.3)
			"plant":
				if plant_i < PLANT_CORNERS.size():
					var p := Decor.plant(style, rng)
					add_child(p)
					p.position = PLANT_CORNERS[plant_i]
					p.rotation.y = rng.randf() * TAU
					plant_i += 1
			"armchair":
				var a := Decor.armchair(style)
				add_child(a)
				a.position = Vector3(1.75, 0, 1.25)
				var target := fire_pos if has_fireplace else Vector3(0, 0, -1.0)
				var dir := target - a.position
				a.rotation.y = atan2(dir.x, dir.z)
			"side_table":
				var t := Decor.side_table(style, rng)
				add_child(t)
				t.position = Vector3(2.55, 0, 1.05)
			"floor_lamp":
				var l := Decor.floor_lamp(style)
				add_child(l)
				l.position = Vector3(2.75, 0, 2.15)
			"pendant":
				var p := Decor.pendant(style)
				add_child(p)
				p.position = Vector3(0, Styles.ROOM_H, 0.3)
			"cat":
				var k := Decor.cat(style)
				add_child(k)
				k.position = Vector3(-0.75, 0.014, 0.85)
				k.rotation.y = 2.4
			"globe":
				var g := Decor.globe(style)
				add_child(g)
				g.position = Vector3(-2.55, 0, 1.9)
			"desk":
				var dk := Decor.desk(style)
				add_child(dk)
				dk.position = Vector3(1.7, 0, 1.15)
			"office_chair":
				var oc := Decor.office_chair(style)
				add_child(oc)
				oc.position = Vector3(1.75, 0, 1.95)
				oc.rotation.y = PI + 0.25
			"bed":
				var bd := Decor.bed(style)
				add_child(bd)
				bd.position = Vector3(-1.9, 0, 1.75)
			"nightstand":
				var ns := Decor.nightstand(style)
				add_child(ns)
				ns.position = Vector3(-0.95, 0, 2.5)
			"candelabra":
				if candle_i < CANDLE_SPOTS.size():
					var cd := Decor.candelabra(style)
					add_child(cd)
					cd.position = CANDLE_SPOTS[candle_i]
					candle_i += 1
			"lectern":
				var lc := Decor.lectern(style)
				add_child(lc)
				lc.position = Vector3(1.6, 0, -1.1)
				lc.rotation.y = -0.5
			"crystal_ball":
				var cb := Decor.crystal_ball(style)
				add_child(cb)
				cb.position = Vector3(-1.7, 0, -1.2)
			"chandelier":
				var ch := Decor.chandelier(style)
				add_child(ch)
				ch.position = Vector3(0, Styles.ROOM_H, 0.3)

## Functional props present in every room: the reading table and the archive box.
func _build_props() -> void:
	table = Decor.reading_table(style)
	add_child(table)
	table.position = TABLE_POS
	table.rotation.y = 0.12
	archive = Decor.archive_box(style)
	add_child(archive)
	# the bed takes the south-west corner in a bedroom, so the box moves to the other side
	var apos := ARCHIVE_POS if str(room.get("type", "living")) != "bedroom" else Vector3(2.4, 0, 2.5)
	archive.position = apos
	var dir := Vector3(0, 0, 0.3) - apos
	archive.rotation.y = atan2(dir.x, dir.z)
	refresh_props()

## Rebuilds the stack on the table and the books in the archive box from the library's statuses.
func refresh_props() -> void:
	if table == null or archive == null:
		return
	var stack: Node3D = table.get_node("Stack")
	for c in stack.get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var y := 0.0
	var reading := Library.reading_ids()
	for i in mini(reading.size(), TABLE_STACK_MAX):
		var b := Library.get_book(reading[i])
		var b3 := Book3D.new()
		b3.flat = true
		b3.setup(b)
		stack.add_child(b3)
		# lie flat, cover up: roll 90° so the cover normal (+x) points up
		b3.rotation = Vector3(0, rng.randf_range(-0.14, 0.14), PI / 2.0)
		b3.position = Vector3(b3.dims.y / 2.0 + rng.randf_range(-0.02, 0.02), y + b3.dims.x / 2.0, rng.randf_range(-0.015, 0.015))
		y += b3.dims.x
	var contents: Node3D = archive.get_node("Contents")
	for c in contents.get_children():
		c.queue_free()
	var archived := Library.archived_ids()
	var shown: Array = []
	var total := 0.0
	for i in mini(archived.size(), ARCHIVE_SHOW_MAX):
		var b := Library.get_book(archived[i])
		var t := float(b.get("thickness", 0.03)) + 0.006
		if total + t > 0.44:
			break
		shown.append(b)
		total += t
	var x := -total / 2.0
	for b in shown:
		var b3 := Book3D.new()
		b3.setup(b)
		contents.add_child(b3)
		b3.position = Vector3(x + b3.dims.x / 2.0, 0.0, 0.0)
		b3.rotation = Vector3(0, 0, rng.randf_range(-0.06, 0.06))
		x += b3.dims.x + 0.006

func prop_by_body(body: Object) -> String:
	if body == null or not body.has_meta("prop"):
		return ""
	return str(body.get_meta("prop"))

func shelf_by_body(body: Object) -> Shelf3D:
	if body == null or not body.has_meta("shelf_id"):
		return null
	return shelves.get(str(body.get_meta("shelf_id")))

func shelf_for_book(book_id: String) -> Shelf3D:
	for sid in shelves:
		if shelves[sid].books.has(book_id):
			return shelves[sid]
	return null
