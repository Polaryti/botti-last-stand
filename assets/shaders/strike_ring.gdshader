shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// Where lightning is about to land: the whole danger area, with a bright rim, and a wave that runs out
// from the middle and reaches the rim just as the bolt comes down.

uniform float progress = 0.0;
varying vec2 at;

void vertex() {
	at = UV * 2.0 - 1.0;
}

void fragment() {
	float r = length(at);
	float edge_width = max(fwidth(r), 0.001);
	float inside = 1.0 - smoothstep(1.0 - max(0.03, edge_width), 1.0, r);
	float rim = smoothstep(0.9, 0.97, r);
	float wave = smoothstep(progress - 0.16, progress, r) * (1.0 - smoothstep(progress, progress + 0.015, r));
	float pulse = 0.84 + 0.16 * sin(TIME * 22.0);
	ALBEDO = vec3(0.78, 0.9, 1.0);
	ALPHA = (rim * 0.85 + wave * 0.5 + 0.12 + 0.16 * progress) * inside * pulse;
}
