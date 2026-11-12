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
var _stars: GPUParticles3D
static var _shell_mat: ShaderMaterial


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
	sphere.is_hemisphere = true
	sphere.radial_segments = 32
	sphere.rings = 12
	_shell = MeshInstance3D.new()
	_shell.mesh = sphere
	_shell.material_override = _material()
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.scale = Vector3.ONE * 0.01
	add_child(_shell)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.97
	ring.outer_radius = 1.03
	ring.rings = 48
	_rim = MeshInstance3D.new()
	_rim.mesh = ring
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.72, 0.5, 0.95)
	glow.disable_fog = true
	_rim.material_override = glow
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rim.scale = Vector3(radius, 1.0, radius)
	_rim.position.y = 0.06
	add_child(_rim)
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
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_mat.albedo_color = Color(0.86, 0.8, 1.0)
	mote_mat.disable_fog = true
	mote.material = mote_mat
	_stars.draw_pass_1 = mote
	_stars.position.y = radius * 0.35
	add_child(_stars)


## Dark glass: deepest at the edge, nearly clear on the top, with a faint violet sheen.
static func _material() -> ShaderMaterial:
	if _shell_mat:
		return _shell_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform float fade = 1.0;
void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float band = 0.5 + 0.5 * sin(TIME * 0.7 + UV.y * 18.0);
	ALBEDO = mix(vec3(0.03, 0.02, 0.07), vec3(0.42, 0.26, 0.62), edge * 0.6 + band * 0.06);
	ALPHA = clamp(0.42 + edge * 0.45, 0.0, 0.92) * fade;
}
"""
	_shell_mat = ShaderMaterial.new()
	_shell_mat.shader = sh
	return _shell_mat


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
	(_shell.material_override as ShaderMaterial).set_shader_parameter("fade", clampf(_left / 0.5, 0.0, 1.0))
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
