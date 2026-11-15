class_name PathUpgrades
extends RefCounted
## The Class Upgrades of the Revenant, the Monk, the Plague Doctor, the Artificer and the Commander, one
## for each path (sold in the Store, ShopDefs). Fields that stay on the ground a while (Mist Wake,
## Healing Mist, the Plague Censer, the Tesla Coil) are PathField nodes; the rest happens here.

# Revenant
const MIST_WAKE_RADIUS := 1.5 # a pool 3 m across
const MIST_WAKE_TIME := 4.0
const MIST_WAKE_DPS := 8.0
const TORN_RIFT_RADIUS := 2.5
const TORN_RIFT_DAMAGE := 30.0
const SOUL_LINK_SHARE := 0.25
const SOUL_LINK_HEAL := 20.0
# Monk
const DRAGON_SPIN_TIME := 1.5
const DRAGON_SPIN_HITS := 3
const DRAGON_SPIN_DAMAGE := 15.0
const DRAGON_SPIN_REACH := 3.0
const FIGHTING_BODY_DAMAGE := 20.0
const FIGHTING_BODY_EVERY := 1.0
const FIGHTING_BODY_REACH := 2.5
const FIGHTING_BODY_GUARD := 0.3 # it takes this much less damage
const AVALANCHE_DELAY := 0.6
const AVALANCHE_REACH := 2.0 # times the stomp's own reach
const AVALANCHE_POWER := 0.5 # of the stomp's damage
const AVALANCHE_STUN := 1.5
# Plague Doctor
const HEALING_MIST_RADIUS := 4.0
const HEALING_MIST_TIME := 6.0
const HEALING_MIST_HEAL := 5.0 # a second
const CENSER_RADIUS := 5.0
const CENSER_TIME := 6.0
const CENSER_DPS := 10.0
const RAT_TIDE_RATS := 8
const RAT_TIDE_REACH := 10.0
const RAT_TIDE_WIDTH := 1.5 # either side of its line
const RAT_TIDE_DAMAGE := 30.0
const RAT_TIDE_STUN := 0.6
const RAT_TIDE_POISON := Vector2(8.0, 5.0) # what the bites leave: damage per second, and seconds
const RAT_TIDE_TIME := 0.7 # for the rats to run its length
# Artificer
const GREAT_KEG_EVERY := 4
const GREAT_KEG_POWER := 2.0 # reach and damage
const FIELD_TURRET_TIME := 20.0
const TESLA_TIME := 6.0
const TESLA_EVERY := 0.5
const TESLA_TARGETS := 4
const TESLA_REACH := 8.0
const TESLA_DAMAGE := 12.0
# Commander
const ARCANE_SURGE_EVERY := 3
const GRAPESHOT_EVERY := 4
const GRAPESHOT_PELLETS := 6
const GRAPESHOT_DAMAGE := 20.0
const GRAPESHOT_CONE := 20.0 # degrees, edge to edge
const SHIELD_WALL_RADIUS := 10.0
const SHIELD_WALL_AMOUNT := 40.0
const SHIELD_WALL_TIME := 8.0

const MIST := Color(0.62, 0.92, 0.95)
const RIFT := Color(0.42, 0.85, 0.9)
const STONE := Color(0.8, 0.72, 0.55)


## The abilities these upgrades add, for the paths that have none of their own. False for a path it
## does not know.
static func cast(p: Player, spec: String) -> bool:
	match spec:
		"pestilence": censer(p)
		"rat_king": rat_tide(p)
		"mechanic": field_turret(p)
		_: return false
	return true


## Timers the upgrades keep on a player, run every physics step.
static func tick(p: Player, delta: float) -> void:
	if p.hunt_left > 0.0:
		UpgradeKit.tick_hunt(p, delta)
	if p.spin_left > 0.0:
		p.spin_left -= delta
		var due := int(floor((DRAGON_SPIN_TIME - maxf(p.spin_left, 0.0)) / (DRAGON_SPIN_TIME / DRAGON_SPIN_HITS)))
		while p.spin_hits < mini(due, DRAGON_SPIN_HITS):
			p.spin_hits += 1
			_spin_hit(p)
	if p.ward_left > 0.0:
		p.ward_left -= delta
		if p.ward_left <= 0.0:
			p.ward_hp = 0.0


# --- Revenant -----------------------------------------------------------------------------

## Mist Leaper: where you land, the mist stays a while.
static func mist_wake(p: Player) -> void:
	p.world.spawn_path_field(p.net_id(), "mist_wake", p.global_position)
	if Net.active():
		Net.path_field(p.net_id(), "mist_wake", p.global_position)


## Rift Traveller: the jump is over, and every enemy it went through tears open.
static func torn_rifts(p: Player, scarred: Array) -> void:
	var dmg := TORN_RIFT_DAMAGE * p.damage_multiplier()
	for t: Variant in scarred:
		if not is_instance_valid(t):
			continue
		var at: Vector3 = (t as Node3D).global_position + Vector3.UP * 0.9
		p.world.fx_blast(at, TORN_RIFT_RADIUS * 0.7, Color(RIFT, 0.45))
		if Net.active():
			Net.blast_fx(at, TORN_RIFT_RADIUS * 0.7, Color(RIFT, 0.45))
		for z: Zombie in p.world.zombies_near(at, TORN_RIFT_RADIUS, 12):
			z.take_damage(dmg, z.position - at, 2.0, z.centre())
			p.on_hit(false)
		for r: Target in p.world.rivals_near(at, TORN_RIFT_RADIUS):
			p.world.hit_rival(r, dmg, at)
	if not scarred.is_empty():
		p.sfx("mist_blink", -4.0, 0.8, 0.1)


## Summoner: a quarter of a hit is taken by the nearest of your Revenants instead. Returns what is
## left for you.
static func soul_link(p: Player, dmg: float) -> float:
	if not p.has_item("soul_link") or dmg <= 0.0:
		return dmg
	var best: Ally = null
	for a: Ally in p.world.allies:
		if a.kind == "revenant" and not a.dead and a.remote_owner == 0 and a.master == p:
			if best == null or a.global_position.distance_squared_to(p.global_position) < best.global_position.distance_squared_to(p.global_position):
				best = a
	if best == null:
		return dmg
	var share := dmg * SOUL_LINK_SHARE
	best.hurt(share, p.global_position)
	return dmg - share


## Summoner: one of your Revenants has fallen (not merely faded): its strength comes back to you.
static func soul_returns(p: Player) -> void:
	if p.has_item("soul_link") and not p.dead:
		p.heal(SOUL_LINK_HEAL)
		p.world.fx_mist(p.global_position + Vector3.UP, 0.8)


# --- Monk -----------------------------------------------------------------------------------

## Bo Master: Pole Vault's landing goes on into a spin.
static func dragon_spin(p: Player) -> void:
	p.spin_left = DRAGON_SPIN_TIME
	p.spin_hits = 0
	p.say("Dragon Spin")


static func _spin_hit(p: Player) -> void:
	var dmg := DRAGON_SPIN_DAMAGE * p.m("melee_damage") * p.damage_multiplier()
	p.world.fx_ring(p.global_position, DRAGON_SPIN_REACH, Color(0.95, 0.75, 0.35))
	p.sfx("heavy_swing", -5.0, 1.25, 0.05)
	for z: Zombie in p.world.zombies_near(p.global_position, DRAGON_SPIN_REACH, 16):
		z.take_damage(dmg, Vector3.ZERO, 0.0, z.centre())
		z.pull_to(p.global_position)
		p.on_hit(false)
	for r: Target in p.world.rivals_near(p.global_position, DRAGON_SPIN_REACH):
		p.world.hit_rival(r, dmg, p.global_position)
	p.start_spin_swing()


## Spirit Walker: the body left behind strikes whatever is close. Called by the body (an Ally).
static func body_strikes(body: Ally, owner_player: Player) -> void:
	var dmg := FIGHTING_BODY_DAMAGE * owner_player.m("melee_damage") * owner_player.damage_multiplier()
	var hit := false
	for z: Zombie in body.world.zombies_near(body.global_position, FIGHTING_BODY_REACH, 8):
		z.next_hitter = owner_player.net_id()
		z.take_damage(dmg, z.position - body.global_position, 2.0, z.centre())
		owner_player.on_hit(false)
		hit = true
	for r: Target in body.world.rivals_near(body.global_position, FIGHTING_BODY_REACH):
		body.world.hit_rival(r, dmg, body.global_position)
		hit = true
	if hit:
		body.strike_anim()


## Iron Mountain: the stomp's second ring, further out and a moment later.
static func avalanche(p: Player, at: Vector3, radius: float, dmg: float) -> void:
	if p.dead:
		return
	var col := STONE
	p.world.fx_ring(at, radius, col)
	p.world.fx_blast(at + Vector3.UP * 0.2, radius * 0.45, Color(col, 0.35))
	if Net.active():
		Net.blast_fx(at + Vector3.UP * 0.2, radius * 0.45, Color(col, 0.35))
	p.sfx("earth_slam", -3.0, 1.1, 0.1)
	p.shake(0.6)
	for z: Zombie in p.world.zombies_near(at, radius, 24):
		z.take_damage(dmg, z.position - at, 3.0, z.centre())
		z.stun(AVALANCHE_STUN)
		p.on_hit(false)
	for r: Target in p.world.rivals_near(at, radius):
		p.world.hit_rival(r, dmg, at)
		p.world.status_rival(r, Net.Status.STUN, AVALANCHE_STUN)


# --- Plague Doctor -------------------------------------------------------------------------

static func healing_mist(p: Player) -> void:
	p.world.spawn_path_field(p.net_id(), "healing_mist", p.global_position)
	if Net.active():
		Net.path_field(p.net_id(), "healing_mist", p.global_position)


static func censer(p: Player) -> void:
	p.world.spawn_path_field(p.net_id(), "censer", p.global_position)
	if Net.active():
		Net.path_field(p.net_id(), "censer", p.global_position)
	p.say("Plague Censer")
	p.sfx("bell", -9.0, 0.7)


## Rat King: a tide of rats runs out along where you look, and bowls over all in its way.
static func rat_tide(p: Player) -> void:
	var dir := -p.global_basis.z
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var from := p.global_position
	p.world.spawn_rat_tide(from, dir)
	if Net.active():
		Net.rat_tide(from, dir)
	var power := p.m("ally_damage") * p.damage_multiplier()
	var dmg := RAT_TIDE_DAMAGE * power
	for z: Zombie in p.world.zombies_near(from + dir * RAT_TIDE_REACH * 0.5, RAT_TIDE_REACH * 0.5 + RAT_TIDE_WIDTH, 32):
		if _on_line(z.position, from, dir):
			z.take_damage(dmg, dir, 2.0, z.centre())
			if z.is_alive():
				z.add_dot(RAT_TIDE_POISON.x * power, RAT_TIDE_POISON.y)
				Game.note_poison(RAT_TIDE_POISON.x * power * RAT_TIDE_POISON.y)
			z.stun(RAT_TIDE_STUN)
			p.on_hit(false)
	for r: Target in p.world.rivals_near(from + dir * RAT_TIDE_REACH * 0.5, RAT_TIDE_REACH * 0.5 + RAT_TIDE_WIDTH):
		if _on_line(r.global_position, from, dir):
			p.world.hit_rival(r, dmg, from)
			p.world.status_rival(r, Net.Status.STUN, RAT_TIDE_STUN)
			p.world.status_rival(r, Net.Status.POISON, RAT_TIDE_POISON.y)
	p.say("Rat Tide")
	p.sfx("wolf", -10.0, 2.2, 0.1)


static func _on_line(at: Vector3, from: Vector3, dir: Vector3) -> bool:
	var rel := at - from
	rel.y = 0.0
	var along := rel.dot(dir)
	return along >= 0.0 and along <= RAT_TIDE_REACH and (rel - dir * along).length() <= RAT_TIDE_WIDTH


# --- Artificer -------------------------------------------------------------------------------

## Pyromaniac: whether this throw is the powder keg (every fourth).
static func next_is_keg(p: Player) -> bool:
	if not p.has_item("great_keg"):
		return false
	p.bombs_thrown += 1
	return p.bombs_thrown % GREAT_KEG_EVERY == 0


## Mechanic: a Clockwork Sentry set down in front of you.
static func field_turret(p: Player) -> void:
	var at := p.global_position - p.global_basis.z * 2.0
	var cell := p.world.grid.to_cell(at)
	if not p.world.grid.is_free(cell):
		at = p.world.grid.to_world(p.world.grid.nearest_free(cell))
	p.world.place_sentry(p, at, FIELD_TURRET_TIME)
	p.sfx("creak", -2.0, 1.0)
	p.say("Field Turret")


## Inventor: the coil is set down where you stand.
static func tesla_coil(p: Player) -> void:
	p.world.spawn_path_field(p.net_id(), "tesla", p.global_position)
	if Net.active():
		Net.path_field(p.net_id(), "tesla", p.global_position)
	p.sfx("creak", -4.0, 1.4)


# --- Commander ---------------------------------------------------------------------------------

## Warlock: how many War Staff attacks to each empowered bolt.
static func bolt_every(p: Player) -> int:
	return ARCANE_SURGE_EVERY if p.has_item("arcane_surge") else 5


## Gunner: every fourth shot of the musket is a spread of shot.
static func grapeshot(p: Player, start: Vector3, dir: Vector3, d: Dictionary) -> bool:
	if not p.has_item("grapeshot"):
		return false
	p.musket_shots += 1
	if p.musket_shots % GRAPESHOT_EVERY != 0:
		return false
	var speed := float(d["speed"]) * p.m("ranged_power")
	var reach := float(d["range"]) * p.m("ranged_power") * 0.5
	var dmg := GRAPESHOT_DAMAGE * p._ranged_mult()
	var side := dir.cross(Vector3.UP).normalized()
	for i in GRAPESHOT_PELLETS:
		var k := float(i) / (GRAPESHOT_PELLETS - 1) - 0.5
		var spread := dir.rotated(Vector3.UP, deg_to_rad(GRAPESHOT_CONE) * k)
		spread = spread.rotated(side, deg_to_rad(randf_range(-3.0, 3.0)))
		p.world.spawn_player_arrow(p, start, spread * speed, 0.0, reach, 1.5, dmg, true, "pellet")
	# No word on the screen: the musket says it. Fire and burning powder fan out of the muzzle, the
	# pellets fly as glowing iron, and the HUD's charge marks burst around the crosshair.
	p.world.fx_grapeshot(start, dir, GRAPESHOT_CONE * 1.4, GRAPESHOT_PELLETS)
	if Net.active():
		Net.blast_fx(start + Vector3(dir.x, 0.0, dir.z).normalized() * 0.7, 1.0, Color(1.0, 0.6, 0.2, 0.75))
	p.grapeshot_flash = 1.0
	return true


## How many musket shots until the next Grapeshot, for the HUD: 0 means the next one is.
static func grapeshot_in(p: Player) -> int:
	return GRAPESHOT_EVERY - 1 - p.musket_shots % GRAPESHOT_EVERY


## Vanguard: Command (and Last Command) put a shield on you and every friend near you.
static func shield_wall(p: Player) -> void:
	if not p.has_item("shield_wall"):
		return
	p.ward(SHIELD_WALL_AMOUNT, SHIELD_WALL_TIME)
	for t: Target in p.world.friends_near(p.global_position, SHIELD_WALL_RADIUS):
		Net.ward_peer(p.world.peer_of(t), SHIELD_WALL_AMOUNT, SHIELD_WALL_TIME)
	p.world.fx_ring(p.global_position, SHIELD_WALL_RADIUS, Color(0.95, 0.8, 0.4))
