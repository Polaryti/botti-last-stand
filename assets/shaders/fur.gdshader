shader_type spatial;
render_mode specular_disabled;
// A creature in fur (the bears of Mesenlla): its colours from the mesh, with strands of fur through them
// (fur.gdshaderinc), a soft sheen where the light grazes it, and tufts that stir. Vertex alpha below 1 marks
// a tuft: the lower it is, the more it moves. glow > 0 is the Mist Bear: mist shining through its fur
// and at its edges.

#include "res://assets/shaders/fur.gdshaderinc"

uniform float density = 42.0;
uniform float depth = 0.42; // how dark the grooves between strands are
uniform vec3 glow_color = vec3(0.45, 0.95, 0.92);
uniform float glow = 0.0;
uniform float sheen = 0.5; // the rim of light along its edges

varying vec3 part_pos;
varying vec3 part_normal;

void vertex() {
	part_pos = VERTEX;
	part_normal = NORMAL;
	float loose = 1.0 - COLOR.a;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX += vec3(0.0, -0.4, -1.0) * sin(TIME * 2.6 + VERTEX.x * 7.0 + VERTEX.z * 5.0 + world.x) * 0.012 * loose;
}

void fragment() {
	float strands = fur_strands(part_pos, part_normal, density);
	vec3 base = COLOR.rgb;
	ALBEDO = base * mix(1.0 - depth, 1.0 + depth * 0.55, strands);
	ROUGHNESS = 1.0;
	// Fur catches the light at its edges.
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	RIM = sheen;
	RIM_TINT = 0.6;
	if (glow > 0.0) {
		ALBEDO = mix(ALBEDO, glow_color, edge * 0.22 * glow);
		EMISSION = glow_color * (edge * 0.4 + strands * 0.05) * glow;
	}
}
