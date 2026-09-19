extends Node
## Style catalogue + room geometry constants (autoload "Styles").

const ROOM_W := 8.0   # x extent (east-west)
const ROOM_D := 6.0   # z extent (north-south)
const ROOM_H := 3.0

const SHELF_W := 1.2
const SHELF_H := 2.2
const SHELF_D := 0.32
const SLOT_PITCH := 1.45
## Depth of the skirting board. Bookcases stand this far off the wall so the board
## runs behind them instead of cutting through the plinth.
const SKIRT_T := 0.03
const SKIRT_H := 0.1

const WALL_NAMES := ["North", "East", "South", "West"]

var styles: Dictionary = {
	"cozy_cabin": {
		"name": "Cozy Cabin",
		"blurb": "Log walls, a crackling fire and warm wood.",
		"wall": {"shader": "logs", "color_a": Color(0.60, 0.40, 0.22), "color_b": Color(0.38, 0.23, 0.12)},
		"floor": {"shader": "planks", "color_a": Color(0.46, 0.30, 0.16), "color_b": Color(0.32, 0.19, 0.10), "roughness": 0.75},
		"ceiling": {"shader": "planks", "color_a": Color(0.36, 0.23, 0.13), "color_b": Color(0.28, 0.17, 0.09), "roughness": 0.8},
		"trim": Color(0.28, 0.17, 0.09),
		"shelf": {"color_a": Color(0.30, 0.18, 0.10), "color_b": Color(0.17, 0.10, 0.06), "roughness": 0.85},
		"background": Color(0.05, 0.03, 0.02),
		"ambient": Color(1.0, 0.80, 0.58), "ambient_energy": 0.45,
		"sun": Color(1.0, 0.88, 0.70), "sun_energy": 1.3,
		"lamp": Color(1.0, 0.70, 0.40), "lamp_energy": 2.8,
		"glow": true,
		"decor": ["fireplace", "window", "rug", "cat", "plant", "plant", "armchair", "side_table", "floor_lamp", "pendant"],
		"cat_color": Color(0.82, 0.48, 0.20),
		"rug": {"field": Color(0.55, 0.22, 0.15), "border": Color(0.30, 0.11, 0.08), "accent": Color(0.85, 0.70, 0.45)},
		"fabric": Color(0.42, 0.24, 0.16),
		"pot": Color(0.62, 0.36, 0.25),
		"ui_bg": Color(0.13, 0.08, 0.05, 0.92), "ui_fg": Color(0.97, 0.92, 0.84), "ui_accent": Color(0.90, 0.58, 0.28), "ui_muted": Color(0.75, 0.66, 0.55),
	},
	"timber_lodge": {
		"name": "Timber Lodge",
		"blurb": "Photo-real logs, worn pine floor and dark hardwood shelves (textures from Poly Haven).",
		"wall": {"pbr": "res://textures/lodge/wood_trunk_wall", "tile": 1.6, "normal_scale": 0.9, "tint": Color(0.95, 0.88, 0.80)},
		"floor": {"pbr": "res://textures/lodge/wood_floor_worn", "tile": 2.2, "normal_scale": 0.6, "tint": Color(0.92, 0.84, 0.74)},
		"ceiling": {"pbr": "res://textures/lodge/brown_planks_09", "tile": 1.4, "normal_scale": 0.5, "tint": Color(0.70, 0.62, 0.55)},
		"trim": Color(0.22, 0.13, 0.08),
		"shelf": {"texture": "res://textures/lodge/dark_wood_diff.jpg", "tex_scale": 1.3, "tint": Color(0.82, 0.74, 0.68), "color_a": Color(0.30, 0.18, 0.10), "color_b": Color(0.17, 0.10, 0.06), "roughness": 0.8},
		"background": Color(0.04, 0.03, 0.02),
		"ambient": Color(1.0, 0.84, 0.66), "ambient_energy": 0.5,
		"sun": Color(1.0, 0.90, 0.74), "sun_energy": 1.4,
		"lamp": Color(1.0, 0.72, 0.42), "lamp_energy": 2.8,
		"glow": true,
		"decor": ["fireplace", "window", "rug", "cat", "plant", "plant", "armchair", "side_table", "floor_lamp", "pendant"],
		"cat_color": Color(0.35, 0.30, 0.28),
		"rug": {"field": Color(0.36, 0.16, 0.12), "border": Color(0.20, 0.09, 0.07), "accent": Color(0.78, 0.64, 0.42)},
		"fabric": Color(0.30, 0.22, 0.18),
		"fabric_spec": {"pbr": "res://textures/lodge/brown_leather", "tile": 0.45, "normal_scale": 0.9, "tint": Color(0.70, 0.60, 0.54), "roughness": 1.0},
		"pot": Color(0.45, 0.30, 0.22),
		"ui_bg": Color(0.11, 0.07, 0.05, 0.92), "ui_fg": Color(0.96, 0.91, 0.83), "ui_accent": Color(0.86, 0.55, 0.26), "ui_muted": Color(0.72, 0.64, 0.54),
	},
	"castle_keep": {
		"name": "Medieval Keep",
		"blurb": "Stone walls, slate floor, gothic chairs, candles and a treasure chest (Poly Haven models).",
		"wall": {"pbr": "res://textures/keep/castle_wall_slates", "tile": 2.5, "normal_scale": 0.9, "tint": Color(0.86, 0.82, 0.76)},
		"floor": {"pbr": "res://textures/keep/slate_floor_02", "tile": 2.0, "normal_scale": 0.7, "tint": Color(0.80, 0.78, 0.76)},
		"ceiling": {"pbr": "res://textures/keep/medieval_wood", "tile": 2.0, "normal_scale": 0.6, "tint": Color(0.62, 0.55, 0.48)},
		"trim": Color(0.20, 0.14, 0.10),
		"shelf": {"texture": "res://textures/keep/dark_wooden_planks_diff.jpg", "tex_scale": 2.0, "tint": Color(0.80, 0.74, 0.68), "color_a": Color(0.28, 0.18, 0.11), "color_b": Color(0.16, 0.10, 0.06), "roughness": 0.85},
		"table_model": {"model": "gothic_coffee_table", "scale": 0.75},
		"bed_model": {"model": "GothicBed_01", "rot": PI},  # the model's headboard faces -z; the room wants it against the wall
		"fireplace": {
			"stone": {"pbr": "res://textures/keep/medieval_blocks_03", "tile": 1.7, "normal_scale": 1.0, "tint": Color(0.82, 0.79, 0.75)},
			"mantel": {"pbr": "res://textures/keep/medieval_wood", "tile": 3.0, "normal_scale": 0.5, "tint": Color(0.60, 0.50, 0.40)},
		},
		"background": Color(0.03, 0.03, 0.03),
		"ambient": Color(0.90, 0.78, 0.62), "ambient_energy": 0.42,
		"sun": Color(0.90, 0.88, 0.82), "sun_energy": 1.0,
		"lamp": Color(1.0, 0.72, 0.40), "lamp_energy": 3.0,
		"glow": true,
		"decor": [
			"fireplace", "window", "rug", "cat",
			{"model": "GreenChair_01", "pos": Vector3(1.55, 0, 1.15), "rot": 2.5},
			{"model": "GreenChair_01", "pos": Vector3(-1.65, 0, 1.25), "rot": -2.5},
			{"model": "potted_plant_01", "pos": Vector3(-3.05, 0, -2.1)},
			{"model": "potted_plant_01", "pos": Vector3(3.05, 0, -2.1), "rot": 2.1},
			{"model": "fern_02", "pos": Vector3(3.0, 0, 2.4), "scale": 0.6, "rot": 0.8},
			{"model": "gothic_statue", "pos": Vector3(-2.95, 0, 2.3), "scale": 0.65, "rot": 0.7},
			{"model": "treasure_chest", "pos": Vector3(2.95, 0, 1.15), "rot": -1.3},
			{"model": "wooden_crate_01", "pos": Vector3(2.55, 0, 2.5), "rot": 0.4},
			{"prop": "candle", "pos": Vector3(2.55, 0.35, 2.5)},
			{"prop": "candle_trio", "pos": Vector3(0.74, 0.42, -0.16)},
			{"model": "lantern_chandelier_01", "pos": Vector3(0, 2.12, 0.3), "light": Vector3(0, 0.3, 0), "energy": 1.3, "range": 9.0, "shadows": true},
			{"model": "kite_shield", "pos": Vector3(-1.35, 0.9, 2.92), "rot": PI},
		],
		"cat_color": Color(0.30, 0.28, 0.27),
		"rug": {"field": Color(0.42, 0.12, 0.10), "border": Color(0.22, 0.08, 0.06), "accent": Color(0.78, 0.62, 0.32)},
		"fabric": Color(0.24, 0.30, 0.22),
		"pot": Color(0.45, 0.32, 0.25),
		"ui_bg": Color(0.10, 0.09, 0.08, 0.93), "ui_fg": Color(0.94, 0.90, 0.82), "ui_accent": Color(0.82, 0.62, 0.30), "ui_muted": Color(0.68, 0.63, 0.56),
	},
	"modern_loft": {
		"name": "Modern Loft",
		"blurb": "Exposed brick, concrete floor and light oak.",
		"wall": {"shader": "plaster", "color": Color(0.90, 0.89, 0.86)},
		"wall_accent": {"shader": "brick", "brick_a": Color(0.60, 0.36, 0.30), "brick_b": Color(0.46, 0.27, 0.23), "mortar": Color(0.80, 0.77, 0.72)},
		"floor": {"shader": "plaster", "color": Color(0.58, 0.58, 0.57), "noise_amount": 0.10, "noise_scale": 1.5, "roughness": 0.75},
		"ceiling": {"shader": "plaster", "color": Color(0.93, 0.93, 0.92)},
		"trim": Color(0.20, 0.20, 0.21),
		"shelf": {"color_a": Color(0.76, 0.62, 0.44), "color_b": Color(0.62, 0.48, 0.32), "roughness": 0.85},
		"background": Color(0.10, 0.10, 0.11),
		"ambient": Color(0.85, 0.90, 1.0), "ambient_energy": 0.7,
		"sun": Color(1.0, 0.98, 0.94), "sun_energy": 1.6,
		"lamp": Color(1.0, 0.92, 0.80), "lamp_energy": 2.0,
		"glow": false,
		"decor": ["window", "rug", "cat", "plant", "plant", "armchair", "side_table", "floor_lamp", "pendant"],
		"cat_color": Color(0.10, 0.10, 0.11),
		"rug": {"field": Color(0.55, 0.56, 0.58), "border": Color(0.30, 0.31, 0.33), "accent": Color(0.85, 0.85, 0.83)},
		"fabric": Color(0.22, 0.26, 0.32),
		"pot": Color(0.90, 0.90, 0.88),
		"ui_bg": Color(0.10, 0.11, 0.13, 0.92), "ui_fg": Color(0.96, 0.96, 0.95), "ui_accent": Color(0.25, 0.62, 0.82), "ui_muted": Color(0.65, 0.68, 0.72),
	},
	"dark_academia": {
		"name": "Dark Academia",
		"blurb": "Green wallpaper, walnut panelling, candlelight.",
		"wall": {"shader": "wallpaper", "color_a": Color(0.11, 0.21, 0.17), "color_b": Color(0.08, 0.16, 0.13), "wainscot_height": 1.05, "wainscot_color": Color(0.24, 0.14, 0.08)},
		"floor": {"shader": "planks", "color_a": Color(0.27, 0.16, 0.09), "color_b": Color(0.18, 0.10, 0.06), "plank_width": 0.12, "plank_length": 0.9, "roughness": 0.75},
		"ceiling": {"shader": "plaster", "color": Color(0.80, 0.76, 0.68)},
		"trim": Color(0.24, 0.14, 0.08),
		"shelf": {"color_a": Color(0.25, 0.14, 0.08), "color_b": Color(0.16, 0.09, 0.05), "roughness": 0.85},
		"background": Color(0.03, 0.04, 0.03),
		"ambient": Color(0.95, 0.80, 0.60), "ambient_energy": 0.3,
		"sun": Color(1.0, 0.85, 0.65), "sun_energy": 0.9,
		"lamp": Color(1.0, 0.75, 0.45), "lamp_energy": 2.5,
		"glow": true,
		"decor": ["fireplace", "rug", "cat", "plant", "armchair", "side_table", "floor_lamp", "pendant", "globe"],
		"cat_color": Color(0.46, 0.44, 0.43),
		"rug": {"field": Color(0.35, 0.10, 0.10), "border": Color(0.18, 0.06, 0.06), "accent": Color(0.75, 0.60, 0.32)},
		"fabric": Color(0.36, 0.16, 0.09),
		"pot": Color(0.30, 0.22, 0.16),
		"ui_bg": Color(0.06, 0.09, 0.08, 0.94), "ui_fg": Color(0.94, 0.90, 0.80), "ui_accent": Color(0.78, 0.62, 0.32), "ui_muted": Color(0.65, 0.65, 0.55),
	},
	"scandi": {
		"name": "Scandi Bright",
		"blurb": "White walls, pale birch and lots of daylight.",
		"wall": {"shader": "plaster", "color": Color(0.95, 0.94, 0.91), "noise_amount": 0.03},
		"floor": {"shader": "planks", "color_a": Color(0.84, 0.74, 0.60), "color_b": Color(0.74, 0.63, 0.49), "plank_width": 0.16, "plank_length": 2.2, "roughness": 0.75},
		"ceiling": {"shader": "plaster", "color": Color(0.98, 0.98, 0.97)},
		"trim": Color(0.96, 0.96, 0.95),
		"shelf": {"color_a": Color(0.88, 0.78, 0.63), "color_b": Color(0.78, 0.67, 0.52), "roughness": 0.85},
		"background": Color(0.75, 0.80, 0.85),
		"ambient": Color(0.95, 0.97, 1.0), "ambient_energy": 0.9,
		"sun": Color(1.0, 0.98, 0.95), "sun_energy": 1.7,
		"lamp": Color(1.0, 0.95, 0.88), "lamp_energy": 1.5,
		"glow": false,
		"decor": ["window", "rug", "cat", "plant", "plant", "armchair", "side_table", "floor_lamp", "pendant"],
		"cat_color": Color(0.92, 0.89, 0.84),
		"rug": {"field": Color(0.86, 0.84, 0.80), "border": Color(0.60, 0.62, 0.60), "accent": Color(0.40, 0.55, 0.50)},
		"fabric": Color(0.72, 0.72, 0.70),
		"pot": Color(0.85, 0.85, 0.82),
		"ui_bg": Color(0.97, 0.96, 0.94, 0.94), "ui_fg": Color(0.15, 0.16, 0.16), "ui_accent": Color(0.30, 0.52, 0.47), "ui_muted": Color(0.45, 0.47, 0.47),
	},
}

func ids() -> Array:
	return styles.keys()

func get_style(id: String) -> Dictionary:
	if styles.has(id):
		return styles[id]
	return styles["cozy_cabin"]

func wall_length(wall: int) -> float:
	return ROOM_W if wall % 2 == 0 else ROOM_D

func slot_count(wall: int) -> int:
	return int(floor((wall_length(wall) - 0.5) / SLOT_PITCH))

## Offset along the wall (left→right as seen from the room centre) for a slot.
func slot_offset(wall: int, slot: int) -> float:
	var n := slot_count(wall)
	return (float(slot) - float(n - 1) / 2.0) * SLOT_PITCH

## Wall-anchored transform: origin on the floor at the shelf footprint centre, +z facing the room.
## `clearance` holds the object that far off the wall, the way real furniture stands
## proud of the skirting board instead of passing through it.
func wall_transform(wall: int, along: float, depth: float, clearance := 0.0) -> Transform3D:
	var basis: Basis
	var pos: Vector3
	var off := depth / 2.0 + clearance
	match wall:
		0:
			basis = Basis.IDENTITY
			pos = Vector3(along, 0.0, -ROOM_D / 2.0 + off)
		1:
			basis = Basis(Vector3.UP, -PI / 2.0)
			pos = Vector3(ROOM_W / 2.0 - off, 0.0, along)
		2:
			basis = Basis(Vector3.UP, PI)
			pos = Vector3(-along, 0.0, ROOM_D / 2.0 - off)
		_:
			basis = Basis(Vector3.UP, PI / 2.0)
			pos = Vector3(-ROOM_W / 2.0 + off, 0.0, -along)
	return Transform3D(basis, pos)

## Where a door goes on each wall, in order of preference: never the centre slot of the long walls
## (window / fireplace) and away from the armchair corner in the south-east.
const DOOR_SLOT_PREFS := {0: [3, 1, 4, 0], 1: [1, 0, 2], 2: [1, 3, 0, 4], 3: [1, 0, 2]}

## Exit wall for room i in the chain: east, then south, alternating, so consecutive rooms always
## turn (an L) and never line up. You arrive through the wall opposite the one you left by, so the
## geometry stays honest; a room whose entry lands on the north wall moves its window instead.
func exit_wall(index: int) -> int:
	return 1 if index % 2 == 0 else 2

func opposite_wall(wall: int) -> int:
	return (wall + 2) % 4

## The wall carrying the window: north unless a door is there, then west, then east.
func window_wall(room: Dictionary) -> int:
	var used: Array = []
	for d in room.get("doors", []):
		used.append(int(d["wall"]))
	for w in [0, 3, 1]:
		if not used.has(w):
			return w
	return -1

## Camera yaw that looks away from a wall, into the room (used after walking through a door).
func facing_from_wall(wall: int) -> float:
	return PI - float(wall) * PI / 2.0

## Shelves sorted clockwise around the room (north wall left→right, then east, south, west),
## so "next" always means the neighbouring bookcase rather than creation order.
func around_room(shelves: Array) -> Array:
	var out := shelves.duplicate()
	out.sort_custom(func(a, b):
		var pa := shelf_transform(int(a["wall"]), int(a["slot"])).origin
		var pb := shelf_transform(int(b["wall"]), int(b["slot"])).origin
		# angle measured from the north-west corner so the ring reads north → east → south → west
		return fposmod(atan2(pa.x, -pa.z) + PI / 4.0, TAU) < fposmod(atan2(pb.x, -pb.z) + PI / 4.0, TAU))
	return out

## The patch of floor one wall spot covers, squared up to the room's axes. A bookcase, a
## door and the window all reserve exactly this, so the ring of spots reads as one row of
## equal places rather than a jumble of whatever each thing happens to measure.
func slot_rect(wall: int, slot: int) -> Rect2:
	var t := shelf_transform(wall, slot)
	var size := Vector2(SHELF_W, SHELF_D) if wall % 2 == 0 else Vector2(SHELF_D, SHELF_W)
	return Rect2(Vector2(t.origin.x, t.origin.z) - size / 2.0, size)

func shelf_transform(wall: int, slot: int) -> Transform3D:
	return wall_transform(wall, slot_offset(wall, slot), SHELF_D, SKIRT_T)

## The wall-centre slot used by wide decor (fireplace, window). Only long walls have one.
func center_slot(wall: int) -> int:
	var n := slot_count(wall)
	if n % 2 == 1:
		return n / 2
	return -1

## A copy of the style adjusted for night: moonlight instead of sun, cool dim ambient, dark sky.
func night_variant(style: Dictionary) -> Dictionary:
	var st := style.duplicate(true)
	st["night"] = true
	st["background"] = Color(0.01, 0.01, 0.03)
	st["ambient"] = Color(0.40, 0.48, 0.75)
	st["ambient_energy"] = maxf(0.16, float(style.get("ambient_energy", 0.4)) * 0.45)
	st["sun"] = Color(0.55, 0.65, 1.0)
	st["sun_energy"] = 0.28
	st["lamp_energy"] = float(style.get("lamp_energy", 2.0)) * 1.25
	st["glow"] = true
	return st
