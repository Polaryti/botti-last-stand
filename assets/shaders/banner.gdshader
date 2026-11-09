shader_type spatial;
render_mode cull_disabled;

void vertex() {
	float free_edge = smoothstep(0.04, 0.75, VERTEX.x);
	VERTEX.z += sin(TIME * 3.5 - VERTEX.x * 8.0 + VERTEX.y * 2.0) * 0.055 * free_edge;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
