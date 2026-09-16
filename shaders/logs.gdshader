shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.58, 0.38, 0.21);
uniform vec3 color_b : source_color = vec3(0.38, 0.23, 0.12);
uniform float log_height = 0.3;

varying highp vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	highp vec2 uv = world_uv(wpos, wnrm);
	float fy = fract(uv.y / log_height);
	float c = (fy - 0.5) * 2.0;
	float round_shade = sqrt(max(0.0, 1.0 - c * c));
	float row = floor(uv.y / log_height);
	float grain = fbm3(vec2(uv.x * 3.0 + row * 17.0, uv.y * 26.0));
	vec3 base = mix(color_a, color_b, grain * 0.6 + hash21(vec2(row, 1.0)) * 0.25);
	base *= 0.6 + 0.4 * round_shade;
	float seam = smoothstep(0.0, 0.07, fy) * smoothstep(1.0, 0.93, fy);
	base *= mix(0.3, 1.0, seam);
	vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(NORMAL + up_v * c * 0.9);
	float knots = smoothstep(0.62, 0.7, fbm(vec2(uv.x * 0.8 + row * 3.0, uv.y * 2.0)));
	base = mix(base, base * 0.7, knots);
	ALBEDO = base;
	ROUGHNESS = 0.85;
}
