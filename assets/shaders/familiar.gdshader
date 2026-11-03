shader_type spatial;
render_mode specular_disabled;
// Familiars at your shoulder. Wings beat, and small things scurry.

uniform float flap = 0.0;
uniform float scurry = 0.0;

void vertex() {
	float wing = smoothstep(0.1, 0.3, abs(VERTEX.x));
	VERTEX.y += wing * sin(TIME * 14.0) * abs(VERTEX.x) * 0.7 * flap;
	VERTEX.y += abs(sin(TIME * 16.0)) * 0.04 * scurry;
	VERTEX.x += sin(TIME * 16.0) * VERTEX.z * 0.08 * scurry;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
