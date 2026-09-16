shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(1.0, 0.35, 0.05);
uniform vec3 color_b : source_color = vec3(1.0, 0.85, 0.35);
uniform float speed = 1.6;
uniform float intensity = 1.6;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float n = fbm(vec2(uv.x * 3.0 + sin(t * 0.7) * 0.2, uv.y * 3.5 - t));
	float bottom = uv.y;
	float center = 1.0 - abs(uv.x - 0.5) * 2.0;
	float shape = bottom * center;
	float f = smoothstep(0.28, 0.95, n * 1.35 * shape + shape * 0.5);
	f *= smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x);
	vec3 col = mix(color_a, color_b, f * f) * f * intensity;
	ALBEDO = col;
	ALPHA = f;
}
