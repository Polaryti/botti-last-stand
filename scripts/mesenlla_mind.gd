class_name MesenllaMind
extends RefCounted
## What the creatures of Mesenlla do beyond walking up and striking, worked out on the host (or alone).
## tick() runs before the ordinary walk-and-strike each frame and returns true while a special move has
## the creature's whole attention. Every special has a tell first: a rearing bear, pawing mist, an amber
## circle under an elemental, a white circle from a storm, an orange one from a wyvern. The state is kept in
## Zombie._current_anim (and Zombie.mesenlla_warning for the tell), which other phones are sent.

const MAUL_REACH := 3.4
const MAUL_TELL := 0.65
const MAUL_POWER := 1.8
const MAUL_EVERY := 7.0
const CHARGE_TELL := 0.8
const CHARGE_SPEED := 2.7
const CHARGE_POWER := 1.6
const CHARGE_EVERY := 9.0
const SHIFT_TIME := 0.8
const STAG_FLEE := 5.0
const STAG_HEAL := 0.04 # of its health, each second it flees
const SLAM_RADIUS := 4.5
const SLAM_TELL := 1.0
const SLAM_EVERY := 6.0
const STONE_TELL := 1.2
const STONE_RADIUS := 2.2
const STONE_EVERY := 9.0
const BLINK_TELL := 0.5
const BLINK_EVERY := 8.0
const STORM_TELL := 1.1
const STORM_RADIUS := 2.6
const STORM_EVERY := 4.5
const STORM_RANGE := Vector2(10.0, 18.0) # the distance it likes to keep
const BREATH_TELL := 1.2
const BREATH_RADIUS := 2.4
const BREATH_EVERY := 8.0
const QUAKE_RADIUS := 6.5
const QUAKE_TELL := 1.3
const BOULDER_RADIUS := 3.2
const BOULDER_TELL := 1.4

var kind := ""
var cooldown := 2.0
var cooldown_b := 4.0
var phase := ""
var left := 0.0
var aim := Vector3.ZERO
var heading := Vector3.ZERO
var struck := false
var form := "stag"
var fled_once := false
var enraged := false
var called := false
var _trail := 0.0


static func wants(id: String) -> bool:
	return id in ["bear", "mist_bear", "mist_eagle", "shapeshifter", "earth_elemental", "mist_elemental", "storm_elemental",
		"wyvern", "great_revenant_elemental", "war_wyvern"]


func _init(id: String) -> void:
	kind = id
	cooldown = randf_range(1.5, 3.5)
	cooldown_b = randf_range(3.0, 6.0)


## The state other phones see, and whether a tell is showing.
func _show(z: Zombie, state: String, warning := false) -> void:
	z._current_anim = state
	z.mesenlla_warning = warning


func _face(z: Zombie, at: Vector3, delta: float, rate := 8.0) -> void:
	var flat := at - z.position
	flat.y = 0.0
	if flat.length_squared() > 0.01:
		z.rotation.y = lerp_angle(z.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * rate))


## Something whose ground is solid enough for a ring to land on.
func _ground(z: Zombie, at: Vector3) -> Vector3:
	return Vector3(at.x, z.world.ground_at(at), at.z)


func tick(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	cooldown -= delta
	cooldown_b -= delta
	match kind:
		"bear": return _bear(z, target, dist, delta)
		"mist_bear": return _bear(z, target, dist, delta) or _mist_bear(z, target, dist, delta)
		"shapeshifter": return _shapeshifter(z, target, to, dist, delta)
		"earth_elemental": return _earth(z, target, dist, delta)
		"mist_elemental": return _mist(z, target, dist, delta)
		"storm_elemental": return _storm(z, target, to, dist, delta)
		"wyvern", "war_wyvern": return _wyvern(z, target, dist, delta)
		"great_revenant_elemental": return _revenant(z, target, dist, delta)
	return false


## After an ordinary step: show a plain blow as a swipe, and settle back to walking.
func after(z: Zombie) -> void:
	if phase != "":
		return
	if kind == "shapeshifter":
		_show(z, ("m_swipe" if z._attack_left > 0.0 else "m_beast") if form == "beast" else "m_stag")
		return
	if kind == "great_revenant_elemental" and enraged:
		_show(z, "m_slam" if z._attack_left > 0.0 else "m_beast")
		return
	_show(z, "m_swipe" if z._attack_left > 0.0 else "")


## A flyer finished a stoop, hit or miss.
func on_dive(z: Zombie) -> void:
	if kind == "mist_eagle":
		MistSeal.cast(z, _ground(z, z.position), 2.4, 0.7, z._damage * 0.6, 0.0, MistSeal.Style.MIST)


func on_death(z: Zombie) -> void:
	if kind == "mist_elemental":
		MistSeal.cast(z, _ground(z, z.position), 3.5, 0.6, z._damage * 0.5, 0.0, MistSeal.Style.MIST)


# --- Bears -------------------------------------------------------------------------

## Close in, rear up, and bring both paws down on whatever is in front.
func _bear(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "" and cooldown <= 0.0 and z._sees and dist < MAUL_REACH - 0.4 and z._stun <= 0.0:
		phase = "rear"
		left = MAUL_TELL
		cooldown = MAUL_EVERY
		_show(z, "m_rear", true)
		z.world.sfx_at("bear_roar", z.position, 0.0)
	if phase == "rear":
		left -= delta
		_face(z, target.global_position, delta, 4.0)
		z.velocity = Vector3.ZERO
		if left <= 0.0:
			phase = "maul"
			left = 0.4
			_show(z, "m_swipe")
			z.world.sfx_at("bear_maul", z.position, 0.0)
			var flat := target.global_position - z.position
			flat.y = 0.0
			var ahead := Vector3(sin(z.rotation.y), 0, cos(z.rotation.y))
			if flat.length() < MAUL_REACH and (flat.length() < 0.6 or flat.normalized().dot(ahead) > 0.3) and absf(target.global_position.y - z.position.y) < 2.4:
				target.hurt(z._damage * MAUL_POWER, z.position, z)
			z.world.fx_gore(z.position + ahead * 1.4 + Vector3.UP * 0.2, Color(0.42, 0.36, 0.3))
		return true
	if phase == "maul":
		left -= delta
		if left <= 0.0:
			phase = ""
			_show(z, "")
		return true
	return false


## Paw the ground in a cloud of mist, then charge in a straight line.
func _mist_bear(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "" and cooldown_b <= 0.0 and z._sees and dist > 6.0 and dist < 18.0 and z.world.has_line_of_sight(z.centre(), target.global_position + Vector3.UP):
		phase = "paw"
		left = CHARGE_TELL
		cooldown_b = CHARGE_EVERY
		_show(z, "m_rear", true)
		z.world.sfx_at("bear_roar", z.position, 2.0)
	if phase == "paw":
		left -= delta
		_face(z, target.global_position, delta, 10.0)
		z.velocity = Vector3.ZERO
		_trail -= delta
		if _trail <= 0.0:
			_trail = 0.2
			z.world.fx_mist(z.position + Vector3.UP * 0.3, 0.9)
		if left <= 0.0:
			phase = "charge"
			heading = target.global_position - z.position
			heading.y = 0.0
			heading = heading.normalized()
			left = minf(1.6, (dist + 4.0) / (z._speed * CHARGE_SPEED))
			struck = false
			_show(z, "m_charge")
		return true
	if phase == "charge":
		left -= delta
		z.velocity = heading * z._speed * CHARGE_SPEED * (0.5 if z._slow > 0.0 else 1.0)
		z.rotation.y = atan2(heading.x, heading.z)
		z.move_and_slide()
		z.position.y = z.world.ground_at(z.position)
		_trail -= delta
		if _trail <= 0.0:
			_trail = 0.12
			z.world.fx_mist(z.position + Vector3.UP * 0.5, 0.7)
		var flat := target.global_position - z.position
		flat.y = 0.0
		if not struck and flat.length() < 2.0 and absf(target.global_position.y - z.position.y) < 2.4:
			struck = true
			target.hurt(z._damage * CHARGE_POWER, z.position, z)
			z.world.sfx_at("bear_maul", z.position, 2.0)
		if left <= 0.0 or _hit_wall(z):
			phase = ""
			_show(z, "")
			z.velocity = Vector3.ZERO
		return true
	return false


## Ran into something upright: a wall, a tree, a rock. The slope underfoot does not count.
func _hit_wall(z: Zombie) -> bool:
	for i in z.get_slide_collision_count():
		if z.get_slide_collision(i).get_normal().y < 0.5:
			return true
	return false


# --- Shapeshifter ----------------------------------------------------------------------

func _shapeshifter(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	if phase == "shift":
		left -= delta
		z.velocity = Vector3.ZERO
		if left <= 0.0:
			phase = "flee" if form == "stag" and fled_once and z.hp < z.max_hp else ""
			left = STAG_FLEE
			_set_form(z, form)
		return true
	if form == "stag":
		if phase == "flee":
			# Away from whoever hurt it, mending as it goes, and then back as the beast.
			left -= delta
			var away := -to.normalized() if dist > 0.1 else Vector3.FORWARD
			z.velocity = away * z._speed * 1.25 * (0.5 if z._slow > 0.0 else 1.0)
			z.move_and_slide()
			z.position.y = z.world.ground_at(z.position)
			z.rotation.y = lerp_angle(z.rotation.y, atan2(away.x, away.z), minf(1.0, delta * 6.0))
			z.hp = minf(z.max_hp, z.hp + z.max_hp * STAG_HEAL * delta)
			z._animate_custom(delta, z.velocity.length())
			if left <= 0.0:
				_begin_shift(z, "beast")
			return true
		if (z._sees and dist < 7.0) or z.hp < z.max_hp:
			_begin_shift(z, "beast")
			return true
		return false
	if not fled_once and z.hp < z.max_hp * 0.3:
		fled_once = true
		_begin_shift(z, "stag")
		return true
	return false


func _begin_shift(z: Zombie, into: String) -> void:
	form = into
	phase = "shift"
	left = SHIFT_TIME
	_show(z, "m_shift", true)
	z.world.fx_mist(z.centre(), 1.6)
	z.world.sfx_at("shapeshift", z.position, 0.0)


## The stag cannot fight; the beast is slower but strikes hard.
func _set_form(z: Zombie, into: String) -> void:
	var d: Dictionary = z.def
	if into == "stag":
		z._damage = 0.0
		z._speed = float(d["speed"]) * 1.15 * Game.enemy_speed()
		_show(z, "m_stag")
	else:
		z._damage = float(d["damage"]) * Game.enemy_damage() * (1.0 + ZombieDefs.NIGHT_DAMAGE * z.hero_minute)
		z._speed = 4.2 * Game.enemy_speed()
		_show(z, "m_beast")


## A stun cuts a special move short, tell and all; a change of shape still finishes.
func interrupt(z: Zombie) -> void:
	if phase == "" or phase == "shift" or phase == "flee":
		return
	phase = ""
	_show(z, "m_beast" if kind == "shapeshifter" and form == "beast" else "m_stag" if kind == "shapeshifter" else "")


func start(z: Zombie) -> void:
	if kind == "shapeshifter":
		_set_form(z, "stag")


# --- Elementals --------------------------------------------------------------------------

## Pound the ground around itself, and at a distance hurl a stone where you stand.
func _earth(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "":
		if cooldown <= 0.0 and z._sees and dist < SLAM_RADIUS:
			phase = "slam"
			left = SLAM_TELL + 0.3
			cooldown = SLAM_EVERY
			_show(z, "m_slam", true)
			MistSeal.cast(z, _ground(z, z.position), SLAM_RADIUS, SLAM_TELL, z._damage * 1.4, 0.0, MistSeal.Style.QUAKE)
		elif cooldown_b <= 0.0 and z._sees and dist > 8.0 and dist < 22.0:
			phase = "throw"
			left = 0.6
			cooldown_b = STONE_EVERY
			_show(z, "m_throw", true)
			MistSeal.cast(z, _ground(z, target.global_position + target.velocity * 0.4), STONE_RADIUS, STONE_TELL, z._damage, 0.0, MistSeal.Style.BOULDER)
	if phase == "slam" or phase == "throw":
		left -= delta
		z.velocity = Vector3.ZERO
		_face(z, target.global_position, delta, 3.0)
		if phase == "slam" and left <= 0.3:
			z.mesenlla_warning = false
		if left <= 0.0:
			phase = ""
			_show(z, "")
		return true
	return false


## Fade, and come back behind you.
func _mist(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "" and cooldown <= 0.0 and z._sees and dist > 4.0 and dist < 22.0 and not target.is_unseen():
		phase = "blink"
		left = BLINK_TELL
		cooldown = BLINK_EVERY
		_show(z, "m_blink", true)
		z.world.fx_mist(z.centre(), 1.4)
		z.world.sfx_at("mist_blink", z.position, 0.0)
	if phase == "blink":
		left -= delta
		z.velocity = Vector3.ZERO
		if left <= 0.0:
			var behind := target.global_basis.z if target is Player else -(target.global_position - z.position).normalized()
			behind.y = 0.0
			var spot := target.global_position + behind.normalized() * 2.2
			if z.world.terrain.is_walkable(spot.x, spot.z):
				z.position = _ground(z, spot)
			z.world.fx_mist(z.centre(), 1.4)
			z._attack_cd = 0.25
			_face(z, target.global_position, 1.0, 1.0)
			phase = ""
			_show(z, "")
		return true
	return false


## Keep its distance and call lightning down where you are about to be.
func _storm(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	if not z._sees:
		if phase == "cast":
			phase = ""
			_show(z, "")
		return false
	if phase == "" and cooldown <= 0.0 and dist < 26.0:
		phase = "cast"
		left = 0.7
		cooldown = STORM_EVERY
		_show(z, "m_cast", true)
		MistSeal.cast(z, _ground(z, target.global_position + target.velocity * 0.5), STORM_RADIUS, STORM_TELL, z._damage, 0.0, MistSeal.Style.STORM)
	if phase == "cast":
		left -= delta
		if left <= 0.0:
			phase = ""
			_show(z, "")
	var want := 0.0
	if dist < STORM_RANGE.x:
		want = -1.0
	elif dist > STORM_RANGE.y:
		want = 1.0
	var dir := to.normalized() * want if dist > 0.1 else Vector3.ZERO
	z.velocity = dir * z._speed * (0.5 if z._slow > 0.0 else 1.0) * (0.0 if phase == "cast" else 1.0)
	z.move_and_slide()
	z.position.y = z.world.ground_at(z.position)
	_face(z, target.global_position, delta, 6.0)
	z._animate_custom(delta, z.velocity.length())
	return true


# --- Wyverns -------------------------------------------------------------------------------

## Hover, breathe, and fire comes down in rings along the ground: one under you, more for the War Wyvern.
func _wyvern(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	var war := kind == "war_wyvern"
	if war and not called and z.hp < z.max_hp * 0.5:
		called = true
		z.world.director.show_banner("The War Wyvern calls the eagles of the peaks", 3.0)
		for i in 3:
			var a := TAU * i / 3.0
			z.world.spawn_zombie("eagle", z.position + Vector3(cos(a) * 6.0, 0, sin(a) * 6.0))
	if phase == "" and cooldown <= 0.0 and z._sees and dist < 28.0 and z._dive <= 0.0 and z._windup <= 0.0:
		phase = "breath"
		left = BREATH_TELL + 0.3
		cooldown = BREATH_EVERY * (0.85 if war else 1.0)
		_show(z, "m_breath", true)
		z.world.sfx_at("wyvern_roar", z.position, 2.0)
		var at := target.global_position + target.velocity * 0.5
		var along := at - z.position
		along.y = 0.0
		along = along.normalized() if along.length() > 0.1 else Vector3.FORWARD
		var rings := 4 if war else 1
		for i in rings:
			var spot := at + along * (i - 1.0) * BREATH_RADIUS * 1.6 if war else at
			MistSeal.cast(z, _ground(z, spot), BREATH_RADIUS * (1.15 if war else 1.0), BREATH_TELL + i * 0.15, z._damage, 0.0, MistSeal.Style.FIRE)
	if phase == "breath":
		left -= delta
		var hover := target.global_position + Vector3.UP * float(z.def["fly_height"]) * 0.75
		var drift := hover - z.position
		z.position += drift.normalized() * minf(drift.length(), z._speed * 0.3 * delta)
		_face(z, target.global_position, delta, 6.0)
		if left <= 0.3:
			z.mesenlla_warning = false
		if left <= 0.0:
			phase = ""
			_show(z, "")
		z._animate_custom(delta, 1.0)
		return true
	return false


# --- The Great Revenant Elemental -----------------------------------------------------------

func _revenant(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if not enraged and z.hp <= z.max_hp * 0.5:
		enraged = true
		z._speed *= 1.25
		z.world.fx_blast(z.centre(), 8.0, Color(0.45, 0.95, 0.92, 0.7))
		if Net.is_host():
			Net.blast_fx(z.centre(), 8.0, Color(0.45, 0.95, 0.92, 0.7))
		z.world.director.show_banner("Its boulders break loose", 3.0)
		z.world.sfx_at("revenant_roar", z.position, 4.0)
		cooldown_b = minf(cooldown_b, 1.0)
	if phase == "":
		if cooldown <= 0.0 and dist < QUAKE_RADIUS - 0.5:
			phase = "quake"
			left = QUAKE_TELL + 0.4
			cooldown = 7.0
			_show(z, "m_slam", true)
			z.world.sfx_at("revenant_roar", z.position, 2.0)
			MistSeal.cast(z, _ground(z, z.position), QUAKE_RADIUS, QUAKE_TELL, z._damage * 1.6, 0.0, MistSeal.Style.QUAKE)
		elif cooldown_b <= 0.0 and dist > 7.0 and dist < 40.0:
			phase = "throw"
			left = 0.7
			cooldown_b = 3.5 if enraged else 4.5
			_show(z, "m_throw", true)
			MistSeal.cast(z, _ground(z, target.global_position + target.velocity * 0.5), BOULDER_RADIUS, BOULDER_TELL, z._damage * 1.3, 0.0, MistSeal.Style.BOULDER)
			if enraged:
				var other := _second_target(z, target)
				var spot := other.global_position if other else target.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
				MistSeal.cast(z, _ground(z, spot), BOULDER_RADIUS, BOULDER_TELL + 0.3, z._damage * 1.3, 0.0, MistSeal.Style.BOULDER)
	if phase == "quake" or phase == "throw":
		left -= delta
		z.velocity = Vector3.ZERO
		_face(z, target.global_position, delta, 2.5)
		if phase == "quake" and left <= 0.4:
			z.mesenlla_warning = false
		if left <= 0.0:
			phase = ""
			_show(z, "m_beast" if enraged else "")
		return true
	return false


## Someone else to throw at, so a second boulder spreads the danger.
func _second_target(z: Zombie, first: Target) -> Target:
	var best: Target = null
	for t in z.world.players:
		if t == first or t.dead or t.is_unseen():
			continue
		if best == null or t.global_position.distance_to(z.position) < best.global_position.distance_to(z.position):
			best = t
	return best
