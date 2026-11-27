shader_type spatial;
render_mode world_vertex_coords, specular_disabled, cull_disabled;
// The plants of Fontanova in the wind, as plants move: rooted where they stand, the stem or trunk
// stiff at the foot, bending more towards the tip (as the square of the height), the tips nodding
// gently back and forth, the leaves fluttering a little. A windy night bends them further and quicker,
// all leaning one way. Each plant moves in its own time, so a meadow never moves as one.
//   Trees are drawn as instances: the height is measured from the instance's own root.
//   Flowers and shrubs are merged into one mesh per patch: each vertex carries its height above its
//   own plant's root in UV2.y (LowPoly.rooted), so nothing sways from the patch's corner.
uniform bool rooted_in_uv2 = false;
uniform float reach = 6.0; // the height at which a plant's tip moves by sway (metres)
uniform float sway = 0.06; // how far the tip moves on a still night (metres, at reach)
uniform float gust_sway = 0.16; // and how much further on a windy one
uniform float flutter = 0.012; // leaves trembling (metres)
uniform float pace = 1.0; // how quickly it nods: grasses quicker than trees
uniform float gust = 0.0; // 0 a still night, 1 a windy one
uniform vec2 wind = vec2(0.95, 0.3);
varying float own_height;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = rooted_in_uv2 ? UV2.y : max(VERTEX.y - root.y, 0.0);
	own_height = h;
	// Where this plant stands: from the instance, or for a merged plant from its vertex (close enough).
	vec2 at = rooted_in_uv2 ? VERTEX.xz : root.xz;
	float phase = dot(floor(at * 0.7), vec2(1.37, 2.11));
	float t = TIME * pace * (1.0 + gust * 0.6);
	float bend = (h / reach) * (h / reach);
	// Nodding: a slow swing and a smaller quicker one on top, around a lean that grows with the gusts.
	float nod = sin(t * 1.1 + phase) * 0.7 + sin(t * 2.3 + phase * 1.9) * 0.3;
	float lean = bend * (sway * nod + gust_sway * gust * (0.65 + 0.35 * nod));
	vec2 dir = normalize(wind);
	VERTEX.xz += dir * lean;
	// Leaves and petals tremble a little, across the wind, more near the tips.
	float tremble = sin(t * 7.0 + VERTEX.x * 3.1 + VERTEX.z * 2.7) * flutter * (0.5 + gust) * min(bend * 4.0, 1.0);
	VERTEX.xz += vec2(-dir.y, dir.x) * tremble;
	// Bending, a stem shortens a little rather than stretching.
	VERTEX.y -= abs(lean) * abs(lean) / max(h, 0.05) * 0.5;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
