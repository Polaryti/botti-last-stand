// Gradient sky that moves from deep night to a warm sunrise, with a sun disc and glow.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_draw_never, shadows_disabled;

uniform float dawn = 0.0;
uniform vec3 sun_dir = vec3(0.0, -0.2, -1.0);

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(dir);
	float h = clamp(d.y, -0.05, 1.0);
	vec3 night_top = vec3(0.012, 0.022, 0.06);
	vec3 night_low = vec3(0.05, 0.08, 0.135);
	vec3 night = mix(night_low, night_top, pow(h, 0.5));
	vec3 day_top = vec3(0.28, 0.44, 0.68);
	vec3 day_mid = vec3(0.74, 0.62, 0.62);
	vec3 day_low = vec3(1.0, 0.62, 0.34);
	vec3 morning = mix(day_low, day_mid, smoothstep(0.0, 0.16, h));
	morning = mix(morning, day_top, smoothstep(0.1, 0.62, h));
	vec3 c = mix(night, morning, smoothstep(0.0, 0.9, dawn));
	float s = max(dot(d, normalize(sun_dir)), 0.0);
	float presence = smoothstep(0.15, 0.7, dawn);
	c += vec3(1.0, 0.56, 0.24) * pow(s, 9.0) * 0.5 * presence;
	c += vec3(1.0, 0.8, 0.52) * pow(s, 90.0) * 0.8 * presence;
	c = mix(c, vec3(1.0, 0.95, 0.78), smoothstep(0.9988, 0.9994, s) * presence);
	ALBEDO = c;
}
