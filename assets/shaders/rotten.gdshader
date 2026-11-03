// Turns the kit's friendly medieval characters into rotten ones:
// skin tones become the type's sick colour, and clothes get dirty and dark.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.46, 0.62, 0.36);

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float warm = smoothstep(0.03, 0.12, c.r - c.g) * smoothstep(0.015, 0.08, c.g - c.b);
	float skin = warm * smoothstep(0.22, 0.42, c.r);
	vec3 clothes = mix(vec3(lum), c, 0.55) * 0.55;
	ALBEDO = mix(clothes, tint * (0.5 + lum * 1.1), skin);
	ROUGHNESS = 1.0;
}
