shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.10, 0.20, 0.16);
uniform vec3 color_b : source_color = vec3(0.08, 0.16, 0.13);
uniform float stripe_w = 0.12;
uniform float wainscot_height = 0.0;
uniform vec3 wainscot_color : source_color = vec3(0.22, 0.13, 0.08);

varying highp vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	highp vec2 uv = world_uv(wpos, wnrm);
	float s = step(0.5, fract(uv.x / stripe_w));
	float n = fbm(uv * 6.0);
	vec3 col = mix(color_a, color_b, s) * (0.94 + 0.12 * n);
	float rough = 0.85;
	if (wainscot_height > 0.0 && wpos.y < wainscot_height) {
		float g = fbm(vec2(uv.x * 1.5, uv.y * 30.0));
		col = wainscot_color * (0.85 + 0.3 * g);
		float rail = step(abs(wpos.y - wainscot_height + 0.04), 0.02);
		float panel = step(0.47, abs(fract(uv.x / 0.6) - 0.5));
		col = mix(col, wainscot_color * 0.6, max(rail, panel * 0.6));
		rough = 0.5;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
