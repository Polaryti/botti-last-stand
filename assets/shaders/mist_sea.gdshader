shader_type spatial;
render_mode unshaded, cull_disabled;
// Two scales of flowing moonlit mist; no depth sampling or volumetric pass on mobile.
varying vec2 at;
void vertex() { at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
float wave(vec2 p, float t) {
	return sin(p.x * 0.031 + t * 0.11) * sin(p.y * 0.027 - t * 0.09)
		+ 0.5 * sin((p.x + p.y) * 0.073 + t * 0.17) * sin((p.x - p.y) * 0.061 - t * 0.13);
}
void fragment() {
	float n = wave(at, TIME) + 0.35 * wave(at * 2.7 + 40.0, TIME * 1.4);
	float threads = pow(0.5 + 0.5 * sin(n * 5.0 + at.x * 0.08 - TIME * 0.15), 7.0);
	ALBEDO = mix(vec3(0.018, 0.045, 0.075), vec3(0.075, 0.18, 0.23), smoothstep(-0.9, 1.1, n));
	ALBEDO += vec3(0.04, 0.12, 0.13) * threads;
}
