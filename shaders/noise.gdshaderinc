// Shared procedural noise helpers.
// Written to stay numerically well-behaved on mobile GPUs: inputs are wrapped into [0,1) before
// any large multiplication, and everything is forced to highp.

float hash21(highp vec2 p) {
	highp vec2 q = fract(p * 0.3183099 + vec2(0.71, 0.113));
	q *= 17.0;
	return fract(q.x * q.y * (q.x + q.y));
}

float vnoise(highp vec2 p) {
	highp vec2 i = floor(p);
	highp vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	highp float a = hash21(i);
	highp float b = hash21(i + vec2(1.0, 0.0));
	highp float c = hash21(i + vec2(0.0, 1.0));
	highp float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(highp vec2 p) {
	highp float v = 0.0;
	highp float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Pick a planar projection of a world position based on the dominant normal axis.
highp vec2 world_uv(highp vec3 p, vec3 n) {
	vec3 an = abs(n);
	if (an.y > an.x && an.y > an.z) {
		return p.xz;
	}
	if (an.x > an.z) {
		return p.zy;
	}
	return p.xy;
}
