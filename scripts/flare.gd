class_name Flare
extends Node3D
## A Flare Pistol's flare where it landed: a sputtering red-gold flame on the ground under a column of
## smoke, throwing a flickering light. On the phone of whoever fired it (shows_only false) it also
## does what a flare does: everything within BURN_RADIUS is set alight when it lands, and while it
## burns every enemy within REVEAL_RADIUS is shown, hidden ones and invisible rivals included.

const TIME := 8.0
const BURN_RADIUS := 3.0
const REVEAL_RADIUS := 7.0
const REVEAL_EVERY := 0.5
const COLOR := Color(1.0, 0.42, 0.22)

var world: World
var owner_player: Player
var shows_only := false
var _left := TIME
var _next_reveal := 0.0
var _light: OmniLight3D
var _flame: MeshInstance3D
var _core: MeshInstance3D
var _smoke: CPUParticles3D
var _sparks: CPUParticles3D
var _tongues: CPUParticles3D

static var _flame_mat: StandardMaterial3D
static var _core_mat: StandardMaterial3D


static func _glow(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	m.disable_fog = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Soft round edges: the same radial fade the puffs of breath and smoke use.
	m.albedo_texture = (WyvernRig.puff_mesh().material as StandardMaterial3D).albedo_texture
	return m


func _init(on: World, by: Player, only_shown: bool) -> void:
	world = on
	owner_player = by
	shows_only = only_shown
	name = "Flare"
	if _flame_mat == null:
		_flame_mat = _glow(Color(1.0, 0.45, 0.2, 0.6))
		_core_mat = _glow(Color(1.0, 0.95, 0.75, 0.95))
	# The spent cartridge it burns out of.
	var cart := MeshInstance3D.new()
	cart.mesh = WeaponDefs.flare_mesh()
	cart.rotation = Vector3(-PI * 0.5 + 0.4, 0.0, 0.0)
	cart.position.y = 0.05
	add_child(cart)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.7)
	_flame = MeshInstance3D.new()
	_flame.mesh = quad
	_flame.material_override = _flame_mat
	_flame.position.y = 0.4
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	var dot := QuadMesh.new()
	dot.size = Vector2(0.38, 0.38)
	_core = MeshInstance3D.new()
	_core.mesh = dot
	_core.material_override = _core_mat
	_core.position.y = 0.18
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = 3.2
	_light.omni_range = REVEAL_RADIUS + 2.0
	_light.position.y = 0.8
	_light.shadow_enabled = false
	add_child(_light)
	# Smoke rising from it, lit red at the bottom.
	_smoke = CPUParticles3D.new()
	_smoke.mesh = WyvernRig.puff_mesh()
	_smoke.amount = 18
	_smoke.lifetime = 3.2
	# Already rising when it lands: a column this young would otherwise show its puffs not yet
	# born as a black disc at its foot in the Compatibility renderer.
	_smoke.preprocess = 3.2
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.gravity = Vector3(0.15, 0.6, 0)
	_smoke.initial_velocity_min = 0.6
	_smoke.initial_velocity_max = 1.1
	_smoke.scale_amount_min = 0.9
	_smoke.scale_amount_max = 1.9
	var smoke_ramp := Gradient.new()
	smoke_ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	smoke_ramp.colors = PackedColorArray([Color(1.0, 0.62, 0.45, 0.0), Color(0.95, 0.6, 0.5, 0.32), Color(0.55, 0.5, 0.55, 0.0)])
	_smoke.color_ramp = smoke_ramp
	_smoke.position.y = 0.5
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)
	# Tongues of flame licking up out of it.
	var tongues := World.make_flames()
	tongues.amount = 12
	tongues.emission_box_extents = Vector3(0.08, 0.06, 0.08)
	tongues.position.y = 0.12
	tongues.scale_amount_min = 0.5
	tongues.scale_amount_max = 0.9
	_tongues = tongues
	add_child(tongues)
	# Sparks spitting out of it.
	_sparks = CPUParticles3D.new()
	var spark := BoxMesh.new()
	spark.size = Vector3(0.03, 0.03, 0.03)
	spark.material = _glow(Color(1.0, 0.8, 0.4))
	(spark.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_sparks.mesh = spark
	_sparks.amount = 24
	_sparks.lifetime = 0.7
	_sparks.direction = Vector3.UP
	_sparks.spread = 55.0
	_sparks.gravity = Vector3(0, -6.0, 0)
	_sparks.initial_velocity_min = 1.5
	_sparks.initial_velocity_max = 3.5
	_sparks.position.y = 0.2
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


func _ready() -> void:
	_smoke.emitting = true
	_sparks.emitting = true
	_tongues.emitting = true
	if not shows_only:
		_burn_around()


## Landing: everything close by catches.
func _burn_around() -> void:
	var was := world.begin_act(owner_player)
	for z: Zombie in world.zombies_near(global_position, BURN_RADIUS + 1.0, 16):
		if z.is_alive() and Vector2(z.position.x - global_position.x, z.position.z - global_position.z).length() <= BURN_RADIUS + z.body_radius():
			z.ignite(ZombieDefs.BURN_SECONDS)
	if owner_player and Net.pvp():
		for t: Target in world.rivals_near(global_position, BURN_RADIUS):
			if owner_player.is_foe_peer(world.peer_of(t)):
				owner_player.status_on(world.peer_of(t), Net.Status.BURN, ZombieDefs.BURN_SECONDS)
	world.end_act(was)


func _process(delta: float) -> void:
	_left -= delta
	var t := TIME - _left
	var fade := clampf(_left / 1.2, 0.0, 1.0)
	var flicker := 0.82 + 0.18 * sin(t * 31.0) * sin(t * 13.0 + 1.3)
	_light.light_energy = 3.2 * flicker * fade
	_flame.scale = Vector3(1.0, 0.85 + 0.25 * flicker, 1.0) * maxf(0.05, fade)
	_core.scale = Vector3.ONE * (0.8 + 0.3 * flicker) * maxf(0.05, fade)
	if _left < 1.4:
		_smoke.emitting = false
		_sparks.emitting = false
		_tongues.emitting = false
	if not shows_only:
		_next_reveal -= delta
		if _next_reveal <= 0.0 and _left > 0.0:
			_next_reveal = REVEAL_EVERY
			_reveal()
	if _left <= -2.0:
		queue_free()


## Its light: nothing within it can hide.
func _reveal() -> void:
	for z: Zombie in world.zombies_near(global_position, REVEAL_RADIUS, 24):
		z.reveal(REVEAL_EVERY + 0.2)
	if owner_player and Net.pvp():
		for t: Target in world.rivals_near(global_position, REVEAL_RADIUS):
			if owner_player.is_foe_peer(world.peer_of(t)):
				owner_player.status_on(world.peer_of(t), Net.Status.REVEAL, REVEAL_EVERY + 0.2)
