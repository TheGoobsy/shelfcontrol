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
## Preview case shown while choosing a spot: see-through, no books, no plants, no picking.
var is_ghost := false
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

## Builds just the case, see-through, for the placement preview.
func setup_ghost(st: Dictionary) -> void:
	is_ghost = true
	shelf = {"id": "", "rows": []}
	shelf_id = ""
	style = st
	if case_root == null:
		case_root = Node3D.new()
		add_child(case_root)
	_build_case()

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
	var mat: Material = Materials.shelf_wood(style)
	if is_ghost:
		mat = Materials.ghost(Color(0.55, 0.78, 1.0), 0.40)
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
	if is_ghost:
		return
	_build_name_tag()
	_build_top_plants()
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

## Optional name plate screwed to the front of the top board, carrying the shelf's name.
## Off by default; the look comes from Library.TAG_STYLES.
func _build_name_tag() -> void:
	if not bool(shelf.get("tag_on", false)):
		return
	var title := str(shelf.get("name", "")).strip_edges()
	if title == "":
		return
	var spec: Dictionary = Library.TAG_STYLES[Library.shelf_tag_style(shelf)]
	var plate_w: float = minf(W * 0.46, 0.40)
	var plate_h := 0.055
	var y := H - TOP_T - plate_h / 2.0 - 0.006
	var z := D / 2.0 + 0.004
	var plate := Materials.std(Color.html(str(spec["plate"])), float(spec["rough"]), float(spec["metallic"]))
	_box(Vector3(plate_w, plate_h, 0.008), Vector3(0, y, z), plate)
	var lbl := Label3D.new()
	lbl.font = Book3D._font("res://fonts/NotoSerif-Bold.ttf" if bool(spec["serif"]) else "res://fonts/NotoSans-Bold.ttf")
	lbl.pixel_size = 0.0002
	# Shrunk to fit the plate rather than spilling off its ends.
	var want := int(plate_h * 0.52 / lbl.pixel_size)
	var w100 := lbl.font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	if w100 > 0.0:
		want = mini(want, int(plate_w * 0.86 / (w100 * lbl.pixel_size) * 100.0))
	lbl.font_size = maxi(want, 14)
	lbl.text = title
	lbl.modulate = Color.html(str(spec["ink"]))
	lbl.position = Vector3(0, y, z + 0.005)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lbl.render_priority = 2
	case_root.add_child(lbl)

## One or two potted plants stand on top of the case. The seed comes from the shelf id,
## so a shelf keeps the same plants in the same spots across rebuilds and sessions.
func _build_top_plants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(shelf_id + "|top")
	var spots := [-0.32, 0.0, 0.32]
	for i in spots.size():
		var j := rng.randi_range(i, spots.size() - 1)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var count := 1 if rng.randf() < 0.55 else 2
	for i in count:
		var kind := rng.randi() % 3
		var z := rng.randf_range(-0.03, 0.03)
		var yaw := rng.randf() * TAU
		var face := 0.0
		if kind == 1:
			# Trailing ivy: stand it near the front edge facing the room, so the vines
			# spill down in front of the case instead of through the top board. Its
			# facing goes into the fan, not onto the node, so the vines know which way
			# the edge actually is.
			z = D / 2.0 - 0.085
			yaw = 0.0
			face = rng.randf_range(-0.3, 0.3)
		var scl := rng.randf_range(0.92, 1.18)
		# Clearance is in the plant's own space, so undo the scale it is about to get.
		var p := Decor.shelf_plant(style, rng, kind, (D / 2.0 - z) / scl, face)
		case_root.add_child(p)
		p.position = Vector3(float(spots[i]) + rng.randf_range(-0.05, 0.05), H, z)
		p.rotation.y = yaw
		p.scale = Vector3.ONE * scl

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

## Hands a book node to the caller and forgets it, so the next rebuild will not free it.
## Used for the flight into the tray, which outlives the book's place on the shelf.
func release_node(id: String) -> Book3D:
	var b: Book3D = books.get(id)
	if b == null:
		return null
	b.kill_tween()
	books.erase(id)
	return b

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
