class_name DeepSong
extends Node3D
## A Deepsinger's song: for a while, rings of sea-green light swell out from the singer. Enemies in
## its reach are drawn slowly toward the singer and slowed; friends in it mend. Every phone shows it
## round the singer (their avatar there). What it does to enemies is worked out on the singer's own
## phone (or the host, for a bot); each phone mends its own people.

const TICK := 0.25
const RINGS := 3
## The tree's switches, sent as bits.
const FLAGS := ["song_mark", "lullaby", "chorus", "song_dps", "requiem"]
const COLOUR := Color(0.45, 1.0, 0.86)

var world: World
var owner_peer := 0
var reach := 9.0
var left := 6.0
var heal := 4.0
var bits := 0
var _tick := 0.0
var _age := 0.0
var _rings: Array[MeshInstance3D] = []
var _singer: Node3D
static var _ring_mesh: Mesh


func _init(owner_world: World, peer: int, radius: float, seconds: float, mend: float, flags: int) -> void:
	world = owner_world
	owner_peer = peer
	reach = radius
	left = seconds
	heal = mend
	bits = flags & ((1 << FLAGS.size()) - 1)
	name = "DeepSong%d" % peer


func has(flag: String) -> bool:
	return bits & (1 << FLAGS.find(flag)) != 0


func _ready() -> void:
	top_level = true
	for i in RINGS:
		var r := MeshInstance3D.new()
		r.mesh = ring_mesh()
		r.material_override = MesenllaModels.glow_material()
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(r)
		_rings.append(r)
	_place()


## Who sings: this phone's player or a bot, or another phone's avatar.
func singer() -> Node3D:
	if _singer and is_instance_valid(_singer):
		return _singer
	if world.player and world.player.net_id() == owner_peer:
		_singer = world.player
	else:
		for bot: Player in Net.bot_pawns():
			if bot.net_id() == owner_peer:
				_singer = bot
		if _singer == null:
			_singer = Net.avatar(owner_peer)
	return _singer


func owner_is_here() -> bool:
	if not Net.active():
		return true
	return owner_peer == Net.my_id() or (Net.is_host() and Net.is_bot(owner_peer))


func centre() -> Vector3:
	var s := singer()
	return s.global_position if s else global_position


func _place() -> void:
	var at := centre()
	global_position = at
	for i in _rings.size():
		# Each ring swells from the singer to the edge of the song, one after another.
		var k := fmod(_age * 0.7 + float(i) / RINGS, 1.0)
		var r := reach * k
		_rings[i].global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(r, 1.0, r)), at + Vector3.UP * (0.2 + 0.9 * k))
		_rings[i].transparency = k * 0.85
		_rings[i].rotate_y(_age * 0.45 + i * TAU / RINGS)


func _physics_process(delta: float) -> void:
	_age += delta
	left -= delta
	var s := singer()
	if s == null or (s is Player and (s as Player).dead):
		queue_free()
		return
	_place()
	for p: Player in world.local_players():
		if not p.dead and _friend(p) and p.global_position.distance_to(centre()) <= reach:
			if p.hp < p.max_hp():
				p.mended_by_friend(heal * delta, owner_peer)
			if has("chorus"):
				p._act({"do": "buff", "key": "chorus", "stat": "damage_taken", "val": -TidecallerKit.CHORUS, "secs": 0.3}, {})
	_tick -= delta
	if left <= 0.0:
		if owner_is_here():
			_finale()
		queue_free()
		return
	if _tick <= 0.0 and owner_is_here():
		_tick = TICK
		_sing()


func _friend(p: Player) -> bool:
	var peer := p.net_id()
	return peer == owner_peer or not Net.active() or not Net.bots_foes(owner_peer, peer)


## Drawn in and slowed, and with the tree marked or hurt.
func _sing() -> void:
	var by := singer() as Player
	if by == null:
		return
	var at := centre()
	var was := world.begin_act(by)
	for z: Zombie in world.zombies_near(at, reach, 40):
		if not z.is_alive():
			continue
		var to := Vector3(at.x - z.position.x, 0, at.z - z.position.z)
		if to.length() > 2.0:
			z.drift_to(at, TidecallerKit.SONG_PULL)
		z.slow(TICK * 2.0)
		if has("song_mark"):
			z.mark(1.0 + TidecallerKit.SONG_MARK, TICK * 2.0)
		if has("song_dps"):
			world.damage_zombie(z, by.modify_damage(z, TidecallerKit.SONG_DPS * TICK), Vector3.ZERO, 0.0, z.centre(), false)
	for r: Target in world.rivals_near(at, reach):
		world.status_rival(r, Net.Status.SLOW, TICK * 2.0)
	world.end_act(was)


## When the song ends: with Lullaby, everything still in it falls asleep; with Requiem of the Deep, a
## wave bursts out of the singer through all of it.
func _finale() -> void:
	var by := singer() as Player
	if by == null:
		return
	var at := centre()
	var was := world.begin_act(by)
	if has("lullaby"):
		for z: Zombie in world.zombies_near(at, reach, 40):
			if z.is_alive():
				z.stun(TidecallerKit.LULLABY)
		for r: Target in world.rivals_near(at, reach):
			world.status_rival(r, Net.Status.STUN, TidecallerKit.LULLABY)
	if has("requiem"):
		for z: Zombie in world.zombies_near(at, reach, 40):
			if z.is_alive():
				world.damage_zombie(z, by.modify_damage(z, TidecallerKit.REQUIEM * by.damage_multiplier()), z.position - at, TidecallerKit.WAVE_KNOCK, z.centre(), false)
		for r: Target in world.rivals_near(at, reach):
			world.hit_rival(r, TidecallerKit.REQUIEM * by.damage_multiplier(), at)
		world.fx_ring(at, reach, Color(COLOUR, 0.6))
		world.fx_water(at, reach * 0.4, Color(0.72, 0.9, 0.92), true)
		world.sfx_at("wave_crash", at, 0.0)
	world.end_act(was)


## A thin ring one metre across, to be scaled to its size.
static func ring_mesh() -> Mesh:
	if _ring_mesh == null:
		var l := LowPoly.new()
		var n := 36
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var note := 0.5 + 0.5 * cos(a0 * 4.0)
			var colour := Color(0.2, 0.5, 0.69).lerp(COLOUR, note)
			l.prism(Vector3(cos(a0), sin(a0 * 4.0) * 0.1, sin(a0)), Vector3(cos(a1), sin(a1 * 4.0) * 0.1, sin(a1)), 0.012, 0.012, 3, colour)
		_ring_mesh = l.commit()
	return _ring_mesh
