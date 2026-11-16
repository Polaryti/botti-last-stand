class_name Ambience
extends Node3D
## The air of the lands beyond the Mists, around whoever is looking: long wisps of mist drifting
## through the trees on the wind, motes of mist light hanging and wandering in the twilight, and in the
## Valleys of Mesenlla leaves coming down from the forest; at Mist Bastion fine mist sifting down and
## sparks of the Great Portal carried up on the wind. It follows the camera, so it costs the same
## wherever you are, and it is only drawn on this phone.

const WISPS := 9
const WISP_REACH := 30.0 # how far round the camera the wisps drift before they come round again
const WIND := Vector3(0.9, 0.0, 0.35)

var world: World
var _wisps: Array[MeshInstance3D] = []
var _motes: CPUParticles3D
var _falling: CPUParticles3D
static var _wisp_material: ShaderMaterial


func _init(w: World) -> void:
	world = w
	name = "Ambience"


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 9157
	var quiet := Game.quality == 0
	for i in (WISPS / 2 if quiet else WISPS):
		var wisp := MeshInstance3D.new()
		wisp.mesh = _wisp_mesh(r.randf_range(7.0, 13.0), r.randf_range(0.8, 1.6), r)
		# Each wisp fades on its own, so each has its own copy of the look.
		wisp.material_override = _wisp_look().duplicate()
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisp.set_meta("drift", r.randf_range(0.6, 1.3))
		wisp.set_meta("height", r.randf_range(1.2, 6.0))
		wisp.set_meta("phase", r.randf() * TAU)
		wisp.position = Vector3(r.randf_range(-WISP_REACH, WISP_REACH), 0, r.randf_range(-WISP_REACH, WISP_REACH))
		wisp.rotation.y = atan2(WIND.x, WIND.z) + r.randf_range(-0.4, 0.4)
		add_child(wisp)
		_wisps.append(wisp)
	var bastion := world.map_id == "bastion"
	_motes = _particles(0 if quiet else (60 if bastion else 80), Vector3(22, 4, 22), 0.14, 7.0)
	_motes.color = Color(0.55, 1.0, 0.95, 0.9) if not bastion else Color(1.0, 0.7, 0.4, 0.9)
	_motes.gravity = Vector3(0, 0.05 if not bastion else 0.35, 0)
	_motes.initial_velocity_min = 0.05
	_motes.initial_velocity_max = 0.3
	_motes.spread = 180.0
	add_child(_motes)
	if bastion:
		# Fine mist sifting down on the mountaintop.
		_falling = _particles(40 if quiet else 110, Vector3(18, 2, 18), 0.09, 9.0)
		_falling.color = Color(0.85, 0.92, 1.0, 0.7)
		_falling.gravity = Vector3(0.3, -0.5, 0.1)
	else:
		# Leaves coming down out of the forest, turning as they fall.
		_falling = _particles(20 if quiet else 50, Vector3(18, 2, 18), 0.16, 10.0)
		_falling.color_ramp = null
		_falling.color_initial_ramp = _leaf_colours()
		_falling.gravity = Vector3(0.25, -0.6, 0.1)
		_falling.angular_velocity_min = -160.0
		_falling.angular_velocity_max = 160.0
		_falling.angle_max = 360.0
	_falling.position.y = 9.0
	add_child(_falling)


## Particles in a box round the camera that glow without light, coming and going softly.
func _particles(amount: int, extents: Vector3, size: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/sprites/glow.png")
	m.disable_fog = true
	q.material = m
	p.mesh = q
	p.amount = maxi(1, amount)
	p.emitting = amount > 0
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _leaf_colours() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0.42, 0.62, 0.28))
	g.add_point(0.5, Color(0.8, 0.55, 0.2))
	g.set_color(g.get_point_count() - 1, Color(0.62, 0.2, 0.15))
	return g


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	_motes.global_position = eye
	_falling.global_position = eye + Vector3.UP * 7.0
	var t := world.now
	for wisp in _wisps:
		var drift: float = wisp.get_meta("drift")
		wisp.global_position += WIND * drift * delta
		# Round again on the far side when it has drifted out of reach.
		var off := wisp.global_position - eye
		if absf(off.x) > WISP_REACH:
			wisp.global_position.x = eye.x - signf(off.x) * WISP_REACH * 0.95
		if absf(off.z) > WISP_REACH:
			wisp.global_position.z = eye.z - signf(off.z) * WISP_REACH * 0.95
		var ground := world.ground_at(wisp.global_position)
		wisp.global_position.y = ground + float(wisp.get_meta("height")) + sin(t * 0.3 + float(wisp.get_meta("phase"))) * 0.6
		# Thin near the eye, so one never fills the screen, and fading at the edge of its reach.
		var flat := Vector2(off.x, off.z).length()
		var fade := clampf((flat - 3.0) / 6.0, 0.0, 1.0) * clampf((WISP_REACH - flat) / 6.0, 0.0, 1.0)
		(wisp.material_override as ShaderMaterial).set_shader_parameter("fade", fade)


## A long, twisting ribbon of mist, along Z.
func _wisp_mesh(length: float, width: float, r: RandomNumberGenerator) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	var twist := r.randf_range(-1.2, 1.2)
	var bend := r.randf_range(-1.5, 1.5)
	var rows: Array = []
	for k in steps + 1:
		var t := float(k) / steps
		var z := (t - 0.5) * length
		var a := t * twist
		var across := Vector3(cos(a), sin(a) * 0.6, 0) * width * (0.35 + sin(t * PI) * 0.65)
		var mid := Vector3(sin(t * PI * 1.3) * bend, sin(t * PI * 2.0) * 0.4, z)
		rows.append([mid - across, mid + across, t])
	for k in steps:
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		for v: Array in [[a[0], 0.0, a[2]], [a[1], 1.0, a[2]], [b[1], 1.0, b[2]], [a[0], 0.0, a[2]], [b[1], 1.0, b[2]], [b[0], 0.0, b[2]]]:
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(v[0])
	return st.commit()


static func _wisp_look() -> ShaderMaterial:
	if _wisp_material:
		return _wisp_material
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;
uniform float fade = 1.0;
uniform vec3 mist = vec3(0.86, 0.84, 1.0);
void fragment() {
	// Soft across the ribbon and at both ends, with a slow ripple running along it.
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = sin(UV.y * 3.14159);
	float ripple = 0.75 + 0.25 * sin(UV.y * 18.0 - TIME * 0.8 + UV.x * 3.0);
	ALBEDO = mist;
	ALPHA = smoothstep(0.0, 0.8, across) * along * ripple * 0.22 * fade;
}
"""
	_wisp_material = ShaderMaterial.new()
	_wisp_material.shader = sh
	return _wisp_material
