shader_type spatial;
render_mode unshaded, cull_disabled;
// World-space ripples stay continuous between round pools and their outflow channels.
uniform vec2 pool_origin = vec2(0.0);
uniform float pool_radius = 8.0;
varying vec2 at;
void vertex() { at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = at - pool_origin;
	float wave = sin(p.x * 0.72 + p.y * 0.45 - TIME * 0.65);
	wave += sin(p.y * 1.05 - p.x * 0.38 + TIME * 0.43) * 0.45;
	float highlight = max(0.0, wave * 0.67);
	float highlight2 = highlight * highlight;
	float highlight4 = highlight2 * highlight2;
	float shimmer = highlight4 * highlight4 * highlight;
	float edge = smoothstep(pool_radius - 0.65, pool_radius, length(p)) * (1.0 - smoothstep(pool_radius, pool_radius + 0.45, length(p)));
	float foam = edge * (0.4 + 0.2 * sin(p.x * 3.0 + p.y * 2.0 + TIME));
	float facing = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float grazing = facing * facing * facing;
	vec3 water = mix(vec3(0.025, 0.085, 0.12), vec3(0.08, 0.19, 0.24), 0.4 + wave * 0.12 + grazing * 0.3);
	ALBEDO = water + vec3(0.12, 0.23, 0.25) * shimmer + vec3(0.1, 0.21, 0.22) * foam;
}
