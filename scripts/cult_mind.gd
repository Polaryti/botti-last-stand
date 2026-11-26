class_name CultMind
extends VaelMind
## What the cult of Al'quimelea does, worked out on the host (or alone). Bodies with bones: their tells
## are poses every phone is sent, and what lands is a MistSeal, so each phone hurts its own player:
##   Worshipper: fights with its sickle. When one falls, the others near it rush in, quickened. Some
##     leave the Honey they would have offered.
##   Priest: keeps its distance and throws a flask of elixir where you are going: the ring it marks
##     poisons and slows. Now and then it raises its staff over a hurt creature of the island and
##     anoints it, healing it and quickening it. A stun breaks off the rite.
##   Guardian (and a Guardian whose ostrich has fallen): braces behind its shield, then rushes; whoever
##     it reaches is thrown back and stunned. Blows from the front glance off its shield (ZombieDefs
##     "shielded"). On its ostrich it rides like any rider (Zombie._tick_rider).

const CULT := ["cult_worshipper", "cult_priest", "cult_guardian", "ostrich_rider"]
const FERVOUR_REACH := 12.0
const FERVOUR_TIME := 4.0
const OFFERING_CHANCE := 0.25
const PRIEST_RANGE := Vector2(8.0, 16.0)
const ELIXIR_EVERY := 6.0
const ELIXIR_TELL := 0.9
const ELIXIR_RADIUS := 2.4
const ELIXIR_POWER := 0.7
const ELIXIR_POISON := 3.0
const ELIXIR_SLOW := 2.0
const ANOINT_EVERY := 12.0
const ANOINT_TELL := 1.0
const ANOINT_REACH := 14.0
const ANOINT_HEAL := 1.0 / 3.0 # of its whole health
const ANOINT_HASTE := 5.0
const RUSH_EVERY := 7.0
const RUSH_TELL := 0.7
const RUSH_RANGE := Vector2(3.0, 9.0)
const RUSH_BURST := 3.0 # times its speed
const RUSH_TIME := 1.0
const BASH_REACH := 1.6
const BASH_POWER := 1.2
const BASH_STUN := 0.8
const BASH_KNOCK := 7.0

var _anointing: Zombie


static func handles(id: String) -> bool:
	return id in CULT


func _init(id: String) -> void:
	super(id)
	match kind:
		"cult_priest":
			cooldown = randf_range(2.0, ELIXIR_EVERY)
			cooldown_b = randf_range(5.0, ANOINT_EVERY)
		"cult_guardian", "ostrich_rider":
			cooldown = randf_range(2.0, RUSH_EVERY)


func tick(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	cooldown -= delta
	cooldown_b -= delta
	match kind:
		"cult_priest": return _priest(z, target, to, dist, delta)
		"cult_guardian": return _guardian(z, target, dist, delta)
		"ostrich_rider": return false if z._mounted else _guardian(z, target, dist, delta)
	return false # a worshipper fights as any of the dead do


func after(_z: Zombie) -> void:
	pass


func interrupt(z: Zombie) -> void:
	_anointing = null
	super(z)


func on_death(z: Zombie) -> void:
	phase = ""
	if kind != "cult_worshipper" or (Net.active() and not Net.is_host()):
		return
	# The others take up the cry.
	for other: Zombie in z.world.zombies:
		if other != z and other.is_alive() and other.type_id == "cult_worshipper" and other.position.distance_to(z.position) < FERVOUR_REACH:
			other.hasten(FERVOUR_TIME)
	if randf() < OFFERING_CHANCE:
		z.world.spawn_pickup_at(_ground(z, z.position), Pickup.Kind.FOOD, "honey")


# --- Priest --------------------------------------------------------------------------------------

func _priest(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	match phase:
		"throw":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, aim, delta, 8.0)
			if left <= 0.0:
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
		"anoint":
			left -= delta
			z.velocity = Vector3.ZERO
			if not is_instance_valid(_anointing) or not _anointing.is_alive():
				interrupt(z)
				return true
			_face(z, _anointing.position, delta, 6.0)
			if left <= 0.0:
				_anoint(z, _anointing)
				_anointing = null
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
	if cooldown_b <= 0.0 and z._stun <= 0.0:
		var hurt := _hurt_ally(z)
		if hurt:
			phase = "anoint"
			left = ANOINT_TELL
			cooldown_b = ANOINT_EVERY
			_anointing = hurt
			z.mesenlla_warning = true
			_pose(z, "Raise", 1.0)
			z.world.sfx_at("priest_intone", z.position, 0.0)
			return true
	if cooldown <= 0.0 and z._sees and dist > 3.0 and dist < PRIEST_RANGE.y + 4.0 and _clear(z, target) and z._stun <= 0.0:
		phase = "throw"
		left = ELIXIR_TELL
		cooldown = ELIXIR_EVERY + randf() * 1.5
		aim = _lead(z, target, ELIXIR_TELL * 0.7)
		z.mesenlla_warning = true
		_pose(z, "Throw", 0.9)
		MistSeal.cast(z, aim, ELIXIR_RADIUS, ELIXIR_TELL, z._damage * ELIXIR_POWER, 0.0, MistSeal.Style.ELIXIR)
		z.world.sfx_at("elixir_throw", z.position, 0.0)
		return true
	if dist < 2.2:
		return false
	_keep(z, to, dist, PRIEST_RANGE, delta, target)
	return true


## The hurt creature of the island (a mutant or one of the cult) nearest it, within reach.
func _hurt_ally(z: Zombie) -> Zombie:
	var best: Zombie = null
	var best_d := ANOINT_REACH
	for other: Zombie in z.world.zombies:
		if other == z or not other.is_alive() or other.hp >= other.max_hp * 0.8:
			continue
		if not (other.type_id in FontaModels.KINDS or other.type_id in CULT):
			continue
		var d := other.position.distance_to(z.position)
		if d < best_d:
			best = other
			best_d = d
	return best


static func _anoint(z: Zombie, who: Zombie) -> void:
	who.hp = minf(who.max_hp, who.hp + who.max_hp * ANOINT_HEAL)
	who.hasten(ANOINT_HASTE)
	z.world.fx_ring(who.position + Vector3.UP * 0.1, 1.6, Color(0.6, 1.0, 0.5))
	z.world.sfx_at("anoint_chime", who.position, 0.0)


# --- Guardian ------------------------------------------------------------------------------------

func _guardian(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	match phase:
		"brace":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 10.0)
			if left <= 0.0:
				heading = (target.global_position - z.position) * Vector3(1, 0, 1)
				heading = heading.normalized() if heading.length_squared() > 0.01 else z.global_basis.z
				phase = "rush"
				left = RUSH_TIME
				struck = false
				z.mesenlla_warning = false
				_pose(z, "Running_A", 1.8)
				z.world.sfx_at("shield_rush", z.position, 0.0)
			return true
		"rush":
			left -= delta
			var before := z.position
			z.velocity = heading * z._speed * RUSH_BURST
			z.move_and_slide()
			z.position.y = z.world.ground_at(z.position)
			_face(z, z.position + heading, delta, 12.0)
			if not struck:
				for p: Target in z.world.players:
					if not p.dead and p.global_position.distance_to(z.position) < BASH_REACH + 0.4:
						MistSeal.cast(z, p.global_position, BASH_REACH, 0.05, z._damage * BASH_POWER, 0.0, MistSeal.Style.BASH)
						struck = true
						left = minf(left, 0.2)
						break
			if left <= 0.0 or z.position.distance_to(before) < z._speed * RUSH_BURST * delta * 0.3:
				phase = ""
				cooldown = RUSH_EVERY
				z._current_anim = ""
			return true
	if cooldown <= 0.0 and z._sees and dist > RUSH_RANGE.x and dist < RUSH_RANGE.y and _clear(z, target) and z._stun <= 0.0:
		phase = "brace"
		left = RUSH_TELL
		z.mesenlla_warning = true
		_pose(z, "WindUp", 0.8)
		z.world.sfx_at("guardian_shout", z.position, 0.0)
		return true
	return false
