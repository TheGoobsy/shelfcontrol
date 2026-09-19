class_name EditOverlay
extends Node3D
## The floor map shown while a room is being furnished.
##
## It answers one question at a glance: where can this go? The floor is tiled in green
## where a piece would fit and red where something already stands, and the ring of wall
## spots the bookcases live on is outlined on top, red where a case, a door, the window
## or the fireplace has claimed one.
##
## Everything is drawn as flat unshaded quads a finger's width above the floor, so the
## map reads the same in a dark keep and a bright Scandi room, day or night.

const CELL := 0.25          # tile size on the floor, in metres
const GAP := 0.015          # grout between tiles, so the map reads as a grid
const LIFT := 0.015         # above the floorboards, clear of z-fighting
const RING_LIFT := 0.02     # the wall ring sits over the tiles

const FREE := Color(0.26, 0.88, 0.44, 0.34)
const BLOCKED := Color(0.95, 0.20, 0.18, 0.46)
const GHOST_OK := Color(0.30, 1.0, 0.50, 0.42)
const GHOST_BAD := Color(1.0, 0.22, 0.20, 0.50)
const GHOST_LIFT := 0.03    # over both the tiles and the wall ring
const SLOT_FREE := Color(0.45, 0.95, 0.60, 0.75)
const SLOT_TAKEN := Color(1.0, 0.32, 0.28, 0.85)
const OUTLINE := 0.035      # thickness of a wall-spot outline

var _grid: MeshInstance3D
var _ring: MeshInstance3D
var _ghost: MeshInstance3D

static var _mat: StandardMaterial3D

## Unshaded and translucent: the map is information, not a surface in the room.
static func overlay_material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mat.no_depth_test = false
	return _mat

func _ready() -> void:
	_grid = _surface()
	_ring = _surface()
	_ghost = _surface()

func _surface() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = overlay_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Redraws the map. `blocked` is every floor box already spoken for, in room space.
func refresh(room: Dictionary, blocked: Array) -> void:
	_grid.mesh = _build_grid(blocked)
	_ring.mesh = _build_ring(room)

## The box of the piece currently in hand: green where it would go, red where it would
## not. Filled as well as outlined, so a piece that does not fit reads as a red slab
## rather than a thin line the furniture itself hides.
func show_ghost(r: Rect2, ok: bool) -> void:
	if r.size == Vector2.ZERO:
		_ghost.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := GHOST_OK if ok else GHOST_BAD
	_quad(st, r, GHOST_LIFT, Color(col.r, col.g, col.b, col.a * 0.55))
	_outline(st, r, GHOST_LIFT + 0.002, Color(col.r, col.g, col.b, 0.95))
	_ghost.mesh = st.commit()

func hide_ghost() -> void:
	_ghost.mesh = null

## One quad per tile, green or red depending on whether anything stands on it. A tile
## counts as taken as soon as a box touches it, so the red area is never smaller than
## what is really in the way.
func _build_grid(blocked: Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = Styles.ROOM_W
	var d: float = Styles.ROOM_D
	var nx := int(round(w / CELL))
	var nz := int(round(d / CELL))
	var cw := w / float(nx)
	var cd := d / float(nz)
	for ix in nx:
		for iz in nz:
			var x0 := -w / 2.0 + float(ix) * cw
			var z0 := -d / 2.0 + float(iz) * cd
			var cell := Rect2(x0, z0, cw, cd)
			var col := FREE
			for b in blocked:
				if (b as Rect2).intersects(cell):
					col = BLOCKED
					break
			_quad(st, Rect2(x0 + GAP / 2.0, z0 + GAP / 2.0, cw - GAP, cd - GAP), LIFT, col)
	return st.commit()

## The ring of wall spots a bookcase can stand on, outlined so the reader can see which
## of them are already spoken for without walking up to the wall.
func _build_ring(room: Dictionary) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rid := str(room.get("id", ""))
	for wall in 4:
		for slot in Styles.slot_count(wall):
			var t := Styles.shelf_transform(wall, slot)
			var along := Styles.SHELF_W
			var deep := Styles.SHELF_D
			# the transform already turns the spot to face the room, so the box is
			# measured along the wall and out from it, then squared up to the axes
			var size := Vector2(along, deep) if wall % 2 == 0 else Vector2(deep, along)
			var r := Rect2(Vector2(t.origin.x, t.origin.z) - size / 2.0, size)
			var col := SLOT_FREE if Library.is_slot_free(rid, wall, slot) else SLOT_TAKEN
			_outline(st, r, RING_LIFT, col)
	return st.commit()

## Four thin quads making the border of `r`.
func _outline(st: SurfaceTool, r: Rect2, y: float, col: Color) -> void:
	var t := OUTLINE
	_quad(st, Rect2(r.position.x, r.position.y, r.size.x, t), y, col)
	_quad(st, Rect2(r.position.x, r.end.y - t, r.size.x, t), y, col)
	_quad(st, Rect2(r.position.x, r.position.y + t, t, r.size.y - 2.0 * t), y, col)
	_quad(st, Rect2(r.end.x - t, r.position.y + t, t, r.size.y - 2.0 * t), y, col)

## A floor-flat quad. `r` is in the x/z plane; y lifts it off the floor.
static func _quad(st: SurfaceTool, r: Rect2, y: float, col: Color) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var c := Vector3(r.end.x, y, r.end.y)
	var dd := Vector3(r.position.x, y, r.end.y)
	for v in [a, b, c, a, c, dd]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
