shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.15, 1.0, dot(p, p));
	float curl = 0.6 + 0.4 * sin(UV.x * 11.0 + sin(UV.y * 8.0 + TIME * 0.3));
	ALBEDO = vec3(0.18, 0.38, 0.45);
	ALPHA = edge * curl * COLOR.a * 0.16 * (0.75 + sin(TIME * 0.25) * 0.25);
}
