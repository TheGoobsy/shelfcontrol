class_name Furniture
## Catalogue of everything a room can be furnished with, and how to build one piece.
##
## A room keeps its furnishing as a plain list, so every piece is something the reader put
## there rather than something a "room type" decided for them. One entry looks like:
##
##   {"id": "f_…", "kind": "armchair", "x": 1.75, "z": 1.25, "rot": 0.4}
##
## Wall-anchored kinds (fireplace, window, a shield) carry {"wall", "slot"} instead of a
## position, because they share the wall slots with the bookcases. Ceiling kinds keep x/z
## and hang from the ceiling height.
##
## Footprints are not written down anywhere: a piece is built and measured, so the box the
## editor tests against is the furniture's real extent, models included.

## Where a kind lives. Floor pieces stand on the floor and take floor space, wall pieces
## take a wall slot, ceiling pieces hang and take no floor.
const FLOOR := "floor"
const WALL := "wall"
const CEILING := "ceiling"

## Category order as the inventory shows it. [id, label].
const CATEGORIES := [
	["functional", "Functional"],
	["seating", "Seating"],
	["tables", "Tables"],
	["lighting", "Lighting"],
	["plants", "Plants"],
	["decor", "Decor"],
	["wall", "Walls"],
]

## kind -> {name, cat, anchor, model?, scale?, light?}
## "model" names a glTF under models/<set>/; everything else is built by Decor.
const CATALOG := {
	# ---- functional: these hold books, so a room without them cannot show its reading pile
	"reading_table": {"name": "Reading table", "cat": "functional", "anchor": FLOOR, "unique": true},
	"archive_box": {"name": "Archive box", "cat": "functional", "anchor": FLOOR, "unique": true},

	# ---- seating
	"armchair": {"name": "Armchair", "cat": "seating", "anchor": FLOOR},
	"office_chair": {"name": "Swivel chair", "cat": "seating", "anchor": FLOOR},
	"bed": {"name": "Bed", "cat": "seating", "anchor": FLOOR},
	"gothic_chair": {"name": "Gothic chair", "cat": "seating", "anchor": FLOOR, "model": "GreenChair_01"},

	# ---- tables
	"side_table": {"name": "Side table", "cat": "tables", "anchor": FLOOR},
	"desk": {"name": "Writing desk", "cat": "tables", "anchor": FLOOR},
	"nightstand": {"name": "Nightstand", "cat": "tables", "anchor": FLOOR},
	"lectern": {"name": "Lectern", "cat": "tables", "anchor": FLOOR},
	"coffee_table": {"name": "Gothic table", "cat": "tables", "anchor": FLOOR, "model": "gothic_coffee_table", "scale": 0.75},
	"crate": {"name": "Crate", "cat": "tables", "anchor": FLOOR, "model": "wooden_crate_01"},
	"chest": {"name": "Treasure chest", "cat": "tables", "anchor": FLOOR, "model": "treasure_chest"},

	# ---- lighting
	"floor_lamp": {"name": "Floor lamp", "cat": "lighting", "anchor": FLOOR},
	"candelabra": {"name": "Candelabra", "cat": "lighting", "anchor": FLOOR},
	"candle": {"name": "Candle", "cat": "lighting", "anchor": FLOOR},
	"candle_trio": {"name": "Three candles", "cat": "lighting", "anchor": FLOOR},
	"pendant": {"name": "Pendant lamp", "cat": "lighting", "anchor": CEILING},
	"chandelier": {"name": "Candle chandelier", "cat": "lighting", "anchor": CEILING},
	"lantern": {"name": "Lantern chandelier", "cat": "lighting", "anchor": CEILING,
		"model": "lantern_chandelier_01", "light": Vector3(0, 0.3, 0), "energy": 1.3, "range": 9.0, "shadows": true},

	# ---- plants
	"plant": {"name": "Potted plant", "cat": "plants", "anchor": FLOOR},
	"potted_plant": {"name": "Leafy plant", "cat": "plants", "anchor": FLOOR, "model": "potted_plant_01"},
	"fern": {"name": "Fern", "cat": "plants", "anchor": FLOOR, "model": "fern_02", "scale": 0.6},

	# ---- decor
	"rug": {"name": "Rug", "cat": "decor", "anchor": FLOOR, "flat": true},
	"cat": {"name": "Cat", "cat": "decor", "anchor": FLOOR, "flat": true},
	"globe": {"name": "Globe", "cat": "decor", "anchor": FLOOR},
	"crystal_ball": {"name": "Crystal ball", "cat": "decor", "anchor": FLOOR},
	"statue": {"name": "Gothic statue", "cat": "decor", "anchor": FLOOR, "model": "gothic_statue", "scale": 0.65},

	# ---- wall slots
	"fireplace": {"name": "Fireplace", "cat": "wall", "anchor": WALL, "depth": 0.5, "unique": true},
	"window": {"name": "Window", "cat": "wall", "anchor": WALL, "depth": 0.1, "unique": true},
	"shield": {"name": "Kite shield", "cat": "wall", "anchor": WALL, "depth": 0.06, "y": 0.9, "model": "kite_shield"},
}

## Pieces a brand new room starts with. Everything else the reader places themselves.
const STARTER := [
	{"kind": "reading_table", "x": 0.35, "z": 0.15, "rot": 0.12},
	{"kind": "archive_box", "x": -1.9, "z": 2.5, "rot": 0.0},
]

static func has_kind(kind: String) -> bool:
	return CATALOG.has(kind)

static func spec(kind: String) -> Dictionary:
	return CATALOG.get(kind, {})

static func display_name(kind: String) -> String:
	return str(CATALOG.get(kind, {}).get("name", kind.capitalize()))

static func anchor(kind: String) -> String:
	return str(CATALOG.get(kind, {}).get("anchor", FLOOR))

## Kinds in a category, in catalogue order.
static func in_category(cat: String) -> Array:
	var out: Array = []
	for kind in CATALOG:
		if str(CATALOG[kind]["cat"]) == cat:
			out.append(kind)
	return out

## Every piece looks the same each time the room is rebuilt, so the randomised builders
## get an rng seeded from the piece's own id rather than a fresh one.
static func _rng(entry: Dictionary) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(entry.get("id", entry.get("kind", ""))))
	return rng

## Builds one piece for a style, or null if the kind is unknown or a model is missing.
## The node's origin sits on the floor at the piece's centre, ready to be positioned.
static func build(entry: Dictionary, style: Dictionary) -> Node3D:
	var kind := str(entry.get("kind", ""))
	var sp: Dictionary = CATALOG.get(kind, {})
	if sp.is_empty():
		return null
	var rng := _rng(entry)
	if sp.has("model"):
		var n := Decor.model(str(sp.get("set", "keep")), str(sp["model"]), float(sp.get("scale", 1.0)))
		if n != null and sp.has("light"):
			Decor.attach_light(n, sp["light"], style.get("lamp", Color(1, 0.75, 0.45)),
				float(sp.get("energy", 1.2)) * float(style.get("lamp_energy", 2.0)) / 2.0,
				float(sp.get("range", 4.0)), bool(sp.get("shadows", false)))
		return n
	match kind:
		"reading_table": return Decor.reading_table(style)
		"archive_box": return Decor.archive_box(style)
		"armchair": return Decor.armchair(style)
		"office_chair": return Decor.office_chair(style)
		"bed": return Decor.bed(style)
		"side_table": return Decor.side_table(style, rng)
		"desk": return Decor.desk(style)
		"nightstand": return Decor.nightstand(style)
		"lectern": return Decor.lectern(style)
		"floor_lamp": return Decor.floor_lamp(style)
		"candelabra": return Decor.candelabra(style)
		"candle": return Decor.candle(style)
		"candle_trio": return Decor.candle_trio(style)
		"pendant": return Decor.pendant(style)
		"chandelier": return Decor.chandelier(style)
		"plant": return Decor.plant(style, rng)
		"rug": return Decor.rug(style)
		"cat": return Decor.cat(style)
		"globe": return Decor.globe(style)
		"crystal_ball": return Decor.crystal_ball(style)
		"fireplace": return Decor.fireplace(style)
		"window": return Decor.window(style)
	return null

## The floor box a built piece occupies, in its own local space. Measured from the meshes,
## so a model is as big as it really is. Flat pieces (rug, cat) return an empty box: they are
## walked over rather than bumped into, so nothing should be blocked from standing on them.
##
## `node` must still be standing at the origin, untouched: the measurement starts from the
## node's own transform, so a piece already moved into place would measure its move twice.
static func footprint(node: Node3D, kind: String) -> Rect2:
	if node == null or bool(CATALOG.get(kind, {}).get("flat", false)):
		return Rect2()
	var box := Decor.model_aabb(node)
	if box.size.x <= 0.0 and box.size.z <= 0.0:
		return Rect2()
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

## The measured box whatever the kind, used for picking a piece up: a rug blocks nothing
## but still has to be tappable.
static func raw_footprint(node: Node3D) -> Rect2:
	if node == null:
		return Rect2()
	var box := Decor.model_aabb(node)
	if box.size.x <= 0.0 and box.size.z <= 0.0:
		return Rect2()
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

## A footprint turned by `rot` and moved to (x, z), as the axis-aligned box that contains it.
## Furniture keeps its own angle, but the editor reserves the containing box, which is the
## honest thing to test against when two pieces are turned differently.
static func world_rect(local: Rect2, x: float, z: float, rot: float) -> Rect2:
	if local.size == Vector2.ZERO:
		return Rect2()
	var c := local.get_center()
	var h := local.size / 2.0
	var s := absf(sin(rot))
	var co := absf(cos(rot))
	var ext := Vector2(h.x * co + h.y * s, h.x * s + h.y * co)
	# the centre travels with the piece: rotate it the way Node3D.rotation.y turns a point
	var turned := Vector2(c.x * cos(rot) + c.y * sin(rot), -c.x * sin(rot) + c.y * cos(rot))
	return Rect2(Vector2(x, z) + turned - ext, ext * 2.0)

## A new entry for `kind` at a spot, with a fresh id.
static func make(kind: String, x: float, z: float, rot := 0.0) -> Dictionary:
	return {"id": _new_id(), "kind": kind, "x": snappedf(x, 0.001), "z": snappedf(z, 0.001), "rot": snappedf(rot, 0.001)}

static func make_wall(kind: String, wall: int, slot: int) -> Dictionary:
	return {"id": _new_id(), "kind": kind, "wall": wall, "slot": slot}

## Ids are a run prefix plus a serial rather than a roll of the dice, because a piece's
## look is derived from its id: which of the three potted plants you get, how a side table
## is proportioned. The demo library sets the prefix to a fixed word, so a screenshot taken
## twice shows the same room and a change to the code is the only thing that can move it.
static var id_prefix := ""
static var _serial := 0

static func _new_id() -> String:
	if id_prefix == "":
		id_prefix = "%x" % (int(Time.get_unix_time_from_system()) & 0xffffff)
	_serial += 1
	return "f_%s_%03x" % [id_prefix, _serial]

# ---------------------------------------------------------------- seeding an old room

## Turns a style's (or an old room type's) decor list into explicit furniture entries, using
## the positions the room used to lay out by hand. Only ever run once, when a room saved
## before the editor is loaded: from then on the list is the reader's to change.
const PLANT_CORNERS := [Vector3(-3.05, 0, -2.05), Vector3(3.05, 0, -2.05), Vector3(-3.05, 0, 2.1), Vector3(3.1, 0, 2.5)]
const CANDLE_SPOTS := [Vector3(-2.3, 0, 1.9), Vector3(2.3, 0, 1.9), Vector3(0, 0, -2.2)]

## Fixed spots for the kinds the old layout code hard-coded. [x, z, rot].
const SEED_SPOTS := {
	"armchair": [1.75, 1.25, 0.0],
	"side_table": [2.55, 1.05, 0.0],
	"floor_lamp": [2.75, 2.15, 0.0],
	"pendant": [0.0, 0.3, 0.0],
	"chandelier": [0.0, 0.3, 0.0],
	"cat": [-0.75, 0.85, 2.4],
	"rug": [0.0, 0.3, 0.0],
	"globe": [-2.55, 1.9, 0.0],
	"desk": [1.7, 1.15, 0.0],
	"office_chair": [1.75, 1.95, PI + 0.25],
	"bed": [-1.9, 1.75, 0.0],
	"nightstand": [-0.95, 2.5, 0.0],
	"lectern": [1.6, -1.1, -0.5],
	"crystal_ball": [-1.7, -1.2, 0.0],
}

## `decor` is a style's or an old room type's list; entries are kind strings or the model
## dictionaries the Medieval Keep style uses.
static func seed_from_decor(decor: Array, room: Dictionary) -> Array:
	var out: Array = []
	var plant_i := 0
	var candle_i := 0
	var has_fireplace := false
	for d in decor:
		if d is Dictionary:
			var me := _seed_model(d)
			if not me.is_empty():
				out.append(me)
			continue
		var kind := str(d)
		match kind:
			"fireplace":
				var cs: int = Styles.center_slot(2)
				if cs >= 0 and _slot_open(room, 2, cs, out):
					out.append(make_wall("fireplace", 2, cs))
					has_fireplace = true
			"window":
				var ww: int = Styles.window_wall(room)
				var cs: int = Styles.center_slot(ww) if ww >= 0 else -1
				if cs >= 0 and _slot_open(room, ww, cs, out):
					out.append(make_wall("window", ww, cs))
			"plant":
				if plant_i < PLANT_CORNERS.size():
					var p: Vector3 = PLANT_CORNERS[plant_i]
					var e := make("plant", p.x, p.z)
					# the old builder turned each plant by a room-seeded roll; any angle does
					e["rot"] = snappedf(float(plant_i) * 1.7, 0.001)
					out.append(e)
					plant_i += 1
			"candelabra":
				if candle_i < CANDLE_SPOTS.size():
					var p: Vector3 = CANDLE_SPOTS[candle_i]
					out.append(make("candelabra", p.x, p.z))
					candle_i += 1
			_:
				if SEED_SPOTS.has(kind):
					var s: Array = SEED_SPOTS[kind]
					out.append(make(kind, s[0], s[1], s[2]))
	# the armchair used to turn towards the fire, or to the middle of the room without one
	for e in out:
		if str(e["kind"]) == "armchair":
			var target := Vector3(0, 0, Styles.ROOM_D / 2.0) if has_fireplace else Vector3(0, 0, -1.0)
			var dir := target - Vector3(float(e["x"]), 0, float(e["z"]))
			e["rot"] = snappedf(atan2(dir.x, dir.z), 0.001)
	return out

## Model entries in an old decor list: {"model": …, "pos": Vector3, "rot": …} or {"prop": …}.
static func _seed_model(d: Dictionary) -> Dictionary:
	var pos: Vector3 = d.get("pos", Vector3.ZERO)
	var kind := ""
	if d.has("prop"):
		kind = str(d["prop"])
	else:
		# find the catalogue kind that wraps this model
		for k in CATALOG:
			if str(CATALOG[k].get("model", "")) == str(d.get("model", "")):
				kind = k
				break
	if kind == "" or not CATALOG.has(kind):
		return {}
	if anchor(kind) == WALL:
		# the shield hung on the south wall; put it on the nearest slot there
		return make_wall(kind, 2, maxi(Styles.center_slot(2), 0))
	var e := make(kind, pos.x, pos.z, float(d.get("rot", 0.0)))
	if pos.y > 0.01:
		# a candle that stood on a crate keeps its height rather than dropping to the floor
		e["y"] = snappedf(pos.y, 0.001)
	return e

## Wall slots are shared with the bookcases and the doors, so a piece only seeds onto one
## that is still free. A shelf already standing where the style wanted its fireplace wins.
static func _slot_open(room: Dictionary, wall: int, slot: int, placed: Array) -> bool:
	for s in room.get("shelves", []):
		if int(s["wall"]) == wall and int(s["slot"]) == slot:
			return false
	for d in room.get("doors", []):
		if int(d["wall"]) == wall and int(d["slot"]) == slot:
			return false
	for e in placed:
		if e.has("wall") and int(e["wall"]) == wall and int(e["slot"]) == slot:
			return false
	return true

## The decor lists rooms were furnished from before the editor: a room type's set, or the
## style's own when it was a living room. Kept only to seed a room saved back then.
const LEGACY_ROOM_DECOR := {
	"office": ["window", "desk", "office_chair", "plant", "plant", "globe", "pendant", "cat"],
	"bedroom": ["window", "bed", "nightstand", "rug", "cat", "plant", "pendant"],
	"fantasy": ["fireplace", "rug", "cat", "candelabra", "candelabra", "lectern", "crystal_ball", "chandelier", "globe", "plant"],
}

static func legacy_decor(room: Dictionary, style: Dictionary) -> Array:
	var t := str(room.get("type", "living"))
	if LEGACY_ROOM_DECOR.has(t):
		return LEGACY_ROOM_DECOR[t]
	return style.get("decor", [])

## Refurnishes a room from one of those old arrangements: the demo library and the
## screenshot harness use it to get a furnished room without tapping through the editor.
## The functional pieces already in the room are kept, since they hold books.
static func legacy_arrangement(legacy_type: String, room: Dictionary, style: Dictionary) -> Array:
	var out: Array = seed_from_decor(legacy_decor({"type": legacy_type}, style), room)
	for e in room.get("furniture", []):
		if str(spec(str(e.get("kind", ""))).get("cat", "")) == "functional":
			out.append(e)
	return out
