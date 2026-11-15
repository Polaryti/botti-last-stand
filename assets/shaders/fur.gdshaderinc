// Fur, drawn into a low-poly body without textures: fine strands of light and shade that lie the way
// fur lies, back along the body on the flanks and the back, down the legs and the chest. Worked out in
// the part's own space, so the strands stay put on the animal as it moves. The strands are a stretched
// value noise seen from the three axes and blended by which way the face looks.

float fur_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fur_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fur_hash(i), fur_hash(i + vec2(1.0, 0.0)), f.x), mix(fur_hash(i + vec2(0.0, 1.0)), fur_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 0..1: dark in the grooves between strands, light on their crests. density: strands a metre.
float fur_strands(vec3 p, vec3 n, float density) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// Flanks (facing sideways): strands slope back and down. Back (facing up): back along the body.
	// Chest and rump (facing forward or back): straight down.
	vec2 side = vec2(p.z * 0.8 + p.y * 0.6, p.y * 0.8 - p.z * 0.6);
	float s = fur_noise(vec2(side.y * density, side.x * density * 0.14));
	float b = fur_noise(vec2(p.x * density, p.z * density * 0.14) + 17.0);
	float f = fur_noise(vec2(p.x * density, p.y * density * 0.14) + 41.0);
	float strands = s * w.x + b * w.y + f * w.z;
	// A coarser layer: locks of fur, a little lighter or darker than their neighbours.
	float locks = fur_noise(vec2(p.x + p.z, p.y - p.z) * density * 0.12 + 7.0);
	return clamp(strands * 0.75 + locks * 0.35, 0.0, 1.0);
}
