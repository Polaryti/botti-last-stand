class_name PathField
extends Node3D
## Something a Class Upgrade leaves on the ground for a while (PathUpgrades): a Mist Leaper's Mist Wake,
## an Apothecary's Healing Mist, a Pestilence's Plague Censer (which follows its owner), an Inventor's
## Tesla Coil. Every phone makes its own copy. The owner's phone (the host, for a bot) does what it
## does to enemies; every phone looks after its own people inside it, as a Consecration does.

const KINDS := {
	"mist_wake": {"radius": PathUpgrades.MIST_WAKE_RADIUS, "time": PathUpgrades.MIST_WAKE_TIME, "col": Color(0.62, 0.92, 0.95)},
	"healing_mist": {"radius": PathUpgrades.HEALING_MIST_RADIUS, "time": PathUpgrades.HEALING_MIST_TIME, "col": Color(0.45, 0.95, 0.55)},
	"censer": {"radius": PathUpgrades.CENSER_RADIUS, "time": PathUpgrades.CENSER_TIME, "col": Color(0.55, 0.75, 0.2)},
	"tesla": {"radius": PathUpgrades.TESLA_REACH, "time": PathUpgrades.TESLA_TIME, "col": Color(0.6, 0.8, 1.0)},
}
const STEP := 0.25

var world: World
var owner_peer := 0
var kind := ""
var radius := 1.0
var _left := 1.0
var _life := 1.0
var _tick := 0.0
var _zap := 0.0
var _owner: Player # the owner, when it lives on this phone
var _wash: MeshInstance3D
var _puffs: Array[MeshInstance3D] = []
var _coil: Node3D


func _init(owner_world: World, peer: int, field_kind: String, at: Vector3) -> void:
	world = owner_world
	owner_peer = peer
	kind = field_kind
	radius = float(KINDS[kind]["radius"])
	_left = float(KINDS[kind]["time"])
	_life = _left
	position = at
	name = "PathField_" + kind


func _ready() -> void:
	if not Net.active() or owner_peer == Net.my_id():
		_owner = world.player
	elif Net.is_host() and Net.is_bot(owner_peer):
		_owner = Net.local_player(owner_peer)
	var col: Color = KINDS[kind]["col"]
	if kind == "tesla":
		_coil = coil_model()
		add_child(_coil)
		return
	# A low cloud: a soft disc over the ground and puffs drifting in it.
	var wash := StandardMaterial3D.new()
	wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wash.albedo_color = Color(col, 0.16)
	wash.disable_fog = true
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.03
	disc.radial_segments = 32
	_wash = MeshInstance3D.new()
	_wash.mesh = disc
	_wash.material_override = wash
	_wash.position.y = 0.1
	_wash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wash)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	var count := clampi(int(radius * 3.0), 5, 14) if Game.quality > 0 else 4
	for i in count:
		var puff := MeshInstance3D.new()
		puff.mesh = ball
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(col.lightened(0.2), 0.22)
		m.disable_fog = true
		puff.material_override = m
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.set_meta("a", TAU * i / count + i * 0.37)
		puff.set_meta("r", radius * (0.25 + 0.65 * fmod(i * 0.61, 1.0)))
		add_child(puff)
		_puffs.append(puff)


## The Tesla Coil: a tripod, a copper column wound with wire, and a brass ball that the sparks leave from.
static func coil_model() -> Node3D:
	var l := LowPoly.new()
	var wood := Color(0.36, 0.24, 0.14)
	var copper := Color(0.78, 0.45, 0.22)
	var brass := Color(0.82, 0.66, 0.28)
	for a: float in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		l.prism(Vector3(0, 0.6, 0), Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5), 0.05, 0.04, 5, wood)
	l.prism(Vector3(0, 0.5, 0), Vector3(0, 1.45, 0), 0.16, 0.14, 8, copper)
	for k in 6:
		l.prism(Vector3(0, 0.6 + k * 0.15, 0), Vector3(0, 0.66 + k * 0.15, 0), 0.19, 0.19, 8, copper.darkened(0.35))
	l.box(Vector3(0, 0.48, 0), Vector3(0.5, 0.08, 0.5), Color(0.27, 0.29, 0.32))
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = l.commit()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	ball.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.albedo_color = brass
	glow.metallic = 0.7
	glow.roughness = 0.3
	glow.emission_enabled = true
	glow.emission = Color(0.6, 0.8, 1.0)
	glow.emission_energy_multiplier = 0.4
	ball.material_override = glow
	ball.position.y = 1.62
	ball.name = "Ball"
	root.add_child(ball)
	return root


func contains(at: Vector3) -> bool:
	return Vector2(at.x - position.x, at.z - position.z).length() <= radius and absf(at.y - position.y) < 4.0


func is_friend(p: Player) -> bool:
	var peer := p.net_id()
	return peer == owner_peer or not Net.active() or not Net.bots_foes(owner_peer, peer)


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if kind == "censer":
		_follow()
	_look(delta)
	if kind == "tesla":
		_zap -= delta
		if _zap <= 0.0:
			_zap += PathUpgrades.TESLA_EVERY
			var was := world.begin_act(_owner)
			_discharge()
			world.end_act(was)
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = STEP
	_tend(world.player)
	if Net.is_host():
		for bot: Player in Net.bot_pawns():
			_tend(bot)
	if _owner != null and is_instance_valid(_owner):
		var was := world.begin_act(_owner)
		_harm()
		world.end_act(was)


## The censer goes where its Plague Doctor goes, on every phone.
func _follow() -> void:
	if _owner != null and is_instance_valid(_owner):
		position = _owner.global_position
		return
	for t: Target in world.players:
		if world.peer_of(t) == owner_peer:
			position = t.global_position
			return


func _look(_delta: float) -> void:
	var fade := clampf(_left / 0.6, 0.0, 1.0) * clampf((_life - _left) / 0.3, 0.0, 1.0)
	var now := _life - _left
	if _coil:
		_coil.scale = Vector3.ONE * clampf((_life - _left) / 0.25, 0.05, 1.0)
		var ball := _coil.get_node("Ball") as MeshInstance3D
		(ball.material_override as StandardMaterial3D).emission_energy_multiplier = 0.4 + 1.6 * absf(sin(now * 13.0))
		return
	(_wash.material_override as StandardMaterial3D).albedo_color.a = 0.16 * fade
	for puff in _puffs:
		var a: float = float(puff.get_meta("a")) + now * (0.5 if kind != "censer" else 1.2)
		var r: float = puff.get_meta("r")
		puff.position = Vector3(cos(a) * r, 0.35 + 0.15 * sin(now * 2.0 + a), sin(a) * r)
		puff.scale = Vector3(1.4, 0.7, 1.4) * (0.6 + 0.25 * sin(now * 1.7 + a))
		(puff.material_override as StandardMaterial3D).albedo_color.a = 0.22 * fade


## One person on this phone (or one of the host's bots).
func _tend(p: Player) -> void:
	if p == null or p.dead or not contains(p.global_position):
		return
	var friend := is_friend(p)
	match kind:
		"healing_mist":
			if friend:
				if p.hp < p.max_hp():
					p.mended_by_friend(PathUpgrades.HEALING_MIST_HEAL * STEP, owner_peer)
				p.cure()
		"mist_wake", "censer":
			if not friend:
				p.apply_status(Net.Status.SLOW, 0.5)
				if kind == "censer":
					p.apply_status(Net.Status.POISON, 1.0)
				else:
					p.hurt(PathUpgrades.MIST_WAKE_DPS * STEP, position)


## What the owner's field does to the creatures in it.
func _harm() -> void:
	match kind:
		"mist_wake":
			var dmg := PathUpgrades.MIST_WAKE_DPS * STEP * _owner.damage_multiplier()
			for z: Zombie in world.zombies_near(position, radius, 24):
				if contains(z.position):
					z.slow(0.5)
					z.next_hitter = owner_peer
					z.take_damage(dmg, Vector3.ZERO, 0.0, z.centre())
		"censer":
			for z: Zombie in world.zombies_near(position, radius, 32):
				if contains(z.position):
					z.slow(0.5)
					z.add_dot(PathUpgrades.CENSER_DPS, 1.0)


## The coil lets go at the nearest few, from its ball.
func _discharge() -> void:
	var top := position + Vector3.UP * 1.62
	var struck := 0
	if _owner != null and is_instance_valid(_owner):
		var dmg := PathUpgrades.TESLA_DAMAGE * _owner.m("inv_damage") * _owner.damage_multiplier()
		var near := world.zombies_near(position, radius, 32)
		near.sort_custom(func(a: Zombie, b: Zombie) -> bool: return a.position.distance_squared_to(position) < b.position.distance_squared_to(position))
		for z: Zombie in near:
			if struck >= PathUpgrades.TESLA_TARGETS:
				break
			if not z.is_alive():
				continue
			struck += 1
			world.fx_spark(top, z.centre())
			if Net.active():
				Net.world_fx(Net.Fx.SPARK, top, z.centre())
			z.next_hitter = owner_peer
			z.take_damage(dmg, z.position - position, 0.5, z.centre())
			_owner.on_hit(false)
		for r: Target in world.rivals_near(position, radius):
			if struck >= PathUpgrades.TESLA_TARGETS:
				break
			struck += 1
			world.fx_spark(top, r.global_position + Vector3.UP)
			if Net.active():
				Net.world_fx(Net.Fx.SPARK, top, r.global_position + Vector3.UP)
			world.hit_rival(r, dmg, position)
	if struck > 0:
		world.sfx_at("thunder", position, -14.0)
