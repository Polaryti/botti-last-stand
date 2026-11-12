class_name NightfallDome
extends Node3D
## A Mercenary's Nightfall: a dome of night on the ground. Every phone makes its own copy and looks
## after its own people: friends of the Mercenary inside it turn invisible and stay so a moment after
## leaving; enemies inside barely see. Creatures are the host's, so only the host blinds them.

## The tree's switches, sent as bits so every phone's copy behaves alike.
const FLAGS := ["night_damage", "night_guard", "night_slow", "night_heal", "night_follow"]
const BLIND_SIGHT := 3.0 # how far a creature inside can still see

var world: World
var owner_peer := 0
var radius := 6.0
var linger := 1.5
var bits := 0
var _left := 8.0
var _life := 8.0
var _shell: MeshInstance3D
var _rim: MeshInstance3D
var _veil: CanvasLayer
var _rim_left := 0.0
static var _shell_shader: Shader
var _stars: GPUParticles3D


func _init(owner_world: World, peer: int, at: Vector3, dome_radius: float, seconds: float, linger_secs: float, switches: int) -> void:
	world = owner_world
	owner_peer = peer
	radius = dome_radius
	_left = seconds
	_life = seconds
	linger = linger_secs
	bits = switches
	position = at
	name = "Nightfall"


func has(flag: String) -> bool:
	return bits & (1 << FLAGS.find(flag)) != 0


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	# A whole sphere sunk to its middle, so it meets sloping ground on every side with no gap under it.
	sphere.is_hemisphere = false
	sphere.radial_segments = 32
	sphere.rings = 20
	_shell = MeshInstance3D.new()
	_shell.mesh = sphere
	_shell.material_override = _material()
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.scale = Vector3.ONE * 0.01
	add_child(_shell)
	# The edge of the night, lying on the ground however it slopes.
	_rim = MeshInstance3D.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.72, 0.5, 0.95)
	glow.disable_fog = true
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rim.material_override = glow
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rim)
	_lay_rim()
	# Seen from inside, the dark is over everything you look at, not on a line across the ground.
	_veil = CanvasLayer.new()
	_veil.layer = 0
	_veil.visible = false
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.material = _veil_material()
	_veil.add_child(shade)
	add_child(_veil)
	# A few slow motes of starlight inside the dark.
	_stars = GPUParticles3D.new()
	_stars.amount = 40
	_stars.lifetime = 2.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.8
	pm.gravity = Vector3(0, 0.15, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	_stars.process_material = pm
	var mote := QuadMesh.new()
	mote.size = Vector2(0.08, 0.08)
	mote.material = _mote_material()
	_stars.draw_pass_1 = mote
	_stars.position.y = radius * 0.35
	add_child(_stars)


## Dark glass: deepest at the edge, nearly clear on the top, with a faint violet sheen. From inside
## (inside = 1) only a faint sheen is left, since the veil over the screen does the darkening.
## Each dome has its own material, since one may be seen from inside while another is not.
func _material() -> ShaderMaterial:
	if _shell_shader == null:
		_shell_shader = Shader.new()
		_shell_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform float fade = 1.0;
uniform float inside = 0.0;
void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float band = 0.5 + 0.5 * sin(TIME * 0.7 + UV.y * 18.0);
	ALBEDO = mix(vec3(0.03, 0.02, 0.07), vec3(0.42, 0.26, 0.62), edge * 0.6 + band * 0.06);
	ALPHA = mix(clamp(0.42 + edge * 0.45, 0.0, 0.92), edge * 0.18, inside) * fade;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shell_shader
	return m


## The screen seen from inside: a deep violet dusk, darker towards the edges.
static func _veil_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float fade = 1.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.1, 0.03, 0.2, (0.4 + smoothstep(0.2, 0.75, d) * 0.4) * fade);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## A soft round point of starlight, rather than a square.
static func _mote_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled, cull_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.86, 0.8, 1.0);
	ALPHA = clamp(1.0 - d, 0.0, 1.0) * 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## A band of light round the dome's edge, each piece set on the ground where it lies.
func _lay_rim() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const PARTS := 64
	var points: Array[Vector3] = []
	for i in PARTS + 1:
		var a := TAU * i / PARTS
		var flat := Vector3(cos(a), 0, sin(a))
		var inner := flat * (radius - 0.08)
		var outer := flat * (radius + 0.08)
		var at := position + flat * radius
		var y := (world.ground_at(at) if world else position.y) - position.y + 0.07
		points.append(Vector3(inner.x, y, inner.z))
		points.append(Vector3(outer.x, y, outer.z))
	for i in PARTS:
		var a := points[i * 2]
		var b := points[i * 2 + 1]
		var c := points[i * 2 + 2]
		var d := points[i * 2 + 3]
		for v: Vector3 in [a, b, c, b, d, c]:
			st.add_vertex(v)
	_rim.mesh = st.commit()


func contains(at: Vector3) -> bool:
	return Vector2(at.x - position.x, at.z - position.z).length() <= radius and at.y < position.y + radius + 1.0


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if has("night_follow"):
		var who := _owner_body()
		if who:
			position = position.lerp(Vector3(who.global_position.x, world.ground_at(who.global_position), who.global_position.z), minf(1.0, delta * 6.0))
	# It grows out of the ground in a quarter second and thins away in its last half second.
	var grow := clampf((_life - _left) / 0.25, 0.0, 1.0)
	_shell.scale = Vector3(radius, radius * 0.8, radius) * grow
	var fade := clampf(_left / 0.5, 0.0, 1.0)
	var mat := _shell.material_override as ShaderMaterial
	mat.set_shader_parameter("fade", fade)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var seen_inside := cam != null and contains(cam.global_position) and grow > 0.5
	mat.set_shader_parameter("inside", 1.0 if seen_inside else 0.0)
	_veil.visible = seen_inside
	if seen_inside:
		((_veil.get_child(0) as ColorRect).material as ShaderMaterial).set_shader_parameter("fade", fade)
	if has("night_follow"):
		_rim_left -= delta
		if _rim_left <= 0.0:
			_rim_left = 0.25
			_lay_rim()
	_tend(world.player)
	if Net.is_host() or not Net.active():
		for bot: Player in Net.bot_pawns():
			_tend(bot)
		_blind_creatures()


func _owner_body() -> Node3D:
	if world.player and world.player.net_id() == owner_peer:
		return world.player
	for bot: Player in Net.bot_pawns():
		if bot.net_id() == owner_peer:
			return bot
	return Net.avatar(owner_peer)


func is_friend(p: Player) -> bool:
	var peer := p.net_id()
	return peer == owner_peer or not Net.active() or not Net.bots_foes(owner_peer, peer)


## One person on this phone (or one of the host's bots): hidden if a friend, half blind if not.
func _tend(p: Player) -> void:
	if p == null or p.dead or not contains(p.global_position):
		return
	if is_friend(p):
		if p.can_vanish():
			p.invis_left = maxf(p.invis_left, linger)
		if has("night_heal") and p.hp < p.max_hp():
			p.heal(2.0 * get_physics_process_delta_time())
		if has("night_guard") and p.net_id() != owner_peer:
			p._act({"do": "buff", "key": "night_guard", "stat": "damage_taken", "val": -0.2, "secs": 0.3}, {})
		if has("night_damage") and p.net_id() == owner_peer:
			p._act({"do": "buff", "key": "night_damage", "stat": "melee_damage", "val": 0.25, "secs": 0.3}, {})
			p._act({"do": "buff", "key": "night_damage_ranged", "stat": "ranged_damage", "val": 0.25, "secs": 0.3}, {})
	else:
		p.night_blind_left = 0.3


func _blind_creatures() -> void:
	for z: Zombie in world.zombies_near(position, radius, 40):
		z.blind(0.4)
		if has("night_slow"):
			z.slow(0.4)
