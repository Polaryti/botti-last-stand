shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// The Mist Tide: grey-green water with mist moving over it, foam where it meets the land, clearer in
// the shallows and darker in the deep. Each vertex carries the height of the ground under it (UV2.x),
// so the water knows how deep it is without reading the depth buffer (too costly on a phone).
uniform float level = 0.0;
uniform float dawn = 0.0;
uniform vec3 deep = vec3(0.03, 0.08, 0.1);
uniform vec3 shallow = vec3(0.16, 0.3, 0.3);
uniform vec3 mist = vec3(0.42, 0.62, 0.6);
uniform vec3 foam = vec3(0.78, 0.9, 0.86);

varying vec2 at;
varying float ground;

void vertex() {
	VERTEX.y = level;
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ground = UV2.x;
}

float wave(vec2 p, float t) {
	return sin(p.x * 0.11 + t * 0.5) * sin(p.y * 0.09 - t * 0.37)
		+ 0.5 * sin((p.x + p.y) * 0.27 + t * 0.8) * sin((p.x - p.y) * 0.21 - t * 0.6);
}

void fragment() {
	float depth = level - ground;
	if (depth <= 0.0) {
		discard;
	}
	float n = wave(at, TIME) + 0.4 * wave(at * 2.3 + 17.0, TIME * 1.3);
	// Threads of mist drifting on the surface.
	float threads = pow(0.5 + 0.5 * sin(n * 4.0 + at.x * 0.05 - TIME * 0.3), 6.0);
	vec3 water = mix(shallow, deep, smoothstep(0.0, 1.6, depth));
	water += mist * threads * 0.22;
	// A line of foam that comes and goes where the water laps the land.
	float lap = 0.06 + 0.05 * sin(TIME * 1.4 + at.x * 0.35 + at.y * 0.2);
	float edge = 1.0 - smoothstep(lap * 0.4, lap + 0.12, depth);
	float froth = 0.6 + 0.4 * sin(at.x * 3.1 + TIME * 2.0) * sin(at.y * 2.7 - TIME * 1.6);
	water = mix(water, foam, edge * froth);
	vec3 morning = mix(vec3(0.42, 0.46, 0.5), vec3(0.96, 0.74, 0.55), threads * 0.6 + edge * 0.4);
	ALBEDO = mix(water, morning, dawn * 0.6);
	ALPHA = clamp(0.45 + depth * 0.5, 0.0, 0.9) * mix(1.0, 0.55, edge * 0.6) + edge * froth * 0.3;
}
