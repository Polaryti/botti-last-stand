shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress = 0.0;
uniform float eye = 0.0;
uniform vec3 col_a = vec3(0.2, 0.8, 1.0); // as it appears
uniform vec3 col_b = vec3(0.85, 0.4, 1.0); // as it is about to strike
varying float height;
void vertex() { height = VERTEX.y; }
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float aa = max(fwidth(r), 0.005);
	float outer = 1.0 - smoothstep(1.0 - aa, 1.0, r);
	float hollow = smoothstep(eye - aa, eye + aa, r);
	float rim = smoothstep(0.92, 0.98, r);
	float inner_rim = eye > 0.0 ? 1.0 - smoothstep(0.0, 0.025, abs(r - eye)) : 0.0;
	float wave = 1.0 - smoothstep(0.0, 0.06, abs(r - progress));
	ALBEDO = mix(col_a, col_b, progress);
	ALBEDO = mix(ALBEDO, vec3(0.35, 1.0, 0.65), inner_rim);
	ALPHA = COLOR.a * (1.0 - smoothstep(3.3, 3.5, abs(height))) * outer * max(hollow * (0.12 + rim * 0.7 + wave * 0.5), inner_rim * 0.85);
}
