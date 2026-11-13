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


## Unshaded and coloured by the mesh, for what shines on its own.
static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.vertex_color_use_as_albedo = true
		_glow_mat.disable_fog = true
	return _glow_mat


## Something the Map screen draws: where it is, which way it runs, and how big it is.
static func _feature(b: MapBuilder, kind: String, size: float) -> void:
	var along := b.xf.basis.x
	b.w.map_features.append({"kind": kind, "at": Vector2(b.xf.origin.x, b.xf.origin.z), "dir": Vector2(along.x, along.z).normalized(), "size": size})


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
	_feature(b, "island", width)
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


## A tear in the world standing upright above the ground: a jagged slit of violet light taller than a
## man, ringed by shards of rock lifted into the air around it, crystals breaking out beneath and mist
## pouring out of it. Its length is how wide the scar on the ground under it runs.
static func rift(b: MapBuilder, length: float) -> void:
	_feature(b, "rift", length)
	var r := b.seeded()
	var high := clampf(length * 0.6, 4.5, 6.5)
	var lift := 1.0
	# The tear: a jagged lens of light, darker at its heart, from two zig-zag edges.
	var g := b.mesh()
	var steps := 9
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / steps
		var y := lift + t * high
		var half := sin(t * PI) * (0.55 + r.randf_range(-0.12, 0.12)) + 0.02
		var bend := sin(t * 4.2 + r.randf()) * 0.25
		left.append(Vector3(bend - half, y, 0))
		right.append(Vector3(bend + half, y, 0))
	for i in steps:
		for face: float in [-1.0, 1.0]:
			var off := Vector3(0, 0, 0.01 * face)
			g._tri(left[i] + off, right[i] + off, right[i + 1] + off, Vector3(0, left[i].y, -face), RIFT_GLOW)
			g._tri(left[i] + off, right[i + 1] + off, left[i + 1] + off, Vector3(0, left[i].y, -face), RIFT_GLOW.lightened(0.15))
		var mid := (left[i] + right[i]) * 0.5
		var mid2 := (left[i + 1] + right[i + 1]) * 0.5
		g.prism(mid, mid2, (right[i].x - left[i].x) * 0.22 + 0.02, (right[i + 1].x - left[i + 1].x) * 0.22 + 0.02, 4, Color(0.95, 0.88, 1.0))
		for side: Array[Vector3] in [left, right]:
			g.prism(side[i], side[i + 1], 0.06, 0.06, 4, MIST_GLOW)
	_shine(b, g)
	# Shards of rock torn from the ground, hanging around the tear, and the scar beneath it.
	var l := b.mesh()
	for k in 7:
		var a := r.randf() * TAU
		var d := r.randf_range(1.0, 2.2)
		var at := Vector3(cos(a) * d, lift + r.randf_range(0.3, high * 0.9), sin(a) * d * 0.6)
		var size := r.randf_range(0.25, 0.6)
		l.prism(at + Vector3.UP * size, at - Vector3.UP * size * 1.4, size * 0.7, 0.0, 5, ROCK_DARK if k % 2 else ROCK)
	var scar := maxf(length * 0.5, 2.0)
	for k in 6:
		var z := (k / 5.0 - 0.5) * scar
		l.box(Vector3(r.randf_range(-0.4, 0.4), 0.04, z), Vector3(r.randf_range(0.6, 1.2), 0.08, scar / 5.0), Color(0.1, 0.08, 0.14))
	b.add(l)
	crystals_at(b, Vector3(0.9, 0, 0.4), 1.6)
	crystals_at(b, Vector3(-0.8, 0, -0.5), 1.2)
	b.solid(Vector3(0, lift + high * 0.5, 0), Vector3(1.2, high, 0.5))
	b.w.add_glow(b.xf * Vector3(0, lift + high * 0.5, 0), RIFT_GLOW, high * 1.4, 160.0)
	_light(b, Vector3(0, lift + high * 0.5, 0.8), RIFT_GLOW, 2.4, high * 2.2)
	_mist(b, Vector3(0, lift + high * 0.5, 0), Vector3(0.5, high * 0.4, 0.3), RIFT_GLOW, 14, 0.5)


## A few crystals at a spot relative to the piece, for dressing other landmarks.
static func crystals_at(b: MapBuilder, local: Vector3, size: float) -> void:
	var keep := b.xf
	b.xf = b.xf.translated_local(local)
	crystals(b, size)
	b.xf = keep


## The Great Portal that led here from Mist Bastion: two weathered pillars and a lintel of carved
## stone, an azure swirl between them, and amber braziers either side.
static func mist_gate(b: MapBuilder, width: float) -> void:
	_feature(b, "portal", width)
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
	_feature(b, "stones", radius)
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
	var body := b.add(l)
	var lamp := b.mesh()
	lamp.box(Vector3(1.0, high + 1.6, 1.0), Vector3(0.3, 0.4, 0.3), AMBER)
	var light := _shine(b, lamp)
	var glow: MeshInstance3D = b.w.add_glow(b.xf * Vector3(1.0, high + 1.6, 1.0), AMBER, 3.0, 160.0)
	if not b.is_preview:
		# A tower can be brought down (the Valleys' camp, when it is shelled): see World.ruin_tower.
		b.w.watchtowers.append({"at": b.xf.origin, "basis": b.xf.basis, "high": high, "parts": [body, light, glow]})


## What is left of a watchtower brought down: its legs snapped off, beams and planks thrown about,
## the roof lying on its side. Drawn where the tower stood, in that tower's frame.
static func tower_ruin(high: float, seed_from: int) -> Mesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_from
	var l := LowPoly.new()
	for c: Vector2 in [Vector2(-1.3, -1.3), Vector2(1.3, -1.3), Vector2(-1.3, 1.3), Vector2(1.3, 1.3)]:
		var top := r.randf_range(0.8, 1.9)
		l.prism(Vector3(c.x, 0, c.y), Vector3(c.x * 0.97, top, c.y * 0.97), 0.2, 0.18, 6, LOG_DARK.darkened(0.3))
		l.prism(Vector3(c.x * 0.97, top, c.y * 0.97), Vector3(c.x * 0.97, top + 0.25, c.y * 0.97), 0.18, 0.04, 5, Color(0.12, 0.09, 0.08))
	for k in 7:
		var a := r.randf() * TAU
		var d := r.randf_range(1.5, high * 0.7)
		var at := Vector3(cos(a) * d, 0.12, sin(a) * d)
		var along := Vector3(cos(a + r.randf_range(-1.0, 1.0)), r.randf_range(-0.05, 0.12), sin(a + r.randf_range(-1.0, 1.0))).normalized()
		l.prism(at - along * 1.3, at + along * 1.3, 0.13, 0.12, 5, LOG if k % 2 else LOG_DARK.darkened(0.2))
	for k in 5:
		var at := Vector3(r.randf_range(-3.0, 3.0), 0.05, r.randf_range(-3.0, 3.0))
		l.box(at, Vector3(r.randf_range(1.0, 2.2), 0.08, 0.35), LOG.darkened(0.25), Vector3(r.randf_range(-6, 6), r.randf_range(0, 180), 0))
	var roof_at := Vector3(r.randf_range(2.0, 3.5), 0.9, r.randf_range(-1.0, 1.0))
	l.prism(roof_at, roof_at + Vector3(1.4, 0.4, 0.2), 2.4, 0.0, 4, Color(0.24, 0.22, 0.24))
	return l.commit()


## A stone ring with a fire in it, where the outpost gathers: a fire that heals, like a bonfire.
static func lodge_fire(b: MapBuilder) -> void:
	b.bonfire()
	var l := b.cell()
	for i in 6:
		var a := TAU * i / 6.0
		var at := Vector3(cos(a) * 2.6, 0, sin(a) * 2.6)
		l.box(at + Vector3.UP * 0.22, Vector3(1.3, 0.44, 0.4), LOG, Vector3(0, -rad_to_deg(a) + 90.0, 0))


# --- The valley: water, arches, the makeshift outpost and the forest floor ---------------------------

const WATER := Color(0.55, 0.8, 0.95)
const MOSS := Color(0.3, 0.5, 0.22)
const MOSS_LIGHT := Color(0.42, 0.62, 0.28)
const CANVAS := Color(0.78, 0.72, 0.6)
const CANVAS_DARK := Color(0.6, 0.54, 0.44)
const CRIMSON := Color(0.72, 0.1, 0.12)
const JADE_TILE := Color(0.18, 0.46, 0.38)
static var _fall_mat: ShaderMaterial


## A waterfall down a rock face: the cliff it pours over (a slab of rock, so it never hangs in the
## air), white water sliding down it, a churning pool of foam at its foot and spray hanging over it.
## Falls towards the piece's +Z; high is how far it drops.
static func waterfall(b: MapBuilder, high: float, wide: float) -> void:
	_feature(b, "falls", wide)
	var r := b.seeded()
	var l := b.mesh()
	# The cliff: a wall of rock from the ground to the lip, rough with columns and ledges, deep enough
	# to meet the mountain behind it, and moss along the top where the stream comes over.
	var face := wide + 10.0
	var columns := int(face / 1.8)
	for k in columns:
		var x := (float(k) + 0.5) / columns * face - face * 0.5
		var near := absf(x) < wide * 0.5 + 0.4
		var top := high + (0.4 if near else r.randf_range(0.6, 2.6))
		var front := -0.4 - (0.6 if near else r.randf_range(0.0, 1.2))
		l.box(Vector3(x, top * 0.5 - 0.5, front - 4.0), Vector3(1.9, top + 1.0, 8.0), ROCK if (k + int(top)) % 3 else ROCK_DARK)
		l.box(Vector3(x, top + 0.25, front - 4.0), Vector3(1.95, 0.5, 8.0), MOSS if k % 2 else MOSS_LIGHT)
		# Ledges across the face.
		if not near and k % 2 == 0:
			l.box(Vector3(x, top * r.randf_range(0.3, 0.7), front + 0.2), Vector3(2.0, 0.4, 0.7), ROCK_DARK)
	# Shoulders of rock either side, stepping down and back into the mountain, so the cliff never
	# stands alone like a wall.
	for side: float in [-1.0, 1.0]:
		for k in 4:
			var x := side * (face * 0.5 + 1.5 + k * 2.6)
			var top := high * (0.85 - k * 0.2)
			l.box(Vector3(x, top * 0.5 - 0.5, -5.0 - k * 1.5), Vector3(2.8, top + 1.0, 9.0), ROCK if k % 2 else ROCK_DARK)
			l.box(Vector3(x, top + 0.25, -5.0 - k * 1.5), Vector3(2.85, 0.5, 9.0), MOSS_LIGHT if k % 2 else MOSS)
	# The stream that feeds it, along the top.
	l.box(Vector3(0, high + 0.52, -4.0), Vector3(wide * 0.9, 0.06, 8.0), Color(0.42, 0.62, 0.8))
	b.add(l)
	b.solid(Vector3(0, high * 0.5, -4.4), Vector3(face, high, 8.0))
	# The falling water and the foam: a scrolling sheet in its own shader.
	if not b.is_preview:
		var sheet := LowPoly.new()
		var bands := 8
		for k in bands:
			var t0 := float(k) / bands
			var t1 := float(k + 1) / bands
			# It bows out a little as it falls.
			var z0 := 0.1 + sin(t0 * PI) * 0.6
			var z1 := 0.1 + sin(t1 * PI) * 0.6
			for side: float in [-1.0, 1.0]:
				sheet._tri(Vector3(-wide * 0.5, high * (1.0 - t0), z0), Vector3(wide * 0.5, high * (1.0 - t0), z0), Vector3(wide * 0.5, high * (1.0 - t1), z1), Vector3(0, high * (1.0 - t0), z0 - side), Color(1, 1, 1, 1.0 - t0 * 0.2))
				sheet._tri(Vector3(-wide * 0.5, high * (1.0 - t0), z0), Vector3(wide * 0.5, high * (1.0 - t1), z1), Vector3(-wide * 0.5, high * (1.0 - t1), z1), Vector3(0, high * (1.0 - t0), z0 - side), Color(1, 1, 1, 1.0 - t1 * 0.2))
		var mi := MeshInstance3D.new()
		mi.mesh = sheet.commit()
		mi.transform = b.xf
		mi.material_override = _falling_water()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.w.add_child(mi)
	var foam := b.mesh()
	for k in 9:
		var a := r.randf() * TAU
		var d := r.randf_range(0.2, wide * 0.6)
		foam.prism(Vector3(cos(a) * d, -0.15, 1.2 + sin(a) * d * 0.6), Vector3(cos(a) * d, 0.25, 1.2 + sin(a) * d * 0.6), r.randf_range(0.5, 1.0), 0.2, 6, Color(0.92, 0.97, 1.0))
	_shine(b, foam)
	_mist(b, Vector3(0, 1.0, 1.4), Vector3(wide * 0.6, 0.8, 1.2), Color(0.85, 0.95, 1.0), 16, 0.8)
	_mist(b, Vector3(0, high * 0.5, 0.6), Vector3(wide * 0.4, high * 0.4, 0.3), Color(0.85, 0.95, 1.0), 8, -0.5)
	b.w.add_glow(b.xf * Vector3(0, high * 0.4, 0.8), Color(0.6, 0.85, 1.0), wide * 1.5, 200.0)


static func _falling_water() -> ShaderMaterial:
	if _fall_mat:
		return _fall_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 water = vec3(0.62, 0.84, 0.98);
void fragment() {
	// Streaks of white racing down, broken into ropes of water.
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float lines = 0.5 + 0.5 * sin(w.x * 5.3 + sin(w.x * 1.7) * 2.0);
	float fall = fract(w.y * 0.35 + TIME * 1.4 + lines * 0.6);
	float streak = smoothstep(0.55, 1.0, fall) * (0.6 + 0.4 * lines);
	ALBEDO = mix(water, vec3(1.0), streak * 0.8 + 0.2);
	ALPHA = (0.55 + streak * 0.4) * COLOR.a;
}
"""
	_fall_mat = ShaderMaterial.new()
	_fall_mat.shader = sh
	return _fall_mat


## A great arch of rock, worn through by the mountain, moss and grass along its back and vines hanging
## from it. Spans the piece's X axis; you can walk under it but not through its legs.
static func arch(b: MapBuilder, span: float) -> void:
	_feature(b, "arch", span)
	var r := b.seeded()
	var l := b.mesh()
	var g := b.mesh()
	var half := span * 0.5
	var rise := span * 0.62
	var thick := maxf(2.2, span * 0.16)
	var segs := 22
	var prev := Vector3.ZERO
	for k in segs + 1:
		var t := float(k) / segs
		var a := PI * t
		# A rounded arch, a little lopsided, its feet sunk into the ground.
		var at := Vector3(-cos(a) * half, sin(a) * rise - 0.8, sin(a * 2.0) * thick * 0.25)
		var fat := thick * (1.3 - 0.4 * sin(a))
		if k > 0:
			var stone := ROCK.lerp(ROCK_DARK, 0.25 + 0.25 * sin(k * 1.7))
			l.prism(prev, at, fat, fat, 8, stone)
			# Moss on its back, thickest along the top, and grass tufts on it.
			var moss_cover := 0.55 + 0.45 * sin(a)
			g.prism(prev + Vector3.UP * fat * 0.55, at + Vector3.UP * fat * 0.55, fat * 0.8 * moss_cover + 0.2, fat * 0.8 * moss_cover + 0.2, 8, MOSS_LIGHT.lerp(MOSS, 0.5 + 0.5 * sin(k * 2.3)))
			if k > 2 and k < segs - 2 and k % 3 == 0:
				for v in 2:
					var drop := Vector3(r.randf_range(-0.4, 0.4), 0, (v - 0.5) * fat * 1.2)
					g.prism(at + drop, at + drop + Vector3.DOWN * r.randf_range(1.2, 2.6), 0.08, 0.04, 4, MOSS.darkened(0.15))
		prev = at
	# Boulders round its feet.
	for x: float in [-half, half]:
		for k in 3:
			var at := Vector3(x + r.randf_range(-1.5, 1.5), 0, r.randf_range(-1.5, 1.5))
			l.prism(at + Vector3.DOWN * 0.3, at + Vector3.UP * r.randf_range(0.6, 1.4), r.randf_range(0.7, 1.2), 0.4, 6, ROCK_DARK)
	b.add(l)
	b.add(g)
	for x: float in [-half, half]:
		b.solid(Vector3(x, rise * 0.25, 0), Vector3(thick * 2.0, rise * 0.5, thick * 2.0))
	# Too high to reach, but it stops shots and flyers like the rock it is.
	for k in 5:
		var a := PI * (k + 0.5) / 5.0
		b.collider(Vector3(-cos(a) * half, sin(a) * rise, 0), Vector3(thick * 1.6, thick * 1.6, thick * 2.0))


## A canvas tent on poles, its door flap tied back: shelter for the outpost's scouts.
static func tent(b: MapBuilder, size: float) -> void:
	var l := b.mesh()
	var w := size * 0.5
	var high := size * 0.72
	var deep := size * 1.2
	for z: float in [-deep * 0.5, deep * 0.5]:
		l.prism(Vector3(0, 0, z), Vector3(0, high + 0.25, z), 0.06, 0.05, 5, LOG_DARK)
	l.prism(Vector3(0, high, -deep * 0.5 - 0.1), Vector3(0, high, deep * 0.5 + 0.1), 0.05, 0.05, 5, LOG_DARK)
	# Two sloping sheets and the back wall, canvas on both faces so it is never seen through.
	for side: float in [-1.0, 1.0]:
		var foot := Vector3(side * w, 0.05, 0)
		var ridge := Vector3(0, high, 0)
		var n := Vector3(side, w / high, 0).normalized()
		var c := CANVAS if side < 0 else CANVAS_DARK
		_sheet(l, foot + Vector3(0, 0, -deep * 0.5), ridge + Vector3(0, 0, -deep * 0.5), ridge + Vector3(0, 0, deep * 0.5), foot - n, c)
		_sheet(l, foot + Vector3(0, 0, -deep * 0.5), ridge + Vector3(0, 0, deep * 0.5), foot + Vector3(0, 0, deep * 0.5), foot - n, c)
	_sheet(l, Vector3(-w, 0.05, -deep * 0.5), Vector3(w, 0.05, -deep * 0.5), Vector3(0, high, -deep * 0.5), Vector3(0, high * 0.3, 0), CANVAS_DARK)
	# The door: laced shut with a darker panel, its flaps folded back at the edges, and the red stripe
	# of Mesenlla along the ridge.
	_sheet(l, Vector3(-w * 0.45, 0.05, deep * 0.5 - 0.02), Vector3(w * 0.45, 0.05, deep * 0.5 - 0.02), Vector3(0, high * 0.97, deep * 0.5 - 0.02), Vector3(0, high * 0.3, 0), CANVAS_DARK.darkened(0.25))
	for side: float in [-1.0, 1.0]:
		_sheet(l, Vector3(side * w, 0.05, deep * 0.5), Vector3(side * w * 0.45, high * 0.55, deep * 0.5 + 0.05), Vector3(0, high, deep * 0.5), Vector3(0, high * 0.3, deep * 0.4), CANVAS.lightened(0.08))
	l.box(Vector3(0, high + 0.02, 0), Vector3(0.3, 0.06, deep + 0.1), CRIMSON)
	# Guy ropes and pegs.
	for side: float in [-1.0, 1.0]:
		for z: float in [-deep * 0.4, deep * 0.4]:
			l.prism(Vector3(side * w * 0.5, high * 0.5, z), Vector3(side * (w + 0.9), 0.05, z), 0.015, 0.015, 3, Color(0.75, 0.7, 0.55))
	b.add(l)
	# The whole tent stops you: its low sides as a wide block, and the higher middle under the ridge.
	b.solid(Vector3(0, high * 0.25, 0), Vector3(size * 0.95, high * 0.5, deep))
	b.solid(Vector3(0, high * 0.7, 0), Vector3(size * 0.5, high * 0.45, deep))


## A triangle of canvas with both faces drawn: the one turned away from `inside`, and its back.
static func _sheet(l: LowPoly, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, col: Color) -> void:
	l._tri(a, b, c, inside, col)
	var middle := (a + b + c) / 3.0
	l._tri(a, b, c, middle + (middle - inside), col.darkened(0.2))


## Red pennants strung on a sagging line between two poles, across the piece's X axis.
static func bunting(b: MapBuilder, length: float) -> void:
	var l := b.cell()
	var half := length * 0.5
	var tall := 4.2
	var ends: Array[Vector3] = []
	for x: float in [-half, half]:
		var foot := b.xf.affine_inverse() * b.on_ground(Vector3(x, 0, 0))
		l.prism(foot + Vector3.DOWN * 0.3, foot + Vector3.UP * tall, 0.07, 0.05, 5, LOG_DARK)
		l.prism(foot + Vector3.UP * tall, foot + Vector3.UP * (tall + 0.2), 0.08, 0.0, 4, AMBER)
		ends.append(foot + Vector3.UP * (tall - 0.2))
		b.solid(foot + Vector3.UP * 1.0, Vector3(0.25, 2.0, 0.25))
	var count := maxi(4, int(length / 0.9))
	var prev := ends[0]
	for k in count + 1:
		var t := float(k) / count
		var at := ends[0].lerp(ends[1], t) + Vector3.DOWN * sin(t * PI) * length * 0.08
		if k > 0:
			l.prism(prev, at, 0.012, 0.012, 3, Color(0.75, 0.7, 0.55))
			if k < count:
				var mid := (prev + at) * 0.5
				var col := CRIMSON if k % 3 else AMBER.darkened(0.1)
				l._tri(mid + Vector3(-0.22, 0, 0), mid + Vector3(0.22, 0, 0), mid + Vector3(0, -0.55, 0), mid + Vector3(0, -0.2, -1), col)
				l._tri(mid + Vector3(0.22, 0, 0), mid + Vector3(-0.22, 0, 0), mid + Vector3(0, -0.55, 0), mid + Vector3(0, -0.2, 1), col)
		prev = at


## Long red banners hung flat against a wall, the piece's front facing out from it (+Z), with a
## lantern between each pair: dressing for the outpost's hall.
static func wall_banners(b: MapBuilder, width: float) -> void:
	var l := b.cell()
	var count := maxi(2, int(width / 3.2))
	for k in count:
		var x := (float(k) + 0.5) / count * width - width * 0.5
		l.box(Vector3(x, 3.4, 0.04), Vector3(1.0, 0.08, 0.08), LOG_DARK)
		l.box(Vector3(x, 2.2, 0.06), Vector3(0.8, 2.3, 0.03), CRIMSON)
		l.box(Vector3(x, 2.4, 0.08), Vector3(0.36, 0.36, 0.02), AMBER)
		l._tri(Vector3(x - 0.4, 1.05, 0.06), Vector3(x + 0.4, 1.05, 0.06), Vector3(x, 0.7, 0.06), Vector3(x, 1.0, -1), CRIMSON)
	var glow := b.mesh()
	for k in count - 1:
		var x := (float(k) + 1.0) / count * width - width * 0.5
		glow.box(Vector3(x, 2.6, 0.25), Vector3(0.24, 0.32, 0.24), AMBER)
		b.w.add_glow(b.xf * Vector3(x, 2.6, 0.4), AMBER, 2.2, 120.0)
	_shine(b, glow)


## The forest floor in a ring: ferns, mushrooms (a few of them glowing), mossy stones and a stump.
static func undergrowth(b: MapBuilder, radius: float) -> void:
	var r := b.seeded()
	var l := b.cell()
	var glow := b.mesh()
	var glowing := false
	var count := int(radius * radius * 0.35)
	for k in count:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * radius
		var at := b.xf.affine_inverse() * b.on_ground(Vector3(cos(a) * d, 0, sin(a) * d))
		match k % 6:
			0, 1, 2:
				# A fern: fronds arching out from the middle.
				var fronds := 5
				var size := r.randf_range(0.5, 0.95)
				for f in fronds:
					var fa := TAU * f / fronds + r.randf()
					var tip := at + Vector3(cos(fa) * size, size * 0.55, sin(fa) * size)
					l.prism(at, tip, 0.09, 0.02, 3, PINE if f % 2 else MOSS)
			3:
				var size := r.randf_range(0.25, 0.5)
				l.prism(at, at + Vector3.UP * size, 0.05, 0.04, 4, Color(0.85, 0.8, 0.7))
				var cap := CRIMSON.lightened(0.1) if r.randf() < 0.6 else Color(0.8, 0.6, 0.35)
				l.prism(at + Vector3.UP * size, at + Vector3.UP * (size + 0.14), size * 0.55, 0.05, 6, cap)
			4:
				if r.randf() < 0.45:
					# A glowing mushroom of the mist.
					var size := r.randf_range(0.2, 0.4)
					glow.prism(at, at + Vector3.UP * size, 0.04, 0.03, 4, MIST_GLOW.lightened(0.3))
					glow.prism(at + Vector3.UP * size, at + Vector3.UP * (size + 0.1), size * 0.6, 0.04, 6, MIST_GLOW)
					glowing = true
				else:
					l.prism(at + Vector3.DOWN * 0.1, at + Vector3.UP * r.randf_range(0.2, 0.45), r.randf_range(0.3, 0.6), 0.15, 5, ROCK_DARK)
					l.prism(at + Vector3.UP * 0.2, at + Vector3.UP * 0.35, 0.4, 0.1, 5, MOSS)
			5:
				if r.randf() < 0.25:
					l.prism(at, at + Vector3.UP * 0.5, 0.45, 0.4, 7, BARK)
					l.prism(at + Vector3.UP * 0.5, at + Vector3.UP * 0.53, 0.4, 0.36, 7, LOG.lightened(0.2))
	if glowing:
		_shine(b, glow)


# --- Trees of the valley ------------------------------------------------------------------------

static var _tree_meshes := {}


## The valley's own trees, at size 1 (MapTree scales them): "giant_fir", an old fir three times a
## man's reach of the common ones, its trunk bare far up; "tall_pine", slender with a high crown; and
## "mossy_oak", broad and low with a heavy round crown and moss on its limbs.
static func tree_mesh(kind: String) -> Mesh:
	if _tree_meshes.has(kind):
		return _tree_meshes[kind]
	var l := LowPoly.new()
	var r := RandomNumberGenerator.new()
	r.seed = hash(kind)
	match kind:
		"giant_fir":
			l.prism(Vector3.DOWN * 0.1, Vector3.UP * 2.9, 0.085, 0.02, 7, BARK)
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				l.prism(Vector3.ZERO, Vector3(cos(a) * 0.17, -0.05, sin(a) * 0.17), 0.05, 0.01, 4, BARK.darkened(0.1))
			# Tiers of boughs from a third of the way up, wide at the bottom, narrowing to a spire.
			var tiers := 11
			for k in tiers:
				var t := float(k) / tiers
				var y := 0.55 + t * 2.2
				var w := lerpf(0.8, 0.14, pow(t, 0.9)) * r.randf_range(0.92, 1.08)
				l.prism(Vector3(0, y, 0), Vector3(0, y + 0.5, 0), w, 0.0, 9, PINE if k % 2 else PINE_DARK)
			l.prism(Vector3(0, 2.75, 0), Vector3(0, 3.1, 0), 0.08, 0.0, 6, PINE)
		"tall_pine":
			l.prism(Vector3.DOWN * 0.1, Vector3.UP * 1.8, 0.05, 0.015, 6, BARK.lightened(0.15))
			for k in 5:
				var t := float(k) / 5.0
				var y := 0.9 + t * 0.9
				var w := lerpf(0.36, 0.1, t)
				l.prism(Vector3(0, y, 0), Vector3(0, y + 0.3, 0), w, 0.0, 7, PINE.lightened(0.06) if k % 2 else PINE)
		"mossy_oak":
			l.prism(Vector3.DOWN * 0.1, Vector3.UP * 0.55, 0.12, 0.09, 7, BARK)
			for k in 4:
				var a := TAU * k / 4.0 + r.randf()
				var limb := Vector3(cos(a) * 0.42, 0.85, sin(a) * 0.42)
				l.prism(Vector3.UP * 0.5, limb, 0.07, 0.04, 5, BARK)
				l.prism(Vector3.UP * 0.5 + (limb - Vector3.UP * 0.5) * 0.3, limb, 0.05, 0.03, 4, MOSS)
			# A heavy crown of round clumps.
			for k in 7:
				var a := TAU * k / 7.0
				var d := 0.35 if k else 0.0
				var at := Vector3(cos(a) * d, 1.0 + r.randf_range(-0.08, 0.12), sin(a) * d)
				var size := r.randf_range(0.3, 0.42)
				l.prism(at + Vector3.DOWN * size * 0.6, at + Vector3.UP * size * 0.6, size, size * 0.55, 8, MOSS_LIGHT.darkened(0.25) if k % 2 else MOSS.darkened(0.15))
			l.prism(Vector3(0, 1.2, 0), Vector3(0, 1.48, 0), 0.4, 0.12, 8, MOSS_LIGHT.darkened(0.2))
	_tree_meshes[kind] = l.commit()
	return _tree_meshes[kind]


# --- The south of the Valleys: ruins, an old mine and the shrines ------------------------------------

const SHRINE_GLOW := {"stag": Color(0.55, 1.0, 0.75), "bear": Color(1.0, 0.55, 0.3), "spring": Color(0.5, 0.8, 1.0)}


## A shrine of the old valley folk: a carved stone over a basin of glowing water, with the sign of what
## it gives (a stag's antlers, a bear's claw, a spring's drop). Touch it for its blessing; it rests a
## while after. See World.shrines and Player.bless.
static func shrine(b: MapBuilder, blessing: String) -> void:
	var glow_col: Color = SHRINE_GLOW.get(blessing, MIST_GLOW)
	var l := b.cell()
	l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.3, 0), 1.6, 1.4, 8, ROCK_DARK)
	l.prism(Vector3(0, 0.3, 0), Vector3(0, 0.45, 0), 1.4, 1.35, 8, ROCK)
	# The basin, and the carved stone behind it.
	l.prism(Vector3(0, 0.45, 0.35), Vector3(0, 0.95, 0.35), 0.6, 0.75, 8, ROCK)
	l.prism(Vector3(0, 0.45, -0.75), Vector3(0, 2.6, -0.8), 0.5, 0.36, 4, ROCK_DARK)
	l.prism(Vector3(0, 2.6, -0.8), Vector3(0, 2.95, -0.8), 0.36, 0.0, 4, MOSS)
	for k in 5:
		var a := TAU * k / 5.0
		l.prism(Vector3(cos(a) * 1.3, 0.45, sin(a) * 1.3), Vector3(cos(a) * 1.3, 0.62, sin(a) * 1.3), 0.12, 0.08, 5, Color(0.85, 0.82, 0.7))
	b.solid(Vector3(0, 0.5, -0.2), Vector3(1.6, 1.0, 2.0))
	var g := b.mesh()
	g.prism(Vector3(0, 0.9, 0.35), Vector3(0, 0.97, 0.35), 0.5, 0.5, 8, glow_col)
	var face := Vector3(0, 1.8, -0.5)
	match blessing:
		"stag":
			for side: float in [-1.0, 1.0]:
				g.prism(face, face + Vector3(side * 0.28, 0.5, 0), 0.04, 0.03, 3, glow_col)
				g.prism(face + Vector3(side * 0.16, 0.3, 0), face + Vector3(side * 0.34, 0.36, 0), 0.03, 0.02, 3, glow_col)
		"bear":
			for k in 3:
				g.prism(face + Vector3(-0.2 + k * 0.2, 0.35, 0), face + Vector3(-0.15 + k * 0.17, -0.3, 0), 0.05, 0.01, 3, glow_col)
		_:
			g.prism(face + Vector3(0, -0.25, 0), face + Vector3(0, 0.05, 0), 0.18, 0.18, 8, glow_col)
			g.prism(face + Vector3(0, 0.05, 0), face + Vector3(0, 0.35, 0), 0.18, 0.0, 8, glow_col)
	var shine := _shine(b, g)
	var halo: MeshInstance3D = b.w.add_glow(b.xf * Vector3(0, 1.4, 0), glow_col, 3.2, 120.0)
	_mist(b, Vector3(0, 1.1, 0.35), Vector3(0.4, 0.2, 0.4), glow_col, 5, 0.4)
	if not b.is_preview:
		b.w.shrines.append({"at": b.xf.origin, "blessing": blessing, "glow": [shine, halo], "ready_at": 0.0})


## The ruins of an old hall: a floor of cracked slabs, a ring of broken columns, fallen drums of stone
## and a lintel still standing on two of them, all of it mossed over. size is the ring's radius.
static func ruins(b: MapBuilder, size: float) -> void:
	var r := b.seeded()
	var l := b.cell()
	# The floor, slab by slab, some of it lifted or gone.
	var step := 1.8
	var x := -size
	while x <= size:
		var z := -size
		while z <= size:
			if Vector2(x, z).length() < size + 0.5 and r.randf() < 0.82:
				var at := b.xf.affine_inverse() * b.on_ground(Vector3(x, 0, z))
				l.box(at + Vector3(0, 0.06 + r.randf_range(0.0, 0.08), 0), Vector3(step - 0.12, 0.16, step - 0.12), ROCK if (int(x / step) + int(z / step)) % 2 else ROCK.darkened(0.12), Vector3(r.randf_range(-3, 3), 0, r.randf_range(-3, 3)))
			z += step
		x += step
	var columns := 8
	for k in columns:
		var a := TAU * k / columns
		var foot := b.xf.affine_inverse() * b.on_ground(Vector3(cos(a) * size, 0, sin(a) * size))
		var high := 4.6 if k in [0, 1] else r.randf_range(0.8, 3.6)
		l.prism(foot, foot + Vector3.UP * high, 0.42, 0.38, 8, ROCK)
		l.prism(foot + Vector3.UP * high, foot + Vector3.UP * (high + 0.12), 0.38, 0.3, 8, MOSS if k % 2 else MOSS_LIGHT)
		b.solid(foot + Vector3.UP * high * 0.5, Vector3(0.8, high, 0.8))
		if k > 1 and r.randf() < 0.7:
			# A drum of it fallen alongside.
			var out := Vector3(cos(a), 0, sin(a)) * r.randf_range(1.2, 2.4) + Vector3(-sin(a), 0, cos(a)) * r.randf_range(-1.0, 1.0)
			var lie := foot + out + Vector3.UP * 0.38
			var along := Vector3(-sin(a + r.randf_range(-0.6, 0.6)), 0, cos(a + r.randf_range(-0.6, 0.6)))
			l.prism(lie - along * 0.6, lie + along * 0.6, 0.38, 0.38, 8, ROCK_DARK)
	# The lintel across the two tallest.
	var a0 := Vector3(cos(0.0), 0, sin(0.0)) * size
	var a1 := Vector3(cos(TAU / columns), 0, sin(TAU / columns)) * size
	var top := maxf((b.xf.affine_inverse() * b.on_ground(a0)).y, (b.xf.affine_inverse() * b.on_ground(a1)).y) + 4.75
	l.prism(Vector3(a0.x, top, a0.z), Vector3(a1.x, top, a1.z), 0.32, 0.32, 4, ROCK_DARK)
	_feature(b, "ruins", size)


## The mouth of an old mine in a slope, facing out along +Z: a frame of timbers round a dark way in,
## rails running out of it, a tipped cart and a lantern still burning.
static func mine(b: MapBuilder, size: float) -> void:
	var l := b.mesh()
	var wide := size * 0.5
	var high := size * 0.6
	# The dark of the way in, and the rock face round it.
	l.box(Vector3(0, high * 0.5, -1.2), Vector3(wide * 2.0 + 0.4, high + 0.2, 0.3), Color(0.04, 0.03, 0.05))
	for side: float in [-1.0, 1.0]:
		l.box(Vector3(side * (wide + 2.2), high * 0.6, -1.0), Vector3(3.6, high * 1.4, 3.0), ROCK_DARK)
	l.box(Vector3(0, high + 1.4, -1.0), Vector3(wide * 2.0 + 8.0, 2.8, 3.0), ROCK)
	l.box(Vector3(0, high + 2.85, -1.0), Vector3(wide * 2.0 + 8.0, 0.2, 3.0), MOSS)
	# The timber frame, in three sets going in.
	for k in 3:
		var z := -k * 1.4
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(side * wide, 0, z), Vector3(side * wide * 0.92, high, z), 0.16, 0.14, 5, LOG_DARK)
		l.box(Vector3(0, high, z), Vector3(wide * 2.0 + 0.5, 0.26, 0.3), LOG)
	# Rails out of the mine, and the cart that ran on them.
	for side: float in [-0.45, 0.45]:
		l.box(Vector3(side, 0.06, 2.5), Vector3(0.08, 0.08, 7.0), Color(0.35, 0.33, 0.33))
	for k in 8:
		l.box(Vector3(0, 0.03, -0.6 + k * 0.9), Vector3(1.3, 0.07, 0.22), LOG_DARK)
	l.box(Vector3(1.8, 0.55, 4.6), Vector3(1.2, 0.8, 1.6), LOG.darkened(0.15), Vector3(0, 20, 62))
	b.add(l)
	b.solid(Vector3(0, high * 0.5 + 0.5, -2.6), Vector3(wide * 2.0 + 8.0, high + 4.0, 3.0))
	for side: float in [-1.0, 1.0]:
		b.solid(Vector3(side * (wide + 2.2), high * 0.6, -1.0), Vector3(3.6, high * 1.4, 3.0))
	b.solid(Vector3(1.8, 0.5, 4.6), Vector3(1.4, 1.0, 1.8))
	var lamp := b.mesh()
	lamp.box(Vector3(-wide - 0.1, high * 0.8, 0.2), Vector3(0.28, 0.36, 0.28), AMBER)
	_shine(b, lamp)
	b.w.add_glow(b.xf * Vector3(-wide - 0.1, high * 0.8, 0.2), AMBER, 3.0, 150.0)
	_feature(b, "mine", size)
