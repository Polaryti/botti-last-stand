shader_type spatial;
render_mode specular_disabled;
// A four-legged creature of Mesenlla (a bear, a stag, a bear under a rider). Made like the horse:
// the head is towards -Z, everything below the belly swings in diagonal pairs by as much as gait says
// (0 stands, 1 runs), the head nods and the shoulders roll. mist > 0 lets the body thin at the edges.

uniform float gait = 0.0;
uniform float belly = 0.7;
uniform float stride = 0.45;
uniform float neck_z = -0.7;
uniform float mist = 0.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float seed = world.x * 0.31 + world.z * 0.27;
	float leg = clamp(belly - VERTEX.y, 0.0, belly);
	float side = sign(VERTEX.x) * sign(VERTEX.z + 0.05);
	float pace = mix(7.0, 11.0, gait);
	VERTEX.z += sin(TIME * pace + seed) * side * leg * stride * gait;
	float head = clamp(neck_z - VERTEX.z, 0.0, 1.0);
	VERTEX.y += sin(TIME * mix(1.4, 5.5, gait) + seed) * head * mix(0.04, 0.1, gait);
	VERTEX.x += sin(TIME * pace * 0.5 + seed) * clamp(VERTEX.y - belly, 0.0, 1.0) * 0.04 * gait;
	if (mist > 0.0) {
		VERTEX += NORMAL * sin(TIME * 2.0 + VERTEX.y * 6.0 + seed) * 0.03 * mist;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	if (mist > 0.0) {
		float rim = 1.0 - abs(dot(NORMAL, VIEW));
		ALBEDO = mix(ALBEDO, vec3(0.7, 0.95, 1.0), rim * mist * 0.7);
		EMISSION = vec3(0.25, 0.7, 0.8) * rim * mist;
	}
}
