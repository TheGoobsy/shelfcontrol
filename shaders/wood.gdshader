shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

// Solid-wood board shader. The grain runs along the board's longest axis, whichever way the
// box is oriented: each MeshInstance3D passes its BoxMesh size via the "box_size" instance uniform.
uniform vec3 color_a : source_color = vec3(0.50, 0.32, 0.16);
uniform vec3 color_b : source_color = vec3(0.36, 0.21, 0.10);
uniform float grain_scale = 1.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.55;
instance uniform vec3 box_size = vec3(1.0, 1.0, 1.0);

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 seed_pos;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	seed_pos = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 an = abs(lnrm);
	// axes lying in this face's plane
	vec3 u_axis;
	vec3 v_axis;
	float u_len;
	float v_len;
	if (an.y > an.x && an.y > an.z) {
		u_axis = vec3(1.0, 0.0, 0.0); v_axis = vec3(0.0, 0.0, 1.0); u_len = box_size.x; v_len = box_size.z;
	} else if (an.x > an.z) {
		u_axis = vec3(0.0, 1.0, 0.0); v_axis = vec3(0.0, 0.0, 1.0); u_len = box_size.y; v_len = box_size.z;
	} else {
		u_axis = vec3(1.0, 0.0, 0.0); v_axis = vec3(0.0, 1.0, 0.0); u_len = box_size.x; v_len = box_size.y;
	}
	// grain runs along the longer of the two
	if (v_len > u_len) {
		vec3 t = u_axis; u_axis = v_axis; v_axis = t;
	}
	float seed = hash21(seed_pos.xz * 7.3 + seed_pos.yy * 3.1) * 40.0;
	vec2 uv = vec2(dot(lpos, u_axis), dot(lpos, v_axis)) * grain_scale + vec2(seed, seed * 0.37);
	float g = fbm(vec2(uv.x * 1.6, uv.y * 24.0));
	float rings = sin(uv.y * 42.0 + g * 6.0 + uv.x * 0.8) * 0.5 + 0.5;
	float streak = fbm(vec2(uv.x * 6.0, uv.y * 90.0)) * 0.25;
	vec3 base = mix(color_a, color_b, rings * 0.42 + g * 0.45 + streak);
	ALBEDO = base;
	ROUGHNESS = roughness_val;
}
