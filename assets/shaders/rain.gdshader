shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
// Rain, all worked out here so it costs almost nothing. Each streak's vertices hold a random place in a
// box, and the box wraps around the camera. Streaks stay put in the world as you walk through them.

uniform float box_size = 26.0;
uniform float box_high = 16.0;
uniform float fall = 19.0;
uniform float clear_radius = 0.0; // indoors, no rain close by
uniform float strength = 1.0;

varying float fade;
varying float along;

void vertex() {
	vec3 seed = VERTEX;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 flat_at = mod(seed.xz * box_size - cam.xz + box_size * 0.5, box_size) - box_size * 0.5;
	float y = mod(seed.y * box_high - TIME * fall * (0.85 + seed.x * 0.3), box_high);
	vec3 at = vec3(cam.x + flat_at.x, cam.y - box_high * 0.42 + y, cam.z + flat_at.y);
	vec3 to_cam = vec3(cam.x - at.x, 0.0, cam.z - at.z);
	float near = length(to_cam);
	to_cam /= max(near, 0.001);
	vec3 side = vec3(to_cam.z, 0.0, -to_cam.x);
	float streak = 0.5 + seed.z * 0.4;
	// A little wider in the distance, or far streaks would shimmer away to nothing.
	at += side * (UV.x - 0.5) * (0.018 + near * 0.0016) + vec3(0.1, 1.0, 0.05) * UV.y * streak;
	VERTEX = at;
	fade = smoothstep(clear_radius, clear_radius + 1.5, near) * (1.0 - smoothstep(box_size * 0.4, box_size * 0.5, near));
	along = UV.y;
}

void fragment() {
	ALBEDO = vec3(0.74, 0.82, 0.95);
	ALPHA = 0.42 * fade * strength * (1.0 - along * 0.8);
}
