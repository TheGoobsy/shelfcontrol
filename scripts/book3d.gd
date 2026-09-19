class_name Book3D
extends Node3D
## One physical book on a shelf. Origin at the bottom centre of its footprint.

## Label pixels to metres. Every spine font size is expressed in these units.
const PIX := 0.0002

## Where each block sits along the spine, as a fraction of spine height, and how
## much of that height it may run across. Mirrors a real jacket: title in the upper
## third, author down near the foot, imprint at the very base.
const TITLE_Y := 0.64
const TITLE_RUN := 0.54
const AUTHOR_Y := 0.21
const AUTHOR_RUN := 0.26
const PUB_Y := 0.055
const PUB_RUN := 0.12

## Genres that read as contemporary non-fiction get a sans face; everything else is serif.
const SANS_KEYS := ["non-fiction", "nonfiction", "science", "technolog", "business", "self-help",
	"computer", "programming", "economic", "politic", "travel", "cook", "health", "design", "reference"]

## Printer's devices for the foot of the spine. These are generic marks, not real
## publisher logos: no catalogue serves logo artwork, and the real ones are trademarks.
## A publisher always gets the same mark, so a run of one imprint still reads as a set.
const IMPRINTS := [
	'<circle cx="32" cy="32" r="21" fill="none" stroke="#fff" stroke-width="5"/>',
	'<path d="M32 9 55 32 32 55 9 32Z" fill="none" stroke="#fff" stroke-width="5"/>',
	'<path d="M32 10 56 52H8Z" fill="#fff"/>',
	'<rect x="11" y="11" width="42" height="42" fill="none" stroke="#fff" stroke-width="5"/><circle cx="32" cy="32" r="7" fill="#fff"/>',
	'<path d="M32 8a24 24 0 100 48 19 19 0 010-48Z" fill="#fff"/>',
	'<rect x="10" y="14" width="44" height="7" fill="#fff"/><rect x="10" y="29" width="44" height="7" fill="#fff"/><rect x="10" y="44" width="44" height="7" fill="#fff"/>',
	'<path d="M32 6 38 26 58 32 38 38 32 58 26 38 6 32 26 26Z" fill="#fff"/>',
	'<ellipse cx="32" cy="32" rx="13" ry="24" fill="none" stroke="#fff" stroke-width="5"/><rect x="29" y="8" width="6" height="48" fill="#fff"/>',
]
## Words that differ between editions of the same imprint and must not split it in two.
const PUB_NOISE := ["ltd", "limited", "inc", "llc", "gmbh", "co", "company", "verlag", "books",
	"book", "publishing", "publishers", "publisher", "press", "group", "the", "and", "editions"]

static var _imprint_tex: Dictionary = {}

static var _fonts: Dictionary = {}
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
var author_label: Label3D
var pub_mark: Sprite3D
var cover_label: Label3D
var _has_cover := false

static func _font(path := "res://fonts/NotoSans-Bold.ttf") -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]

static func _pages() -> StandardMaterial3D:
	if _pages_mat == null:
		_pages_mat = Materials.std(Color(0.93, 0.89, 0.80), 0.95)
	return _pages_mat

## Strips edition noise so "Tor" and "Tor Books", or "Hodder Paperback" and
## "Hodder & Stoughton Ltd", land on the same mark.
static func _pub_key(pub: String) -> String:
	var out := ""
	for word in pub.to_lower().replace("&", " ").replace(",", " ").replace(".", " ").split(" ", false):
		var w := str(word).strip_edges()
		if w == "" or PUB_NOISE.has(w):
			continue
		out += w
	return out

## Rasterised once and shared by every book, so a shelf costs one texture per mark.
static func _imprint(idx: int) -> Texture2D:
	if not _imprint_tex.has(idx):
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>' % IMPRINTS[idx]
		var img := Image.new()
		if img.load_svg_from_string(svg, 1.0) != OK:
			return null
		_imprint_tex[idx] = ImageTexture.create_from_image(img)
	return _imprint_tex[idx]

## Serif unless the genres say contemporary non-fiction.
static func _serif(b: Dictionary) -> bool:
	for g in b.get("genres", []):
		var s := str(g).to_lower()
		for k in SANS_KEYS:
			if s.find(k) != -1:
				return false
	return true

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
		author_label = Label3D.new()
		body.add_child(author_label)
		pub_mark = Sprite3D.new()
		body.add_child(pub_mark)
		cover_quad = MeshInstance3D.new()
		body.add_child(cover_quad)
		cover_label = Label3D.new()
		body.add_child(cover_label)
	mesh_inst.mesh = BookMesh.get_mesh(dims.x, dims.y, dims.z)
	_apply_body_material(false)

	var light_spine := color.get_luminance() > 0.5
	var text_col := Color(0.12, 0.09, 0.06) if light_spine else Color(0.96, 0.92, 0.82)
	# Stamped foil: deep bronze pressed into a pale cloth, warm gold onto a dark one.
	var foil := Color(0.30, 0.20, 0.06) if light_spine else Color(0.92, 0.76, 0.42)
	# Warm gold on a warm spine goes muddy, so force the two apart when they sit too close.
	if absf(foil.get_luminance() - color.get_luminance()) < 0.34:
		foil = foil.darkened(0.45) if light_spine else foil.lightened(0.5)
	var alpha := 0.6 if ghost else 1.0

	var serif := _serif(b)
	var title_font := _font("res://fonts/NotoSerif-Bold.ttf" if serif else "res://fonts/NotoSans-Bold.ttf")
	var body_font := _font("res://fonts/NotoSerif-Regular.ttf" if serif else "res://fonts/NotoSans-Regular.ttf")

	_layout_spine(b, title_font, body_font, foil, text_col, alpha)

	# front cover
	var q := QuadMesh.new()
	q.size = Vector2(dims.z * 0.97, dims.y * 0.97)
	cover_quad.mesh = q
	cover_quad.position = Vector3(dims.x / 2.0 + 0.0007, dims.y / 2.0, 0)
	cover_quad.rotation = Vector3(0, PI / 2.0, 0)
	cover_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	cover_label.font = title_font
	cover_label.pixel_size = PIX
	cover_label.font_size = 70
	cover_label.text = str(b.get("title", ""))
	cover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cover_label.width = dims.z * 0.85 / cover_label.pixel_size
	cover_label.modulate = Color(text_col, alpha)
	cover_label.position = Vector3(dims.x / 2.0 + 0.0008, dims.y * 0.62, 0)
	cover_label.rotation = Vector3(0, PI / 2.0, 0)
	cover_label.alpha_cut = Label3D.ALPHA_CUT_DISABLED if ghost else Label3D.ALPHA_CUT_DISCARD
	cover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_label.render_priority = 1

	_apply_orientation()
	refresh_cover()

## Lays out title, author and imprint along the spine, sizing each to fit rather
## than cutting it short. Titles wrap to two lines once the spine is thick enough.
func _layout_spine(b: Dictionary, title_font: Font, body_font: Font, foil: Color, text_col: Color, alpha: float) -> void:
	var spin := -PI / 2.0 if Settings.get_value("spine_top_down") else PI / 2.0
	var z := dims.z / 2.0 + 0.0007

	# --- title ---
	var title := str(b.get("title", "")).strip_edges()
	var run := dims.y * TITLE_RUN
	var want := int(clamp(dims.x * 0.52, 0.0075, 0.018) / PIX)
	var size := mini(want, _fit_size(title_font, title, run, 1))
	var two := false
	# Only break to two lines when one line would squash the type and the spine can take it.
	if size < int(want * 0.72) and dims.x >= 0.019:
		var want2 := int(clamp(dims.x * 0.30, 0.006, 0.011) / PIX)
		var size2 := mini(want2, _fit_size(title_font, title, run, 2))
		if size2 > size:
			size = size2
			two = true
	size = maxi(size, 16)

	label.font = title_font
	label.pixel_size = PIX
	label.font_size = size
	label.text = _ellipsize(title_font, title, size, run * (2.0 if two else 1.0) * 0.96)
	label.width = run / PIX
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if two else TextServer.AUTOWRAP_OFF
	label.modulate = Color(foil, alpha)
	# Left unshaded on purpose: a lit label goes too dark to read inside a shelf,
	# and reading spines is the whole point. The foil reads through colour instead.
	label.shaded = false
	# A thin dark rim reads as type pressed into the cloth. Any heavier and it turns furry.
	label.outline_size = maxi(int(size * 0.03), 1)
	label.outline_modulate = Color(Color(0.05, 0.03, 0.02), alpha * 0.45)
	label.position = Vector3(0, dims.y * TITLE_Y, z)
	label.rotation = Vector3(0, 0, spin)
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED if ghost else Label3D.ALPHA_CUT_DISCARD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.render_priority = 1

	# --- author, near the foot ---
	var author := ""
	var authors: Array = b.get("authors", [])
	if authors.size() > 0:
		author = str(authors[0]).strip_edges()
	var a_run := dims.y * AUTHOR_RUN
	var a_want := maxi(int(size * 0.62), 24)
	var full_fit := _fit_size(body_font, author, a_run, 1)
	var a_size := mini(a_want, full_fit)
	# A long full name shrinks to mush. Real jackets drop to the surname instead.
	# Compare the raw fits, not the floored sizes, or the floor hides the overflow.
	if full_fit < a_want and author.find(" ") != -1:
		var surname := author.substr(author.rfind(" ") + 1)
		var s_fit := _fit_size(body_font, surname, a_run, 1)
		if s_fit > full_fit:
			author = surname
			a_size = mini(a_want, s_fit)
	a_size = maxi(a_size, 15)
	# Nothing on a real spine ends in an ellipsis, so if the floor still overruns the
	# block, shed the forenames before letting it clip.
	if author.find(" ") != -1 and _clips(body_font, author, a_size, a_run * 0.96):
		var last := author.substr(author.rfind(" ") + 1)
		if not _clips(body_font, last, a_size, a_run * 0.96):
			author = last

	author_label.font = body_font
	author_label.pixel_size = PIX
	author_label.font_size = a_size
	author_label.text = _ellipsize(body_font, author, a_size, a_run * 0.96)
	author_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	author_label.modulate = Color(text_col, alpha * 0.92)
	author_label.outline_size = 0
	author_label.position = Vector3(0, dims.y * AUTHOR_Y, z)
	author_label.rotation = Vector3(0, 0, spin)
	author_label.alpha_cut = Label3D.ALPHA_CUT_DISABLED if ghost else Label3D.ALPHA_CUT_DISCARD
	author_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	author_label.render_priority = 1
	author_label.visible = author != ""

	# --- imprint device at the base, only where there is room for it ---
	var key := _pub_key(str(b.get("publisher", "")))
	var show_pub := key != "" and dims.x >= 0.013
	if show_pub:
		var tex := _imprint(absi(hash(key)) % IMPRINTS.size())
		show_pub = tex != null
		if tex != null:
			# Sized off the spine thickness, since that is the narrow axis it has to sit in.
			var mark: float = minf(dims.x * 0.52, dims.y * PUB_RUN * 0.8)
			pub_mark.texture = tex
			pub_mark.pixel_size = mark / float(tex.get_height())
			pub_mark.modulate = Color(text_col, alpha * 0.6)
			pub_mark.position = Vector3(0, dims.y * PUB_Y, z)
			pub_mark.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if ghost else SpriteBase3D.ALPHA_CUT_DISCARD
			pub_mark.render_priority = 1
	pub_mark.visible = show_pub

## Largest font size at which `text` fits `lines` rows inside `avail` metres.
func _fit_size(f: Font, text: String, avail: float, lines: int) -> int:
	if text.strip_edges() == "":
		return 999
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	if w <= 0.0:
		return 999
	# Must stay inside the same margin the clip check uses, or a size that "fits" here
	# still gets ellipsized there. Wrapping never splits a title exactly in half, so the
	# two-line case gets extra slack on top.
	var budget := avail * float(lines) * (0.90 if lines > 1 else 0.95)
	return int(budget / (w * PIX) * 100.0)

## True when `text` at `size` overruns `avail` metres on one line.
func _clips(f: Font, text: String, size: int, avail: float) -> bool:
	if text == "":
		return false
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * PIX > avail

## Last resort once the type is already at its floor.
func _ellipsize(f: Font, text: String, size: int, avail: float) -> String:
	if text == "":
		return text
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * PIX <= avail:
		return text
	var out := text
	while out.length() > 1:
		out = out.substr(0, out.length() - 1)
		if f.get_string_size(out + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * PIX <= avail:
			return out.strip_edges() + "…"
	return out

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
