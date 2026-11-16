shader_type spatial;
render_mode unshaded, cull_disabled;
// A dark river that catches the moon, and at sunrise the sky. Costs one opaque surface.
uniform float dawn = 0.0;
uniform vec3 deep = vec3(0.016, 0.042, 0.075);
uniform vec3 glint = vec3(0.2, 0.3, 0.42);
uniform float ripple = 0.0; // Soft bands under the bright streaks, for water seen by daylight.

void fragment() {
	float across = min(abs(UV.x - 0.5) * 2.0, 1.0);
	float s = UV.y * 0.55 - TIME * 0.42;
	float streak = sin(s + sin(UV.x * 17.0) * 1.3) * sin(s * 0.37 + UV.x * 31.0);
	// Pixel-width filtering keeps moon glints stable at shallow viewing angles.
	float aa = min(fwidth(streak), 0.18);
	streak = smoothstep(0.55 - aa, 0.96 + aa, streak) * (1.0 - across * 0.55);
	float band = sin(UV.y * 1.7 - TIME * 0.7 + sin(UV.x * 5.0) * 1.6) * 0.5 + 0.5;
	vec3 night = mix(deep + (glint - deep) * band * ripple, glint, streak);
	vec3 morning = mix(vec3(0.3, 0.33, 0.38), vec3(0.98, 0.72, 0.5), streak);
	ALBEDO = mix(night, morning, dawn);
}
