class_name Room3D
extends Node3D
## Builds the room shell, lighting, decor and shelves for one room + style.

var room: Dictionary = {}
var style: Dictionary = {}
var shelves: Dictionary = {}   # sid -> Shelf3D
var env: WorldEnvironment
var table: Node3D
var archive: Node3D
var doors: Dictionary = {}   # target room id -> door Node3D
var decor_nodes: Array[Node3D] = []   # furniture that may be faded out of the way
## Every placed piece, keyed by its furniture id: {node, kind, entry, rect}. `rect` is the
## floor box it occupies in room space, which is what the editor tests a new piece against.
var furniture: Dictionary = {}
var ceiling: MeshInstance3D
var _decor_boxes: Array[AABB] = []
var _fade_args := []   # [eye, shelf, amount] of the fade in force, so rebuilt props match

const TABLE_STACK_MAX := 6
const ARCHIVE_SHOW_MAX := 10

func build(r: Dictionary, st: Dictionary) -> void:
	room = r
	style = Styles.night_variant(st) if Settings.is_night() else st
	for c in get_children():
		remove_child(c)
		c.queue_free()
	shelves.clear()
	doors.clear()
	decor_nodes.clear()
	furniture.clear()
	_decor_boxes.clear()
	_build_environment()
	_build_shell()
	_build_lights()
	_build_shelves()
	_build_doors()
	_build_furniture()

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
	ceiling = _box(Vector3(W + 0.4, 0.1, D + 0.4), Vector3(0, H + 0.05, 0), ceil_mat)
	_box(Vector3(W + 0.4, H + 0.2, 0.1), Vector3(0, H / 2.0, -D / 2.0 - 0.05), accent_mat)
	_box(Vector3(W + 0.4, H + 0.2, 0.1), Vector3(0, H / 2.0, D / 2.0 + 0.05), wall_mat)
	_box(Vector3(0.1, H + 0.2, D + 0.4), Vector3(W / 2.0 + 0.05, H / 2.0, 0), wall_mat)
	_box(Vector3(0.1, H + 0.2, D + 0.4), Vector3(-W / 2.0 - 0.05, H / 2.0, 0), wall_mat)
	# baseboards and crown trim
	var trim := Materials.std(style.get("trim", Color(0.3, 0.2, 0.1)), 0.5)
	var skirt := Styles.SKIRT_T
	for y in [Styles.SKIRT_H / 2.0, H - 0.04]:
		var th := Styles.SKIRT_H if y < 1.0 else 0.08
		_box(Vector3(W, th, skirt), Vector3(0, y, -D / 2.0 + skirt / 2.0), trim)
		_box(Vector3(W, th, skirt), Vector3(0, y, D / 2.0 - skirt / 2.0), trim)
		_box(Vector3(skirt, th, D), Vector3(W / 2.0 - skirt / 2.0, y, 0), trim)
		_box(Vector3(skirt, th, D), Vector3(-W / 2.0 + skirt / 2.0, y, 0), trim)

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

func _build_doors() -> void:
	for d in room.get("doors", []):
		var target := Library.get_room(str(d["to"]))
		var dn := Decor.door(style, str(target.get("name", "")), str(d["to"]))
		add_child(dn)
		dn.transform = Styles.wall_transform(int(d["wall"]), Styles.slot_offset(int(d["wall"]), int(d["slot"])), 0.12)
		doors[str(d["to"])] = dn

## The top-down editing view looks through where the ceiling is, so it goes away while
## the room is being furnished. Hanging lamps stay: they are furniture like any other.
func set_ceiling_visible(on: bool) -> void:
	if ceiling != null:
		ceiling.visible = on

## Target room id for a tapped door body, or "".
func door_by_body(body: Object) -> String:
	if body == null or not body.has_meta("door_to"):
		return ""
	return str(body.get_meta("door_to"))

func occupied(wall: int, slot: int) -> bool:
	for sh in room.get("shelves", []):
		if int(sh["wall"]) == wall and int(sh["slot"]) == slot:
			return true
	return false

## Builds the room's furnishing from its furniture list. Nothing here is decided by a
## style or a room type any more: the list is what the reader arranged in the editor.
func _build_furniture() -> void:
	table = null
	archive = null
	var first := get_child_count()
	for e in room.get("furniture", []):
		_place_entry(e)
	_track_decor(first)
	refresh_props()

func _place_entry(e: Dictionary) -> void:
	var kind := str(e.get("kind", ""))
	var node := Furniture.build(e, style)
	if node == null:
		return
	add_child(node)
	var sp := Furniture.spec(kind)
	# Measured while the piece is still standing at the origin: the box is its own extent,
	# which the placement below then moves. Reading it afterwards would count the move twice.
	var local := Furniture.footprint(node, kind)
	var rect := Rect2()
	match Furniture.anchor(kind):
		Furniture.WALL:
			var wall := int(e.get("wall", 0))
			var slot := int(e.get("slot", 0))
			var t := Styles.wall_transform(wall, Styles.slot_offset(wall, slot), float(sp.get("depth", 0.2)))
			node.transform = t
			node.position.y = float(sp.get("y", 0.0))
			# a fireplace stands well out from the wall, so it takes real floor
			rect = Furniture.world_rect(local, t.origin.x, t.origin.z, t.basis.get_euler().y)
		Furniture.CEILING:
			node.position = Vector3(float(e.get("x", 0.0)), float(sp.get("y", Styles.ROOM_H)), float(e.get("z", 0.0)))
			node.rotation.y = float(e.get("rot", 0.0))
		_:
			var x := float(e.get("x", 0.0))
			var z := float(e.get("z", 0.0))
			var rot := float(e.get("rot", 0.0))
			# a piece may sit on top of another one (a candle on a crate), so it keeps its height
			node.position = Vector3(x, float(e.get("y", 0.0)), z)
			node.rotation.y = rot
			rect = Furniture.world_rect(local, x, z, rot)
	match kind:
		"reading_table": table = node
		"archive_box": archive = node
	furniture[str(e.get("id", ""))] = {"node": node, "kind": kind, "entry": e, "rect": rect, "local": local}

## The floor boxes the room's furniture stands on, as {id, kind, rect} in room space.
## `skip` leaves one piece out, which is what moving a piece needs so it does not
## collide with the spot it is being lifted from.
func furniture_rects(skip := "") -> Array:
	var out: Array = []
	for fid in furniture:
		if fid == skip:
			continue
		var f: Dictionary = furniture[fid]
		if f["rect"].size == Vector2.ZERO:
			continue
		out.append({"id": fid, "kind": f["kind"], "rect": f["rect"]})
	return out

func furniture_node(fid: String) -> Node3D:
	var f: Dictionary = furniture.get(fid, {})
	return f.get("node", null)

## Remembers the furniture added since `first`, with the world box each piece occupies,
## so shelf mode can fade whatever stands in front of the books.
func _track_decor(first: int) -> void:
	for i in range(first, get_child_count()):
		var c := get_child(i)
		if c is Node3D and not (c is Light3D):
			decor_nodes.append(c)
			_decor_boxes.append(global_transform * Decor.model_aabb(c))

## Furniture standing between the reader's eye and the shelf they opened turns see-through,
## so a chair, a plant or the reading table never hides the books. `amount` 0.0 is solid.
func fade_for_view(eye: Vector3, sh: Shelf3D, amount: float) -> int:
	_fade_args = [eye, sh, amount]
	var targets: Array[Vector3] = []
	if sh != null and amount > 0.0:
		var c := sh.center_world()
		var right := sh.global_transform.basis.x.normalized() * (Styles.SHELF_W * 0.45)
		var up := Vector3.UP * (Styles.SHELF_H * 0.45)
		targets = [c, c + right, c - right, c + up, c - up, c + right + up, c - right - up]
	var faded := 0
	for i in decor_nodes.size():
		var n := decor_nodes[i]
		if not is_instance_valid(n):
			continue
		var hidden := false
		for t in targets:
			if _decor_boxes[i].intersects_segment(eye, t):
				hidden = true
				break
		_set_transparency(n, amount if hidden else 0.0)
		if hidden:
			faded += 1
	return faded

## GeometryInstance3D.transparency only works in Forward+, and this app runs the mobile
## renderer, so a see-through copy of each material is swapped in instead.
static func _set_transparency(n: Node, amount: float) -> void:
	if n is MeshInstance3D and n.mesh != null:
		if amount > 0.0:
			if not n.has_meta("solid_mat"):
				n.set_meta("solid_mat", n.material_override)
				n.set_meta("solid_shadow", n.cast_shadow)
				n.material_override = Materials.see_through(n.get_active_material(0), 1.0 - amount)
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n.has_meta("solid_mat"):
			n.material_override = n.get_meta("solid_mat")
			n.cast_shadow = n.get_meta("solid_shadow")
			n.remove_meta("solid_mat")
			n.remove_meta("solid_shadow")
	for c in n.get_children():
		_set_transparency(c, amount)

## Rebuilds the stack on the table and the books in the archive box from the library's statuses.
## A room only has these if the reader placed them, so each half stands on its own.
func refresh_props() -> void:
	if not _fade_args.is_empty() and float(_fade_args[2]) > 0.0:
		(func(): fade_for_view(_fade_args[0], _fade_args[1], _fade_args[2])).call_deferred()
	_refresh_table()
	_refresh_archive()

func _refresh_table() -> void:
	if table == null:
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

func _refresh_archive() -> void:
	if archive == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
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
