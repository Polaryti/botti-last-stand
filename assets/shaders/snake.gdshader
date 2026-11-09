shader_type spatial;
render_mode cull_disabled;
uniform float phase = 0.0;
uniform float motion = 0.0;
uniform float bite = 0.0;
void vertex() {
	float wave = phase - VERTEX.z * 6.0;
	float amplitude = mix(0.025, 0.15, motion);
	VERTEX.x += sin(wave) * amplitude;
	NORMAL.z += cos(wave) * amplitude * 6.0 * NORMAL.x;
	NORMAL = normalize(NORMAL);
	float head = smoothstep(0.0, 0.4, VERTEX.z);
	VERTEX.y += head * (0.02 + sin(phase * 0.35) * 0.012 + bite * 0.07);
	VERTEX.z += head * bite * 0.2;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.82;
}
