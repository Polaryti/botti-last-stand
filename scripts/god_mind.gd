class_name GodMind
extends VaelMind
## What Al'quimelea does, worked out on the host (or alone). Everything it does is told before it lands
## (its pose, sent to every phone as Zombie._current_anim, and a MistSeal's ring), and every phone
## hurts its own player when the ring lands:
##   It floats, keeping 9 to 18 m from whoever it hunts, over cliffs and all.
##   Elixir rain (m_cast): its retort raised, flasks fall round each of you, several to each.
##   Fields of change (m_slam): a great ring opens under each of you; whoever is still in it when it
##     opens is poisoned and held fast.
##   Crucible nova (m_sweep): anyone within NOVA_REACH: its chest blazes, and the light throws them back
##     and sets them burning.
##   Crystal lance (m_ink): a line of shards strikes out toward whoever stands furthest off.
##   Brood (m_roar): at two thirds and one third of its health, mutants are born of it; each time it
##     grows quicker.
## It comes down from its temple at ALQ_AT (Director), and dawn does not come until it falls.

const GODS := ["alquimelea"]
const RANGE := Vector2(9.0, 18.0)
const STAGES := [0.66, 0.33] # of its health, where it broods and grows quicker
const QUICKER := [1.0, 0.85, 0.7] # its cooldowns at each stage
const RAIN_EVERY := 8.0
const RAIN_TELL := 1.4
const RAIN_PER := [3, 4, 5] # flasks round each of you, by stage
const RAIN_RADIUS := 2.4
const RAIN_SCATTER := 4.0
const RAIN_POWER := 0.7
const RAIN_REACH := 30.0
const FIELD_EVERY := 12.0
const FIELD_TELL := 1.6
const FIELD_RADIUS := 4.0
const FIELD_POWER := 1.0
const CHANGE_POISON := 3.0
const CHANGE_ROOT := 1.2
const NOVA_EVERY := 9.0
const NOVA_TELL := 1.4
const NOVA_REACH := 8.0
const NOVA_POWER := 1.4
const NOVA_KNOCK := 11.0
const NOVA_BURN := 2.0
const LANCE_EVERY := 10.0
const LANCE_TELL := 1.2
const LANCE_SHARDS := 7
const LANCE_STEP := 0.12 # each shard a little after the one before it
const LANCE_GAP := 3.0 # metres between shards
const SHARD_RADIUS := 1.8
const SHARD_POWER := 0.9
const SHARD_SLOW := 1.5
const LANCE_REACH := 34.0
const BROOD := [["mutant_bee", "mutant_bee", "mutant_bee", "mutant_snail"], ["battle_ostrich", "thornback", "mutant_wasp", "mutant_wasp"]]
const BROOD_TIME := 1.8

var _brooded := 0
var _cool_field := 6.0
var _cool_nova := 0.0
var _cool_lance := 4.0
var _risen := false


static func handles(id: String) -> bool:
	return id in GODS


func _init(id: String) -> void:
	super(id)
	cooldown = 3.0


func tick(z: Zombie, target: Target, _to: Vector3, _dist: float, delta: float) -> bool:
	z.velocity = Vector3.ZERO
	if not _risen:
		# It comes down from its temple first; nothing it does lands until it is down.
		_risen = true
		phase = "rise"
		left = GodModels.RISE_TIME
		_show(z, "m_rise")
		z.world.sfx_at("alq_voice", z.position, 8.0)
	var stage := stage_of(z)
	var quick: float = QUICKER[stage]
	cooldown -= delta
	_cool_field -= delta
	_cool_nova -= delta
	_cool_lance -= delta
	match phase:
		"rise", "rain", "field", "nova", "lance", "brood":
			left -= delta
			if target:
				_face(z, target.global_position, delta, 1.5)
			if left <= 0.0:
				if phase == "brood":
					_birth(z, _brooded - 1)
				phase = ""
				z.mesenlla_warning = false
				_show(z, "")
			return true
	if target == null:
		return true
	if stage > _brooded:
		_brooded = stage
		phase = "brood"
		left = BROOD_TIME
		_show(z, "m_roar", true)
		z.world.sfx_at("alq_roar", z.position, 8.0)
		z.world.director.show_banner("Al'quimelea changes, and things are born of it!" if stage == 1 else "Al'quimelea tears itself open: the island changes with it!", 3.5)
		return true
	var dist := Vector2(target.global_position.x - z.position.x, target.global_position.z - z.position.z).length()
	# Floating where it wants to be, over everything.
	_drift(z, target, dist, delta)
	_face(z, target.global_position, delta, 1.2)
	if not z._sees:
		return true
	if _cool_nova <= 0.0 and _players_within(z, NOVA_REACH) > 0:
		_cool_nova = NOVA_EVERY * quick
		phase = "nova"
		left = NOVA_TELL + 0.4
		_show(z, "m_sweep", true)
		MistSeal.cast(z, _ground(z, z.position), NOVA_REACH, NOVA_TELL, z._damage * NOVA_POWER, 0.0, MistSeal.Style.NOVA)
		return true
	if _cool_lance <= 0.0:
		var far := _furthest(z, target)
		var gap := far.global_position.distance_to(z.position)
		if gap > NOVA_REACH and gap < LANCE_REACH:
			_cool_lance = LANCE_EVERY * quick
			phase = "lance"
			left = LANCE_TELL + LANCE_SHARDS * LANCE_STEP + 0.2
			_show(z, "m_ink", true)
			var along := (far.global_position - z.position) * Vector3(1, 0, 1)
			along = along.normalized() if along.length() > 0.1 else Vector3.FORWARD
			for i in LANCE_SHARDS:
				MistSeal.cast(z, _ground(z, z.position + along * (3.0 + i * LANCE_GAP)), SHARD_RADIUS, LANCE_TELL + i * LANCE_STEP, z._damage * SHARD_POWER, 0.0, MistSeal.Style.SHARD)
			z.world.sfx_at("alq_lance", z.position, 4.0)
			return true
	if _cool_field <= 0.0:
		_cool_field = FIELD_EVERY * quick
		phase = "field"
		left = FIELD_TELL + 0.5
		_show(z, "m_slam", true)
		for t: Target in z.world.players:
			if not t.dead and not t.is_unseen() and t.global_position.distance_to(z.position) < RAIN_REACH:
				MistSeal.cast(z, _ground(z, t.global_position), FIELD_RADIUS, FIELD_TELL, z._damage * FIELD_POWER, 0.0, MistSeal.Style.CHANGE)
		z.world.sfx_at("alq_voice", z.position, 4.0)
		return true
	if cooldown <= 0.0:
		cooldown = RAIN_EVERY * quick
		phase = "rain"
		left = RAIN_TELL + 0.6
		_show(z, "m_cast", true)
		var per: int = RAIN_PER[stage]
		for t: Target in z.world.players:
			if t.dead or t.is_unseen() or t.global_position.distance_to(z.position) > RAIN_REACH:
				continue
			for i in per:
				var spot := _lead(z, t, RAIN_TELL * 0.5) if i == 0 else t.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.5, RAIN_SCATTER)
				MistSeal.cast(z, _ground(z, spot), RAIN_RADIUS, RAIN_TELL + i * 0.18, z._damage * RAIN_POWER, 0.0, MistSeal.Style.ELIXIR)
		z.world.sfx_at("elixir_throw", z.position, 6.0)
		return true
	return true


## Its changes are not broken off: it rises, and it broods, whatever strikes it.
func interrupt(z: Zombie) -> void:
	if phase == "brood":
		return
	super(z)


## 0 above two thirds of its health, 1 to one third, 2 below.
static func stage_of(z: Zombie) -> int:
	var f := z.hp / maxf(z.max_hp, 1.0)
	return 2 if f <= float(STAGES[1]) else 1 if f <= float(STAGES[0]) else 0


## It floats toward or away from whoever it hunts, to keep RANGE, drifting a little round them; nothing
## on the ground stops it.
func _drift(z: Zombie, target: Target, dist: float, delta: float) -> void:
	var to := (target.global_position - z.position) * Vector3(1, 0, 1)
	if to.length() < 0.1:
		return
	var dir := to.normalized()
	var want := 0.0
	if dist > RANGE.y:
		want = 1.0
	elif dist < RANGE.x:
		want = -1.0
	var aside := dir.cross(Vector3.UP) * 0.35
	var step := (dir * want + aside) * z._speed * delta
	var next := z.position + step
	var half := z.world.play_half - 6.0
	next.x = clampf(next.x, -half, half)
	next.z = clampf(next.z, -half, half)
	next.y = z.world.ground_at(next)
	z.position = next


## Born of it: mutants, round it, in a burst of violet.
func _birth(z: Zombie, which: int) -> void:
	var brood: Array = BROOD[clampi(which, 0, BROOD.size() - 1)]
	for i in brood.size():
		var a := TAU * i / float(brood.size()) + z.rotation.y
		var at := _ground(z, z.position + Vector3(cos(a), 0, sin(a)) * 6.0)
		if not z.world.terrain.is_walkable(at.x, at.z):
			continue
		if z.world.spawn_zombie(str(brood[i]), at):
			z.world.fx_ring(at + Vector3.UP * 0.1, 1.6, Color(0.75, 0.4, 1.0))
			z.world.fx_mist(at + Vector3.UP * 0.6, 1.2)
