shader_type spatial;
render_mode unshaded, cull_disabled;
// A dark river that catches the moon, and at sunrise the sky. Costs one opaque surface.
uniform float dawn = 0.0;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float s = UV.y * 0.55 - TIME * 0.42;
	float streak = sin(s + sin(UV.x * 17.0) * 1.3) * sin(s * 0.37 + UV.x * 31.0);
	streak = smoothstep(0.55, 0.96, streak) * (1.0 - across * 0.55);
	vec3 night = mix(vec3(0.016, 0.042, 0.075), vec3(0.2, 0.3, 0.42), streak);
	vec3 morning = mix(vec3(0.3, 0.33, 0.38), vec3(0.98, 0.72, 0.5), streak);
	ALBEDO = mix(night, morning, dawn);
}
