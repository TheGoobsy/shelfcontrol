shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 field : source_color = vec3(0.55, 0.20, 0.15);
uniform vec3 border : source_color = vec3(0.30, 0.10, 0.08);
uniform vec3 accent : source_color = vec3(0.85, 0.70, 0.45);
uniform vec2 rug_size = vec2(3.2, 2.2);
uniform float border_w = 0.25;
uniform float pattern_scale = 0.35;

varying highp vec3 lpos;
varying vec3 lnrm;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

void fragment() {
	highp vec2 p = lpos.xz;
	vec2 e = rug_size * 0.5 - abs(p);
	float m = min(e.x, e.y);
	float in_border = step(m, border_w);
	float in_line = step(abs(m - border_w * 0.5), 0.02) + step(abs(m - border_w - 0.06), 0.015);
	vec2 q = p / pattern_scale;
	float diamond = step(0.72, abs(fract(q.x) - 0.5) + abs(fract(q.y) - 0.5));
	vec3 col = mix(field, accent, diamond * 0.55);
	col = mix(col, border, in_border);
	col = mix(col, accent, clamp(in_line, 0.0, 1.0));
	if (lnrm.y < 0.5) {
		col = border;
	}
	float weave = fbm(p * 60.0);
	col *= 0.88 + 0.24 * weave;
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
