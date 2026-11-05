shader_type spatial;
// The same clothes in another colour: what is green turns to saffron, and skin stays as it is.

uniform sampler2D tex : source_color, filter_nearest;

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	if (c.g > c.r * 1.05 && c.g > c.b * 1.05) {
		c = vec3(c.g * 1.2, c.g * 0.62, c.b * 0.35);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
