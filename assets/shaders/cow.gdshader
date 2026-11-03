shader_type spatial;
render_mode specular_disabled;
// A cow's day, worked out from the clock so it costs nothing: graze, walk a few steps, look up, walk
// back. Each cow keeps its own time, taken from where it stands. It faces its own +Z.

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float seed = fract(world.x * 0.37 + world.z * 0.71) * 24.0;
	float t = mod(TIME + seed, 24.0);
	float out_walk = smoothstep(8.0, 8.5, t) * (1.0 - smoothstep(10.5, 11.0, t));
	float back_walk = smoothstep(19.0, 19.5, t) * (1.0 - smoothstep(21.5, 22.0, t));
	float walking = out_walk + back_walk;
	float graze = 1.0 - smoothstep(6.5, 7.5, t) + smoothstep(22.5, 23.5, t);
	float along = 0.7 * (smoothstep(8.0, 11.0, t) - smoothstep(19.0, 22.0, t));
	float leg = clamp(0.64 - VERTEX.y, 0.0, 0.64);
	float side = sign(VERTEX.x) * sign(VERTEX.z);
	VERTEX.z += sin(TIME * 5.0) * side * leg * 0.55 * walking;
	float head = smoothstep(0.72, 0.86, VERTEX.z);
	VERTEX.y -= head * (graze * (0.62 + sin(TIME * 2.6 + seed) * 0.03) + (1.0 - graze) * sin(TIME * 0.9 + seed) * 0.03);
	VERTEX.z += head * graze * 0.12;
	float tail = clamp(-0.86 - VERTEX.z, 0.0, 0.2) * 5.0 * clamp(1.3 - VERTEX.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * 2.3 + seed * 3.0) * tail * 0.32;
	VERTEX.y += sin(TIME * 5.0) * 0.02 * walking;
	VERTEX.z += along;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
