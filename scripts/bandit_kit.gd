class_name BanditKit
extends RefCounted
## The Bandit's ability, from the start and for each profession. The player calls art() for the
## button and cast() when the cast ends. Nightfall itself lives in NightfallDome.

const SHADOW_TIME := 4.0
const STEAL_RANGE := 14.0
const STEAL_DAMAGE := 40.0
const STEAL_HIDE := 2.5
const STEAL_SPLASH := 4.0
const NIGHT_RADIUS := 6.0
const NIGHT_TIME := 8.0
const NIGHT_LINGER := 1.5
const FAN_KNIVES := 5
const FAN_SPREAD := 40.0 # degrees, edge to edge
const FAN_POWER := 0.8 # of WeaponDefs.DAMAGE, per knife
const FAN_SPEED := 32.0
const FAN_RANGE := 22.0
const PLUNDER_ARROWS := 6

const ARTS := {
	"": {"name": "Into the Shadows", "cost": 0.0, "cast": 0.1, "cd": 12.0, "icon": "eye_closed", "anim": "Stance"},
	"thief": {"name": "Steal", "cost": 0.0, "cast": 0.08, "cd": 10.0, "icon": "hand"},
	"mercenary": {"name": "Nightfall", "cost": 0.0, "cast": 0.3, "cd": 22.0, "icon": "moon", "anim": "Stance"},
	"highwayman": {"name": "Dagger Fan", "cost": 0.0, "cast": 0.15, "cd": 8.0, "icon": "dagger"},
}


static func art(p: Player) -> Dictionary:
	return ARTS.get(p.spec_id, ARTS[""])


static func cast(p: Player) -> void:
	match p.spec_id:
		"thief": steal(p)
		"mercenary": nightfall(p)
		"highwayman":
			dagger_fan(p)
			if p.has_flag("fan_twice"):
				p.get_tree().create_timer(0.35).timeout.connect(func() -> void:
					if is_instance_valid(p) and not p.dead:
						dagger_fan(p))
		_: into_shadows(p)


# --- Into the Shadows ----------------------------------------------------------

static func into_shadows(p: Player) -> void:
	if not p.can_vanish():
		p.say("Can't vanish for %d s" % ceili(p.invis_lockout))
		return
	p.invis_left = maxf(p.invis_left, SHADOW_TIME + p.m("shadow_time"))
	p.say("Into the Shadows")
	p.world.fx_mist(p.global_position + Vector3.UP, 1.1)
	p.world.sfx_at("vanish", p.global_position, -4.0)


# --- Steal ---------------------------------------------------------------------

## Who Steal goes for: the nearest player first, then the nearest bot, then the nearest creature.
static func steal_target(p: Player) -> Node3D:
	var reach := STEAL_RANGE + p.m("steal_range")
	var was := p.world.begin_act(p)
	var rivals := p.world.rivals_near(p.global_position, reach)
	p.world.end_act(was)
	var people: Array[Target] = []
	var bots: Array[Target] = []
	for r in rivals:
		(bots if Net.is_bot(p.world.peer_of(r)) else people).append(r)
	for group: Array[Target] in [people, bots]:
		var best: Target = null
		for r in group:
			if best == null or r.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
				best = r
		if best:
			return best
	var nearest: Zombie = null
	for z: Zombie in p.world.zombies_near(p.global_position, reach, 24):
		if z.is_alive() and (nearest == null or z.position.distance_to(p.global_position) < nearest.position.distance_to(p.global_position)):
			nearest = z
	return nearest


static func _facing(t: Node3D) -> Vector3:
	if t is Zombie:
		return Vector3(sin(t.rotation.y), 0, cos(t.rotation.y))
	var f := -t.global_basis.z
	return Vector3(f.x, 0, f.z).normalized() if Vector2(f.x, f.z).length() > 0.1 else Vector3.FORWARD


static func steal(p: Player) -> void:
	var t := steal_target(p)
	if t == null:
		p.say("Nothing to steal from")
		p.art_cd_left = 0.5
		return
	var from := p.global_position
	var there: Vector3 = t.global_position
	var front := _facing(t)
	var spot := p.leap_landing(there, front, 1.3)
	p.world.fx_mist(from + Vector3.UP, 0.9)
	p.global_position = spot + Vector3.UP * 0.04
	p.velocity = Vector3.ZERO
	var to_target := there - spot
	p.yaw = atan2(-to_target.x, -to_target.z)
	p.rotation.y = p.yaw
	p.world.fx_mist(spot + Vector3.UP, 0.9)
	if p.can_vanish():
		p.invis_left = maxf(p.invis_left, STEAL_HIDE + p.m("steal_hide"))
	p.world.sfx_at("steal", spot, -3.0)
	var targets: Array[Node3D] = [t]
	if p.has_flag("steal_all"):
		for z: Zombie in p.world.zombies_near(there, STEAL_SPLASH, 12):
			if z != t:
				targets.append(z)
		var was := p.world.begin_act(p)
		for r in p.world.rivals_near(there, STEAL_SPLASH):
			if r != t:
				targets.append(r)
		p.world.end_act(was)
	var dmg := STEAL_DAMAGE * p.m("steal_damage") * p.m("melee_damage") * p.damage_multiplier()
	for victim in targets:
		_rob(p, victim, dmg, victim == t)
	if p.has_flag("steal_dash"):
		p._act({"do": "buff", "key": "steal_dash", "stat": "speed", "val": 0.35, "secs": 3.0}, {})
	p._noise(3.0)


## Strikes one victim and knocks its weapon down, if it holds one it can lose. With Fence, the weapon
## of the creature Steal went for comes straight to the Thief's hand, and if both hands are full the
## one held drops in its place.
static func _rob(p: Player, victim: Node3D, dmg: float, main_target := true) -> void:
	var was := p.world.begin_act(p)
	if victim is Zombie:
		var z := victim as Zombie
		z.take_damage(p.modify_damage(z, dmg), z.position - p.global_position, 1.5, z.centre())
		p.on_hit(false)
		if p.has_flag("steal_stun"):
			z.stun(1.5)
		var keep := main_target and p.has_flag("steal_keep") and z.weapon_id != "" and WeaponDefs.lies_around(z.weapon_id) \
			and p.can_use(z.weapon_id) and not p.carries(z.weapon_id) and (p.has_empty_slot() or p.can_drop_weapon())
		var taken := z.disarm(not keep)
		if keep and taken != "":
			if not p.has_empty_slot():
				p.drop_current_weapon()
			p.give_weapon(taken)
			p.say("Took the %s" % WeaponDefs.ALL[taken]["name"])
	elif victim is Target:
		p.world.hit_rival(victim as Target, dmg, p.global_position)
		Net.disarm(p.world.peer_of(victim as Target), p.net_id(), p.has_flag("steal_stun"))
	p.world.end_act(was)


## What a player or bot does when it is robbed: the weapon in hand goes to the ground, unless it is
## the class's own, or the only weapon it has.
static func be_robbed(p: Player, stunned: bool) -> void:
	if stunned:
		p.apply_status(Net.Status.STUN, 1.5)
	if p.can_drop_weapon():
		p.drop_current_weapon()
		p.say("Robbed!")


# --- Nightfall -----------------------------------------------------------------

static func nightfall(p: Player) -> void:
	var radius := NIGHT_RADIUS + p.m("night_radius")
	var secs := NIGHT_TIME + p.m("night_time")
	var bits := 0
	for i in NightfallDome.FLAGS.size():
		if p.has_flag(NightfallDome.FLAGS[i]):
			bits |= 1 << i
	var linger := NIGHT_LINGER + p.m("night_linger")
	p.world.spawn_nightfall(p.net_id(), p.global_position, radius, secs, linger, bits)
	if Net.active():
		Net.nightfall(p.net_id(), p.global_position, radius, secs, linger, bits)


# --- Dagger Fan and Plunder -------------------------------------------------------

static func dagger_fan(p: Player) -> void:
	var knives := FAN_KNIVES + int(p.m("fan_knives"))
	var dir := -p.camera.global_basis.z
	var from := p.camera.global_position + dir * 0.5 + Vector3.DOWN * 0.1
	var dmg := WeaponDefs.DAMAGE * FAN_POWER * p.m("fan_damage") * p._ranged_mult()
	for i in knives:
		var t := 0.5 if knives == 1 else float(i) / float(knives - 1)
		var angle := deg_to_rad(lerpf(-FAN_SPREAD * 0.5, FAN_SPREAD * 0.5, t))
		var d := dir.rotated(Vector3.UP, angle)
		p.world.spawn_knife(p, from, d * FAN_SPEED, FAN_RANGE, dmg, int(p.m("fan_bounces")), p.has_flag("fan_bleed"), p.has_flag("fan_slow"), p.has_flag("fan_close"))
	p.world.sfx_at("dagger_fan", from, -3.0)
	p._swing_time = 0.3
	p._swing = 0.0
	p._swing_keys = "throw"
	p._noise(3.0)


## A Highwayman's kill sometimes leaves something worth taking.
static func plunder(p: Player, at: Vector3) -> void:
	if randf() >= p.m("plunder"):
		return
	var roll := randf()
	if roll < 0.45:
		p.world.spawn_pickup_at(at, Pickup.Kind.FOOD, PowerDefs.pick_weighted(PowerDefs.FOODS))
	elif roll < 0.8:
		p.world.spawn_pickup_at(at, Pickup.Kind.ARROWS, "arrows", PLUNDER_ARROWS)
	else:
		p.world.spawn_pickup_at(at, Pickup.Kind.POWER, PowerDefs.pick_potion())
