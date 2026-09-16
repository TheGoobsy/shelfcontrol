shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

// Solid-wood board shader. The grain runs along the board's longest axis and the ring pattern is
// unwrapped around the board's cross-section so it continues over the edges. Cut ends show end grain.
// Each MeshInstance3D passes its BoxMesh size via the "box_size" instance uniform.
uniform vec3 color_a : source_color = vec3(0.50, 0.32, 0.16);
uniform vec3 color_b : source_color = vec3(0.36, 0.21, 0.10);
uniform float grain_scale = 1.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.55;
uniform float bump = 0.004;
instance uniform vec3 box_size = vec3(1.0, 1.0, 1.0);

varying highp vec3 lpos;
varying vec3 lnrm;
varying highp vec3 seed_pos;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	seed_pos = MODEL_MATRIX[3].xyz;
}

void fragment() {
	// long axis L and the two cross axes A, B (with half extents ha, hb)
	vec3 L; vec3 A; vec3 B;
	float ha; float hb;
	if (box_size.x >= box_size.y && box_size.x >= box_size.z) {
		L = vec3(1.0, 0.0, 0.0); A = vec3(0.0, 1.0, 0.0); B = vec3(0.0, 0.0, 1.0); ha = box_size.y * 0.5; hb = box_size.z * 0.5;
	} else if (box_size.y >= box_size.z) {
		L = vec3(0.0, 1.0, 0.0); A = vec3(0.0, 0.0, 1.0); B = vec3(1.0, 0.0, 0.0); ha = box_size.z * 0.5; hb = box_size.x * 0.5;
	} else {
		L = vec3(0.0, 0.0, 1.0); A = vec3(1.0, 0.0, 0.0); B = vec3(0.0, 1.0, 0.0); ha = box_size.x * 0.5; hb = box_size.y * 0.5;
	}
	highp float seed = hash21(seed_pos.xz * 7.3 + seed_pos.yy * 3.1) * 6.0;
	highp float u = dot(lpos, L) + seed;
	highp float a = dot(lpos, A);
	highp float b = dot(lpos, B);
	float na = dot(lnrm, A);
	float nb = dot(lnrm, B);
	float nl = dot(lnrm, L);
	vec3 base;
	float h = 0.0;
	float rough = roughness_val;
	if (abs(nl) > 0.7) {
		// end grain: concentric rings around an off-centre pith
		highp vec2 c = vec2(a, b) - vec2(ha * 0.3, -hb * 0.2);
		highp float rr = length(c) * 60.0 + fbm3(c * 12.0 + seed) * 3.0;
		float rings = sin(rr) * 0.5 + 0.5;
		base = mix(color_a, color_b, rings * 0.5 + 0.35) * 0.92;
		h = rings * 0.2;
		rough = roughness_val + 0.25;
	} else {
		// perimeter coordinate v, continuous across three of the four edges
		highp float v;
		if (nb > 0.7) {
			v = a;
		} else if (na > 0.7) {
			v = ha + (hb - b);
		} else if (nb < -0.7) {
			v = ha + 2.0 * hb + (ha - a);
		} else {
			v = 2.0 * ha + 2.0 * hb + (b + hb);
		}
		highp vec2 uv = vec2(u, v + seed * 0.37) * grain_scale;
		float g = fbm3(vec2(uv.x * 1.6, uv.y * 10.0));
		float rings = sin(uv.y * 42.0 + g * 4.0 + uv.x * 0.6) * 0.5 + 0.5;
		float streak = fbm3(vec2(uv.x * 4.0, uv.y * 20.0)) * 0.22;
		base = mix(color_a, color_b, rings * 0.42 + g * 0.45 + streak);
		// dark late-wood rings sit slightly proud and are a touch rougher
		h = rings * 0.5;
		rough = roughness_val + (rings - 0.5) * 0.12 + streak * 0.2;
	}
	NORMAL = bump_normal(NORMAL, VERTEX, h, bump);
	ALBEDO = base;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
}
