class_name Shelf3D
extends Node3D
## A bookcase: procedural case geometry plus Book3D children laid out per row.
## Local space: origin at floor centre of footprint, +z faces into the room.

const SIDE_T := 0.025
const BOARD_T := 0.022
const BACK_T := 0.012
const PLINTH := 0.06
const TOP_T := 0.03
const PAD := 0.015
const GAP := 0.003

var W: float = Styles.SHELF_W
var H: float = Styles.SHELF_H
var D: float = Styles.SHELF_D
var ROWS: int = Library.SHELF_ROWS

var shelf_id := ""
var shelf: Dictionary = {}
var style: Dictionary = {}
var books: Dictionary = {}     # id -> Book3D
var rows_y: Array = []         # standing height per row
var row_h := 0.0
var body: StaticBody3D
var books_root: Node3D
var case_root: Node3D

func setup(s: Dictionary, st: Dictionary) -> void:
	shelf = s
	shelf_id = str(s["id"])
	style = st
	if case_root == null:
		case_root = Node3D.new()
		add_child(case_root)
		books_root = Node3D.new()
		add_child(books_root)
	_build_case()
	rebuild_books(false)

func refresh_data() -> void:
	shelf = Library.get_shelf(shelf_id)

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.set_instance_shader_parameter("box_size", size)
	case_root.add_child(mi)
	return mi

func _build_case() -> void:
	for c in case_root.get_children():
		c.queue_free()
	var sh: Dictionary = style.get("shelf", {})
	var spec := {
		"shader": "wood",
		"color_a": sh.get("color_a", Color(0.45, 0.28, 0.14)),
		"color_b": sh.get("color_b", Color(0.30, 0.18, 0.09)),
		"roughness": sh.get("roughness", 0.55),
		"grain_scale": 1.0,
	}
	if sh.has("texture"):
		spec["albedo_tex"] = str(sh["texture"])
		spec["use_tex"] = 1.0
		spec["tex_scale"] = float(sh.get("tex_scale", 1.0))
		spec["tex_tint"] = sh.get("tint", Color.WHITE)
	var mat := Materials.from_spec(spec)
	_box(Vector3(SIDE_T, H, D), Vector3(-W / 2.0 + SIDE_T / 2.0, H / 2.0, 0), mat)
	_box(Vector3(SIDE_T, H, D), Vector3(W / 2.0 - SIDE_T / 2.0, H / 2.0, 0), mat)
	_box(Vector3(W, TOP_T, D), Vector3(0, H - TOP_T / 2.0, 0), mat)
	_box(Vector3(W - 2.0 * SIDE_T, H, BACK_T), Vector3(0, H / 2.0, -D / 2.0 + BACK_T / 2.0), mat)
	_box(Vector3(W - 2.0 * SIDE_T, PLINTH, D - 0.02), Vector3(0, PLINTH / 2.0, -0.01), mat)
	var inner_h := H - TOP_T - PLINTH
	row_h = inner_h / ROWS
	rows_y.clear()
	for r in ROWS:
		var band_bottom := PLINTH + r * row_h
		if r > 0:
			_box(Vector3(W - 2.0 * SIDE_T, BOARD_T, D - BACK_T - 0.01), Vector3(0, band_bottom + BOARD_T / 2.0, BACK_T / 2.0), mat)
			rows_y.append(band_bottom + BOARD_T)
		else:
			rows_y.append(band_bottom)
	# picking body
	if body == null:
		body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(W, H, D)
		cs.shape = shape
		cs.position = Vector3(0, H / 2.0, 0)
		body.add_child(cs)
		add_child(body)
	body.set_meta("shelf_id", shelf_id)

# ---------------------------------------------------------------- books

func rebuild_books(animate := true) -> void:
	refresh_data()
	var wanted := {}
	for row in shelf.get("rows", []):
		for id in row:
			wanted[id] = true
	for id in books.keys():
		if not wanted.has(id):
			books[id].kill_tween()
			books[id].queue_free()
			books.erase(id)
	for id in wanted.keys():
		var data := Library.get_book(id)
		if data.is_empty():
			continue
		if not books.has(id):
			var b3 := Book3D.new()
			b3.setup(data)
			books_root.add_child(b3)
			books[id] = b3
			b3.position = Vector3(0, H + 0.3, 0.2)
		else:
			books[id].setup(data)
	layout(animate)

func refresh_book(id: String) -> void:
	if books.has(id):
		books[id].setup(Library.get_book(id))
		layout(true)

func z_for(b3: Book3D) -> float:
	if b3.face_out:
		return -D / 2.0 + BACK_T + b3.dims.x / 2.0 + 0.035
	return D / 2.0 - 0.035 - b3.dims.z / 2.0

func spine_plane_z() -> float:
	return D / 2.0 - 0.035

func inner_left() -> float:
	return -W / 2.0 + SIDE_T + PAD

func layout(animate: bool, exclude_id := "", gap_row := -1, gap_index := -1, gap_width := 0.0) -> void:
	var rows: Array = shelf.get("rows", [])
	for r in rows.size():
		var x := inner_left()
		var vis_i := 0
		for id in rows[r]:
			if id == exclude_id:
				continue
			if r == gap_row and vis_i == gap_index:
				x += gap_width + GAP
			var b3: Book3D = books.get(id)
			if b3 == null:
				continue
			var w := b3.shelf_width()
			var target := Vector3(x + w / 2.0, rows_y[r], z_for(b3))
			_move(b3, target, animate)
			x += w + GAP
			vis_i += 1

func _move(b3: Book3D, target: Vector3, animate: bool) -> void:
	b3.kill_tween()
	if animate and b3.is_inside_tree():
		b3.tween = b3.create_tween()
		b3.tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		b3.tween.tween_property(b3, "position", target, 0.22)
		b3.tween.parallel().tween_property(b3, "rotation", Vector3.ZERO, 0.22)
		b3.tween.parallel().tween_property(b3, "scale", Vector3.ONE, 0.22)
	else:
		b3.position = target
		b3.rotation = Vector3.ZERO
		b3.scale = Vector3.ONE

# ---------------------------------------------------------------- hit testing

func row_at_local_y(y: float) -> int:
	return clamp(int(floor((y - PLINTH) / row_h)), 0, ROWS - 1)

func row_top(r: int) -> float:
	return PLINTH + (r + 1) * row_h

## Insertion index (counting only non-excluded books) for a pointer at local x.
func index_at_local_x(r: int, px: float, exclude_id := "") -> int:
	var rows: Array = shelf.get("rows", [])
	if r < 0 or r >= rows.size():
		return 0
	var x := inner_left()
	var vis_i := 0
	for id in rows[r]:
		if id == exclude_id:
			continue
		var b3: Book3D = books.get(id)
		if b3 == null:
			continue
		var w := b3.shelf_width()
		if px < x + w / 2.0:
			return vis_i
		x += w + GAP
		vis_i += 1
	return vis_i

func book_at_local(px: float, py: float) -> String:
	var r := row_at_local_y(py)
	var rows: Array = shelf.get("rows", [])
	if r >= rows.size():
		return ""
	for id in rows[r]:
		var b3: Book3D = books.get(id)
		if b3 == null:
			continue
		var half := b3.shelf_width() / 2.0 + GAP
		if abs(px - b3.position.x) <= half and py >= rows_y[r] - 0.03 and py <= rows_y[r] + b3.dims.y + 0.03:
			return id
	return ""

func front_plane(z_local: float) -> Plane:
	var n := global_transform.basis.z.normalized()
	return Plane(n, to_global(Vector3(0, 0, z_local)))

func local_from_screen(cam: Camera3D, screen_pos: Vector2, z_local: float) -> Variant:
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var hit = front_plane(z_local).intersects_ray(from, dir)
	if hit == null:
		return null
	return to_local(hit)

func book_node(id: String) -> Book3D:
	return books.get(id)

func center_world() -> Vector3:
	return to_global(Vector3(0, H / 2.0, 0))

func forward_world() -> Vector3:
	return global_transform.basis.z.normalized()
