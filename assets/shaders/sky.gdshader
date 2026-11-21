// Gradient sky that moves from deep night to a warm sunrise, with a sun disc and glow.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_draw_never, shadows_disabled;

uniform float dawn = 0.0;
uniform vec3 sun_dir = vec3(0.0, -0.2, -1.0);
uniform float cloud = 0.0; // how overcast it is
uniform float flash = 0.0; // lightning
uniform vec3 tint = vec3(1.0); // the Mists are teal
uniform float dusk = 0.0; // Mesenlla: a luminous twilight, still glowing where the sun went down
uniform float sea = 0.0; // the drowned kingdom of Vael: the Mists glowing green over the sea, and its veil in the sky
uniform float aurora = 0.0;
uniform vec3 sea_dir = vec3(0.0, 0.0, 1.0);

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(dir);
	float h = clamp(d.y, -0.05, 1.0);
	vec3 night_top = vec3(0.012, 0.022, 0.06);
	vec3 night_low = vec3(0.05, 0.08, 0.135);
	vec3 night = mix(night_low, night_top, pow(max(h, 0.0), 0.5)) * tint;
	if (dusk > 0.0) {
		// Indigo overhead, violet in the middle, rose and amber along the horizon, brightest in the west.
		vec3 west = normalize(vec3(-0.9, 0.0, 0.35));
		float glow_side = 0.55 + 0.45 * max(dot(normalize(vec3(d.x, 0.0, d.z)), west), 0.0);
		vec3 top = vec3(0.05, 0.05, 0.16);
		vec3 mid = vec3(0.24, 0.15, 0.34);
		vec3 low = mix(vec3(0.42, 0.24, 0.38), vec3(0.98, 0.58, 0.36), glow_side);
		vec3 twilight = mix(low, mid, smoothstep(0.0, 0.22, h));
		twilight = mix(twilight, top, smoothstep(0.18, 0.75, h));
		night = mix(night, twilight, dusk);
	}
	if (sea > 0.0) {
		// Over the sea, the Mists glow: a cold green light low along the horizon, strongest out to sea,
		// and above it a veil hanging in the sky, slow folds of it drifting along.
		vec3 flat_d = normalize(vec3(d.x, 0.0, d.z) + vec3(0.0001));
		float seaward = 0.35 + 0.65 * max(dot(flat_d, normalize(sea_dir)), 0.0);
		float band = exp(-h * 9.0) * seaward;
		night += vec3(0.06, 0.24, 0.22) * band * sea;
		float az = atan(d.x, d.z);
		float folds = 0.5 + 0.5 * sin(az * 7.0 + TIME * 0.05 + sin(az * 3.0 - TIME * 0.03) * 2.0);
		folds *= 0.6 + 0.4 * sin(az * 17.0 - TIME * 0.08);
		float veil = smoothstep(0.08, 0.2, h) * (1.0 - smoothstep(0.32, 0.62, h)) * seaward;
		night += mix(vec3(0.05, 0.3, 0.22), vec3(0.12, 0.2, 0.36), smoothstep(0.15, 0.5, h)) * veil * folds * 0.55 * sea;
	}
	if (aurora > 0.0) {
		float az = atan(d.x, d.z);
		float drift = TIME * 0.06;
		float facing = smoothstep(-0.45, 0.7, d.z);
		float arc = 0.24 + 0.10 * sin(az * 2.0 + drift) + 0.035 * sin(az * 6.0 - drift);
		float height = h - arc;
		float curtains = 0.54 + 0.28 * sin(az * 26.0 + sin(az * 8.0 + drift) * 2.7) + 0.18 * sin(az * 43.0 - drift);
		float ribbon = smoothstep(-0.018, 0.006, height) * (1.0 - smoothstep(0.018, 0.2, height));
		float echo_height = h - (0.37 + 0.064 * sin(az * 3.0 - drift + 1.2));
		float echo = smoothstep(-0.02, 0.018, echo_height) * (1.0 - smoothstep(0.03, 0.18, echo_height));
		vec3 light = mix(vec3(0.09, 0.64, 0.52), vec3(0.28, 0.18, 0.48), smoothstep(0.0, 0.19, height));
		night += facing * aurora * (light * ribbon * curtains * 0.76 + vec3(0.17, 0.25, 0.52) * echo * (1.0 - curtains) * 0.36);
	}
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
	vec3 overcast = mix(vec3(0.05, 0.06, 0.08), vec3(0.3, 0.32, 0.36), smoothstep(0.1, 0.9, dawn));
	c = mix(c, overcast, cloud * 0.85);
	c += vec3(0.55, 0.62, 0.8) * flash * (0.35 + 0.65 * (1.0 - h));
	ALBEDO = c;
}
