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
##   The Hierophant (miniboss): keeps its distance and throws three flasks at once, one where you are
##     going and one to either side. Below half health it pours the elixir of change over the
##     Worshippers near it, and they become mutants; with none near, it calls two down to it first.
##   The Polemarch (miniboss): behind a tower shield (a quarter of a blow from the front gets through).
##     Close in it sweeps its spear across the ground before it, throwing back and stunning whoever it
##     catches; further off it charges behind the shield. At 60% and 30% health it calls two Guardians.

const CULT := ["cult_worshipper", "cult_priest", "cult_guardian", "ostrich_rider"]
const GREAT := ["hierophant", "polemarch"] # the cult's minibosses, each come once in the night
const FAN_EVERY := 7.0
const FAN_TELL := 1.1
const FAN_SPREAD := 3.2 # metres either side of the middle flask
const FAN_POWER := 0.8
const HIERO_RANGE := Vector2(7.0, 14.0)
const RITE_EVERY := 20.0
const RITE_TELL := 1.6
const RITE_REACH := 18.0
const RITE_COUNT := 2
const RITE_INTO := ["battle_ostrich", "thornback"] # what a Worshipper becomes, in turn
const SPEAR_EVERY := 5.0
const SPEAR_TELL := 0.8
const SPEAR_REACH := 4.2 # how near you must be for it to sweep rather than charge
const SPEAR_RADIUS := 2.6
const SPEAR_AHEAD := 2.0 # the middle of the arc, in front of it
const SPEAR_POWER := 1.3
const SPEAR_STUN := 1.0
const SPEAR_KNOCK := 9.0
const CHARGE_RANGE := Vector2(5.0, 16.0)
const CHARGE_BURST := 3.4
const CHARGE_TIME := 1.4
const PHALANX := [0.6, 0.3] # of its health, where it calls its Guardians
const PHALANX_COUNT := 2
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
	return id in CULT or id in GREAT


func _init(id: String) -> void:
	super(id)
	match kind:
		"cult_priest":
			cooldown = randf_range(2.0, ELIXIR_EVERY)
			cooldown_b = randf_range(5.0, ANOINT_EVERY)
		"cult_guardian", "ostrich_rider":
			cooldown = randf_range(2.0, RUSH_EVERY)
		"hierophant":
			cooldown = 2.5
			cooldown_b = 0.0
		"polemarch":
			cooldown = 3.0
			cooldown_b = 1.5


func tick(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	cooldown -= delta
	cooldown_b -= delta
	match kind:
		"cult_priest": return _priest(z, target, to, dist, delta)
		"cult_guardian": return _guardian(z, target, dist, delta)
		"ostrich_rider": return false if z._mounted else _guardian(z, target, dist, delta)
		"hierophant": return _hierophant(z, target, to, dist, delta)
		"polemarch": return _polemarch(z, target, dist, delta)
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


# --- The Hierophant -------------------------------------------------------------------------------

var _rites := 0 # rites of change so far; which mutant the next Worshipper becomes
var _phalanx := 0 # Guardians' calls so far

func _hierophant(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	match phase:
		"fan":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, aim, delta, 8.0)
			if left <= 0.0:
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
		"rite":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				_change_worshippers(z)
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
	if z.hp <= z.max_hp * 0.5 and cooldown_b <= 0.0 and z._stun <= 0.0:
		phase = "rite"
		left = RITE_TELL
		cooldown_b = RITE_EVERY
		z.mesenlla_warning = true
		_pose(z, "Raise", 1.2 / RITE_TELL)
		z.world.sfx_at("transmute_rite", z.position, 4.0)
		z.world.fx_ring(z.position + Vector3.UP * 0.1, RITE_REACH * 0.5, Color(0.7, 0.4, 1.0))
		z.world.director.show_banner("The Hierophant pours out the elixir of change", 3.0)
		return true
	if cooldown <= 0.0 and z._sees and dist > 3.0 and dist < HIERO_RANGE.y + 6.0 and _clear(z, target) and z._stun <= 0.0:
		phase = "fan"
		left = FAN_TELL
		cooldown = FAN_EVERY + randf() * 1.5
		aim = _lead(z, target, FAN_TELL * 0.7)
		z.mesenlla_warning = true
		_pose(z, "Throw", 0.8)
		var across := (aim - z.position).cross(Vector3.UP)
		across = across.normalized() if across.length_squared() > 0.01 else Vector3.RIGHT
		for k: float in [-1.0, 0.0, 1.0]:
			var spot := _ground(z, aim + across * FAN_SPREAD * k)
			MistSeal.cast(z, spot, ELIXIR_RADIUS, FAN_TELL + absf(k) * 0.15, z._damage * FAN_POWER, 0.0, MistSeal.Style.ELIXIR)
		z.world.sfx_at("elixir_throw", z.position, 2.0)
		return true
	if dist < 2.2:
		return false
	_keep(z, to, dist, HIERO_RANGE, delta, target)
	return true


## The elixir of change: up to RITE_COUNT Worshippers near it become mutants of the island, in a
## burst of violet. If none are near, it calls two down to it, to change them at the next rite.
func _change_worshippers(z: Zombie) -> void:
	var w := z.world
	var near: Array[Zombie] = []
	for other: Zombie in w.zombies:
		if other.is_alive() and other.type_id == "cult_worshipper" and other.position.distance_to(z.position) < RITE_REACH:
			near.append(other)
	if near.is_empty():
		for i in RITE_COUNT:
			var at := w.spawn_point_near(z.position, 3.0, 6.0)
			if at != Vector3.INF and w.spawn_zombie("cult_worshipper", at):
				w.fx_ring(at + Vector3.UP * 0.1, 1.2, Color(0.9, 0.8, 0.55))
		return
	near.sort_custom(func(a: Zombie, b: Zombie) -> bool: return a.position.distance_to(z.position) < b.position.distance_to(z.position))
	for i in mini(RITE_COUNT, near.size()):
		var who := near[i]
		var at := who.position
		var into: String = RITE_INTO[_rites % RITE_INTO.size()]
		_rites += 1
		who.release()
		w.fx_mist(at + Vector3.UP * 0.8, 1.6)
		w.fx_ring(at + Vector3.UP * 0.1, 2.2, Color(0.75, 0.4, 1.0))
		w.fx_gore(at + Vector3.UP * 1.0, Color(0.55, 0.3, 0.7))
		w.spawn_zombie(into, at)


# --- The Polemarch --------------------------------------------------------------------------------

func _polemarch(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	match phase:
		"sweep":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
		"call":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				_call_phalanx(z)
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
		"brace", "rush":
			return _charge(z, target, delta)
	if _phalanx < PHALANX.size() and z.hp <= z.max_hp * float(PHALANX[_phalanx]) and z._stun <= 0.0:
		_phalanx += 1
		phase = "call"
		left = 1.2
		z.mesenlla_warning = true
		_pose(z, "Raise", 1.0)
		z.world.sfx_at("phalanx_call", z.position, 4.0)
		z.world.director.show_banner("The Polemarch calls its Guardians to its sides", 3.0)
		return true
	if cooldown_b <= 0.0 and dist < SPEAR_REACH and z._stun <= 0.0:
		phase = "sweep"
		left = SPEAR_TELL + 0.35
		cooldown_b = SPEAR_EVERY
		z.mesenlla_warning = true
		_face(z, target.global_position, 1.0, 100.0)
		_pose(z, "Sweep", 0.9 / (SPEAR_TELL + 0.35)) # the spear swept round, as a spearman does
		var ahead := Vector3(sin(z.rotation.y), 0, cos(z.rotation.y))
		MistSeal.cast(z, _ground(z, z.position + ahead * SPEAR_AHEAD), SPEAR_RADIUS, SPEAR_TELL, z._damage * SPEAR_POWER, 0.0, MistSeal.Style.SWEEP)
		z.world.sfx_at("polemarch_voice", z.position, 0.0)
		return true
	if cooldown <= 0.0 and z._sees and dist > CHARGE_RANGE.x and dist < CHARGE_RANGE.y and _clear(z, target) and z._stun <= 0.0:
		phase = "brace"
		left = RUSH_TELL + 0.2
		z.mesenlla_warning = true
		_pose(z, "WindUp", 0.7)
		z.world.sfx_at("polemarch_voice", z.position, 2.0)
		return true
	return false


## The Polemarch's charge: as a Guardian's rush, longer and harder.
func _charge(z: Zombie, target: Target, delta: float) -> bool:
	match phase:
		"brace":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 10.0)
			if left <= 0.0:
				heading = (target.global_position - z.position) * Vector3(1, 0, 1)
				heading = heading.normalized() if heading.length_squared() > 0.01 else z.global_basis.z
				phase = "rush"
				left = CHARGE_TIME
				struck = false
				z.mesenlla_warning = false
				_pose(z, "Running_A", 1.8)
				z.world.sfx_at("shield_rush", z.position, 2.0)
		"rush":
			left -= delta
			var before := z.position
			z.velocity = heading * z._speed * CHARGE_BURST
			z.move_and_slide()
			z.position.y = z.world.ground_at(z.position)
			_face(z, z.position + heading, delta, 12.0)
			if not struck:
				for p: Target in z.world.players:
					if not p.dead and p.global_position.distance_to(z.position) < BASH_REACH + 0.8:
						MistSeal.cast(z, p.global_position, BASH_REACH + 0.4, 0.05, z._damage * BASH_POWER, 0.0, MistSeal.Style.BASH)
						struck = true
						left = minf(left, 0.2)
						break
			if left <= 0.0 or z.position.distance_to(before) < z._speed * CHARGE_BURST * delta * 0.3:
				phase = ""
				cooldown = RUSH_EVERY + 1.0
				z._current_anim = ""
	return true


func _call_phalanx(z: Zombie) -> void:
	var side := Vector3(cos(z.rotation.y), 0, -sin(z.rotation.y))
	for k: float in [-1.0, 1.0]:
		var at := z.world.grid.to_world(z.world.grid.nearest_free(z.world.grid.to_cell(z.position + side * 2.6 * k)))
		at.y = z.world.ground_at(at)
		if z.world.spawn_zombie("cult_guardian", at):
			z.world.fx_ring(at + Vector3.UP * 0.1, 1.4, Color(0.95, 0.75, 0.35))
