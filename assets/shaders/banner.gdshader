shader_type spatial;
render_mode cull_disabled, specular_disabled;
// The heraldry belongs to the cloth surface, so there are no overlapping trim or emblem meshes.
void vertex() {
	float free_edge = smoothstep(0.02, 0.5, VERTEX.x) * smoothstep(0.0, 0.3, UV.y);
	VERTEX.z += sin(TIME * 3.2 - VERTEX.x * 9.0 + VERTEX.y * 2.0) * 0.035 * free_edge;
}
void fragment() {
	float border = 1.0 - step(0.055, UV.x) * step(UV.x, 0.945) * step(0.045, UV.y) * step(UV.y, 0.955);
	float stem = (1.0 - step(0.055, abs(UV.x - 0.5))) * step(0.22, UV.y) * step(UV.y, 0.77);
	float arms = (1.0 - step(0.045, abs(UV.y - 0.4))) * step(0.27, UV.x) * step(UV.x, 0.73);
	float weave = 0.96 + 0.04 * sin(UV.x * 160.0) * sin(UV.y * 160.0);
	ALBEDO = mix(vec3(0.29, 0.055, 0.36), vec3(0.82, 0.58, 0.18), max(border, max(stem, arms))) * weave;
	ROUGHNESS = 1.0;
}
