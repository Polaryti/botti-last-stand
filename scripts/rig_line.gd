class_name RigLine
extends Node3D
## A Rigger's line: a rope staked taut across the ground between two points, at shin height, for a
## while. Every phone keeps its own copy. What trips on it is worked out on the Rigger's own phone (or
## the host, for a bot), so each trip is counted once: an enemy that crosses is stunned and slowed, and
## with the Rigger's knots also cut, held or thrown. Each phone looks after its own people: a friend
## who crosses a Lifeline runs faster.

const HEIGHT := 0.42 # the rope above the ground
const REACH := 0.7 # how close to the rope counts as crossing it
const TICK := 0.1
const REST := 3.0 # an enemy trips on the same line at most this often
## The tree's switches, sent as bits.
const FLAGS := ["line_barbs", "line_snare", "line_speed", "crows_nest"]

var world: World
var owner_peer := 0
var a := Vector3.ZERO
var b := Vector3.ZERO
var left := 0.0
var bits := 0
var cradle := false # tied by Cat's Cradle between the ends of two other lines: it goes when its line goes
var tied_to: RigLine # ...those lines
var tied_also: RigLine
var _rest := {} # instance id -> world.now when it may trip again
var _tick := 0.0
var _rope: MeshInstance3D
static var _stake_mesh: Mesh


func _init(owner_world: World, peer: int, from: Vector3, to: Vector3, seconds: float, flags: int) -> void:
	world = owner_world
	owner_peer = peer
	a = from
	b = to
	left = seconds
	bits = flags & ((1 << FLAGS.size()) - 1)
	name = "RigLine%d" % peer


func has(flag: String) -> bool:
	return bits & (1 << FLAGS.find(flag)) != 0


func _ready() -> void:
	top_level = true
	for end: Vector3 in [a, b]:
		var stake := MeshInstance3D.new()
		stake.mesh = stake_mesh()
		add_child(stake)
		stake.global_position = end
		var to_other := (b - a) if end == a else (a - b)
		stake.rotation.y = atan2(-to_other.x, -to_other.z)
	_rope = MeshInstance3D.new()
	_rope.mesh = HaulRope.line_mesh()
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	var from := a + Vector3.UP * HEIGHT
	var to := b + Vector3.UP * HEIGHT
	var span := to - from
	if span.length() > 0.05:
		var look := Basis.looking_at(span.normalized(), Vector3.UP if absf(span.normalized().y) < 0.98 else Vector3.RIGHT)
		_rope.global_transform = Transform3D(look.scaled(Vector3(1.5, 1.5, span.length())), from)


static func _gone(line: RigLine) -> bool:
	return line == null or not is_instance_valid(line) or line.is_queued_for_deletion()


func length() -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


## How far a point is from the rope, along the ground.
func distance_to(at: Vector3) -> float:
	var p := Vector2(at.x, at.z)
	var s := Vector2(a.x, a.z)
	var e := Vector2(b.x, b.z)
	var seg := e - s
	var t := 0.0 if seg.length_squared() < 0.0001 else clampf((p - s).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return p.distance_to(s + seg * t)


## Whether this phone does the Rigger's sums: its own player, or a bot on the host.
func owner_is_here() -> bool:
	if not Net.active():
		return true
	return owner_peer == Net.my_id() or (Net.is_host() and Net.is_bot(owner_peer))


func owner_player() -> Player:
	if world.player and world.player.net_id() == owner_peer:
		return world.player
	for bot: Player in Net.bot_pawns():
		if bot.net_id() == owner_peer:
			return bot
	return null


func is_friend(p: Player) -> bool:
	var peer := p.net_id()
	return peer == owner_peer or not Net.active() or not Net.bots_foes(owner_peer, peer)


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0 or (cradle and (_gone(tied_to) or _gone(tied_also))):
		world.remove_rig_line(self)
		return
	if has("line_speed"):
		for p: Player in world.local_players():
			if not p.dead and is_friend(p) and distance_to(p.global_position) <= REACH:
				p._act({"do": "buff", "key": "lifeline", "stat": "speed", "val": HarpoonerKit.LIFELINE_SPEED, "secs": HarpoonerKit.LIFELINE_TIME}, {})
	_tick -= delta
	if _tick > 0.0 or not owner_is_here():
		return
	_tick = TICK
	var by := owner_player()
	if by == null:
		return
	var was := world.begin_act(by)
	var mid := (a + b) * 0.5
	var reach := length() * 0.5 + REACH + 1.0
	for z: Zombie in world.zombies_near(mid, reach, 40):
		if z.is_alive() and not z.flies and distance_to(z.position) <= REACH and float(_rest.get(z.get_instance_id(), -1.0)) <= world.now:
			_rest[z.get_instance_id()] = world.now + REST
			_trip(by, z)
	for r: Target in world.rivals_near(mid, reach):
		if distance_to(r.global_position) <= REACH and float(_rest.get(r.get_instance_id(), -1.0)) <= world.now:
			_rest[r.get_instance_id()] = world.now + REST
			world.status_rival(r, Net.Status.STUN, HarpoonerKit.TRIP_STUN)
			world.status_rival(r, Net.Status.SLOW, HarpoonerKit.TRIP_SLOW)
			if has("line_barbs"):
				world.hit_rival(r, HarpoonerKit.BARB_DAMAGE * by.damage_multiplier(), r.global_position)
	world.end_act(was)


## Caught by the ankles: down for a moment, slow to get up, and with the Rigger's knots worse.
func _trip(by: Player, z: Zombie) -> void:
	z.stun(HarpoonerKit.TRIP_STUN)
	z.slow(HarpoonerKit.TRIP_SLOW)
	if has("line_snare"):
		z.root(HarpoonerKit.TRIP_STUN + HarpoonerKit.SNARE, true)
	if has("line_barbs"):
		world.damage_zombie(z, by.modify_damage(z, HarpoonerKit.BARB_DAMAGE * by.damage_multiplier()), Vector3.ZERO, 0.0, z.centre(), false)
		z.add_dot(HarpoonerKit.BARB_BLEED.x, HarpoonerKit.BARB_BLEED.y, true)
	world.fx_rise(z.position + Vector3.UP * 0.3, Color(0.9, 0.78, 0.5))
	world.sfx_at("line_trip", z.position, -4.0)


## A stake driven into the ground with the rope's end lashed round it, leaning away from the rope.
static func stake_mesh() -> Mesh:
	if _stake_mesh == null:
		var l := LowPoly.new()
		var wood := Color(0.42, 0.3, 0.18)
		l.prism(Vector3(0, -0.15, 0), Vector3(0, 0.62, 0.1), 0.05, 0.035, 6, wood)
		l.prism(Vector3(0, 0.62, 0.1), Vector3(0, 0.68, 0.11), 0.045, 0.045, 6, wood.lightened(0.1))
		for i in 3:
			var y := HEIGHT - 0.04 + i * 0.035
			l.prism(Vector3(0, y, 0.07), Vector3(0, y + 0.025, 0.07), 0.06, 0.06, 6, HaulRope.ROPE.darkened(0.08 * i))
		_stake_mesh = l.commit()
	return _stake_mesh
