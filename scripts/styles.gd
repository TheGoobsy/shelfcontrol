extends Node
## Style catalogue + room geometry constants (autoload "Styles").

const ROOM_W := 8.0   # x extent (east-west)
const ROOM_D := 6.0   # z extent (north-south)
const ROOM_H := 3.0

const SHELF_W := 1.2
const SHELF_H := 2.2
const SHELF_D := 0.32
const SLOT_PITCH := 1.45

const WALL_NAMES := ["North", "East", "South", "West"]

var styles: Dictionary = {
	"cozy_cabin": {
		"name": "Cozy Cabin",
		"blurb": "Log walls, a crackling fire and warm wood.",
		"wall": {"shader": "logs", "color_a": Color(0.60, 0.40, 0.22), "color_b": Color(0.38, 0.23, 0.12)},
		"floor": {"shader": "planks", "color_a": Color(0.46, 0.30, 0.16), "color_b": Color(0.32, 0.19, 0.10), "roughness": 0.55},
		"ceiling": {"shader": "planks", "color_a": Color(0.36, 0.23, 0.13), "color_b": Color(0.28, 0.17, 0.09), "roughness": 0.8},
		"trim": Color(0.28, 0.17, 0.09),
		"shelf": {"color_a": Color(0.46, 0.29, 0.15), "color_b": Color(0.30, 0.18, 0.09), "roughness": 0.55},
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
	"modern_loft": {
		"name": "Modern Loft",
		"blurb": "Exposed brick, concrete floor and light oak.",
		"wall": {"shader": "plaster", "color": Color(0.90, 0.89, 0.86)},
		"wall_accent": {"shader": "brick", "brick_a": Color(0.60, 0.36, 0.30), "brick_b": Color(0.46, 0.27, 0.23), "mortar": Color(0.80, 0.77, 0.72)},
		"floor": {"shader": "plaster", "color": Color(0.58, 0.58, 0.57), "noise_amount": 0.10, "noise_scale": 1.5, "roughness": 0.65},
		"ceiling": {"shader": "plaster", "color": Color(0.93, 0.93, 0.92)},
		"trim": Color(0.20, 0.20, 0.21),
		"shelf": {"color_a": Color(0.76, 0.62, 0.44), "color_b": Color(0.62, 0.48, 0.32), "roughness": 0.45},
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
		"floor": {"shader": "planks", "color_a": Color(0.27, 0.16, 0.09), "color_b": Color(0.18, 0.10, 0.06), "plank_width": 0.12, "plank_length": 0.9, "roughness": 0.4},
		"ceiling": {"shader": "plaster", "color": Color(0.80, 0.76, 0.68)},
		"trim": Color(0.24, 0.14, 0.08),
		"shelf": {"color_a": Color(0.25, 0.14, 0.08), "color_b": Color(0.16, 0.09, 0.05), "roughness": 0.4},
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
		"floor": {"shader": "planks", "color_a": Color(0.84, 0.74, 0.60), "color_b": Color(0.74, 0.63, 0.49), "plank_width": 0.16, "plank_length": 2.2, "roughness": 0.6},
		"ceiling": {"shader": "plaster", "color": Color(0.98, 0.98, 0.97)},
		"trim": Color(0.96, 0.96, 0.95),
		"shelf": {"color_a": Color(0.88, 0.78, 0.63), "color_b": Color(0.78, 0.67, 0.52), "roughness": 0.6},
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
func wall_transform(wall: int, along: float, depth: float) -> Transform3D:
	var basis: Basis
	var pos: Vector3
	match wall:
		0:
			basis = Basis.IDENTITY
			pos = Vector3(along, 0.0, -ROOM_D / 2.0 + depth / 2.0)
		1:
			basis = Basis(Vector3.UP, -PI / 2.0)
			pos = Vector3(ROOM_W / 2.0 - depth / 2.0, 0.0, along)
		2:
			basis = Basis(Vector3.UP, PI)
			pos = Vector3(-along, 0.0, ROOM_D / 2.0 - depth / 2.0)
		_:
			basis = Basis(Vector3.UP, PI / 2.0)
			pos = Vector3(-ROOM_W / 2.0 + depth / 2.0, 0.0, -along)
	return Transform3D(basis, pos)

func shelf_transform(wall: int, slot: int) -> Transform3D:
	return wall_transform(wall, slot_offset(wall, slot), SHELF_D)

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
