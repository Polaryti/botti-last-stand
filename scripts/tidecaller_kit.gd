class_name TidecallerKit
extends RefCounted
## The Tidecaller: one ability button, fed by tide (its mana) that its Trident draws with every blow
## and that rises a little by itself. Call the Tide sends a wave out (TideWave). Each path makes the
## button its own, and each feeds on the Trident:
## - a Tidewarden raises a Tide Shell that soaks up harm, is filled again by every Trident blow, and
##   breaks outward in a surge;
## - a Stormcaller soaks what the Trident strikes, then hurls a Stormspear whose lightning leaps from
##   one soaked enemy to the next (StormArc, Maelstrom);
## - a Deepcaller calls a sea serpent up out of the ground (an Ally, SeaSerpentBody) that fights
##   beside it and that enemies turn on.
## Every number lives here; the text audit checks the words in the tree against them.

# The class
const TRIDENT_TIDE := 6.0 # tide drawn by each Trident blow that lands
# Call the Tide
const WAVE_WIDTH := 3.0
const WAVE_RANGE := 14.0
const WAVE_DAMAGE := 30.0
const WAVE_KNOCK := 6.0
const WAVE_SLOW := 1.5
# The core of the tree: the Trident
const LONG_HAFT_REACH := 1.0 # Long Haft: metres more reach
const LONG_HAFT_HITS := 1 # and one more in the line
const SKEWER_EVERY := 3 # Skewer: every third Trident thrust that lands
const SKEWER_MULT := 2.0
const SKEWER_HOLD := 0.8
const SKEWER_TIDE := 10.0
const DEEP_BREATH_TIDE := 3.0 # Deep Breath: more tide from each Trident blow
const BRINE_SLOW := 1.5 # Brine: a Trident blow slows this long
const BRINE_HARD := 0.2 # and strikes what is slowed this much harder
# Tidewarden: Tide Shell
const SHELL_BASE := 40.0
const SHELL_SHARE := 0.25 # of your max health, added to the shell
const SHELL_TIME := 10.0
const SHELL_REFILL := 6.0 # each Trident blow that lands while it holds
const SHELL_THICK := 25.0 # Thick Shell
const BURST_RADIUS := 3.5
const BURST_DAMAGE := 35.0
const BURST_KNOCK := 5.0
const CORAL_DAMAGE := 8.0 # Coral Barbs: to what strikes you while the shell holds
const SALT_MEND := 3.0 # Salt Mend: health from each Trident blow while the shell holds
const BREAKWATER_STUN := 1.0
const SURGE_REACH := 2.0 # High Surge
const SURGE_HARD := 0.5
const WARD_REACH := 6.0 # Tidal Ward: friends this near share a shell
const WARD_SHARE := 0.5 # half as strong
const UNBROKEN_REST := 60.0 # Unbroken Sea: once a minute
const UNBROKEN_TIME := 2.0
const UNBROKEN_HEAL := 0.3
# Stormcaller: soaking, Stormspear, Maelstrom
const SOAK_TIME := 6.0 # a Trident blow soaks what it strikes this long
const SPEAR_RANGE := 18.0
const SPEAR_DAMAGE := 45.0
const CHAIN_DAMAGE := 35.0
const CHAINS := 3 # leaps to this many soaked enemies
const CHAIN_REACH := 6.0 # metres between one and the next
const CHAIN_JOLT := 0.4 # a soaked enemy the lightning reaches is stunned this long
const CHARGED_TINES := 0.25 # Charged Tines: Trident blows on soaked enemies
const LONG_THROW := 8.0
const CONDUCTOR := 2 # more leaps
const STATIC_SLOW := 2.0
const SQUALL_STEP := 4.0 # Squall Step: metres back as you throw
const RAIN_CLOAK := 0.15 # Rain Cloak: less harm while enough soaked enemies are near
const RAIN_COUNT := 3
const RAIN_REACH := 8.0
const DOWNPOUR := 2.5 # Downpour: a Trident blow soaks everything this near what it strikes
const MAELSTROM_EVERY := 3 # every third Stormspear
const MAELSTROM_TIME := 6.0
const MAELSTROM_GAP := 0.6
const MAELSTROM_REACH := 7.0
const MAELSTROM_DAMAGE := 30.0
# Deepcaller: Call of the Deep
const SERPENT_TIME := 20.0
const SERPENT_TAUNT := 8.0 # enemies this near turn on it as it rises
const SERPENT_HP := 170.0
const SERPENT_BITE := 1.1 # of a weapon blow
const THICK_SCALES := 0.5
const LONG_TIDE := 10.0
const PACK_HUNTER := 0.3 # Pack Hunter: its bites on what your Trident last struck
const VENOM := Vector2(6.0, 3.0) # Venom of the Deep: damage a second, and seconds
const COIL_HOLD := 0.8
const BOND_SHARE := 0.25 # Bond of Salt: of the harm you take, to the serpent
const SHED_HEAL := 30.0
const SHED_REST := 0.5 # the next call is ready this much sooner
const CHILD_SIZE := 1.4 # Leviathan's Child
const CHILD_HP := 0.5
const CHILD_LASH := 0.5 # of each Trident blow, lashed at the same enemy
const CHILD_REACH := 12.0

const ARTS := {
	"": {"name": "Call the Tide", "cost": 35.0, "cast": 0.3, "cd": 5.0, "icon": "wave", "anim": "Spellcast_Shoot"},
	"tidewarden": {"name": "Tide Shell", "cost": 30.0, "cast": 0.25, "cd": 12.0, "icon": "shell", "anim": "Spellcast_Raise"},
	"stormcaller": {"name": "Stormspear", "cost": 30.0, "cast": 0.3, "cd": 6.0, "icon": "bolt", "anim": "Spellcast_Shoot"},
	"deepcaller": {"name": "Call of the Deep", "cost": 40.0, "cast": 0.4, "cd": 18.0, "icon": "serpent", "anim": "Spellcast_Raise"},
}
const TIDE := Color(0.3, 0.86, 0.82)
const STORM := Color(0.62, 0.86, 1.0)


static func art(p: Player) -> Dictionary:
	return ARTS.get(p.spec_id, ARTS[""])


static func cast(p: Player) -> void:
	match p.spec_id:
		"tidewarden": raise_shell(p)
		"stormcaller": stormspear(p)
		"deepcaller": call_of_the_deep(p)
		_: call_the_tide(p)


static func _flat_ahead(p: Player) -> Vector3:
	var ahead := -p.global_basis.z
	return Vector3(ahead.x, 0, ahead.z).normalized() if Vector2(ahead.x, ahead.z).length() > 0.1 else Vector3.FORWARD


static func _tide(p: Player, amount: float) -> void:
	p.mana = minf(p.max_mana(), p.mana + amount)


# --- Call the Tide -----------------------------------------------------------------

static func call_the_tide(p: Player) -> void:
	var start := p.global_position + _flat_ahead(p) * 0.8
	start.y = p.world.ground_at(start)
	var dmg := WAVE_DAMAGE * p.damage_multiplier() * p.m("spell_damage")
	p.world.tide_wave(p.net_id(), start, _flat_ahead(p), WAVE_WIDTH, WAVE_RANGE, dmg)
	if Net.active():
		Net.tide_wave(p.net_id(), start, _flat_ahead(p), WAVE_WIDTH, WAVE_RANGE)
	p.world.sfx_at("call_tide", start, -1.0)
	p.shake(0.1)


# --- The Trident ------------------------------------------------------------------------

## How much harder this Trident blow strikes this enemy: Skewer's every third thrust, Brine on what
## is slowed, Charged Tines on what is soaked. A thrust is counted once, however many it reaches.
static func trident_scale(p: Player, z: Zombie) -> float:
	var frame := Engine.get_physics_frames()
	if frame != p.trident_frame:
		p.trident_frame = frame
		p.trident_thrusts += 1
		p.skewering = p.has_flag("skewer") and p.trident_thrusts % SKEWER_EVERY == 0
	var scale := SKEWER_MULT if p.skewering else 1.0
	if p.has_flag("brine") and z._slow > 0.0:
		scale *= 1.0 + BRINE_HARD
	if p.has_flag("charged_tines") and z.soaked_left > 0.0:
		scale *= 1.0 + CHARGED_TINES
	return scale


## A Trident blow that landed: tide, and whatever the tree makes of it.
static func on_trident_hit(p: Player, z: Zombie) -> void:
	_tide(p, TRIDENT_TIDE + p.m("trident_tide"))
	if z == null:
		return
	if p.skewering:
		_tide(p, SKEWER_TIDE)
		z.root(SKEWER_HOLD, true)
		p.world.fx_water(z.centre(), 0.7)
	if p.has_flag("brine"):
		z.slow(BRINE_SLOW)
	p.trident_prey = z
	match p.spec_id:
		"tidewarden":
			if p.shell_left > 0.0:
				p.shell_hp = minf(p.shell_max, p.shell_hp + SHELL_REFILL)
				if p.has_flag("salt_mend"):
					p.heal(SALT_MEND)
		"stormcaller":
			soak(p, z)
			if p.has_flag("downpour"):
				for other: Zombie in p.world.zombies_near(z.position, DOWNPOUR, 12):
					soak(p, other)
		"deepcaller":
			var serpent := serpent_of(p)
			if serpent and p.has_flag("leviathans_child") and z.is_alive() and serpent.global_position.distance_to(z.position) <= CHILD_REACH:
				serpent.lash(z, float(p.melee_stats(WeaponDefs.ALL["trident"])["damage"]) * CHILD_LASH)


# --- Tidewarden: Tide Shell -------------------------------------------------------------

static func shell_size(p: Player) -> float:
	return SHELL_BASE + SHELL_SHARE * p.max_hp() + p.m("shell_hp")


static func raise_shell(p: Player) -> void:
	p.shell_max = shell_size(p)
	p.shell_hp = p.shell_max
	p.shell_left = SHELL_TIME
	p.world.sfx_here("tide_shell", p.global_position, -2.0)
	p.world.fx_water(p.global_position + Vector3.UP, 1.6)
	if Net.active():
		Net.tide_shell(p.net_id(), true)
	if p.has_flag("tidal_ward"):
		for t: Target in p.world.friends_near(p.global_position, WARD_REACH):
			Net.shell_peer(p.world.peer_of(t), shell_size(p) * WARD_SHARE, SHELL_TIME)
		p.world.fx_ring(p.global_position, WARD_REACH, TIDE)


## A friend's share of a Tidal Ward: a shell of its own, that does not burst.
static func lend_shell(p: Player, amount: float, seconds: float) -> void:
	if p.dead:
		return
	p.shell_max = maxf(p.shell_hp, amount)
	p.shell_hp = p.shell_max
	p.shell_left = maxf(p.shell_left, seconds)
	p.world.fx_water(p.global_position + Vector3.UP, 1.2)
	if Net.active():
		Net.tide_shell(p.net_id(), true)


## The shell gives way, broken or spent: it bursts outward, throwing back what stands round you.
static func burst(p: Player) -> void:
	p.shell_hp = 0.0
	p.shell_left = 0.0
	if p.class_id != "tidecaller":
		# A shell lent by a Tidewarden only slips away.
		p.world.fx_water(p.global_position + Vector3.UP, 1.0)
		if Net.active():
			Net.tide_shell(p.net_id(), false)
		return
	var reach := BURST_RADIUS + (SURGE_REACH if p.has_flag("high_surge") else 0.0)
	var dmg := BURST_DAMAGE * (1.0 + (SURGE_HARD if p.has_flag("high_surge") else 0.0)) * p.damage_multiplier() * p.m("spell_damage")
	var at := p.global_position
	p.world.tide_burst(at, reach)
	if Net.active():
		Net.tide_shell(p.net_id(), false, at, reach)
	var was := p.world.begin_act(p)
	for z: Zombie in p.world.zombies_near(at, reach, 24):
		if not z.is_alive():
			continue
		p.world.damage_zombie(z, dmg, z.position - at, BURST_KNOCK, z.centre(), false)
		if p.has_flag("breakwater"):
			z.stun(BREAKWATER_STUN)
	for r: Target in p.world.rivals_near(at, reach):
		p.world.hit_rival(r, dmg, at)
		if p.has_flag("breakwater"):
			p.world.status_rival(r, Net.Status.STUN, BREAKWATER_STUN)
	p.world.end_act(was)
	p.shake(0.25)


## Steady Footing: while the shell holds, nothing knocks you down, stops you or drags you.
static func steady(p: Player) -> bool:
	return p.class_id == "tidecaller" and p.has_flag("steady_footing") and p.shell_left > 0.0


# --- Stormcaller: soaking, Stormspear, Maelstrom ---------------------------------------------

static func soak(p: Player, z: Zombie) -> void:
	if z and z.is_alive():
		z.soak(SOAK_TIME)


static func stormspear(p: Player) -> void:
	var ahead := _flat_ahead(p)
	var from := p.global_position + Vector3.UP * 1.3 + ahead * 0.6
	var reach := SPEAR_RANGE + p.m("spear_range")
	# The spear flies level along your aim and strikes the first enemy in its way.
	var first: Zombie = null
	var best := reach
	for z: Zombie in p.world.zombies_near(p.global_position + ahead * reach * 0.5, reach * 0.5 + 2.0, 64):
		if not z.is_alive() or z.dormant:
			continue
		var rel := z.centre() - from
		var along := Vector3(rel.x, 0, rel.z).dot(ahead)
		if along < 0.0 or along > best:
			continue
		var side := (Vector3(rel.x, 0, rel.z) - ahead * along).length()
		if side > z.body_radius() + 0.6 or not p.world.has_line_of_sight(from, z.centre()):
			continue
		best = along
		first = z
	var end := from + ahead * best
	var points := PackedVector3Array([from])
	var was := p.world.begin_act(p)
	var scale := p.damage_multiplier() * p.m("spell_damage")
	var slows := p.has_flag("static")
	if first:
		end = first.centre()
		points.append(end)
		p.world.damage_zombie(first, SPEAR_DAMAGE * scale, ahead, 2.0, end, false)
		_jolt(first, slows)
		# Then the lightning leaps, from each soaked enemy to the nearest soaked one not yet struck.
		var struck := {first.get_instance_id(): true}
		var at := first
		for i in CHAINS + int(p.m("chains")):
			var next: Zombie = null
			var near := CHAIN_REACH
			for z: Zombie in p.world.zombies_near(at.centre(), CHAIN_REACH, 24):
				if z.is_alive() and z.soaked_left > 0.0 and not struck.has(z.get_instance_id()) and z.centre().distance_to(at.centre()) < near:
					near = z.centre().distance_to(at.centre())
					next = z
			if next == null:
				break
			struck[next.get_instance_id()] = true
			points.append(next.centre())
			p.world.damage_zombie(next, CHAIN_DAMAGE * scale, next.position - at.position, 1.0, next.centre(), false)
			_jolt(next, slows)
			at = next
	else:
		end.y = maxf(end.y, p.world.ground_at(end) + 0.4)
		points.append(end)
	for r: Target in p.world.rivals_near(end, 1.5):
		p.world.hit_rival(r, SPEAR_DAMAGE * scale, from)
		if slows:
			p.world.status_rival(r, Net.Status.SLOW, STATIC_SLOW)
	p.world.end_act(was)
	p.world.storm_arcs(points)
	if Net.active():
		Net.storm_arcs(p.net_id(), points)
	p.world.sfx_here("stormspear", from, -2.0)
	if points.size() > 2:
		p.world.sfx_here("chain_lightning", points[points.size() - 1], -3.0)
	if p.has_flag("squall_step"):
		p.squall_step(-ahead * SQUALL_STEP)
	p.spears_thrown += 1
	if p.has_flag("maelstrom") and p.spears_thrown % MAELSTROM_EVERY == 0:
		var eye := points[points.size() - 1]
		eye.y = p.world.ground_at(eye)
		p.world.maelstrom(p.net_id(), eye)
		if Net.active():
			Net.maelstrom(p.net_id(), eye)
		p.say("Maelstrom!")
	p.shake(0.15)


static func _jolt(z: Zombie, slows: bool) -> void:
	if not z.is_alive():
		return
	if z.soaked_left > 0.0:
		z.soaked_left = 0.0
		z.stun(CHAIN_JOLT)
	if slows:
		z.slow(STATIC_SLOW)


## Rain Cloak: enough soaked enemies round you and the storm hangs over you too.
static func cloaked(p: Player) -> bool:
	if not p.has_flag("rain_cloak"):
		return false
	var n := 0
	for z: Zombie in p.world.zombies_near(p.global_position, RAIN_REACH, 24):
		if z.is_alive() and z.soaked_left > 0.0:
			n += 1
	return n >= RAIN_COUNT


# --- Deepcaller: Call of the Deep ----------------------------------------------------------

static func serpent_of(p: Player) -> Ally:
	for a: Ally in p.world.allies:
		if a.kind == "sea_serpent" and a.master == p and not a.dead and a.remote_owner == 0:
			return a
	return null


static func serpent_life(p: Player) -> float:
	return SERPENT_TIME + p.m("serpent_time")


static func serpent_health(p: Player) -> float:
	return SERPENT_HP * (1.0 + (THICK_SCALES if p.has_flag("thick_scales") else 0.0) + (CHILD_HP if p.has_flag("leviathans_child") else 0.0))


static func call_of_the_deep(p: Player) -> void:
	var old := serpent_of(p)
	var at := p.global_position + _flat_ahead(p) * 2.2 + p.global_basis.x * 0.8
	if old:
		# Called again: the serpent it has is made whole and stays as long again.
		old.life = serpent_life(p)
		old.hp = serpent_health(p)
		old.rise_again()
	else:
		p.world.spawn_ally("sea_serpent", at, serpent_life(p))
		old = serpent_of(p)
		if old:
			old.hp = serpent_health(p)
			old.grown = CHILD_SIZE if p.has_flag("leviathans_child") else 1.0
	if old == null:
		return
	p.world.fx_water(old.global_position, 2.2)
	p.world.sfx_at("serpent_rise", old.global_position, -1.0)
	# What is near turns on the thing that rose out of the ground.
	for z: Zombie in p.world.zombies_near(old.global_position, SERPENT_TAUNT, 24):
		if z.is_alive():
			z.taunted_by(old.global_position)
	p.shake(0.15)


## The serpent fell (not when its time ran out): Shed Skin.
static func serpent_fell(p: Player) -> void:
	if p.has_flag("shed_skin"):
		p.heal(SHED_HEAL)
		p.art_cd_left *= 1.0 - SHED_REST


# --- Harm, and the passing of time -----------------------------------------------------------

## The harm that reaches you, after what your path takes off it. Returns what is left.
static func on_hurt(p: Player, dmg: float, attacker: Zombie) -> float:
	if dmg <= 0.0:
		return dmg
	if p.class_id != "tidecaller":
		return _through_shell(p, dmg, attacker)
	if cloaked(p):
		dmg *= 1.0 - RAIN_CLOAK
	if p.has_flag("bond_of_salt"):
		var serpent := serpent_of(p)
		if serpent:
			var shared := dmg * BOND_SHARE
			serpent.hurt(shared, p.global_position)
			dmg -= shared
	dmg = _through_shell(p, dmg, attacker)
	if dmg >= p.hp and p.has_flag("unbroken_sea") and p.unbroken_cd <= 0.0:
		# Unbroken Sea: the blow passes through water.
		p.unbroken_cd = UNBROKEN_REST
		p.guard_left = maxf(p.guard_left, UNBROKEN_TIME)
		p.heal(p.max_hp() * UNBROKEN_HEAL)
		raise_shell(p)
		p.say("Unbroken Sea!")
		p.world.fx_water(p.global_position + Vector3.UP, 2.4)
		return 0.0
	return dmg


## What the shell stops (and Coral Barbs strikes back at). Returns what gets through.
static func _through_shell(p: Player, dmg: float, attacker: Zombie) -> float:
	if p.shell_left <= 0.0 or p.shell_hp <= 0.0:
		return dmg
	if attacker and p.has_flag("coral_barbs") and attacker.is_alive():
		attacker.take_damage(CORAL_DAMAGE, attacker.position - p.global_position, 1.0, attacker.centre())
	var stopped := minf(p.shell_hp, dmg)
	p.shell_hp -= stopped
	p.sfx("shell_hit", -6.0, 1.0, 0.12)
	if p.shell_hp <= 0.0:
		burst(p)
	return dmg - stopped


static func tick(p: Player, delta: float) -> void:
	p.unbroken_cd = maxf(0.0, p.unbroken_cd - delta)
	if p.shell_left > 0.0:
		p.shell_left -= delta
		if p.shell_left <= 0.0:
			burst(p)
	# The shell as it is, on this phone's own body.
	var showing := p.shell_left > 0.0 and not p.dead
	if showing and p._tide_shell == null:
		p._tide_shell = TideShell.new(p == p.world.player)
		p.add_child(p._tide_shell)
	if p._tide_shell:
		p._tide_shell.set_fill(p.shell_hp / maxf(1.0, p.shell_max) if showing else 0.0)
		if not showing and p._tide_shell.gone():
			p._tide_shell.queue_free()
			p._tide_shell = null
