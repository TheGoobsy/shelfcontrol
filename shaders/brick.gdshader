shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 brick_a : source_color = vec3(0.62, 0.36, 0.30);
uniform vec3 brick_b : source_color = vec3(0.48, 0.27, 0.23);
uniform vec3 mortar : source_color = vec3(0.78, 0.75, 0.70);
uniform float brick_w = 0.24;
uniform float brick_h = 0.075;
uniform float mortar_w = 0.012;
uniform float jitter = 0.0;
uniform float bump = 0.045;

varying highp vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	highp vec2 uv = world_uv(wpos, wnrm);
	uv += (fbm(uv * 9.0) - 0.5) * jitter;
	float row = floor(uv.y / brick_h);
	float offx = mod(row, 2.0) * 0.5 * brick_w + hash21(vec2(row, 9.1)) * brick_w * jitter * 4.0;
	float bx = fract((uv.x + offx) / brick_w);
	float by = fract(uv.y / brick_h);
	float id = hash21(vec2(floor((uv.x + offx) / brick_w), row));
	vec3 bcol = mix(brick_a, brick_b, id) * (0.85 + 0.3 * fbm(uv * 30.0));
	float mx = mortar_w / brick_w;
	float my = mortar_w / brick_h;
	// soft mortar edges so the recess reads as a bevel, not a hard step
	float mortar_x = 1.0 - smoothstep(mx, mx + 0.03, bx);
	float mortar_y = 1.0 - smoothstep(my, my + 0.08, by);
	float is_mortar = clamp(mortar_x + mortar_y, 0.0, 1.0);
	vec3 col = mix(bcol, mortar, is_mortar);
	float surface = fbm(uv * 12.0 + id) * 0.4;
	float h = -is_mortar * 1.0 + surface * (1.0 - is_mortar);
	NORMAL = bump_normal(NORMAL, VERTEX, h, bump);
	ALBEDO = col * (0.94 + surface * 0.15 + fbm(uv * 30.0) * 0.08);
	ROUGHNESS = mix(0.84 + surface * 0.12, 0.97, is_mortar);
}
