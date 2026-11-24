class_name SeaSerpentBody
extends Node3D
## A Deepcaller's sea serpent: a long neck of deep-green scale reared out of a pool of seawater that
## goes wherever it goes, a crest of glowing fin down its back, a frilled head with a jaw that drops
## open and two pale eyes. It rises out of the pool, sways, coils back and lunges when it bites, and
## sinks back into the pool when it falls. Faces +Z; the pool lies on the ground at its feet.

const SEGMENTS := 11
const NECK := 2.5 # how high the head is carried
const RISE_TIME := 0.7
const SINK_TIME := 0.9
const SCALE := Color(0.12, 0.44, 0.42)
const SCALE_DARK := Color(0.04, 0.2, 0.22)
const BELLY := Color(0.72, 0.8, 0.62)
const FIN := Color(0.35, 1.0, 0.82)
const EYE := Color(0.95, 0.9, 0.35)

var moving := false
var biting := false
var _bones: Array[Node3D] = []
var _head: Node3D
var _jaw: Node3D
var _pool: Node3D
var _foam: MeshInstance3D
var _spray: CPUParticles3D
static var _swirl_shader: Shader
var _t := 0.0
var _rise := 0.0 # 0 under the ground, 1 reared up
var _sinking := false
var _strike := 0.0 # 0 at rest; up to 1 as it lunges; below 0 as it coils back
var _bite_t := -1.0
static var _parts := {}


func _init() -> void:
	name = "SeaSerpent"
	_build()


func rise() -> void:
	_rise = 0.0
	_sinking = false
	_bite_t = -1.0


func sink() -> void:
	_sinking = true


static func _meshes() -> Dictionary:
	if not _parts.is_empty():
		return _parts
	# One length of neck, a unit long along +Z: scaled to each bone's width. Scale on the back, a pale
	# belly underneath, a glowing fin rising from the top, and a ring of barnacles now and then.
	var segs: Array[Mesh] = []
	for shade in 2:
		var seg := LowPoly.new()
		var body := SCALE.darkened(0.12 * shade)
		seg.prism(Vector3(0, 0, -0.04), Vector3(0, 0, 1.04), 1.0, 0.92, 8, body)
		# Darker scale down the back (local +Y), the pale belly down the front (local -Y).
		seg.prism(Vector3(0, 0.5, 0.0), Vector3(0, 0.5, 1.0), 0.55, 0.5, 6, SCALE_DARK)
		seg.prism(Vector3(0, -0.45, 0.05), Vector3(0, -0.45, 0.95), 0.6, 0.55, 6, BELLY.darkened(0.08 * shade))
		for k in 3:
			var z := 0.2 + k * 0.3
			seg.prism(Vector3(0, 0.9, z), Vector3(0, 1.25, z + 0.1), 0.09, 0.0, 4, SCALE_DARK) # a spine
		segs.append(seg.commit())
	var fin := LowPoly.new()
	fin.leaf(Vector3(0, 0.85, 0.0), Vector3(0, 1.9, -0.35), Vector3(0, 0.85, 1.0), FIN)
	fin.leaf(Vector3(0, 0.85, 0.3), Vector3(0, 1.45, -0.1), Vector3(0, 0.85, 0.9), FIN.lightened(0.3))
	var head := LowPoly.new()
	# The skull: long and flat, wider at the back, a ridge over each eye, frills fanning behind.
	head.prism(Vector3(0, 0.0, -0.1), Vector3(0, -0.02, 0.95), 0.36, 0.2, 8, SCALE)
	head.box(Vector3(0, 0.16, 0.35), Vector3(0.34, 0.1, 0.5), SCALE_DARK)
	for side: float in [-1.0, 1.0]:
		head.prism(Vector3(side * 0.2, 0.18, 0.2), Vector3(side * 0.22, 0.24, 0.48), 0.07, 0.03, 5, SCALE_DARK)
		head.leaf(Vector3(side * 0.24, 0.05, -0.05), Vector3(side * 0.85, 0.4, -0.45), Vector3(side * 0.3, 0.3, 0.25), FIN.darkened(0.25))
		head.leaf(Vector3(side * 0.2, -0.05, 0.0), Vector3(side * 0.7, -0.15, -0.5), Vector3(side * 0.28, 0.12, 0.2), FIN.darkened(0.45))
		for k in 4:
			head.prism(Vector3(side * 0.13, -0.1, 0.55 + k * 0.1), Vector3(side * 0.13, -0.2, 0.57 + k * 0.1), 0.025, 0.0, 3, Color(0.95, 0.93, 0.85))
	head.prism(Vector3(0, 0.12, -0.15), Vector3(0, 0.55, -0.5), 0.08, 0.0, 4, FIN.darkened(0.2))
	var eyes := LowPoly.new()
	for side: float in [-1.0, 1.0]:
		eyes.prism(Vector3(side * 0.25, 0.13, 0.4), Vector3(side * 0.29, 0.13, 0.4), 0.045, 0.045, 6, EYE)
	var jaw := LowPoly.new()
	jaw.prism(Vector3(0, 0, 0), Vector3(0, -0.04, 0.82), 0.26, 0.12, 7, SCALE_DARK)
	jaw.prism(Vector3(0, -0.06, 0.05), Vector3(0, -0.08, 0.7), 0.16, 0.08, 6, BELLY.darkened(0.25))
	for side: float in [-1.0, 1.0]:
		for k in 4:
			jaw.prism(Vector3(side * 0.11, 0.04, 0.5 + k * 0.08), Vector3(side * 0.11, 0.14, 0.52 + k * 0.08), 0.022, 0.0, 3, Color(0.95, 0.93, 0.85))
	var pool := LowPoly.new()
	# Wet rocks round the edge of the pool, dark with weed.
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		pool.box(Vector3(cos(a) * 1.3, 0.06, sin(a) * 1.3), Vector3(0.3, 0.16, 0.24), Color(0.2, 0.23, 0.22).lerp(Color(0.12, 0.3, 0.18), 0.3 * (i % 2)), Vector3(0, rad_to_deg(a) + 20.0 * sin(i), 8.0 * cos(i * 2.0)))
	_parts = {"seg": segs[0], "seg_dark": segs[1], "fin": fin.commit(), "head": head.commit(), "eyes": eyes.commit(), "jaw": jaw.commit(),
		"pool": pool.commit()}
	return _parts


func _build() -> void:
	var m := _meshes()
	_pool = Node3D.new()
	add_child(_pool)
	_add(_pool, m["pool"])
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.25
	disc.bottom_radius = 1.25
	disc.height = 0.02
	disc.radial_segments = 28
	water.mesh = disc
	water.position.y = 0.04
	var swirl := ShaderMaterial.new()
	swirl.shader = _water_shader()
	water.material_override = swirl
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool.add_child(water)
	_foam = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.62
	ring.rings = 20
	ring.ring_segments = 5
	_foam.mesh = ring
	var froth := StandardMaterial3D.new()
	froth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	froth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	froth.albedo_color = Color(0.86, 1.0, 0.97, 0.6)
	_foam.material_override = froth
	_foam.position.y = 0.07
	_foam.scale = Vector3(1, 0.25, 1)
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool.add_child(_foam)
	# Spray thrown up where the neck leaves the water.
	_spray = CPUParticles3D.new()
	_spray.amount = 14
	_spray.lifetime = 0.8
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_spray.emission_ring_axis = Vector3.UP
	_spray.emission_ring_radius = 0.5
	_spray.emission_ring_inner_radius = 0.35
	_spray.emission_ring_height = 0.0
	_spray.direction = Vector3.UP
	_spray.spread = 35.0
	_spray.gravity = Vector3(0, -7.0, 0)
	_spray.initial_velocity_min = 1.2
	_spray.initial_velocity_max = 2.4
	var drop := SphereMesh.new()
	drop.radius = 0.04
	drop.height = 0.08
	drop.radial_segments = 4
	drop.rings = 2
	var wet := StandardMaterial3D.new()
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet.albedo_color = Color(0.78, 0.98, 0.96)
	drop.material = wet
	_spray.mesh = drop
	_spray.position.y = 0.1
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool.add_child(_spray)
	var glow := MesenllaModels.glow_material()
	for i in SEGMENTS:
		var bone := Node3D.new()
		add_child(bone)
		var flesh := _add(bone, m["seg" if i % 2 == 0 else "seg_dark"])
		flesh.name = "Flesh"
		if i >= 1:
			var fin := _add(bone, m["fin"])
			fin.material_override = glow
			fin.name = "Fin"
		_bones.append(bone)
	_head = Node3D.new()
	add_child(_head)
	_add(_head, m["head"])
	var eyes := _add(_head, m["eyes"])
	eyes.material_override = glow
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.08, 0.05)
	_head.add_child(_jaw)
	_add(_jaw, m["jaw"])
	var light := OmniLight3D.new()
	light.light_color = FIN
	light.light_energy = 0.6
	light.omni_range = 4.0
	light.position = Vector3(0, 0.4, 0.4)
	_head.add_child(light)
	_pose(0.0)


static func _water_shader() -> Shader:
	if _swirl_shader == null:
		_swirl_shader = Shader.new()
		_swirl_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float spiral = sin(a * 3.0 + r * 10.0 - TIME * 4.0) * 0.5 + 0.5;
	vec3 deep = vec3(0.02, 0.12, 0.14);
	vec3 lit = vec3(0.25, 0.75, 0.68);
	ALBEDO = mix(deep, lit, spiral * 0.45 * (1.0 - r) + smoothstep(0.85, 1.0, r) * 0.6);
	ALPHA = 0.9 * (1.0 - smoothstep(0.92, 1.0, r));
}
"""
	return _swirl_shader


func _add(to: Node3D, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	to.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if _sinking:
		_rise = maxf(0.0, _rise - delta / SINK_TIME)
	else:
		_rise = minf(1.0, _rise + delta / RISE_TIME)
	# A bite: coil back, then lunge, then draw back up.
	if biting and _bite_t < 0.0:
		_bite_t = 0.0
	if _bite_t >= 0.0:
		_bite_t += delta
		var f := _bite_t / 0.42
		if f < 0.35:
			_strike = -smoothstep(0.0, 0.35, f) * 0.6
		elif f < 0.6:
			_strike = lerpf(-0.6, 1.0, smoothstep(0.35, 0.6, f))
		else:
			_strike = lerpf(1.0, 0.0, smoothstep(0.6, 1.0, f))
		if f >= 1.0:
			_bite_t = -1.0
			_strike = 0.0
	_pose(delta)


## Lays the neck along its curve: up out of the pool, leaning back, curling forward at the head;
## swaying side to side, more when it moves; coiled back or flung forward when it bites.
func _pose(delta: float) -> void:
	var rise := 1.0 - pow(1.0 - _rise, 3.0)
	var sway := 0.22 + (0.18 if moving else 0.0)
	var points: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var s := float(i) / SEGMENTS
		var up := NECK * (1.0 - pow(1.0 - s, 2.0)) * rise - (1.0 - rise) * 1.2
		# An S: the lower neck leans back, the upper neck arches forward over the head.
		var fwd := -0.55 * sin(s * PI) * s + 1.25 * s * s * s
		fwd += _strike * 1.5 * s * s
		up -= maxf(0.0, _strike) * 0.8 * s * s
		var side := sin(_t * (2.4 if moving else 1.3) - s * 3.4) * sway * s
		points.append(Vector3(side, up, fwd))
	for i in SEGMENTS:
		var a := points[i]
		var b := points[i + 1]
		var along := b - a
		var width := lerpf(0.42, 0.2, float(i) / SEGMENTS) * (1.0 + 0.05 * sin(_t * 2.0 - i * 0.8))
		var bone := _bones[i]
		bone.visible = a.y > -0.15 or b.y > -0.15
		if along.length() < 0.001:
			continue
		# Its back (local +Y) to the rear and its belly to the front, however the neck bends.
		var basis := Basis.looking_at(-along.normalized(), along.normalized().cross(Vector3.RIGHT))
		bone.transform = Transform3D(basis.scaled(Vector3(width, width, along.length())), a)
	var tip := points[SEGMENTS]
	var dir := (points[SEGMENTS] - points[SEGMENTS - 1]).normalized()
	var look := Vector3(dir.x, dir.y * 0.4 - 0.25 - maxf(0.0, _strike) * 0.35, maxf(0.2, dir.z + 0.6)).normalized()
	_head.transform = Transform3D(Basis.looking_at(-look, Vector3.UP), tip)
	_head.visible = tip.y > -0.2
	_jaw.rotation.x = lerpf(_jaw.rotation.x, 0.75 if _strike > 0.2 or _strike < -0.3 else 0.08 + 0.05 * sin(_t * 1.7), minf(1.0, delta * 14.0)) if delta > 0.0 else 0.08
	_pool.scale = Vector3.ONE * maxf(0.05, minf(1.0, _rise * 1.6 + (0.4 if not _sinking else 0.0)))
	_foam.rotation.y = _t * 0.9
	_foam.scale = Vector3(1.0 + 0.08 * sin(_t * 3.0), 0.25, 1.0 + 0.08 * sin(_t * 3.0))
	_spray.emitting = _rise > 0.05 and (moving or _bite_t >= 0.0 or _rise < 1.0 or _sinking)
