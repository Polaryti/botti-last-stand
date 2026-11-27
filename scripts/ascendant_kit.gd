class_name AscendantKit
extends RefCounted
## The Ascendant: one ability button, and a hand that falls hardest on what is more than mortal. It
## strikes bosses, minibosses and Fontanova's mutants harder than anything else does.
## Ascend leaps up and crashes down on everything near where it lands. Each profession makes the button
## its own:
## - a Godslayer leaps on the enemy it faces with Deicide: a heavy blow that ends lesser things outright
##   when they are low, and that breaks an attack being readied, even a god's (Zombie.break_rite);
## - an Adorer of Al'quimelea drinks the Elixir of Change: for a while it is Changed (quicker, its blows
##   poisoning), and a field of change opens where it stands that poisons and holds what stays in it.
## The Adorer is earned (Game.earn_spec): win a night on Fontanova as the Ascendant.
## Every number lives here; the text audit checks the words in the tree against them.

# The class
const BANE := 0.15 # how much harder it strikes bosses, minibosses and mutants
# Ascend
const ASCEND_REACH := 8.0
const ASCEND_RADIUS := 3.0
const ASCEND_DAMAGE := 35.0
const ASCEND_STUN := 0.6
# The core of the tree
const DIVINE_BANE := 0.2 # Divine Bane: more again
const ICHOR_HEAL := 3.0 # Ichor: health from each kill
# Godslayer: Deicide
const DEICIDE_REACH := 10.0
const DEICIDE_CONE := 70.0 # degrees either side of where you look
const DEICIDE_DAMAGE := 70.0
const DEICIDE_STRIKE := 3.5 # how near where it lands its quarry must be
const EXECUTE_BELOW := 0.25 # it ends anything but a boss or miniboss below this share of its health
const LONG_LEAP := 4.0 # Long Leap
const HEAVY_FALL := 35.0 # Heavy Fall: to everything else near where it lands
const HEAVY_FALL_RADIUS := 3.0
const HEADSMAN_BELOW := 0.4 # Headsman
const GODMARK := 0.2 # Godmark: what Deicide strikes takes this much more from everyone
const GODMARK_TIME := 8.0
const TROPHY_HEAL := 15.0 # Trophy: from each boss, miniboss or mutant you kill
const TROPHY_CD := 3.0 # and seconds off Deicide
const UNBOWED := 0.15 # Unbowed: less harm while a boss or miniboss is near
const UNBOWED_REACH := 20.0
const FAITH_BREAKER := 0.5 # Faith-Breaker: of Deicide's wait given back when it breaks an attack
const TWILIGHT_SHARE := 0.05 # Twilight of the Gods: of a boss's or miniboss's max health, more
const TWILIGHT_REACH := 8.0 # and every attack being readied this near is broken
# Adorer of Al'quimelea: the Elixir of Change
const CHANGED_TIME := 8.0
const CHANGED_SPEED := 0.2
const BLOW_DOT := 5.0 # Changed, your blows poison for this much a second
const BLOW_DOT_TIME := 3.0
const FIELD_RADIUS := 4.0
const FIELD_TELL := 0.8
const FIELD_DOT := 8.0 # the field poisons for this much a second
const FIELD_POISON := 3.0
const FIELD_ROOT := 1.2
const LONG_DRAUGHT := 4.0 # Long Draught
const WIDE_FIELD := 2.0 # Wide Field
const MUTAGEN := 0.2 # Mutagen: Changed, your blows strike harder
const THICK_HIDE := 0.2 # Thick Hide: Changed, less harm
const TRANSMUTE_HEAL := 8.0 # Transmute: Changed, health from each kill
const ALEMBIC := 1.0 # Alembic: Changed, each kill keeps you Changed longer
const CRUCIBLE_RADIUS := 6.0 # Crucible Heart: when the change ends
const CRUCIBLE_DAMAGE := 60.0
const CRUCIBLE_KNOCK := 9.0
const CRUCIBLE_BURN := 2.0

# Adorer of Pelagros: Feast of Embers
const FEAST_RADIUS := 7.0
const FEAST_HEAL := 18.0
const FEAST_DAMAGE := 38.0
const FEAST_COURSE := 12.0
const FEAST_WARD := 1.1
const FEAST_REFUND := 2.0
const FEAST_LAST := 26.0

const ARTS := {
	"": {"name": "Ascend", "cost": 0.0, "cast": 0.1, "cd": 10.0, "icon": "ascend"},
	"godslayer": {"name": "Deicide", "cost": 0.0, "cast": 0.1, "cd": 12.0, "icon": "deicide"},
	"adorer_pelagros": {"name": "Feast of Embers", "cost": 0.0, "cast": 0.32, "cd": 16.0, "icon": "spec_adorer_pelagros", "anim": "Spellcast_Raise"},
	"adorer": {"name": "Elixir of Change", "cost": 0.0, "cast": 0.35, "cd": 15.0, "icon": "elixir", "anim": "Spellcast_Raise"},
}
const ICHOR := Color(0.62, 0.66, 0.24) # the class's colour: the olive-gold of ichor
const CHANGE := Color(0.62, 0.95, 0.42)
const RITE := Color(1.0, 0.9, 0.6)


static func art(p: Player) -> Dictionary:
	return ARTS.get(p.spec_id, ARTS[""])


static func cast(p: Player) -> void:
	match p.spec_id:
		"godslayer": deicide(p)
		"adorer": drink(p)
		"adorer_pelagros": feast(p)
		_: ascend(p)


## Feast shares a meal with allies and brings the god's hearthfire down on nearby enemies.
static func feast(p: Player) -> void:
	var at := p.global_position
	var radius := FEAST_RADIUS + p.m("feast_radius")
	var healing := FEAST_HEAL + p.m("feast_heal")
	var protection := FEAST_WARD if p.has_flag("feast_ward") else 0.0
	var damage := FEAST_DAMAGE + p.m("feast_damage")
	if p.has_flag("last_course"):
		healing += FEAST_COURSE
		damage += FEAST_LAST
	if p.has_flag("feast_cleanse"):
		p.poison_left = 0.0
		p.bleed_left = 0.0
	var was := p.world.begin_act(p)
	p.heal(healing)
	p.guard_left = maxf(p.guard_left, protection)
	for ally: Target in p.world.friends_near(at, radius):
		Net.guard_peer(p.world.peer_of(ally), protection, healing)
	var hits := _crash(p, radius, damage, 0.0, null)
	if hits > 0 and p.has_flag("feast_refund"):
		p.art_cd_left = maxf(0.0, p.art_cd_left - FEAST_REFUND)
	p.world.end_act(was)
	p.world.fx_ring(at + Vector3.UP * 0.18, radius * 0.64, Color("f89959"))
	p.world.sfx_at("feast_bless", at, -1.0)


## The gods, their servants and what they made: bosses, minibosses and Fontanova's mutants.
static func divine(z: Zombie) -> bool:
	return z.is_boss() or z.is_miniboss() or FontaMind.handles(z.type_id)


## How much harder the Ascendant's blows fall on z (Player.modify_damage).
static func damage_scale(p: Player, z: Zombie) -> float:
	var scale := 1.0
	if divine(z):
		scale += BANE + p.m("divine_bane")
	if p.changed_left > 0.0 and p.has_flag("mutagen"):
		scale += MUTAGEN
	return scale


## How much of a blow reaches it (Player.take_hit).
static func hurt_scale(p: Player) -> float:
	if p.class_id != "ascendant":
		return 1.0
	var scale := 1.0
	if p.has_flag("unbowed") and _great_one_near(p):
		scale -= UNBOWED
	if p.changed_left > 0.0 and p.has_flag("thick_hide"):
		scale -= THICK_HIDE
	return scale


static func _great_one_near(p: Player) -> bool:
	for z: Zombie in p.world.zombies_near(p.global_position, UNBOWED_REACH, 24):
		if z.is_alive() and (z.is_boss() or z.is_miniboss()):
			return true
	return false


# --- Ascend ------------------------------------------------------------------------------------

static func ascend(p: Player) -> void:
	p.ascending = "ascend"
	p._start_leap(ASCEND_REACH)
	p.sfx("ascend_leap", -2.0)


## Down again (Player._tick_leap): Ascend crashes on everything near; Deicide strikes its quarry.
static func land(p: Player) -> void:
	var how := p.ascending
	p.ascending = ""
	if how == "deicide":
		_deicide_lands(p)
	else:
		_crash(p, ASCEND_RADIUS, ASCEND_DAMAGE, ASCEND_STUN, null)
	p.world.sfx_at("ascend_crash", p.global_position, 0.0)
	p.shake(0.5)


## A crash where it lands: everything within `radius` but `spare` takes `damage` and is stunned.
static func _crash(p: Player, radius: float, damage: float, stun: float, spare: Zombie) -> int:
	var at := p.global_position
	p.world.fx_ring(at + Vector3.UP * 0.1, radius, RITE)
	p.world.fx_blast(at + Vector3.UP * 0.4, radius * 0.6, Color(RITE, 0.45))
	if Net.active():
		Net.blast_fx(at + Vector3.UP * 0.4, radius * 0.6, Color(RITE, 0.45))
	var caught := 0
	var was := p.world.begin_act(p)
	for z: Zombie in p.world.zombies_near(at, radius + 1.0, 24):
		if not z.is_alive() or z == spare:
			continue
		var flat := Vector3(z.position.x - at.x, 0, z.position.z - at.z)
		if flat.length() > radius + z.body_radius():
			continue
		p.world.damage_zombie(z, p.modify_damage(z, damage * p.damage_multiplier()), flat.normalized(), 3.0, z.centre(), false)
		if stun > 0.0:
			z.stun(stun)
		caught += 1
	if Net.pvp():
		for t: Target in p.world.rivals_near(at, radius):
			p.world.hit_rival(t, damage * p.damage_multiplier(), at)
			if stun > 0.0:
				p.world.status_rival(t, Net.Status.STUN, stun)
			caught += 1
	p.world.end_act(was)
	return caught


# --- Godslayer: Deicide ------------------------------------------------------------------------

static func deicide_reach(p: Player) -> float:
	return DEICIDE_REACH + p.m("deicide_reach")


## What Deicide leaps on: the nearest living enemy ahead within its reach, the toughest first when
## a boss or miniboss is among them.
static func quarry(p: Player) -> Zombie:
	var look := -p.camera.global_basis.z if p.camera else -p.global_basis.z
	look = Vector3(look.x, 0, look.z).normalized()
	var limit := cos(deg_to_rad(DEICIDE_CONE))
	var best: Zombie = null
	var best_score := INF
	for z: Zombie in p.world.zombies_near(p.global_position, deicide_reach(p) + 2.0, 32):
		if not z.is_alive():
			continue
		var to := Vector3(z.position.x - p.global_position.x, 0, z.position.z - p.global_position.z)
		var dist := to.length()
		if dist > deicide_reach(p) + z.body_radius() or (dist > 0.5 and (to / dist).dot(look) < limit):
			continue
		var score := dist - (6.0 if divine(z) else 0.0)
		if score < best_score:
			best_score = score
			best = z
	return best


static func deicide(p: Player) -> void:
	var z := quarry(p)
	p.deicide_on = z
	p.ascending = "deicide"
	if z == null:
		p._start_leap(deicide_reach(p) * 0.5)
	else:
		var to := Vector3(z.position.x - p.global_position.x, 0, z.position.z - p.global_position.z)
		var reach := maxf(0.5, to.length() - z.body_radius() - 0.8)
		p._leap_from = p.global_position
		p._leap_to = p.leap_landing(p.global_position, to.normalized(), reach)
		p._leap_t = 0.0
		p.guard_left = maxf(p.guard_left, 0.55)
		p._mist_trail = 0.0
		p.look_at(Vector3(z.position.x, p.global_position.y, z.position.z), Vector3.UP)
		p.yaw = p.rotation.y
	p.sfx("ascend_leap", -2.0, 0.9)


static func _deicide_lands(p: Player) -> void:
	var z := p.deicide_on
	p.deicide_on = null
	var struck := z != null and is_instance_valid(z) and z.is_alive() \
		and Vector2(z.position.x - p.global_position.x, z.position.z - p.global_position.z).length() <= DEICIDE_STRIKE + z.body_radius()
	if p.has_flag("heavy_fall"):
		_crash(p, HEAVY_FALL_RADIUS, HEAVY_FALL, 0.0, z if struck else null)
	if p.has_flag("twilight"):
		for other: Zombie in p.world.zombies_near(p.global_position, TWILIGHT_REACH, 24):
			if other.is_alive() and other != z and other.is_warning():
				break_rite(p, other)
	if not struck:
		p.say("Nothing to strike")
		return
	var was := p.world.begin_act(p)
	var blow := DEICIDE_DAMAGE * p.damage_multiplier()
	if p.has_flag("twilight") and (z.is_boss() or z.is_miniboss()):
		blow += z.max_hp * TWILIGHT_SHARE
	var broke := z.is_warning()
	var dir := Vector3(z.position.x - p.global_position.x, 0, z.position.z - p.global_position.z).normalized()
	p.world.damage_zombie(z, p.modify_damage(z, blow), dir, 4.0, z.centre(), false)
	if z.is_alive() and not (z.is_boss() or z.is_miniboss()) and z.hp < z.max_hp * execute_below(p):
		z.take_damage(z.hp + 1.0, dir, 4.0, z.centre())
		p.say("Ended!")
	if z.is_alive() and p.has_flag("godmark"):
		z.mark(1.0 + GODMARK, GODMARK_TIME)
	p.world.end_act(was)
	if broke and z.is_alive():
		break_rite(p, z)
	p.world.fx_blast(z.centre(), 1.4, Color(RITE, 0.6))
	p.world.sfx_at("deicide_strike", z.centre(), 0.0)


static func execute_below(p: Player) -> float:
	return HEADSMAN_BELOW if p.has_flag("headsman") else EXECUTE_BELOW


## An attack being readied, broken: its rings fade, its pose drops, even a god's.
static func break_rite(p: Player, z: Zombie) -> void:
	z.break_rite()
	p.world.fx_ring(z.position + Vector3.UP * 0.2, 2.5, RITE)
	p.world.sfx_at("rite_break", z.centre(), 0.0)
	p.say("Broken!")
	if p.has_flag("faith_breaker"):
		p.art_cd_left *= 1.0 - FAITH_BREAKER


# --- Adorer of Al'quimelea: the Elixir of Change --------------------------------------------

static func changed_time(p: Player) -> float:
	return CHANGED_TIME + p.m("changed_time")


static func field_radius(p: Player) -> float:
	return FIELD_RADIUS + p.m("field_reach")


static func drink(p: Player) -> void:
	p.changed_left = changed_time(p)
	p._buffs["changed"] = {"stat": "speed", "val": CHANGED_SPEED, "left": p.changed_left, "stacks": 1}
	p.sfx("elixir_drink", -1.0)
	p.say("Changed!")
	open_field(p, p.global_position)


## A field of change: told by a ring as it opens, and after FIELD_TELL whatever is still in it is poisoned
## and held fast. Everyone sees it; the drinker's phone (or the host, for a bot) does the sums.
static func open_field(p: Player, at: Vector3) -> void:
	var radius := field_radius(p)
	p.world.change_field_fx(at, radius, FIELD_TELL)
	if Net.active():
		Net.world_fx(Net.Fx.CHANGE_FIELD, at, Vector3(radius, FIELD_TELL, 0))
	var timer := p.get_tree().create_timer(FIELD_TELL)
	timer.timeout.connect(func() -> void: _field_opens(p, at, radius))


static func _field_opens(p: Player, at: Vector3, radius: float) -> void:
	if not is_instance_valid(p) or p.world == null:
		return
	var was := p.world.begin_act(p)
	for z: Zombie in p.world.zombies_near(at, radius + 1.0, 24):
		if not z.is_alive() or Vector2(z.position.x - at.x, z.position.z - at.z).length() > radius + z.body_radius():
			continue
		z.add_dot(FIELD_DOT, FIELD_POISON)
		z.root(FIELD_ROOT)
	if Net.pvp():
		for t: Target in p.world.rivals_near(at, radius):
			p.status_on(p.world.peer_of(t), Net.Status.POISON, FIELD_POISON)
			p.status_on(p.world.peer_of(t), Net.Status.ROOT, FIELD_ROOT)
	p.world.end_act(was)


## Changed, its blows poison (Player.on_melee_connect).
static func on_blow(p: Player, z: Zombie) -> void:
	if p.changed_left > 0.0:
		z.add_dot(BLOW_DOT, BLOW_DOT_TIME)


static func on_kill(p: Player, z: Zombie) -> void:
	if p.has_flag("ichor"):
		p.heal(ICHOR_HEAL)
	if p.has_flag("trophy") and divine(z):
		p.heal(TROPHY_HEAL)
		p.art_cd_left = maxf(0.0, p.art_cd_left - TROPHY_CD)
	if p.changed_left > 0.0:
		if p.has_flag("transmute"):
			p.heal(TRANSMUTE_HEAL)
		if p.has_flag("alembic"):
			p.changed_left += ALEMBIC
			if p._buffs.has("changed"):
				p._buffs["changed"]["left"] = p.changed_left
		if p.has_flag("spreading") and z.poison_left > 0.0:
			open_field(p, z.position)


static func tick(p: Player, delta: float) -> void:
	if p.changed_left <= 0.0:
		return
	p.changed_left -= delta
	p.changed_glow -= delta
	if p.changed_glow <= 0.0:
		p.changed_glow = 0.5
		var at := p.global_position + Vector3.UP * 0.9
		p.world.fx_blast(at, 0.6, Color(CHANGE, 0.35))
		if Net.active():
			Net.blast_fx(at, 0.6, Color(CHANGE, 0.35))
	if p.changed_left <= 0.0:
		p.changed_left = 0.0
		p._buffs.erase("changed")
		p.sfx("change_end", -3.0)
		if p.has_flag("crucible"):
			_crucible(p)


## Crucible Heart: light bursts out of the Adorer as the change ends.
static func _crucible(p: Player) -> void:
	var at := p.global_position
	p.world.fx_ring(at + Vector3.UP * 0.2, CRUCIBLE_RADIUS, Color(0.8, 1.0, 0.6))
	p.world.fx_blast(at + Vector3.UP, CRUCIBLE_RADIUS * 0.6, Color(0.85, 1.0, 0.7, 0.5))
	p.world.sfx_at("alq_nova", at, -2.0)
	if Net.active():
		Net.blast_fx(at + Vector3.UP, CRUCIBLE_RADIUS * 0.6, Color(0.85, 1.0, 0.7, 0.5))
	var was := p.world.begin_act(p)
	for z: Zombie in p.world.zombies_near(at, CRUCIBLE_RADIUS + 1.0, 24):
		var flat := Vector3(z.position.x - at.x, 0, z.position.z - at.z)
		if not z.is_alive() or flat.length() > CRUCIBLE_RADIUS + z.body_radius():
			continue
		p.world.damage_zombie(z, p.modify_damage(z, CRUCIBLE_DAMAGE * p.damage_multiplier()), flat.normalized(), CRUCIBLE_KNOCK, z.centre(), false)
		z.ignite(CRUCIBLE_BURN)
	if Net.pvp():
		for t: Target in p.world.rivals_near(at, CRUCIBLE_RADIUS):
			p.world.hit_rival(t, CRUCIBLE_DAMAGE * p.damage_multiplier(), at)
			p.status_on(p.world.peer_of(t), Net.Status.BURN, CRUCIBLE_BURN)
	p.world.end_act(was)


## Whether the button would do anything now.
static func has_use(_p: Player) -> bool:
	return true
