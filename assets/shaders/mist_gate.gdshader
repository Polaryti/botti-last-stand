shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float edge_width = max(fwidth(radius), 0.002);
	float angle = atan(p.y, p.x);
	float curl = sin(radius * 18.0 - angle * 3.0 - TIME * 1.6);
	float filament = 1.0 - smoothstep(0.0, max(fwidth(curl), 0.035), abs(curl));
	// Evaluate derivatives before discarding fully transparent corners.
	if (radius >= 1.0) { discard; }
	float veil = 0.5 + 0.5 * sin(p.x * 9.0 + sin(p.y * 8.0 + TIME * 0.6));
	float rim = smoothstep(0.72, 0.95, radius);
	ALBEDO = mix(vec3(0.08, 0.38, 0.42), vec3(0.35, 0.8, 0.76), rim * 0.7 + veil * 0.2 + curl * 0.05);
	ALBEDO += vec3(0.08, 0.18, 0.17) * filament * (1.0 - rim);
	ALPHA = (0.38 + veil * 0.12 + rim * 0.28) * (1.0 - smoothstep(1.0 - max(0.05, edge_width), 1.0, radius));
}
