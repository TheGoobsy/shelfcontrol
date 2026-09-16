class_name Materials
## Cached material factory for procedural shaders and plain PBR materials.

static var _cache: Dictionary = {}
static var _shaders: Dictionary = {}

static func shader(shader_name: String) -> Shader:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://shaders/%s.gdshader" % shader_name)
	return _shaders[shader_name]

## spec = {"shader": "planks", "color_a": Color(...), "roughness": 0.6, ...}
static func from_spec(spec: Dictionary) -> Material:
	var key := "spec:" + var_to_str(spec)
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = shader(str(spec.get("shader", "plaster")))
	for k in spec.keys():
		if k == "shader":
			continue
		var pname := str(k)
		if pname == "roughness":
			pname = "roughness_val"
		m.set_shader_parameter(pname, spec[k])
	_cache[key] = m
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

static func textured(tex: Texture2D, roughness := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
