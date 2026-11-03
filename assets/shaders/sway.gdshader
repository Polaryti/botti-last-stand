shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Crops and grass moving in the wind. Everything is in the vertex stage, so it costs next to nothing.
uniform float strength = 0.09;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float wave = sin(TIME * 1.5 + world.x * 0.6 + world.z * 0.45) + sin(TIME * 2.9 + world.x * 1.7) * 0.35;
	VERTEX.x += wave * strength * h * h;
	VERTEX.z += wave * strength * 0.5 * h * h;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
