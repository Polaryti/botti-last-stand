shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The land, with the roads painted on it. "roads" holds how far each spot is from the nearest
// road's edge, so a road follows the ground exactly and has a clean edge at any distance.

// xyz: fire centre; w: inverse squared radius, prepared once by MapBuilder.
uniform vec4 hearths[8];
uniform sampler2D tile : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roads : hint_default_white, filter_linear, repeat_disable;
uniform vec3 dirt;
uniform float map_half = 110.0;
uniform float mask_reach = 3.0;
uniform vec3 tint = vec3(1.0); // the grass of other lands
uniform float cliffs = 0.0; // on the islands, the steep faces are banded rock

varying vec2 at;
varying vec3 world_at;
varying float flat_ground;
varying float patches;

void vertex() {
	at = VERTEX.xz;
	world_at = VERTEX;
	flat_ground = NORMAL.y;
	// Wide, slow patches of deeper and paler grass, so no field is one flat colour. Worked out at
	// each corner of the land's mesh and blended between them: it costs the picture nothing.
	float a = sin(at.x * 0.071 + sin(at.y * 0.043) * 2.1) * sin(at.y * 0.083 + sin(at.x * 0.037) * 1.7);
	float b = sin(at.x * 0.23 + at.y * 0.17 + 1.3) * sin(at.y * 0.29 - at.x * 0.11);
	patches = 1.0 + a * 0.17 + b * 0.07;
}

void fragment() {
	vec3 grain = texture(tile, UV).rgb;
	float edge = (texture(roads, at / (2.0 * map_half) + 0.5).r * 2.0 - 1.0) * mask_reach;
	// Grain at two sizes makes the edge wander and fray, the way a worn track does, so bare earth
	// fades into the grass instead of stopping at a line.
	float wander = texture(tile, at * 0.021).g - 0.5;
	vec3 land = grain * COLOR.rgb * tint * patches;
	float worn = edge + (grain.g - 0.5) * 1.1 + wander * 2.2;
	float road = 1.0 - smoothstep(-0.55, 0.45, worn);
	vec3 surface = dirt * mix(1.08, 0.92, smoothstep(-2.0, 0.0, edge)) * (0.68 + grain.g * 0.64);
	surface = mix(surface, land, 0.18);
	vec3 ground = mix(land, surface, road);
	if (cliffs > 0.5 && flat_ground < 0.75) {
		float side_grain = texture(tile, vec2(at.x + at.y, world_at.y) * 0.09).g;
		float band = 0.5 + 0.5 * sin(world_at.y * 0.9 + sin((at.x + at.y) * 0.05) * 3.0 + side_grain * 2.0);
		vec3 rock = mix(vec3(0.27, 0.3, 0.35), vec3(0.47, 0.49, 0.52), band * 0.8 + side_grain * 0.2);
		ground = mix(rock, ground, smoothstep(0.35, 0.75, flat_ground));
	}
	ALBEDO = ground;
	float warmth = 0.0;
	for (int i = 0; i < 8; i++) {
		if (hearths[i].w > 0.0) {
			vec3 delta = world_at - hearths[i].xyz;
			float falloff = max(0.0, 1.0 - dot(delta, delta) * hearths[i].w);
			warmth += falloff * falloff;
		}
	}
	EMISSION = ground * vec3(0.9, 0.45, 0.12) * min(warmth, 1.5);
	ROUGHNESS = 1.0;
}
