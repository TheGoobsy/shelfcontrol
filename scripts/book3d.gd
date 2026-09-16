class_name Book3D
extends Node3D
## One physical book on a shelf. Origin at the bottom centre of its footprint.

static var spine_font: Font
static var _pages_mat: StandardMaterial3D

var book_id := ""
var book: Dictionary = {}
var dims := Vector3(0.03, 0.2, 0.14)  # thickness, height, cover width
var face_out := false
var color := Color.WHITE
var tween: Tween
## flat = lying cover-up on the reading table (always shows the cover, never ghosted).
var flat := false
## ghost = the physical copy is on the reading table; the shelf copy is drawn translucent.
var ghost := false

var body: Node3D
var mesh_inst: MeshInstance3D
var cover_quad: MeshInstance3D
var label: Label3D
var cover_label: Label3D
var _has_cover := false

static func _font() -> Font:
	if spine_font == null:
		spine_font = load("res://fonts/NotoSans-Bold.ttf")
	return spine_font

static func _pages() -> StandardMaterial3D:
	if _pages_mat == null:
		_pages_mat = Materials.std(Color(0.93, 0.89, 0.80), 0.95)
	return _pages_mat

func setup(b: Dictionary) -> void:
	book = b
	book_id = str(b["id"])
	dims = Vector3(float(b.get("thickness", 0.03)), float(b.get("height", 0.2)), float(b.get("width", 0.14)))
	face_out = bool(b.get("face_out", false)) and not flat
	ghost = not flat and str(b.get("status", "")) == "currently-reading"
	color = Color.html(str(b.get("color", "#555555")))
	if body == null:
		body = Node3D.new()
		add_child(body)
		mesh_inst = MeshInstance3D.new()
		body.add_child(mesh_inst)
		label = Label3D.new()
		body.add_child(label)
		cover_quad = MeshInstance3D.new()
		body.add_child(cover_quad)
		cover_label = Label3D.new()
		body.add_child(cover_label)
	mesh_inst.mesh = BookMesh.get_mesh(dims.x, dims.y, dims.z)
	_apply_body_material(false)

	var dark := color.get_luminance() > 0.5
	var text_col := Color(0.12, 0.09, 0.06) if dark else Color(0.96, 0.92, 0.82)

	# spine label
	var em: float = clamp(dims.x * 0.5, 0.008, 0.019)
	label.font = _font()
	label.pixel_size = 0.0002
	label.font_size = int(em / label.pixel_size)
	label.text = _fit_title(str(b.get("title", "")), em)
	label.modulate = Color(text_col, 0.6 if ghost else 1.0)
	label.outline_size = 0
	label.position = Vector3(0, dims.y / 2.0, dims.z / 2.0 + 0.0007)
	label.rotation = Vector3(0, 0, -PI / 2.0 if Settings.get_value("spine_top_down") else PI / 2.0)
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED if ghost else Label3D.ALPHA_CUT_DISCARD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.render_priority = 1

	# front cover
	var q := QuadMesh.new()
	q.size = Vector2(dims.z * 0.97, dims.y * 0.97)
	cover_quad.mesh = q
	cover_quad.position = Vector3(dims.x / 2.0 + 0.0007, dims.y / 2.0, 0)
	cover_quad.rotation = Vector3(0, PI / 2.0, 0)
	cover_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	cover_label.font = _font()
	cover_label.pixel_size = 0.0002
	cover_label.font_size = 70
	cover_label.text = str(b.get("title", ""))
	cover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cover_label.width = dims.z * 0.85 / cover_label.pixel_size
	cover_label.modulate = Color(text_col, 0.6 if ghost else 1.0)
	cover_label.position = Vector3(dims.x / 2.0 + 0.0008, dims.y * 0.62, 0)
	cover_label.rotation = Vector3(0, PI / 2.0, 0)
	cover_label.alpha_cut = Label3D.ALPHA_CUT_DISABLED if ghost else Label3D.ALPHA_CUT_DISCARD
	cover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_label.render_priority = 1

	_apply_orientation()
	refresh_cover()

func _fit_title(title: String, em: float) -> String:
	var max_chars := int(dims.y * 0.86 / (em * 0.58))
	if title.length() <= max_chars:
		return title
	if max_chars < 4:
		return title.left(max(max_chars, 1))
	return title.left(max_chars - 1).strip_edges() + "…"

func _apply_orientation() -> void:
	if face_out:
		body.rotation = Vector3(-0.08, -PI / 2.0, 0)
	else:
		body.rotation = Vector3.ZERO

## Width the book occupies along the shelf.
func shelf_width() -> float:
	return dims.z if face_out else dims.x

func refresh_cover() -> void:
	var tex := BookAPI.get_cover_texture(book)
	_has_cover = tex != null
	if tex != null:
		cover_quad.set_surface_override_material(0, Materials.textured(tex, 0.65, 0.4 if ghost else 1.0))
	var show_cover := face_out or flat
	cover_quad.visible = _has_cover and show_cover
	cover_label.visible = show_cover and not _has_cover

func _apply_body_material(highlight: bool) -> void:
	if ghost:
		# frosted, pale version of the spine colour so it reads as "not really here"
		var pale := color.lerp(Color(0.85, 0.90, 1.0), 0.45)
		mesh_inst.set_surface_override_material(0, Materials.ghost(pale.lightened(0.2) if highlight else pale, 0.42))
		mesh_inst.set_surface_override_material(1, Materials.ghost(Color(0.93, 0.93, 0.98), 0.3, 0.95))
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		if highlight:
			mesh_inst.set_surface_override_material(0, Materials.std(color, 0.72, 0.0, color.lightened(0.3), 0.9))
		else:
			mesh_inst.set_surface_override_material(0, Materials.std(color, 0.72))
		mesh_inst.set_surface_override_material(1, _pages())
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func set_highlight(on: bool) -> void:
	_apply_body_material(on)

func kill_tween() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null
