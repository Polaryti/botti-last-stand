shader_type spatial;
render_mode world_vertex_coords, specular_disabled;
// The plants of Fontanova moving in the wind: trees lean and rock from the root up, their leaves
// flutter, and on a windy night everything bends further and faster, all one way. Each plant rocks in
// its own time (from where it stands), so a grove never moves as one. All in the vertex stage.
uniform float bend = 0.005; // how far a point h metres up moves: h * h * bend
uniform float gust = 0.0; // 0 a still night, 1 a windy one
uniform vec2 wind = vec2(0.95, 0.3);

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y - root.y, 0.0);
	float t = TIME * (1.0 + gust * 1.3);
	float phase = root.x * 0.21 + root.z * 0.17;
	float sway = sin(t * 1.2 + phase) * 0.6 + sin(t * 2.7 + phase * 2.3) * 0.25;
	float lean = h * h * bend * (sway * (0.55 + gust * 0.8) + gust * 1.1);
	vec2 dir = normalize(wind);
	VERTEX.xz += dir * lean;
	// The leaves flutter on their own, a little across the wind.
	float flutter = sin(t * 6.5 + VERTEX.x * 2.9 + VERTEX.z * 2.3) * (0.05 + gust * 0.1) * min(h, 4.0) * bend * 8.0;
	VERTEX.xz += vec2(-dir.y, dir.x) * flutter;
	VERTEX.y -= abs(lean) * 0.08;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
