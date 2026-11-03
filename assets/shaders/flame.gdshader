shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Low-poly fire. Each flame finds its own rhythm from where it stands.

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float seed = world.x * 1.7 + world.z * 2.3;
	float h = VERTEX.y;
	VERTEX.x += sin(TIME * 7.0 + h * 3.0 + seed) * 0.13 * h;
	VERTEX.z += cos(TIME * 5.7 + h * 2.4 + seed) * 0.11 * h;
	VERTEX.y *= 0.92 + sin(TIME * 11.0 + seed) * 0.09;
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
