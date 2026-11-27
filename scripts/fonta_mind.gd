class_name FontaMind
extends VaelSkyMind
## What the mutants of Fontanova do, worked out on the host (or alone). Every special has a tell, and
## what lands is a MistSeal, so each phone hurts its own player where it lands and a step aside is
## always enough:
##   Mutant Bee: circles low, curls its stinger forward (the tell), then dives at where you stood. Its
##     sting poisons. Half the time it leaves Honey when it dies.
##   Beehive: stands where it grew. Struck, it sends out bees (a few at a time, up to a few at once);
##     broken, it spills Honey.
##   Mutant Wasp: keeps its distance and shoots its stinger, which poisons; close in, it dives to bite.
##   Mutant Snail: crawls after you, leaving a trail of poison or of fire (FontaTrails) that lasts.
##   Wasp-Hive Snail: its nest shudders and wasps come out of it, a few at a time.
##   Mutant Spider: clings head down to a tree trunk until someone comes near, then drops on them: the
##     web where it lands roots and poisons. On the ground it crouches and pounces again.
##   Battle Ostrich: paws the ground, then charges straight; whoever it reaches is kicked away.
##   Ember Moth: spreads its wings, eye-spots blazing, and claps them: the burning dust where it was
##     looking dazzles and sets you alight.
##   Thornback: plods after you and snaps; blows from the front glance off its shell.

const BEE_EVERY := 3.6
const BEE_TELL := 0.45
const BEE_DIVE := 2.4 # times its speed
const STING_RADIUS := 1.3
const STING_POISON := 4.0 # seconds a bee's sting poisons you
const HONEY_CHANCE := 0.5
const HIVE_RELEASE := 2 # bees out each time it is struck
const HIVE_REST := 4.0
const HIVE_BEES := 6 # no more than this many of its bees about at once
const HIVE_HONEY := 4
const WASP_EVERY := 4.5
const WASP_TELL := 0.5
const WASP_RANGE := Vector2(5.0, 20.0)
const WASP_SHOT := 0.8 # of its damage
const WASP_POISON := 3.0 # seconds its stinger poisons you
const WASP_REACH := 3.5
const MOTH_EVERY := 7.0
const MOTH_TELL := 1.0
const DUST_RADIUS := 2.6
const DUST_BLIND := 2.5
const DUST_BURN := 2.0
const NEST_EVERY := 12.0
const NEST_TELL := 0.9
const NEST_WASPS := 3
const PERCH_HIGH := 3.2 # the highest up a tree trunk a spider clings, below the leaves
const PERCH_LOW := 1.6
const CLING := 0.3 # from the bark to the spider's body, its legs gripping between
const PERCH_WAKE := 14.0 # how near you come before it drops
const POUNCE_TIME := 0.8
const POUNCE_RADIUS := 1.8
const POUNCE_POWER := 1.3
const POUNCE_TELL := 0.4
const POUNCE_EVERY := 6.0
const POUNCE_RANGE := Vector2(4.0, 10.0)
const WEB_ROOT := 1.2
const WEB_POISON := 3.0
const CHARGE_TELL_OSTRICH := 0.6
const CHARGE_EVERY_OSTRICH := 7.0
const CHARGE_RANGE := Vector2(6.0, 22.0)
const CHARGE_BURST := 2.6 # times its speed
const CHARGE_RUN := 1.4
const KICK_POWER := 1.4
const KICK_KNOCK := 8.0
const KICK_REACH := 1.7

var _from := Vector3.ZERO
var _released := 0.0
var perched := false


## Where a spider clings on a tree (World.spider_trunks), on the side `out` faces: on the bark, below the
## leaves, its body (whose pivot is SPIDER_RIG above it) against the trunk.
const SPIDER_RIG := 0.55
static func perch_at(perch: Dictionary, out: Vector3, ground: float) -> Vector3:
	var tree: Vector3 = perch["at"]
	var high := clampf(float(perch["high"]) * 0.85, PERCH_LOW, PERCH_HIGH)
	return Vector3(tree.x, ground + high - SPIDER_RIG, tree.z) + out * (float(perch["girth"]) + CLING)


static func handles(id: String) -> bool:
	return id in FontaModels.KINDS


func _init(id: String) -> void:
	super(id)
	match kind:
		"mutant_bee": cooldown = randf_range(1.5, BEE_EVERY)
		"mutant_wasp": cooldown = randf_range(2.0, WASP_EVERY)
		"ember_moth": cooldown = randf_range(3.0, MOTH_EVERY)
		"wasp_hive_snail": cooldown = randf_range(4.0, NEST_EVERY)
		"battle_ostrich": cooldown = randf_range(2.0, CHARGE_EVERY_OSTRICH)
		"mutant_spider": cooldown = 1.0


## A snail's trail: fire for some, poison for the rest, the same on every phone.
static func trail_of(z: Zombie) -> String:
	return "fire" if z.net_id % 2 == 1 else "poison"


static func trail_colour(z: Zombie) -> Color:
	return Color(1.0, 0.5, 0.18) if trail_of(z) == "fire" else Color(0.45, 1.0, 0.35)


func interrupt(z: Zombie) -> void:
	if phase == "pounce" or phase == "charge":
		return # already flying through the air or running flat out: a stun lands when it does
	phase = ""
	cooldown = maxf(cooldown, 2.0)
	# A stun knocks a spider off its trunk: it lands (Zombie's stun puts it on the ground) and fights there.
	perched = false
	_show(z, "")


func on_death(z: Zombie) -> void:
	phase = ""
	if Net.active() and not Net.is_host():
		return
	match kind:
		"mutant_bee":
			if randf() < HONEY_CHANCE:
				z.world.spawn_pickup_at(_ground(z, z.position), Pickup.Kind.FOOD, "honey")
		"beehive":
			for i in HIVE_HONEY:
				var a := TAU * i / HIVE_HONEY + randf() * 0.4
				z.world.spawn_pickup_at(_ground(z, z.position + Vector3(cos(a), 0, sin(a)) * 1.6), Pickup.Kind.FOOD, "honey")
			# And in its heart, the Royal Jelly.
			z.world.spawn_pickup_at(_ground(z, z.position), Pickup.Kind.FOOD, "royal_jelly")


## Struck: a hive sends out its bees; a perched spider drops at once.
func on_hurt(z: Zombie) -> void:
	if kind == "beehive" and _released <= 0.0:
		_released = HIVE_REST
		var out := 0
		for other: Zombie in z.world.zombies:
			if other.is_alive() and int(other.get_meta("from", -1)) == z.net_id:
				out += 1
		for i in mini(HIVE_RELEASE, HIVE_BEES - out):
			var a := randf() * TAU
			if z.world.spawn_zombie("mutant_bee", z.position + Vector3(cos(a) * 1.2, 1.6, sin(a) * 1.2)):
				z.world.zombies.back().set_meta("from", z.net_id)
		z.world.sfx_at("hive_swarm", z.position, 0.0)
	elif kind == "mutant_spider" and perched and phase == "":
		var t := z.world.nearest_player(z.position)
		if t:
			_pounce(z, t.global_position)


func tick(z: Zombie, target: Target, _to: Vector3, dist: float, delta: float) -> bool:
	cooldown -= delta
	_released -= delta
	match kind:
		"mutant_bee": return _bee(z, target, dist, delta)
		"mutant_wasp": return _wasp(z, target, dist, delta)
		"ember_moth": return _moth(z, target, dist, delta)
		"beehive":
			z.velocity = Vector3.ZERO
			return true
		"wasp_hive_snail": return _nest(z, delta)
		"mutant_spider": return _spider(z, target, dist, delta)
		"battle_ostrich": return _ostrich(z, target, dist, delta)
	return false


func after(z: Zombie) -> void:
	if phase != "":
		return
	if kind in ["thornback", "mutant_snail", "wasp_hive_snail", "battle_ostrich", "mutant_spider"]:
		_show(z, "m_bite" if z._attack_left > 0.0 else "")


# --- Flyers --------------------------------------------------------------------------------------

## Circling round where it is going, at its height, swaying; the shared flight of the island's flyers.
func _circle(z: Zombie, target: Target, radius: float, delta: float) -> void:
	orbit += delta * (0.9 if kind == "ember_moth" else 1.4)
	var centre := target.global_position if z._sees else z._home
	var desired := centre + Vector3(cos(orbit) * radius, float(z.def["fly_height"]) + sin(orbit * 1.7) * 0.4, sin(orbit) * radius)
	_steer(z, desired, delta)
	_face(z, target.global_position if z._sees else z.position + z.velocity, delta, 4.0)


## A dive at a place locked when the tell began: whatever is there when it arrives is stung (bee) or
## bitten (wasp).
func _dive(z: Zombie, delta: float, style: int, damage: float) -> bool:
	left -= delta
	var at := aim + Vector3.UP * 0.9
	var dir := at - z.position
	z.velocity = dir.limit_length(1.0) * z._speed * BEE_DIVE
	_move_air(z, z.velocity, delta)
	_face(z, aim, delta, 10.0)
	if dir.length() < 0.7 or left <= 0.0:
		MistSeal.cast(z, aim, STING_RADIUS, 0.06, damage, 0.0, style)
		phase = "recover"
		left = 1.1
		_show(z, "")
	return true


func _bee(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	match phase:
		"tell":
			left -= delta
			z.velocity = z.velocity.move_toward(Vector3.ZERO, delta * 10.0)
			_move_air(z, z.velocity, delta)
			_face(z, aim, delta, 8.0)
			if left <= 0.0:
				phase = "dive"
				left = 1.2
				_show(z, "m_dive")
			return true
		"dive":
			return _dive(z, delta, MistSeal.Style.STINGER, z._damage)
		"recover":
			left -= delta
			_steer(z, z.position + Vector3.UP * 2.0 - z.velocity.normalized() * 2.0, delta, 0.8)
			if left <= 0.0:
				phase = ""
			return true
	if cooldown <= 0.0 and z._sees and dist < 12.0 and _clear_shot(z, target):
		phase = "tell"
		left = BEE_TELL
		cooldown = BEE_EVERY + randf() * 1.0
		aim = _ground(z, target.global_position + target.velocity.limit_length(5.0) * 0.25)
		_show(z, "m_cast", true)
		z.world.sfx_at("bee_buzz", z.position, 0.0)
		return true
	_circle(z, target, 4.0, delta)
	return true


func _wasp(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	match phase:
		"tell":
			left -= delta
			z.velocity = z.velocity.move_toward(Vector3.ZERO, delta * 10.0)
			_move_air(z, z.velocity, delta)
			_face(z, target.global_position, delta, 8.0)
			if left <= 0.0:
				if heading == Vector3.UP:
					phase = "dive"
					left = 1.0
					_show(z, "m_dive")
				else:
					z.world.spawn_enemy_arrow(z.centre() + Vector3.DOWN * 0.2, target.eye_position(), z._damage * WASP_SHOT, WASP_RANGE.y, false, "mutant_wasp")
					z.world.sfx_at("wasp_shot", z.position, 0.0)
					phase = "recover"
					left = 0.6
					_show(z, "m_throw")
			return true
		"dive":
			return _dive(z, delta, MistSeal.Style.BITE, z._damage)
		"recover":
			left -= delta
			_circle(z, target, 7.0, delta)
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	if cooldown <= 0.0 and z._sees and _clear_shot(z, target):
		if dist < WASP_REACH:
			heading = Vector3.UP # the bite
			aim = _ground(z, target.global_position)
		elif dist > WASP_RANGE.x and dist < WASP_RANGE.y:
			heading = Vector3.FORWARD # the stinger
		else:
			_circle(z, target, 7.0, delta)
			return true
		phase = "tell"
		left = WASP_TELL
		cooldown = WASP_EVERY + randf() * 1.2
		_show(z, "m_cast", true)
		z.world.sfx_at("wasp_buzz", z.position, 0.0)
		return true
	_circle(z, target, 7.0, delta)
	return true


func _moth(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	match phase:
		"tell":
			left -= delta
			z.velocity = z.velocity.move_toward(Vector3.ZERO, delta * 8.0)
			_move_air(z, z.velocity, delta)
			_face(z, aim, delta, 5.0)
			if not z._sees or not _clear_shot(z, target):
				interrupt(z)
			elif left <= 0.0:
				MistSeal.cast(z, aim, DUST_RADIUS, 0.9, z._damage, 0.0, MistSeal.Style.DUST)
				z.world.sfx_at("moth_dust", z.position, 0.0)
				phase = "recover"
				left = 1.2
				_show(z, "m_throw")
			return true
		"recover":
			left -= delta
			_circle(z, target, 8.0, delta)
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	if cooldown <= 0.0 and z._sees and dist > 3.0 and dist < 22.0 and _clear_shot(z, target):
		phase = "tell"
		left = MOTH_TELL
		cooldown = MOTH_EVERY
		aim = _ground(z, target.global_position + target.velocity.limit_length(5.0) * 0.3)
		_show(z, "m_cast", true)
		z.world.sfx_at("moth_flutter", z.position, 0.0)
		return true
	_circle(z, target, 8.0, delta)
	return true


# --- On the ground -------------------------------------------------------------------------------

## The wasp-hive snail: its nest shudders, then wasps crawl out of it, no more than NEST_WASPS of its
## own at once.
func _nest(z: Zombie, delta: float) -> bool:
	if phase == "tell":
		left -= delta
		if left <= 0.0:
			phase = ""
			_show(z, "")
			var out := 0
			for other: Zombie in z.world.zombies:
				if other.is_alive() and int(other.get_meta("from", -1)) == z.net_id:
					out += 1
			if out < NEST_WASPS:
				if z.world.spawn_zombie("mutant_wasp", z.position + Vector3(0, 2.4, 0) - z.global_basis.z * 0.6):
					z.world.zombies.back().set_meta("from", z.net_id)
					z.world.sfx_at("wasp_buzz", z.position, 0.0)
		return false
	if cooldown <= 0.0 and z._sees:
		cooldown = NEST_EVERY
		phase = "tell"
		left = NEST_TELL
		_show(z, "m_cast", true)
		z.world.sfx_at("nest_shudder", z.position, 0.0)
	return false


## The spider: perched head down on a trunk until someone comes within PERCH_WAKE metres in sight,
## then it drops on them; on the ground it crouches and pounces again every POUNCE_EVERY seconds.
func _spider(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "pounce":
		left -= delta
		var k := clampf(1.0 - left / POUNCE_TIME, 0.0, 1.0)
		var at := _from.lerp(aim, k)
		at.y = lerpf(_from.y, aim.y, k) + sin(k * PI) * (1.6 if not perched else 0.6)
		z.position = at
		_face(z, aim, delta, 12.0)
		if left <= 0.0:
			z.position = aim
			perched = false
			phase = ""
			cooldown = POUNCE_EVERY
			_show(z, "")
		return true
	if phase == "tell":
		left -= delta
		_face(z, target.global_position, delta, 10.0)
		if left <= 0.0:
			_pounce(z, target.global_position)
		return true
	if perched:
		z.velocity = Vector3.ZERO
		_show(z, "m_sink")
		if dist < PERCH_WAKE and z.world.has_line_of_sight(z.centre(), target.eye_position()):
			_pounce(z, target.global_position)
		return true
	if cooldown <= 0.0 and dist > POUNCE_RANGE.x and dist < POUNCE_RANGE.y and z._sees and _clear_shot(z, target):
		phase = "tell"
		left = POUNCE_TELL
		_show(z, "m_cast", true)
		z.world.sfx_at("spider_hiss", z.position, 0.0)
		return true
	return false


func _pounce(z: Zombie, at: Vector3) -> void:
	_from = z.position
	aim = _ground(z, at)
	phase = "pounce"
	left = POUNCE_TIME
	MistSeal.cast(z, aim, POUNCE_RADIUS, POUNCE_TIME, z._damage * POUNCE_POWER, 0.0, MistSeal.Style.WEB)
	_show(z, "m_lunge")
	z.world.sfx_at("spider_pounce", z.position, 0.0)


## The ostrich: it paws the ground, then charges straight at where you were for CHARGE_RUN seconds;
## anyone it reaches on the way is kicked away.
func _ostrich(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	match phase:
		"tell":
			left -= delta
			_face(z, target.global_position, delta, 10.0)
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				heading = (target.global_position - z.position) * Vector3(1, 0, 1)
				heading = heading.normalized() if heading.length_squared() > 0.01 else z.global_basis.z
				phase = "charge"
				left = CHARGE_RUN
				struck = false
				_show(z, "m_charge")
				z.world.sfx_at("ostrich_screech", z.position, 0.0)
			return true
		"charge":
			left -= delta
			var before := z.position
			z.velocity = heading * z._speed * CHARGE_BURST
			z.move_and_slide()
			z.position.y = z.world.ground_at(z.position)
			_face(z, z.position + heading, delta, 12.0)
			if not struck:
				for p: Target in z.world.players:
					if not p.dead and p.global_position.distance_to(z.position) < KICK_REACH:
						MistSeal.cast(z, p.global_position, KICK_REACH, 0.05, z._damage * KICK_POWER, 0.0, MistSeal.Style.KICK)
						struck = true
						left = minf(left, 0.4)
						_show(z, "m_bite") # the kick, on every phone
						break
			if left <= 0.0 or z.position.distance_to(before) < z._speed * CHARGE_BURST * delta * 0.3:
				phase = ""
				cooldown = CHARGE_EVERY_OSTRICH
				_show(z, "")
			return true
	if cooldown <= 0.0 and dist > CHARGE_RANGE.x and dist < CHARGE_RANGE.y and z._sees and _clear_shot(z, target):
		phase = "tell"
		left = CHARGE_TELL_OSTRICH
		_show(z, "m_cast", true)
		z.world.sfx_at("ostrich_hiss", z.position, 0.0)
		return true
	return false
