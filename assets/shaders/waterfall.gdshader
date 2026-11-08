shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Water falling a long way: streaks running down, thinning into mist towards the bottom.

uniform float tall = 40.0;

float streak(float x, float y) {
	return 0.5 + 0.5 * sin(x * 31.0 + sin(x * 11.0) * 3.0) * sin(y * 0.9 + sin(x * 17.0) * 6.0);
}

void fragment() {
	float y = UV.y * tall - TIME * 9.0;
	float s = streak(UV.x, y) * 0.6 + streak(UV.x * 2.3 + 3.0, y * 1.7) * 0.4;
	float side = smoothstep(0.0, 0.14, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x));
	ALBEDO = mix(vec3(0.5, 0.86, 0.92), vec3(0.96, 1.0, 1.0), s);
	ALPHA = side * mix(0.92, 0.3, UV.y) * (0.55 + 0.45 * s);
}
