class_name MesenllaBuilder
extends RefCounted
## How the landmarks of Mesenlla look (MapMesenlla). Each draws at the builder's current spot (b.xf)
## the way MapBuilder's own pieces do, and adds the colliders, glows and lights it needs.

const ROCK := Color(0.42, 0.4, 0.43)
const ROCK_DARK := Color(0.28, 0.27, 0.31)
const ROCK_UNDER := Color(0.22, 0.2, 0.27)
const MEADOW := Color(0.33, 0.47, 0.25)
const MEADOW_DARK := Color(0.24, 0.36, 0.19)
const PINE := Color(0.16, 0.3, 0.22)
const PINE_DARK := Color(0.11, 0.22, 0.17)
const BARK := Color(0.3, 0.2, 0.13)
const LOG := Color(0.46, 0.32, 0.2)
const LOG_DARK := Color(0.3, 0.2, 0.12)
const MIST_GLOW := Color(0.45, 0.95, 0.92)
const RIFT_GLOW := Color(0.62, 0.42, 1.0)
const AZURE := Color(0.18, 0.4, 0.72)
const AMBER := Color(0.95, 0.66, 0.22)
const RUNE := Color(0.55, 1.0, 0.92)

static var _glow_mat: StandardMaterial3D
static var _portal_mat: ShaderMaterial
static var _banner_mat: ShaderMaterial


## Unshaded and coloured by the mesh, for what shines on its own.
static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.vertex_color_use_as_albedo = true
		_glow_mat.disable_fog = true
	return _glow_mat


static func _shine(b: MapBuilder, l: LowPoly) -> MeshInstance3D:
	var mi := b.add(l)
	mi.material_override = glow_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _light(b: MapBuilder, local: Vector3, col: Color, energy: float, reach: float) -> void:
	if b.quality == 0:
		return
	var light := OmniLight3D.new()
	light.light_cull_mask = 3
	light.position = b.xf * local
	light.light_color = col
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.3
	b.w.add_child(light)


static func _mist(b: MapBuilder, local: Vector3, extents: Vector3, col: Color, amount: int, rise := 0.4) -> void:
	if b.is_preview:
		return
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = load("res://assets/sprites/glow.png")
	m.albedo_color = Color(col, 0.3)
	m.disable_fog = true
	q.material = m
	p.mesh = q
	p.amount = maxi(2, amount if b.quality > 0 else amount / 2)
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.position = b.xf * local
	p.visibility_range_end = 110.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(p)


## A lump of the mountains torn loose and hanging in the twilight: meadow on top with a few pines,
## raw rock beneath narrowing to a point, mist crystals glinting under it and mist falling from its edge.
static func floating_island(b: MapBuilder, width: float) -> void:
	var r := b.seeded()
	var l := b.mesh()
	var w := width * 0.5
	var sides := 9
	var top: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides
		var k := r.randf_range(0.82, 1.1)
		top.append(Vector3(cos(a) * w * k, r.randf_range(-0.2, 0.2), sin(a) * w * k))
	# The meadow cap and its rim.
	for i in sides:
		var a: Vector3 = top[i]
		var c: Vector3 = top[(i + 1) % sides]
		l._tri(Vector3(0, 0.35, 0), a, c, Vector3(0, -1, 0), MEADOW if i % 2 else MEADOW_DARK)
	# The rock beneath, in three tapering rings to a point.
	var rings := [[1.0, -0.8], [0.72, -width * 0.35], [0.38, -width * 0.65]]
	var prev: Array[Vector3] = top
	for ring: Array in rings:
		var next: Array[Vector3] = []
		for i in sides:
			var p: Vector3 = top[i] * float(ring[0])
			next.append(Vector3(p.x * r.randf_range(0.9, 1.1), float(ring[1]) + r.randf_range(-0.4, 0.4), p.z * r.randf_range(0.9, 1.1)))
		for i in sides:
			var col := ROCK if i % 3 else ROCK_DARK
			l._tri(prev[i], next[i], next[(i + 1) % sides], Vector3(0, float(ring[1]) * 0.5, 0), col)
			l._tri(prev[i], next[(i + 1) % sides], prev[(i + 1) % sides], Vector3(0, float(ring[1]) * 0.5, 0), col.darkened(0.08))
		prev = next
	var tip := Vector3(r.randf_range(-0.5, 0.5), -width * 0.95, r.randf_range(-0.5, 0.5))
	for i in sides:
		l._tri(prev[i], tip, prev[(i + 1) % sides], Vector3(0, -width * 0.7, 0), ROCK_UNDER)
	# Pines and a boulder or two on top.
	for i in int(width / 3.0):
		var a := r.randf() * TAU
		var d := r.randf_range(0.0, w * 0.65)
		var at := Vector3(cos(a) * d, 0.3, sin(a) * d)
		var tall := r.randf_range(2.2, 4.2)
		l.prism(at, at + Vector3.UP * 0.6, 0.12, 0.1, 5, BARK)
		l.prism(at + Vector3.UP * 0.5, at + Vector3.UP * tall, tall * 0.28, 0.0, 6, PINE if i % 2 else PINE_DARK)
	l.box(Vector3(w * 0.3, 0.5, -w * 0.25), Vector3(1.4, 1.0, 1.1), ROCK, Vector3(5, 30, 8))
	# Roots torn out with it, hanging from the rim in two bent lengths.
	for i in sides:
		if r.randf() < 0.35:
			continue
		var rim: Vector3 = top[i] * 0.94 + Vector3(0, -0.5, 0)
		var out := Vector3(rim.x, 0, rim.z).normalized()
		var bend := rim + Vector3(0, -r.randf_range(1.0, 2.2), 0) + out * r.randf_range(0.1, 0.4)
		var end := bend + Vector3(r.randf_range(-0.4, 0.4), -r.randf_range(0.8, 2.4), r.randf_range(-0.4, 0.4))
		l.prism(rim, bend, 0.09, 0.07, 4, BARK.darkened(0.25))
		l.prism(bend, end, 0.07, 0.02, 4, BARK.darkened(0.35))
	b.add(l)
	# Loose rocks drifting slowly around it, each with a seam of mist-glass.
	var debris := LowPoly.new()
	var seams := LowPoly.new()
	for i in r.randi_range(3, 5):
		var a := TAU * i / 5.0 + r.randf_range(-0.3, 0.3)
		var d := w * r.randf_range(1.15, 1.5)
		var at := Vector3(cos(a) * d, r.randf_range(-width * 0.45, 0.6), sin(a) * d)
		var big := r.randf_range(0.6, 1.4) * clampf(width / 12.0, 0.6, 1.6)
		debris.prism(at + Vector3.UP * big * 0.5, at - Vector3.UP * big * 1.3, big * 0.9, 0.0, 5, ROCK_DARK if i % 2 else ROCK)
		debris.prism(at + Vector3.UP * big * 0.5, at + Vector3.UP * big * 0.8, big * 0.9, big * 0.5, 5, MEADOW_DARK)
		seams.prism(at - Vector3.UP * big * 1.1, at - Vector3.UP * big * 1.7, big * 0.18, 0.0, 4, MIST_GLOW)
	var ring := Node3D.new()
	ring.name = "IslandDebris"
	ring.transform = b.xf
	b.w.add_child(ring)
	var rocks := MeshInstance3D.new()
	rocks.mesh = debris.commit()
	ring.add_child(rocks)
	var glints := MeshInstance3D.new()
	glints.mesh = seams.commit()
	glints.material_override = glow_material()
	glints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(glints)
	b.w.add_spinner(ring, Vector3.UP, r.randf_range(0.05, 0.09) * (1.0 if r.randf() < 0.5 else -1.0))
	# Crystals beneath, shining.
	var c := b.mesh()
	for i in 6:
		var a := TAU * i / 6.0 + r.randf()
		var at := Vector3(cos(a) * w * 0.4, -width * r.randf_range(0.35, 0.6), sin(a) * w * 0.4)
		c.prism(at, at + Vector3(cos(a) * 0.4, -r.randf_range(0.8, 1.6), sin(a) * 0.4), 0.22, 0.0, 5, MIST_GLOW)
	c.prism(tip + Vector3.UP * 0.4, tip + Vector3.DOWN * 1.2, 0.3, 0.0, 5, MIST_GLOW)
	_shine(b, c)
	b.w.add_glow(b.xf * (tip + Vector3.UP * 0.5), MIST_GLOW, width * 0.6, 220.0)
	_mist(b, Vector3(0, -width * 0.4, 0), Vector3(w * 0.7, width * 0.25, w * 0.7), MIST_GLOW, 10, -0.3)
	# Mist pours off one edge like a slow waterfall.
	var lip: Vector3 = top[r.randi() % sides] * 0.95
	_mist(b, lip + Vector3(0, -width * 0.5, 0), Vector3(0.6, width * 0.5, 0.6), MIST_GLOW.lerp(Color.WHITE, 0.3), 8, -0.6)


## A crack in the world: a dark, jagged fissure with a violet glow along its lips and mist rising.
static func rift(b: MapBuilder, length: float) -> void:
	var r := b.seeded()
	var l := b.mesh()
	var g := b.mesh()
	var steps := maxi(4, int(length / 1.6))
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / steps
		var z := (t - 0.5) * length
		var half := sin(t * PI) * r.randf_range(0.7, 1.3) * 0.9 + 0.05
		var bend := sin(t * 5.0 + r.randf()) * 0.6
		left.append(Vector3(bend - half, 0.05, z))
		right.append(Vector3(bend + half, 0.05, z))
	for i in steps:
		l._tri(left[i], right[i], right[i + 1], Vector3(0, -2, left[i].z), Color(0.04, 0.03, 0.07))
		l._tri(left[i], right[i + 1], left[i + 1], Vector3(0, -2, left[i].z), Color(0.04, 0.03, 0.07))
		for side: Array[Vector3] in [left, right]:
			var a: Vector3 = side[i]
			var c: Vector3 = side[i + 1]
			g.prism(a + Vector3.UP * 0.02, c + Vector3.UP * 0.02, 0.07, 0.07, 4, RIFT_GLOW if i % 2 else MIST_GLOW)
		var mid := (left[i] + right[i]) * 0.5
		g.prism(mid, mid + Vector3(0, 0.02, 0), (right[i].x - left[i].x) * 0.3, (right[i].x - left[i].x) * 0.3, 5, RIFT_GLOW.darkened(0.3))
	b.add(l)
	_shine(b, g)
	for z in [-length * 0.25, length * 0.25]:
		b.w.add_glow(b.xf * Vector3(0, 0.6, z), RIFT_GLOW, 4.0, 120.0)
	_light(b, Vector3(0, 1.2, 0), RIFT_GLOW, 2.2, length * 0.6 + 4.0)
	_mist(b, Vector3(0, 0.6, 0), Vector3(0.6, 0.4, length * 0.45), RIFT_GLOW, 12, 0.9)


## The Great Portal that led here from Mist Bastion: two weathered pillars and a lintel of carved
## stone, an azure swirl between them, and amber braziers either side.
static func mist_gate(b: MapBuilder, width: float) -> void:
	var l := b.mesh()
	var half := width * 0.5
	var high := width * 1.15
	for x: float in [-half, half]:
		l.box(Vector3(x, high * 0.5, 0), Vector3(1.2, high, 1.4), ROCK)
		l.box(Vector3(x, 0.3, 0), Vector3(1.8, 0.6, 2.0), ROCK_DARK)
		l.box(Vector3(x, high * 0.5, 0.72), Vector3(0.5, high * 0.8, 0.06), ROCK_DARK)
		b.solid(Vector3(x, high * 0.5, 0), Vector3(1.2, high, 1.4))
	l.box(Vector3(0, high + 0.5, 0), Vector3(width + 2.4, 1.0, 1.6), ROCK)
	l.box(Vector3(0, high + 1.2, 0), Vector3(width * 0.5, 0.4, 1.2), ROCK_DARK)
	l.box(Vector3(0, -0.02, 0), Vector3(width + 4.0, 0.1, 4.0), ROCK_DARK)
	b.add(l)
	var runes := b.mesh()
	for i in 5:
		var y := high * (0.2 + i * 0.15)
		for x: float in [-half, half]:
			runes.box(Vector3(x, y, 0.76), Vector3(0.24, 0.08, 0.02), RUNE)
	runes.box(Vector3(0, high + 0.5, 0.82), Vector3(1.2, 0.14, 0.02), RUNE)
	_shine(b, runes)
	if not b.is_preview:
		var swirl := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(width - 1.0, high - 0.3)
		swirl.mesh = q
		swirl.material_override = _portal_material()
		swirl.transform = b.xf * Transform3D(Basis.IDENTITY, Vector3(0, high * 0.5, 0))
		swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.w.add_child(swirl)
	b.w.add_glow(b.xf * Vector3(0, high * 0.5, 0.4), Color(0.35, 0.65, 1.0), width * 1.6, 200.0)
	_light(b, Vector3(0, high * 0.5, 1.5), Color(0.45, 0.7, 1.0), 2.6, width * 1.4)
	for x: float in [-half - 2.4, half + 2.4]:
		var br := b.mesh()
		br.prism(Vector3(x, 0, 1.2), Vector3(x, 1.1, 1.2), 0.25, 0.18, 6, ROCK_DARK)
		br.prism(Vector3(x, 1.1, 1.2), Vector3(x, 1.35, 1.2), 0.42, 0.5, 8, Color(0.18, 0.16, 0.15))
		b.add(br)
		b.solid(Vector3(x, 0.6, 1.2), Vector3(0.9, 1.2, 0.9))
		var at := b.xf * Vector3(x, 1.35, 1.2)
		b.w.add_glow(at + Vector3.UP * 0.4, AMBER, 2.4, 120.0)
		b._flame(at, 0.55)
		b.w.add_fire(at, WorldLight.TORCH_REACH)


static func _portal_material() -> ShaderMaterial:
	if _portal_mat:
		return _portal_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	c.y *= 0.8;
	float r = length(c);
	float a = atan(c.y, c.x);
	float swirl = 0.5 + 0.5 * sin(a * 4.0 + r * 10.0 - TIME * 1.6);
	float body = smoothstep(1.05, 0.6, r);
	ALBEDO = mix(vec3(0.12, 0.3, 0.85), vec3(0.75, 0.95, 1.0), swirl * (1.0 - r * 0.8));
	ALPHA = body * (0.3 + 0.45 * swirl);
}
"""
	_portal_mat = ShaderMaterial.new()
	_portal_mat.shader = sh
	return _portal_mat


## A ring of tall runestones, their carvings lit from inside, around a flat stone.
static func standing_stones(b: MapBuilder, radius: float) -> void:
	var r := b.seeded()
	var l := b.mesh()
	var runes := b.mesh()
	var count := 7
	for i in count:
		var a := TAU * i / count
		var at := Vector3(cos(a) * radius, 0, sin(a) * radius)
		var tall := r.randf_range(2.4, 3.6)
		var face := Vector3(-cos(a), 0, -sin(a))
		var stone_basis := Basis(Vector3.UP, -a + PI * 0.5)
		l.turned_box(at + Vector3.UP * tall * 0.5, Vector3(0.9, tall, 0.5), ROCK if i % 2 else ROCK_DARK, stone_basis)
		l.turned_box(at + Vector3.UP * (tall + 0.15), Vector3(0.7, 0.3, 0.42), ROCK_DARK, stone_basis)
		for k in 3:
			runes.turned_box(at + face * 0.27 + Vector3.UP * (0.8 + k * 0.55), Vector3(0.28, 0.1, 0.02), RUNE, stone_basis)
		b.solid(at + Vector3.UP * tall * 0.5, Vector3(0.9, tall, 0.9))
	l.prism(Vector3(0, 0, 0), Vector3(0, 0.4, 0), 1.3, 1.2, 8, ROCK_DARK)
	b.add(l)
	_shine(b, runes)
	b.solid(Vector3(0, 0.2, 0), Vector3(2.2, 0.4, 2.2))
	b.w.add_glow(b.xf * Vector3(0, 1.2, 0), RUNE, radius * 1.2, 160.0)
	_light(b, Vector3(0, 2.0, 0), RUNE, 1.6, radius + 4.0)
	_mist(b, Vector3(0, 0.4, 0), Vector3(radius * 0.6, 0.2, radius * 0.6), MIST_GLOW, 6, 0.3)


## A tall Mesenlla banner: azure cloth with an amber sun over mountains, on a pole with a cross-bar.
static func banner(b: MapBuilder, tall: float) -> void:
	var l := b.cell()
	l.prism(Vector3.ZERO, Vector3.UP * tall, 0.08, 0.06, 6, BARK)
	l.box(Vector3(0, tall - 0.2, 0), Vector3(1.6, 0.08, 0.08), BARK)
	l.prism(Vector3.UP * tall, Vector3.UP * (tall + 0.25), 0.12, 0.0, 5, AMBER)
	b.solid(Vector3.UP * 1.0, Vector3(0.3, 2.0, 0.3))
	if b.is_preview:
		return
	var cloth := b.mesh()
	cloth.box(Vector3(0, -1.1, 0), Vector3(1.4, 2.2, 0.03), AZURE)
	cloth.box(Vector3(0, -0.55, 0.02), Vector3(0.5, 0.5, 0.02), AMBER)
	cloth.prism(Vector3(-0.45, -1.7, 0.02), Vector3(-0.1, -1.1, 0.02), 0.25, 0.0, 3, Color(0.9, 0.92, 0.95))
	cloth.prism(Vector3(0.25, -1.7, 0.02), Vector3(0.5, -1.2, 0.02), 0.22, 0.0, 3, Color(0.9, 0.92, 0.95))
	cloth.box(Vector3(0, -2.25, 0), Vector3(1.4, 0.1, 0.035), AMBER)
	var mi := MeshInstance3D.new()
	mi.mesh = cloth.commit()
	mi.transform = b.xf * Transform3D(Basis.IDENTITY, Vector3(0, tall - 0.25, 0.06))
	if _banner_mat == null:
		# Coloured by the cloth's own mesh, and stirring in the mountain wind from the pole outwards.
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
void vertex() {
	float free_edge = smoothstep(-0.7, 0.7, VERTEX.x) * smoothstep(0.0, -1.5, VERTEX.y);
	VERTEX.z += sin(TIME * 2.6 - VERTEX.x * 5.0 + VERTEX.y * 1.5) * 0.08 * (0.3 + free_edge);
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""
		_banner_mat = ShaderMaterial.new()
		_banner_mat.shader = sh
	mi.material_override = _banner_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(mi)


## Mist crystals breaking out of the ground in a cluster, pale and shining.
static func crystals(b: MapBuilder, size: float) -> void:
	var r := b.seeded()
	var c := b.mesh()
	for i in 7:
		var a := r.randf() * TAU
		var d := r.randf_range(0.0, size * 0.35)
		var at := Vector3(cos(a) * d, -0.1, sin(a) * d)
		var lean := Vector3(r.randf_range(-0.35, 0.35), 1.0, r.randf_range(-0.35, 0.35)).normalized()
		var tall := r.randf_range(0.6, 1.0) * size * 0.45
		var thick := tall * 0.18
		c.prism(at, at + lean * tall * 0.75, thick, thick * 0.9, 6, MIST_GLOW if i % 3 else MIST_GLOW.lightened(0.3))
		c.prism(at + lean * tall * 0.75, at + lean * tall, thick * 0.9, 0.0, 6, Color(0.9, 1.0, 1.0))
	_shine(b, c)
	b.solid(Vector3.UP * size * 0.2, Vector3(size * 0.5, size * 0.4, size * 0.5))
	b.w.add_glow(b.xf * Vector3(0, size * 0.25, 0), MIST_GLOW, size * 1.4, 140.0)
	_light(b, Vector3(0, size * 0.4, 0), MIST_GLOW, 1.5, size * 2.0 + 3.0)


## A wall of sharpened logs along the piece's X axis, bound with rope, with any gaps it is given.
static func palisade(b: MapBuilder, length: float, gaps_text: String) -> void:
	var gaps: Array[Vector2] = []
	for part: String in gaps_text.split(",", false):
		var ends := part.strip_edges().split("-")
		if ends.size() == 2:
			gaps.append(Vector2(float(ends[0]), float(ends[1])))
	var l := b.mesh()
	var x := 0.0
	var r := b.seeded()
	var run_from := -1.0
	while x <= length:
		var open := false
		for g in gaps:
			if x >= g.x and x <= g.y:
				open = true
		if not open:
			var at := b.on_ground(Vector3(x - length * 0.5, 0, 0))
			var local := b.xf.affine_inverse() * at
			var tall := r.randf_range(2.8, 3.4)
			l.prism(local + Vector3.DOWN * 0.3, local + Vector3.UP * tall, 0.2, 0.19, 6, LOG if int(x / 0.42) % 2 else LOG_DARK)
			l.prism(local + Vector3.UP * tall, local + Vector3.UP * (tall + 0.5), 0.19, 0.0, 6, LOG.lightened(0.15))
			if run_from < 0.0:
				run_from = x
		if (open or x + 0.42 > length) and run_from >= 0.0:
			var end := x if not open else x - 0.42
			var mid := (run_from + end) * 0.5 - length * 0.5
			var span := end - run_from + 0.4
			var foot := b.xf.affine_inverse() * b.on_ground(Vector3(mid, 0, 0))
			l.box(foot + Vector3.UP * 1.2, Vector3(span, 0.08, 0.44), Color(0.6, 0.52, 0.35))
			l.box(foot + Vector3.UP * 2.3, Vector3(span, 0.08, 0.44), Color(0.6, 0.52, 0.35))
			b.solid(foot + Vector3.UP * 1.6, Vector3(span, 3.2, 0.45))
			run_from = -1.0
		x += 0.42
	b.add(l)


## A watchtower of logs on four legs with a roofed platform, a ladder and a lantern.
static func watchtower(b: MapBuilder, high: float) -> void:
	var l := b.mesh()
	for c: Vector2 in [Vector2(-1.3, -1.3), Vector2(1.3, -1.3), Vector2(-1.3, 1.3), Vector2(1.3, 1.3)]:
		l.prism(Vector3(c.x, 0, c.y), Vector3(c.x * 0.85, high + 2.4, c.y * 0.85), 0.2, 0.17, 6, LOG_DARK)
		b.solid(Vector3(c.x, 1.0, c.y), Vector3(0.45, 2.0, 0.45))
	for y: float in [high * 0.35, high * 0.7]:
		l.box(Vector3(0, y, -1.2), Vector3(2.7, 0.14, 0.14), LOG, Vector3(0, 0, 18))
		l.box(Vector3(0, y, 1.2), Vector3(2.7, 0.14, 0.14), LOG, Vector3(0, 0, -18))
		l.box(Vector3(-1.2, y, 0), Vector3(0.14, 0.14, 2.7), LOG, Vector3(18, 0, 0))
		l.box(Vector3(1.2, y, 0), Vector3(0.14, 0.14, 2.7), LOG, Vector3(-18, 0, 0))
	l.box(Vector3(0, high, 0), Vector3(3.4, 0.25, 3.4), LOG)
	for side in 4:
		var a := side * PI * 0.5
		var along := Vector3(cos(a), 0, sin(a))
		l.box(Vector3(0, high + 0.6, 0) + along * 1.65, Vector3(0.12, 1.0, 3.4) if side % 2 == 0 else Vector3(3.4, 1.0, 0.12), LOG_DARK)
	l.prism(Vector3(0, high + 2.3, 0), Vector3(0, high + 3.8, 0), 2.6, 0.0, 4, Color(0.3, 0.27, 0.3))
	l.box(Vector3(0, high * 0.5, 1.75), Vector3(0.6, high, 0.06), LOG.darkened(0.2))
	for k in int(high / 0.5):
		l.box(Vector3(0, 0.4 + k * 0.5, 1.8), Vector3(0.6, 0.07, 0.07), LOG)
	b.add(l)
	var lamp := b.mesh()
	lamp.box(Vector3(1.0, high + 1.6, 1.0), Vector3(0.3, 0.4, 0.3), AMBER)
	_shine(b, lamp)
	b.w.add_glow(b.xf * Vector3(1.0, high + 1.6, 1.0), AMBER, 3.0, 160.0)


## A stone ring with a fire in it, where the outpost gathers: a fire that heals, like a bonfire.
static func lodge_fire(b: MapBuilder) -> void:
	b.bonfire()
	var l := b.cell()
	for i in 6:
		var a := TAU * i / 6.0
		var at := Vector3(cos(a) * 2.6, 0, sin(a) * 2.6)
		l.box(at + Vector3.UP * 0.22, Vector3(1.3, 0.44, 0.4), LOG, Vector3(0, -rad_to_deg(a) + 90.0, 0))
