shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.45, 0.29, 0.16);
uniform vec3 color_b : source_color = vec3(0.33, 0.20, 0.10);
uniform float plank_width = 0.18;
uniform float plank_length = 1.6;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.6;
uniform float uv_scale = 1.0;

varying highp vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	highp vec2 uv = world_uv(wpos, wnrm) * uv_scale;
	float row = floor(uv.y / plank_width);
	float off = hash21(vec2(row, 3.7)) * plank_length;
	float col = floor((uv.x + off) / plank_length);
	float id = hash21(vec2(row, col));
	float grain = fbm3(vec2(uv.x * 2.0 + id * 40.0, uv.y * 24.0 + id * 10.0));
	vec3 base = mix(color_a, color_b, id * 0.7 + grain * 0.3);
	float sy = abs(fract(uv.y / plank_width) - 0.5) * 2.0;
	float sx = abs(fract((uv.x + off) / plank_length) - 0.5) * 2.0;
	float seam = clamp(smoothstep(0.93, 1.0, sy) + smoothstep(0.985, 1.0, sx), 0.0, 1.0);
	base *= 1.0 - 0.55 * seam;
	ALBEDO = base;
	ROUGHNESS = roughness_val;
}
