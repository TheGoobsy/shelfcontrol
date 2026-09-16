shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color : source_color = vec3(0.9, 0.88, 0.84);
uniform float noise_amount = 0.06;
uniform float noise_scale = 4.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.9;
uniform float bump = 0.012;

varying highp vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	highp vec2 uv = world_uv(wpos, wnrm);
	float n = fbm(uv * noise_scale);
	float fine = fbm(uv * 12.0);
	float h = n * 0.6 + fine * 0.4;
	NORMAL = bump_normal(NORMAL, VERTEX, h, bump);
	ALBEDO = color * (1.0 - noise_amount + noise_amount * 2.0 * n);
	ROUGHNESS = clamp(roughness_val + (fine - 0.5) * 0.2, 0.0, 1.0);
}
