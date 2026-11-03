shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// The edge of the deadly fog: a slow, dim curtain that fades away upwards, and thins out close to you
// so that it never hides what is right in front of you.

varying vec2 around;
varying float high;

void vertex() {
	around = VERTEX.xz;
	high = VERTEX.y;
}

void fragment() {
	float wave = 0.6 + 0.24 * sin(around.x * 40.0 + TIME * 0.7 + high * 0.15) + 0.16 * sin(around.y * 31.0 - TIME * 0.45 - high * 0.2);
	float up = 1.0 - smoothstep(-8.0, 22.0, high);
	float close = mix(0.3, 1.0, smoothstep(3.0, 16.0, length(VERTEX)));
	ALBEDO = mix(vec3(0.16, 0.26, 0.24), vec3(0.42, 0.6, 0.54), wave);
	ALPHA = 0.62 * wave * up * close;
}
