shader_type spatial;
render_mode unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 sky_top : source_color = vec3(0.35, 0.55, 0.85);
uniform vec3 sky_bottom : source_color = vec3(0.85, 0.80, 0.70);
uniform float brightness = 1.4;

void fragment() {
	vec3 c = mix(sky_top, sky_bottom, UV.y);
	float n = fbm(UV * vec2(3.0, 5.0) + vec2(TIME * 0.01, 0.0));
	c = mix(c, vec3(1.0), smoothstep(0.58, 0.72, n) * 0.35 * (1.0 - UV.y * 0.5));
	ALBEDO = c * brightness;
	EMISSION = c * brightness * 0.5;
}
