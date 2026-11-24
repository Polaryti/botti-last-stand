class_name CrownUpgrades
extends RefCounted
## The Class Upgrades of the Adept, the Cartographer and the Bandit, one for each path (sold in the
## Store, ShopDefs). What stays on the ground a while (Event Horizon, a Trailblazer's marks) is a
## PathField; the Contract's seal is a ContractSeal; the rest happens here. All numbers are here.

# Adept
const ENCORE_EVERY := 3 # every third stance change
const ENCORE_REACH := 2.0 # metres further than the sweep
const ENCORE_POWER := 1.5
const ENCORE_DOWN := 0.8 # seconds knocked down
const SHARDS := 6
const SHARD_REACH := 10.0
const SHARD_DAMAGE := 25.0
const SHARD_BLEED := Vector2(8.0, 3.0) # damage a second, and seconds
const SHARD_SPEED := 30.0
const HORIZON_TIME := 4.0
const HORIZON_REACH := 7.0
const HORIZON_DPS := 15.0
const HORIZON_PULL := 3.5 # metres a second towards its heart
const HORIZON_COLLAPSE := 60.0
const HORIZON_COLLAPSE_REACH := 4.0
# Cartographer
const SHOWER_STARS := 5
const SHOWER_DAMAGE := 40.0
const SHOWER_RADIUS := 2.5
const SHOWER_STUN := 0.5
const SHOWER_EVERY := 0.3 # seconds between one star and the next
const DOOR_BELOW := 0.3 # of max health
const DOOR_HEAL := 20.0
const DOOR_REST := 60.0
const DOOR_MIN := 8.0 # metres: a gate any nearer is no way out
const DOOR_GUARD := 1.0 # seconds nothing touches you as you come out
const BLAZE_GAP := 3.0
const BLAZE_TIME := 8.0
const BLAZE_RADIUS := 1.5
const BLAZE_SPEED := 0.2
# Bandit
const LUCKY_ONE_IN := 4
const CONTRACT_MARK := 1.5 # it takes 50% more damage
const CONTRACT_HEAL := 25.0
const CONTRACT_REFUND := 8.0
const TOLL_EVERY := 3
const TOLL_PIN := 1.5

const VOID := Color(0.55, 0.32, 0.95)
const GLASS := Color(0.72, 0.9, 1.0)
const COIN := Color(1.0, 0.8, 0.32)


## Timers the upgrades keep on a player, run every physics step.
static func tick(p: Player, _delta: float) -> void:
	if p.contract_on != null:
		_watch_contract(p)
	if p.spec_id == "pathfinder" and p.has_item("trailblazer"):
		_blaze(p)


# --- Adept ---------------------------------------------------------------------------------

## Blade Dancer: whether this stance change is the Encore (every third), counted as it comes.
static func next_is_encore(p: Player) -> bool:
	if not p.has_item("encore"):
		return false
	p.encore_count += 1
	return p.encore_count % ENCORE_EVERY == 0


## How many stance changes until the next Encore, for the HUD's marks (0: the next one is).
static func encore_have(p: Player) -> int:
	return p.encore_count % ENCORE_EVERY


## The Encore itself, after the sweep it crowns: everything inside its wider reach goes down.
static func encore(p: Player, col: Color) -> void:
	var reach := p.sweep_reach() + ENCORE_REACH
	p.world.fx_ring(p.global_position, reach, col)
	p.world.fx_blast(p.global_position + Vector3.UP * 0.8, reach * 0.55, Color(col.lightened(0.3), 0.4))
	if Net.active():
		Net.blast_fx(p.global_position + Vector3.UP * 0.8, reach * 0.55, Color(col.lightened(0.3), 0.4))
	for z: Zombie in p.world.zombies_near(p.global_position, reach, 24):
		z.stun(ENCORE_DOWN)
	for r: Target in p.world.rivals_near(p.global_position, reach):
		p.world.status_rival(r, Net.Status.STUN, ENCORE_DOWN)
	p.world.sfx_at("encore", p.global_position, -2.0)
	p.shake(0.5)
	p.say("Encore")


## Mirror Step: an undone hit shatters the mirror into shards that fly at the nearest enemies.
static func shatter(p: Player) -> void:
	if not p.has_item("shattered_mirror"):
		return
	var chest := p.global_position + Vector3.UP * 1.1
	var near: Array[Node3D] = []
	for z: Zombie in p.world.zombies_near(p.global_position, SHARD_REACH, 24):
		if z.is_alive():
			near.append(z)
	var was := p.world.begin_act(p)
	for r: Target in p.world.rivals_near(p.global_position, SHARD_REACH):
		near.append(r)
	p.world.end_act(was)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(chest) < b.global_position.distance_squared_to(chest))
	p.world.fx_blast(chest, 1.1, Color(GLASS, 0.55))
	if Net.active():
		Net.blast_fx(chest, 1.1, Color(GLASS, 0.55))
	p.world.sfx_at("mirror_shatter", chest, -3.0)
	if near.is_empty():
		return
	var dmg := SHARD_DAMAGE * p.damage_multiplier()
	for i in SHARDS:
		# Round the nearest, as many as there are: with two near, each takes three.
		var t: Node3D = near[i % mini(near.size(), SHARDS)]
		var aim: Vector3 = (t as Zombie).centre() if t is Zombie else t.global_position + Vector3.UP
		var turn := (float(i) - float(SHARDS - 1) * 0.5) * 0.12
		var from := chest + Vector3(cos(turn * 9.0), 0.15 * sin(i * 2.1), sin(turn * 9.0)) * 0.35
		var dir := (aim - from).normalized()
		var shot := p.world.spawn_player_arrow(p, from, dir * SHARD_SPEED, 0.0, SHARD_REACH + 3.0, 0.5, dmg, false, "shard")
		if shot:
			# Glass, whatever the bow would add to an arrow: no fire, no bounce, no piercing.
			shot.bleed = SHARD_BLEED
			shot.fire = false
			shot.bounces = 0
			shot.pierce = 0


## Void Walker: leaving Void stance tears a horizon open where you stand.
static func event_horizon(p: Player) -> void:
	if not p.has_item("event_horizon"):
		return
	p.world.spawn_path_field(p.net_id(), "horizon", p.global_position)
	if Net.active():
		Net.path_field(p.net_id(), "horizon", p.global_position)


## The horizon's pull and bite on creatures, for its owner's phone, each PathField step.
static func horizon_harm(f: PathField, owner_player: Player, step: float) -> void:
	var dmg := HORIZON_DPS * step * owner_player.damage_multiplier()
	for z: Zombie in f.world.zombies_near(f.position, HORIZON_REACH, 32):
		if not z.is_alive() or not f.contains(z.position):
			continue
		z.drift_to(f.position, HORIZON_PULL)
		z.next_hitter = f.owner_peer
		z.take_damage(dmg, Vector3.ZERO, 0.0, z.centre())


## It falls in on itself: one last blow to all that is close.
static func horizon_collapse(f: PathField, owner_player: Player) -> void:
	var dmg := HORIZON_COLLAPSE * owner_player.damage_multiplier()
	for z: Zombie in f.world.zombies_near(f.position, HORIZON_COLLAPSE_REACH, 32):
		if z.is_alive():
			z.next_hitter = f.owner_peer
			z.take_damage(dmg, z.position - f.position, 2.5, z.centre())
			owner_player.on_hit(false)
	for r: Target in f.world.rivals_near(f.position, HORIZON_COLLAPSE_REACH):
		f.world.hit_rival(r, dmg, f.position)


# --- Cartographer --------------------------------------------------------------------------

## Star Reader: where the nth star of a Star Shower falls. The stars go to the creatures under the
## constellation, toughest first, one each while they last (looked at as each falls, so they follow
## what they are after); the rest come down across its ground, spread over the triangles.
static func shower_spot(s: SurveyNet, n: int) -> Vector3:
	var inside := s.creatures_starlit()
	inside.sort_custom(func(a: Zombie, b: Zombie) -> bool: return a.hp > b.hp)
	if n < inside.size():
		return inside[n].position
	var tris := s.triangles()
	if tris.is_empty():
		return s.beacons[s.beacons.size() - 1]["at"]
	var tri: Vector3i = tris[n % tris.size()]
	var w := Vector3(0.15 + 0.6 * fmod(n * 0.618, 1.0), 0.15 + 0.6 * fmod(n * 0.382 + 0.3, 1.0), 0.0)
	w.z = maxf(0.15, 1.4 - w.x - w.y)
	w /= w.x + w.y + w.z
	var at: Vector3 = s.beacons[tri.x]["at"] * w.x + s.beacons[tri.y]["at"] * w.y + s.beacons[tri.z]["at"] * w.z
	at.y = s.world.ground_at(at)
	return at


## One star of the shower, struck by the Cartographer's phone and seen on every phone.
static func shower_star(s: SurveyNet, at: Vector3, who: Player) -> void:
	SurveyNet.show_falling_star(s.world, at)
	if Net.active():
		Net.survey_fx(0, at)
	var dmg := SHOWER_DAMAGE
	for z: Zombie in s.world.zombies_near(at, SHOWER_RADIUS, 16):
		if z.is_alive():
			z.next_hitter = s.owner_peer
			z.take_damage(dmg, z.position - at, 2.0, z.centre())
			z.stun(SHOWER_STUN)
	if who and Net.pvp():
		var was := s.world.begin_act(who)
		for r in s.world.rivals_near(at, SHOWER_RADIUS):
			s.world.hit_rival(r, dmg, at)
			s.world.status_rival(r, Net.Status.STUN, SHOWER_STUN)
		s.world.end_act(was)


## Worlds Traveler: whether Open Door is ready to save you now (for the HUD as well).
static func door_ready(p: Player) -> bool:
	return p.spec_id == "worlds_traveler" and p.has_item("open_door") and p.open_door_cd <= 0.0 and _far_gate(p) != Vector3.INF


## The Waygate farthest from you, if one is far enough to be a way out.
static func _far_gate(p: Player) -> Vector3:
	var s: SurveyNet = p.world.survey_of(p.net_id())
	if s == null or s.kind() != "gates":
		return Vector3.INF
	var best := Vector3.INF
	var far := DOOR_MIN
	for b: Dictionary in s.beacons:
		var d := Vector2((b["at"] as Vector3).x - p.global_position.x, (b["at"] as Vector3).z - p.global_position.z).length()
		if d >= far:
			far = d
			best = b["at"]
	return best


## A hit that would leave you under 30% health: if a far gate stands, you go through it instead, and
## the hit is never taken. True when it saved you.
static func open_door(p: Player, dmg: float) -> bool:
	if p.hp - dmg >= p.max_hp() * DOOR_BELOW or not door_ready(p):
		return false
	var gate := _far_gate(p)
	var from := p.global_position
	var ahead := gate - from
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
	var to := gate + ahead * 1.6
	to.y = p.world.ground_at(to) + 0.05
	p.global_position = to
	p.velocity = Vector3.ZERO
	p.open_door_cd = DOOR_REST
	p.gate_rest_left = maxf(p.gate_rest_left, 1.5) # not straight back through the gate you came out of
	p.guard_left = maxf(p.guard_left, DOOR_GUARD)
	p.heal(DOOR_HEAL)
	p.world.fx_mist(from + Vector3.UP, 1.0)
	p.world.fx_mist(to + Vector3.UP, 1.0)
	p.world.fx_ring(to, 2.4, SurveyNet.AZURE)
	if Net.active():
		Net.survey_fx(1, from)
		Net.survey_fx(1, to)
	p.world.sfx_at("waygate", to, 0.0)
	p.say("Open Door")
	return true


## Pathfinder: a mark on the trail every few metres while you are on the move.
static func _blaze(p: Player) -> void:
	if p.dead or not p.is_on_floor():
		return
	var here := p.global_position
	if p.blaze_from == Vector3.INF:
		p.blaze_from = here
		return
	if Vector2(here.x - p.blaze_from.x, here.z - p.blaze_from.z).length() < BLAZE_GAP:
		return
	p.blaze_from = here
	p.world.spawn_path_field(p.net_id(), "blaze", here)
	if Net.active():
		Net.path_field(p.net_id(), "blaze", here)


# --- Bandit ----------------------------------------------------------------------------------

## Thief: a Steal picks a pocket too, and one in four is lucky and comes back at once.
static func lucky_fingers(p: Player, at: Vector3) -> void:
	if not p.has_item("lucky_fingers"):
		return
	BanditKit.plunder(p, at, true)
	p.world.fx_blast(at + Vector3.UP * 0.6, 0.5, Color(COIN, 0.8))
	p.lucky_steals += 1
	if p.lucky_steals % LUCKY_ONE_IN == 0:
		p.path_art_cd_left = 0.0
		p.world.sfx_at("coin_flip", p.global_position, -2.0)
		p.say("Lucky!")


## How many Steals until the lucky one, for the HUD (0: the next is).
static func lucky_have(p: Player) -> int:
	return p.lucky_steals % LUCKY_ONE_IN


## Mercenary: Nightfall names the toughest creature inside it.
static func contract(p: Player, at: Vector3, radius: float, secs: float) -> void:
	if not p.has_item("contract"):
		return
	var best: Zombie = null
	for z: Zombie in p.world.zombies_near(at, radius, 32):
		if z.is_alive() and (best == null or z.max_hp > best.max_hp or (z.max_hp == best.max_hp and z.hp > best.hp)):
			best = z
	if best == null:
		return
	best.mark(CONTRACT_MARK, secs)
	p.contract_on = best
	p.contract_until = p.world.now + secs
	p.contract_at = at
	p.contract_radius = radius
	p.world.show_contract(best, secs)
	if Net.active():
		Net.contract(best, secs)


static func _watch_contract(p: Player) -> void:
	var z: Variant = p.contract_on
	if not is_instance_valid(z) or p.world.now > p.contract_until:
		p.contract_on = null
		return
	if (z as Zombie).is_alive():
		return
	p.contract_on = null
	# Paid: you and every friend still inside the dome.
	p.heal(CONTRACT_HEAL)
	p.path_art_cd_left = maxf(0.0, p.path_art_cd_left - CONTRACT_REFUND)
	var was := p.world.begin_act(p)
	for t: Target in p.world.friends_near(p.contract_at, p.contract_radius):
		Net.guard_peer(p.world.peer_of(t), 0.0, CONTRACT_HEAL)
	p.world.end_act(was)
	p.world.fx_ring(p.contract_at, p.contract_radius, COIN)
	p.world.sfx_at("coin_flip", p.global_position, -1.0)
	p.say("Contract paid")


## Highwayman: whether this Dagger Fan is the Toll (every third), counted as it comes.
static func next_is_toll(p: Player) -> bool:
	if not p.has_item("toll_road"):
		return false
	p.fans_thrown += 1
	return p.fans_thrown % TOLL_EVERY == 0


static func toll_have(p: Player) -> int:
	return p.fans_thrown % TOLL_EVERY
