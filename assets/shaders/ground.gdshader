shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The land, with the roads painted on it. "roads" holds how far each spot is from the nearest
// road's edge, so a road follows the ground exactly and has a clean edge at any distance.

uniform sampler2D tile : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roads : hint_default_white, filter_linear, repeat_disable;
uniform vec3 dirt;
uniform float map_half = 110.0;
uniform float mask_reach = 3.0;

varying vec2 at;

void vertex() {
	at = VERTEX.xz;
}

void fragment() {
	vec3 grain = texture(tile, UV).rgb;
	vec3 land = grain * COLOR.rgb;
	float edge = (texture(roads, at / (2.0 * map_half) + 0.5).r * 2.0 - 1.0) * mask_reach;
	// Grain at two sizes makes the edge wander and fray, the way a worn track does, so bare earth
	// fades into the grass instead of stopping at a line.
	float wander = texture(tile, at * 0.021).g - 0.5;
	float worn = edge + (grain.g - 0.5) * 1.1 + wander * 2.2;
	float road = 1.0 - smoothstep(-0.55, 0.45, worn);
	vec3 surface = dirt * mix(1.08, 0.92, smoothstep(-2.0, 0.0, edge)) * (0.68 + grain.g * 0.64);
	surface = mix(surface, land, 0.18);
	ALBEDO = mix(land, surface, road);
	ROUGHNESS = 1.0;
}
