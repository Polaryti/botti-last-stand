shader_type spatial;
render_mode specular_disabled;
// A horse. Everything below the belly swings, diagonal pairs of legs moving together, by as much as
// gait says: 0 stands still, 1 is a full gallop. The head nods and the tail swishes all the time.

uniform float gait = 1.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float seed = world.x * 0.3 + world.z * 0.3;
	float leg = clamp(0.9 - VERTEX.y, 0.0, 0.9);
	float side = sign(VERTEX.x) * sign(VERTEX.z - 0.15);
	VERTEX.z += sin(TIME * 12.0 + seed) * side * leg * 0.55 * gait;
	float neck = clamp(-0.72 - VERTEX.z, 0.0, 1.2);
	VERTEX.y += sin(TIME * mix(1.6, 6.0, gait) + seed) * neck * mix(0.05, 0.12, gait);
	float tail = clamp(VERTEX.z - 1.14, 0.0, 1.0) * clamp(1.5 - VERTEX.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * mix(2.2, 9.0, gait) + seed * 2.0) * tail * 1.4;
	VERTEX.y += abs(sin(TIME * 6.0 + world.x)) * 0.06 * gait;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
