class_name Materials
## Cached material factory for procedural shaders and plain PBR materials.

static var _cache: Dictionary = {}
static var _shaders: Dictionary = {}

static func shader(shader_name: String) -> Shader:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://shaders/%s.gdshader" % shader_name)
	return _shaders[shader_name]

## spec = {"shader": "planks", "color_a": Color(...), "roughness": 0.6, ...}
## or   {"pbr": "res://textures/lodge/wood_floor_worn", "tile": 2.0, "normal_scale": 0.7, "tint": Color(...)}
## String values ending in .jpg/.png are loaded as textures (e.g. "albedo_tex" for the wood shader).
static func from_spec(spec: Dictionary) -> Material:
	var key := "spec:" + var_to_str(spec)
	if _cache.has(key):
		return _cache[key]
	if spec.has("pbr"):
		var pm := pbr(str(spec["pbr"]), float(spec.get("tile", 2.0)), float(spec.get("normal_scale", 0.8)), spec.get("tint", Color.WHITE), float(spec.get("roughness", 1.0)))
		_cache[key] = pm
		return pm
	var m := ShaderMaterial.new()
	m.shader = shader(str(spec.get("shader", "plaster")))
	for k in spec.keys():
		if k == "shader":
			continue
		var pname := str(k)
		if pname == "roughness":
			pname = "roughness_val"
		var v = spec[k]
		if typeof(v) == TYPE_STRING and (str(v).ends_with(".jpg") or str(v).ends_with(".png")):
			v = load(str(v))
		m.set_shader_parameter(pname, v)
	_cache[key] = m
	return m

## The board material used by bookcases and wooden furniture, from a style's "shelf" spec.
static func shelf_wood(style: Dictionary) -> Material:
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
	return from_spec(spec)

## Upholstery: a photo set when the style has "fabric_spec", else a flat colour.
static func fabric(style: Dictionary, lighten := 0.0) -> Material:
	if style.has("fabric_spec"):
		var spec: Dictionary = (style["fabric_spec"] as Dictionary).duplicate()
		if lighten > 0.0:
			spec["tint"] = (spec.get("tint", Color.WHITE) as Color).lightened(lighten)
		return from_spec(spec)
	var col: Color = style.get("fabric", Color(0.4, 0.25, 0.18))
	return std(col.lightened(lighten) if lighten > 0.0 else col, 0.95)

## Photo-based material from a "<base>_diff.jpg / _nor_gl.jpg / _rough.jpg" set (Poly Haven naming),
## projected in world space (triplanar) so it tiles seamlessly across walls, floor and ceiling.
## tile = metres per texture repeat.
static func pbr(base: String, tile := 2.0, normal_scale := 0.8, tint := Color.WHITE, rough_mul := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = load(base + "_diff.jpg")
	if ResourceLoader.exists(base + "_nor_gl.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(base + "_nor_gl.jpg")
		m.normal_scale = normal_scale
	if ResourceLoader.exists(base + "_rough.jpg"):
		m.roughness_texture = load(base + "_rough.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = rough_mul
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / maxf(tile, 0.01)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func std(color: Color, roughness := 0.8, metallic := 0.0, emission := Color(0, 0, 0, 0), emission_energy := 1.0) -> StandardMaterial3D:
	var key := "std:%s:%.2f:%.2f:%s:%.2f" % [color.to_html(true), roughness, metallic, emission.to_html(true), emission_energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission.a > 0.0 and (emission.r + emission.g + emission.b) > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_cache[key] = m
	return m

static func textured(tex: Texture2D, roughness := 0.7, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, alpha)
	return m

## Translucent version of a plain colour, used for "ghost" books that are elsewhere in the room.
static func ghost(color: Color, alpha := 0.35, roughness := 0.8) -> StandardMaterial3D:
	var key := "ghost:%s:%.2f:%.2f" % [color.to_html(true), alpha, roughness]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = roughness
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_cache[key] = m
	return m

## A see-through copy of a material, keeping its texture and colour. Used for furniture
## standing in front of an open shelf. Custom shaders cannot be made translucent, so they
## fall back to a neutral pane.
static func see_through(src: Material, alpha := 0.2) -> Material:
	var key := "see:%d:%.2f" % [src.get_instance_id() if src != null else 0, alpha]
	if _cache.has(key):
		return _cache[key]
	var m: BaseMaterial3D
	if src is BaseMaterial3D:
		m = src.duplicate()
		m.albedo_color.a = alpha
	else:
		m = StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.50, 0.45, alpha)
		m.roughness = 0.9
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	_cache[key] = m
	return m

static func double_sided(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var key := "ds:%s:%.2f" % [color.to_html(true), roughness]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m
