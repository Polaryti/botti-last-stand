shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
// A wave running out along the ground from whatever just shook it: a stun, a slow, a burst of fire.

uniform float progress = 0.0;
uniform vec3 tint = vec3(1.0);
varying vec2 at;

void vertex() {
	at = UV * 2.0 - 1.0;
}

void fragment() {
	float r = length(at);
	float wave = smoothstep(progress - 0.22, progress, r) * (1.0 - smoothstep(progress, progress + 0.05, r));
	float wash = (1.0 - smoothstep(0.0, progress, r)) * 0.14;
	ALBEDO = tint;
	ALPHA = (wave * 0.9 + wash) * (1.0 - progress * progress) * step(r, 1.0);
}
