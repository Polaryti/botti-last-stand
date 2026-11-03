shader_type spatial;
render_mode specular_disabled;
// A gallop: everything below the belly swings, and diagonal pairs of legs move together.

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float leg = clamp(0.9 - VERTEX.y, 0.0, 0.9);
	float side = sign(VERTEX.x) * sign(VERTEX.z - 0.15);
	VERTEX.z += sin(TIME * 12.0 + (world.x + world.z) * 0.3) * side * leg * 0.55;
	VERTEX.y += abs(sin(TIME * 6.0 + world.x)) * 0.06;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
