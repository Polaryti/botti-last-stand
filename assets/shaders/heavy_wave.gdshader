shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 1.1;
	ALPHA = fade * 0.85;
}
