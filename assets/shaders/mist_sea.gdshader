shader_type spatial;
render_mode unshaded, cull_disabled;
// The sea of mist the islands stand in: slow, soft, pale teal.

varying vec2 at;

void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float wave(vec2 p, float t) {
	return sin(p.x * 0.031 + t * 0.11) * sin(p.y * 0.027 - t * 0.09) + 0.5 * sin((p.x + p.y) * 0.073 + t * 0.17) * sin((p.x - p.y) * 0.061 - t * 0.13);
}

void fragment() {
	float n = wave(at, TIME) + 0.35 * wave(at * 2.7 + 40.0, TIME * 1.4);
	vec3 low = vec3(0.34, 0.58, 0.62);
	vec3 high = vec3(0.68, 0.9, 0.9);
	ALBEDO = mix(low, high, smoothstep(-0.9, 1.1, n));
}
