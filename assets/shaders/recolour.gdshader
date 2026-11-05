shader_type spatial;
// The same clothes in another colour: what is green turns to saffron, and skin stays as it is.

uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 robe = vec3(1.2, 0.62, 0.35);
uniform vec3 plate = vec3(1.0);

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	if (c.g > c.r * 1.05 && c.g > c.b * 1.05) {
		c = c.g * robe;
	} else if (abs(c.r - c.g) < 0.07 && abs(c.g - c.b) < 0.07) {
		c *= plate;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
