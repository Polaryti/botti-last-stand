shader_type spatial;
render_mode cull_disabled, specular_disabled;
void vertex() {
	float hem = 1.0 - smoothstep(0.1, 0.9, VERTEX.y);
	VERTEX.x += sin(TIME * 2.0 + VERTEX.z * 5.0) * hem * 0.055;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	EMISSION = COLOR.rgb * max(COLOR.g - 0.7, 0.0) * 1.8;
}
