class_name FerrymanKit
extends RefCounted
## The Ferryman: one ability button. Crossing glides the Ferryman across the dark in a ghostly skiff,
## through enemies, shoving them aside; each path makes the button its own. A Tollkeeper demands the
## toll and collects obols from the dead; a Boatman's skiff carries friends; a Psychopomp gathers the
## souls of the dead and sends them out. The skiff everyone sees is a FerrySkiff, the souls SoulBolts.

# Crossing
const CROSS_REACH := 9.0
const CROSS_TIME := 0.45
const CROSS_WIDTH := 1.8 # what is this close to the path is struck as the skiff passes
const CROSS_DAMAGE := 15.0
const CROSS_SLOW := 2.0
const CROSS_HEAL := 15.0
const CROSS_SHOVE := 6.0
const TOLL_BELL := 0.5 # Toll Bell: stuns what the skiff shoves aside
const DUE_HEAL := 4.0 # Ferryman's Due: health from each kill
# Tollkeeper
const TOLL_REACH := 7.0
const TOLL_CONE := 90.0
const DEBT := 1.25
const DEBT_TIME := 8.0
const OBOLS := 5
const OBOL_HEAL := 10.0
const OBOL_DAMAGE := 0.05
const INTEREST := 4.0 # Interest: damage a second to what is in debt
const TOLL_WIDE := 3.0
const OBOL_SPEED := 0.03
const COLLECT_BELOW := 0.2
# Boatman
const CARRY_REACH := 3.0
const BOAT_STUN := 1.0
const WAKE_SLOW := 0.4
const WAKE_TIME := 4.0
const LEECH := 4.0
const OARLOCK := 2.0
const SAFE_PASSAGE := 0.3
const SAFE_TIME := 2.0
const SECOND_TRIP := 4.0
# Psychopomp
const SOUL_REACH := 8.0
const SOULS := 6
const SOUL_DAMAGE := 20.0
const SOUL_HEAL := 12.0
const SOUL_WARD := 0.03
const SOUL_AURA := 8.0
const SOUL_AURA_REACH := 2.0
const GATE_SOULS := 6
const GATE_REST := 60.0

const ARTS := {
	"": {"name": "Crossing", "cost": 0.0, "cast": 0.1, "cd": 10.0, "icon": "skiff"},
	"tollkeeper": {"name": "Demand the Toll", "cost": 0.0, "cast": 0.3, "cd": 12.0, "icon": "coin", "anim": "Spellcast_Raise"},
	"boatman": {"name": "Crossing", "cost": 0.0, "cast": 0.1, "cd": 10.0, "icon": "skiff"},
	"psychopomp": {"name": "Guide the Souls", "cost": 0.0, "cast": 0.25, "cd": 6.0, "icon": "soul", "anim": "Spellcast_Shoot"},
}
const PALE := Color(0.78, 0.92, 0.88)


static func art(p: Player) -> Dictionary:
	return ARTS.get(p.spec_id, ARTS[""])


static func cast(p: Player) -> void:
	match p.spec_id:
		"tollkeeper": demand_the_toll(p)
		"psychopomp": guide_the_souls(p)
		_: cross(p)


## Guide the Souls has nothing to send without souls.
static func has_use(p: Player) -> bool:
	return p.spec_id != "psychopomp" or p.souls > 0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z).normalized() if Vector2(v.x, v.z).length() > 0.05 else Vector3.FORWARD


# --- Crossing ----------------------------------------------------------------------------

static func cross_reach(p: Player) -> float:
	return CROSS_REACH + p.m("cross_reach")


## Set off: the way the stick points, or ahead. The skiff carries the Ferryman along the ground to the
## furthest open spot in reach (Player._tick_cross), and everyone sees it.
static func cross(p: Player) -> void:
	var dir := p.global_basis * Vector3(p.input_move.x, 0, p.input_move.y)
	if dir.length_squared() < 0.04:
		dir = -p.global_basis.z
	dir = _flat(dir)
	var from := p.global_position
	var to := p.leap_landing(from, dir, cross_reach(p))
	if Vector2(to.x - from.x, to.z - from.z).length() < 1.5:
		p.say("No room to cross")
		p.art_cd_left = 0.5
		return
	p.start_cross(from, to)
	FerrySkiff.create(p.world, p, from, to, CROSS_TIME)
	if Net.active():
		Net.crossing(p.net_id(), from, to)
	if p.has_flag("carry"):
		_carry_friends(p, from, to)
	p.world.sfx_at("crossing", from, -2.0)
	if p.has_flag("last_ferry"):
		# The Last Ferry: a second trip, free, for a few seconds after the first.
		if p.second_trip_left > 0.0:
			p.second_trip_left = 0.0
		else:
			p.second_trip_left = SECOND_TRIP


## A Boatman's skiff takes friends standing close aboard: they cross with it, to its far side.
static func _carry_friends(p: Player, from: Vector3, to: Vector3) -> void:
	var shift := to - from
	var was := p.world.begin_act(p)
	for friend: Target in p.world.friends_near(from, CARRY_REACH):
		var there := friend.global_position + shift
		there.y = p.world.ground_at(there)
		Net.carried(p.world.peer_of(friend), there, p.net_id())
	p.world.end_act(was)


## Everything the skiff passes on its way (from Player._tick_cross, on the Ferryman's own phone).
static func on_cross_step(p: Player, from: Vector3, at: Vector3, struck: Dictionary) -> void:
	var width := CROSS_WIDTH + p.m("cross_width")
	var was := p.world.begin_act(p)
	var line := _flat(at - from)
	for z: Zombie in p.world.zombies_near(at, width + 1.0, 20):
		if not z.is_alive() or struck.has(z.get_instance_id()):
			continue
		if Vector2(z.position.x - at.x, z.position.z - at.z).length() > width + z.body_radius():
			continue
		struck[z.get_instance_id()] = true
		var side := (z.position - at)
		side = _flat(side - line * side.dot(line))
		var dmg := CROSS_DAMAGE * (1.0 + p.m("cross_damage")) * p.damage_multiplier()
		p.world.damage_zombie(z, p.modify_damage(z, dmg), side, CROSS_SHOVE, z.centre(), false)
		z.slow(CROSS_SLOW)
		if p.has_flag("cross_stun"):
			z.stun(TOLL_BELL)
		if p.spec_id == "boatman":
			z.stun(BOAT_STUN)
		if p.has_flag("cross_leech") and p.hp < p.max_hp():
			p.heal(LEECH)
	for r: Target in p.world.rivals_near(at, width + 0.5):
		if struck.has(r.get_instance_id()):
			continue
		struck[r.get_instance_id()] = true
		p.world.hit_rival(r, CROSS_DAMAGE * p.damage_multiplier(), at)
		p.world.status_rival(r, Net.Status.SLOW, CROSS_SLOW)
	for friend: Target in p.world.friends_near(at, width):
		if not struck.has(friend.get_instance_id()):
			struck[friend.get_instance_id()] = true
			Net.guard_peer(p.world.peer_of(friend), 0.0, CROSS_HEAL)
	p.world.end_act(was)


## The skiff grounds where it was going.
static func on_cross_end(p: Player, from: Vector3, to: Vector3) -> void:
	if p.has_flag("wake"):
		p.world.black_water(p.net_id(), from, to, WAKE_TIME)
		if Net.active():
			Net.black_water(p.net_id(), from, to, WAKE_TIME)
	if p.has_flag("oarlock"):
		p.oarlock = true
	if p.has_flag("safe_passage"):
		p._act({"do": "buff", "key": "safe_passage", "stat": "damage_taken", "val": -SAFE_PASSAGE, "secs": SAFE_TIME}, {})
	if p.second_trip_left > 0.0:
		p.art_cd_left = 0.0


# --- Tollkeeper ------------------------------------------------------------------------------

static func toll_reach(p: Player) -> float:
	return TOLL_REACH + (TOLL_WIDE if p.has_flag("toll_round") else 0.0)


static func debt_time(p: Player) -> float:
	return DEBT_TIME + p.m("debt_time")


static func demand_the_toll(p: Player) -> void:
	var at := p.global_position
	var ahead := _flat(-p.global_basis.z)
	var limit := cos(deg_to_rad(TOLL_CONE * 0.5))
	var round := p.has_flag("toll_round")
	var count := 0
	for z: Zombie in p.world.zombies_near(at, toll_reach(p), 30):
		if not z.is_alive():
			continue
		var to := _flat(z.position - at)
		if not round and to.dot(ahead) < limit:
			continue
		z.mark(DEBT, debt_time(p))
		if p.has_flag("interest"):
			z.add_dot(INTEREST, debt_time(p))
		if p.has_flag("debt_reveal"):
			z.reveal_left = maxf(z.reveal_left, debt_time(p))
		p.debtors[z.get_instance_id()] = p.world.now + debt_time(p)
		count += 1
	p.world.fx_ring(at, toll_reach(p), Color(0.95, 0.8, 0.4, 0.6))
	p.world.sfx_at("toll_bell", at, -1.0)
	p.say("Pay the toll!" if count > 0 else "No one to pay")


static func in_debt(p: Player, z: Zombie) -> bool:
	return float(p.debtors.get(z.get_instance_id(), -1.0)) >= p.world.now


static func obols_max(p: Player) -> int:
	return OBOLS + int(p.m("obols"))


## The Tollkeeper's blows: everything below the line pays at once (Debt Collector), and each obol held
## makes them harder.
static func blow_scale(p: Player) -> float:
	var scale := 1.0 + OBOL_DAMAGE * p.obols if p.spec_id == "tollkeeper" else 1.0
	if p.oarlock:
		scale *= OARLOCK
	return scale


static func collect(p: Player, z: Zombie) -> void:
	if p.has_flag("debt_collector") and z.is_alive() and in_debt(p, z) and z.hp < z.max_hp * COLLECT_BELOW:
		z.take_damage(9999.0, Vector3.FORWARD, 0.0, z.centre())


# --- Psychopomp -------------------------------------------------------------------------------

static func souls_max(p: Player) -> int:
	return SOULS + int(p.m("souls"))


## Something died within reach: its soul comes to the Psychopomp.
static func gather(p: Player, at: Vector3, own: bool) -> void:
	if p.spec_id != "psychopomp" or p.dead or p.global_position.distance_to(at) > SOUL_REACH:
		return
	var more := 2 if own and p.has_flag("reaping") else 1
	p.set_souls(mini(souls_max(p), p.souls + more))
	p.world.fx_rise(at + Vector3.UP * 0.6, PALE)


## Each soul flies out to an enemy near, the nearest first; with no enemy near, they mend the Psychopomp.
static func guide_the_souls(p: Player) -> void:
	if p.souls <= 0:
		p.say("No souls to guide")
		p.art_cd_left = 0.5
		return
	var foes: Array[Node3D] = []
	for z: Zombie in p.world.zombies_near(p.global_position, 16.0, 20):
		if z.is_alive():
			foes.append(z)
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	var sent := p.souls
	for i in sent:
		if not foes.is_empty():
			var target: Node3D = foes[i % foes.size()]
			SoulBolt.create(p.world, p, target, i, false)
			if Net.active():
				Net.soul_bolt(p.net_id(), target, i)
		else:
			SoulBolt.create(p.world, p, p, i, true)
	p.set_souls(0)
	p.world.sfx_at("souls_go", p.global_position, -1.0)


## A soul arrives (on the Psychopomp's own phone).
static func soul_lands(p: Player, target: Node3D, heals: bool) -> void:
	if heals:
		if p.dead:
			return
		p.heal(SOUL_HEAL)
		if p.has_flag("soul_cure"):
			p.cure()
		return
	var z := target as Zombie
	if z == null or not z.is_alive():
		return
	var was := p.world.begin_act(p)
	p.world.damage_zombie(z, p.modify_damage(z, SOUL_DAMAGE * (1.0 + p.m("soul_damage")) * p.damage_multiplier()), Vector3.ZERO, 0.0, z.centre(), false)
	p.world.end_act(was)


## Restless Dead: the souls about the Psychopomp strike what comes close, every second.
static func soul_aura(p: Player) -> void:
	if p.souls <= 0 or not p.has_flag("soul_aura"):
		return
	var was := p.world.begin_act(p)
	for z: Zombie in p.world.zombies_near(p.global_position, SOUL_AURA_REACH, 8):
		if z.is_alive():
			p.world.damage_zombie(z, p.modify_damage(z, SOUL_AURA * p.damage_multiplier()), Vector3.ZERO, 0.0, z.centre(), false)
	p.world.end_act(was)


## Gate of the Dead: a Psychopomp who falls with enough souls about them comes back at once.
static func gate_of_the_dead(p: Player) -> bool:
	if not p.has_flag("gate") or p.souls < GATE_SOULS or p.death_gate_left > 0.0:
		return false
	p.set_souls(0)
	p.death_gate_left = GATE_REST
	p.hp = p.max_hp() * 0.5
	p.guard_left = maxf(p.guard_left, 1.0)
	p.say("Turned back at the Gate!")
	p.world.fx_ring(p.global_position, 4.0, PALE)
	p.world.sfx_at("souls_go", p.global_position, 0.0)
	return true


# --- Kills and blows ----------------------------------------------------------------------------

static func on_kill(p: Player, z: Zombie) -> void:
	if p.has_flag("ferry_due") and p.hp < p.max_hp():
		p.heal(DUE_HEAL)
	if p.spec_id == "tollkeeper" and in_debt(p, z):
		_pay(p)
	p.debtors.erase(z.get_instance_id())


## A debtor dies: the Tollkeeper takes an obol.
static func _pay(p: Player) -> void:
	p.obols = mini(obols_max(p), p.obols + 1)
	if p.hp < p.max_hp():
		p.heal(OBOL_HEAL + p.m("obol_heal"))
	p.world.sfx_at("obol", p.global_position, -4.0)


## Each melee blow: Oarlock's doubled blow is spent.
static func on_blow(p: Player, z: Zombie) -> void:
	p.oarlock = false
	if z and p.spec_id == "tollkeeper":
		collect(p, z)


static func ward(p: Player) -> float:
	return 1.0 - SOUL_WARD * p.souls if p.has_flag("soul_ward") else 1.0
