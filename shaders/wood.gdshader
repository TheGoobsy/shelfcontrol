shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.50, 0.32, 0.16);
uniform vec3 color_b : source_color = vec3(0.36, 0.21, 0.10);
uniform float grain_scale = 1.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.55;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 uv = world_uv(wpos, wnrm) * grain_scale;
	float g = fbm(vec2(uv.x * 1.5, uv.y * 22.0));
	float rings = sin(uv.y * 38.0 + g * 7.0) * 0.5 + 0.5;
	vec3 base = mix(color_a, color_b, rings * 0.45 + g * 0.55);
	ALBEDO = base;
	ROUGHNESS = roughness_val;
}
