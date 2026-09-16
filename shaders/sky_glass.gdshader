shader_type spatial;
render_mode unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 sky_top : source_color = vec3(0.35, 0.55, 0.85);
uniform vec3 sky_bottom : source_color = vec3(0.85, 0.80, 0.70);
uniform float brightness = 1.4;
uniform float stars = 0.0;
uniform float moon = 0.0;

void fragment() {
	vec3 c = mix(sky_top, sky_bottom, UV.y);
	float n = fbm(UV * vec2(3.0, 5.0) + vec2(TIME * 0.01, 0.0));
	float cloud = smoothstep(0.58, 0.72, n) * (1.0 - UV.y * 0.5);
	c = mix(c, vec3(1.0), cloud * mix(0.35, 0.06, stars));
	if (stars > 0.0) {
		vec2 cell = floor(UV * vec2(28.0, 42.0));
		vec2 f = fract(UV * vec2(28.0, 42.0)) - 0.5;
		float r = hash21(cell + 3.7);
		float twinkle = 0.7 + 0.3 * sin(TIME * (1.5 + r * 3.0) + r * 20.0);
		float star = step(0.93, r) * smoothstep(0.12, 0.0, length(f)) * twinkle * (1.0 - cloud);
		c += vec3(0.9, 0.95, 1.0) * star * stars * (1.0 - UV.y);
	}
	if (moon > 0.0) {
		float d = length((UV - vec2(0.72, 0.22)) * vec2(1.0, 1.15));
		float disc = smoothstep(0.075, 0.06, d);
		float halo = smoothstep(0.22, 0.06, d) * 0.25;
		c = mix(c, vec3(0.95, 0.95, 0.88), disc * moon);
		c += vec3(0.5, 0.55, 0.7) * halo * moon;
	}
	ALBEDO = c * brightness;
	EMISSION = c * brightness * 0.5;
}
