class_name UpgradeKit
extends RefCounted
## The Class Upgrades of the Cavalry and the Magician, one for each path (sold in the Store, ShopDefs):
## Lance Charge, Consecration and Whistle; Grave Call, Frost Nova and Hall of Mirrors.

const CHARGE_REACH := 10.0
const CHARGE_TIME := 0.32 # seconds to cover it
const CHARGE_DAMAGE := 55.0
const CHARGE_WIDTH := 1.8 # how far to either side of the path a body is caught
const CHARGE_KNOCK := 6.0

const CONSECRATE_RADIUS := 6.0
const CONSECRATE_TIME := 8.0
const CONSECRATE_HEAL := 4.0 # a second, to friends inside
const CONSECRATE_BURN := 3.0 # seconds of burning, renewed while an enemy stays inside

const GRAVE_REACH := 12.0
const GRAVE_RECENT := 10.0 # how long ago a fall may have been
const GRAVE_RAISED := 3
const GRAVE_TIME := 15.0

const NOVA_RADIUS := 6.0
const NOVA_DAMAGE := 25.0
const NOVA_FREEZE := 2.0

const MIRROR_SHARE := 0.25 # a hit of at least this much of your health is swapped away
const MIRROR_REST := 30.0


## What an upgrade's ability does when its cast is over. Returns false for a path it does not know.
static func cast(p: Player, spec: String) -> bool:
	match spec:
		"lancer": lance_charge(p)
		"paladin": consecrate(p)
		"horse_archer": whistle(p)
		"necromancer": grave_call(p)
		"elementalist": frost_nova(p)
		_: return false
	return true


# --- Lance Charge (Lancer) --------------------------------------------------------

static func lance_charge(p: Player) -> void:
	var dir := -p.global_basis.z
	dir = Vector3(dir.x, 0, dir.z).normalized()
	p.charge_dir = dir
	p.charge_left = CHARGE_TIME
	p.charge_hit.clear()
	p.guard_left = maxf(p.guard_left, CHARGE_TIME + 0.1)
	p.sfx("gallop", -2.0, 1.3)
	p.say("Lance Charge!")
	p._noise(10.0)


## One step of the charge: on at speed (walls still stop it), and everything beside the lance is struck
## once and thrown aside.
static func tick_charge(p: Player, delta: float) -> void:
	p.charge_left -= delta
	var speed := CHARGE_REACH / CHARGE_TIME
	p.velocity = Vector3(p.charge_dir.x * speed, p.velocity.y - 30.0 * delta, p.charge_dir.z * speed)
	p.move_and_slide()
	var dmg := CHARGE_DAMAGE * p.damage_multiplier()
	for z: Zombie in p.world.zombies_near(p.global_position, CHARGE_WIDTH + 1.0, 16):
		if p.charge_hit.has(z) or not z.is_alive():
			continue
		p.charge_hit[z] = true
		var away := z.position - p.global_position
		away.y = 0.0
		var side := away - p.charge_dir * away.dot(p.charge_dir)
		var push := (side.normalized() if side.length() > 0.1 else p.charge_dir) + p.charge_dir * 0.5
		z.take_damage(p.modify_damage(z, dmg), push, CHARGE_KNOCK, z.centre())
		p.on_hit(false)
	for r: Target in p.world.rivals_near(p.global_position, CHARGE_WIDTH + 0.5):
		if p.charge_hit.has(r):
			continue
		p.charge_hit[r] = true
		p.world.hit_rival(r, dmg, p.global_position)
	if p.charge_left <= 0.0:
		p.charge_left = 0.0
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		p.world.fx_blast(p.global_position + Vector3.UP * 0.4, 1.4, Color(0.95, 0.75, 0.45, 0.4))


# --- Consecration (Paladin) --------------------------------------------------------

static func consecrate(p: Player) -> void:
	var at := p.global_position
	p.world.spawn_consecration(p.net_id(), at, CONSECRATE_RADIUS, CONSECRATE_TIME)
	if Net.active():
		Net.consecrate(p.net_id(), at, CONSECRATE_RADIUS, CONSECRATE_TIME)
	p.say("Consecration")


# --- Whistle (Horse Archer) -------------------------------------------------------

static func whistle(p: Player) -> void:
	if p.is_riding():
		return
	p.horse_progress = maxi(p.horse_progress, p.horses_needed())
	p.mount()
	p.say("Whistle")


## Whether Whistle would do anything now (no second horse while riding the first).
static func whistle_has_use(p: Player) -> bool:
	return not p.is_riding() and p.has_mount()


# --- Grave Call (Necromancer) -------------------------------------------------------

## The spots where enemies fell near you lately, nearest first.
static func graves(p: Player) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for fall: Dictionary in p.world.recent_falls(GRAVE_RECENT):
		var at: Vector3 = fall["at"]
		if at.distance_to(p.global_position) <= GRAVE_REACH:
			out.append(at)
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(p.global_position) < b.distance_to(p.global_position))
	return out


static func grave_call(p: Player) -> void:
	var spots := graves(p)
	var raised := 0
	for at in spots:
		if raised >= GRAVE_RAISED:
			break
		p.world.spawn_ally("skeleton", at, GRAVE_TIME * p.m("ally_time"))
		p.world.fx_mist(at + Vector3.UP * 0.5, 0.9)
		p.world.forget_fall(at)
		raised += 1
	if raised == 0:
		# Nothing to raise: nothing is spent.
		p.mana = minf(p.max_mana(), p.mana + p.art_cost())
		p.art_cd_left = 0.0
		p.say("No fallen to raise")
		return
	p.say("Grave Call: %d rise" % raised)
	p.sfx("wraith", -4.0, 0.8)


# --- Frost Nova (Elementalist) -------------------------------------------------------

static func frost_nova(p: Player) -> void:
	var at := p.global_position
	var dmg := NOVA_DAMAGE * p.m("spell_damage") * p.damage_multiplier()
	var col := Color(0.62, 0.86, 1.0, 0.5)
	p.world.fx_blast(at + Vector3.UP * 0.6, NOVA_RADIUS * 0.8, col)
	if Net.active():
		Net.blast_fx(at + Vector3.UP * 0.6, NOVA_RADIUS * 0.8, col)
	p.sfx("blast", -3.0, 1.6, 0.1)
	for z: Zombie in p.world.zombies_near(at, NOVA_RADIUS, 32):
		z.take_damage(p.modify_damage(z, dmg), z.position - at, 1.0, z.centre())
		z.freeze(NOVA_FREEZE)
		p.on_hit(false)
	for r: Target in p.world.rivals_near(at, NOVA_RADIUS):
		p.world.hit_rival(r, dmg, at)
		p.world.status_rival(r, Net.Status.FREEZE, NOVA_FREEZE)
	p._noise(8.0)


# --- Hall of Mirrors (Illusionist) -------------------------------------------------------

## Called with a hit about to land (after armour and shields): true when the Illusionist was not
## there to take it.
static func mirror_dodges(p: Player, dmg: float) -> bool:
	if not p.has_item("hall_of_mirrors") or p.mirror_hall_left > 0.0 or dmg < p.max_hp() * MIRROR_SHARE:
		return false
	p.mirror_hall_left = MIRROR_REST
	p._mirror_swap()
	p.say("Hall of Mirrors")
	return true
