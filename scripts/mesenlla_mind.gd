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
const STAG_FLEE := 10.0 # how long it runs as a stag; not killed by then, it comes back whole
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
const PASS_EVERY := 22.0 # the War Wyvern's burning passes over a stronghold's portal
const PASS_GIVE_UP := 9.0
const QUAKE_RADIUS := 6.5
const QUAKE_TELL := 1.3
const BOULDER_RADIUS := 3.2
const BOULDER_TELL := 1.4
# Port Vael
const STING_TELL := 0.7 # a Lantern Jelly's threads flare this long before it stings
const STING_EVERY := 3.2
const BITE_REACH := 2.6 # an Angler's lunge
const BITE_TELL := 0.45
const BITE_POWER := 1.0
const BITE_EVERY := 2.4

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
var _pass_left := 8.0
var _at_portal := false
var _trail := 0.0


static func wants(id: String) -> bool:
	return id in ["bear", "mist_bear", "mist_eagle", "shapeshifter", "earth_elemental", "mist_elemental", "storm_elemental",
		"wyvern", "great_revenant_elemental", "war_wyvern", "brine_hound", "lantern_jelly", "angler"]


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
		"brine_hound": return _wolf(z, target, dist, delta)
		"lantern_jelly": return _jelly(z, target, dist, delta)
		"angler": return _angler(z, target, dist, delta)
	return false


## Struck, and still standing (the host's or a lone phone's blow). Nothing, unless a mind says otherwise.
func on_hurt(z: Zombie) -> void:
	if kind == "war_wyvern":
		_call_eagles(z) # the blow that takes it below half calls them at once, whatever it is doing


## The War Wyvern below half health calls the eagles of the peaks, once: from the blow that takes it
## there (on_hurt), or from its next turn if its health fell some other way.
func _call_eagles(z: Zombie) -> void:
	if called or z.hp >= z.max_hp * 0.5:
		return
	called = true
	z.world.director.show_banner("The War Wyvern calls the eagles of the peaks", 3.0)
	for i in 3:
		var a := TAU * i / 3.0
		z.world.spawn_zombie("eagle", z.position + Vector3(cos(a) * 6.0, 0, sin(a) * 6.0))


## After an ordinary step: show a plain blow as a swipe, and settle back to walking.
func after(z: Zombie) -> void:
	if phase != "":
		return
	if kind == "shapeshifter":
		_show(z, FORM_STATES[form][1 if z._attack_left > 0.0 and form != "stag" else 0])
		return
	if kind == "great_revenant_elemental" and enraged:
		_show(z, "m_slam" if z._attack_left > 0.0 else "m_beast")
		return
	_show(z, "m_swipe" if z._attack_left > 0.0 else "")


## A flyer finished a stoop, hit or miss.
func on_dive(z: Zombie) -> void:
	if kind == "mist_eagle":
		MistSeal.cast(z, _ground(z, z.position), 2.4, 0.7, z._damage * 0.6, 0.0, MistSeal.Style.MIST)
	elif kind == "wyvern" or kind == "war_wyvern":
		# Its element bursts where it struck, a moment later: step out of it.
		MistSeal.cast(z, _ground(z, z.position), DIVE_BURST_RADIUS * (1.4 if kind == "war_wyvern" else 1.0), DIVE_BURST_DELAY, z._damage * DIVE_BURST_POWER, 0.0, element_style(z.element))


func on_death(z: Zombie) -> void:
	if kind == "mist_elemental":
		MistSeal.cast(z, _ground(z, z.position), 3.5, 0.6, z._damage * 0.5, 0.0, MistSeal.Style.MIST)
	elif kind == "lantern_jelly":
		# Its last sting, as it bursts.
		MistSeal.cast(z, _ground(z, z.position), float(z.def["sting_reach"]), STING_TELL * 0.5, z._damage * 0.6, 0.0, MistSeal.Style.STING)


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
		_show(z, "m_paw", true)
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

## The Shapeshifter's fighting shapes. Close by or hurt, the white stag takes one of them at random, and
## every FORM_TIME seconds another: the clawed beast (walks up and strikes); the Mist Wolf (fast; lunges,
## and howls to hasten the creatures around it); the Great Owl (takes to the air, and dives with its
## talons); the Tusked Boar (paws the ground and charges, knocking you down).
const FIGHTING_FORMS := ["beast", "wolf", "owl", "boar"]
const FORM_NAMES := {"stag": "White Stag", "beast": "Beast", "wolf": "Mist Wolf", "owl": "Great Owl", "boar": "Tusked Boar"}
const FORM_TIME := 12.0
const FORM_SPEED := {"beast": 5.0, "wolf": 6.6, "owl": 6.0, "boar": 5.4}
## What each shape shows going about, and striking (Zombie._current_anim).
const FORM_STATES := {"stag": ["m_stag", "m_stag"], "beast": ["m_beast", "m_swipe"], "wolf": ["m_wolf", "m_bite"], "owl": ["m_owl", "m_dive"], "boar": ["m_boar", "m_gore"]}
const LUNGE_TELL := 0.45
const LUNGE_TIME := 0.4
const LUNGE_SPEED := 15.0
const LUNGE_POWER := 1.3
const LUNGE_EVERY := 5.0
const LUNGE_RANGE := Vector2(3.0, 8.0)
const HOWL_TIME := 0.9
const HOWL_EVERY := 14.0
const HOWL_REACH := 12.0
const HOWL_HASTE_TIME := 6.0
const OWL_HEIGHT := 4.5
const OWL_TELL := 0.6
const OWL_DIVE_SPEED := 13.0
const OWL_POWER := 1.2
const OWL_EVERY := 3.5
const GORE_TELL := 0.7
const GORE_SPEED := 2.8 # times its own, charging
const GORE_POWER := 1.4
const GORE_EVERY := 7.0
const GORE_KNOCKDOWN := 0.8
var _form_left := 0.0
var _orbit := 0.0


func _shapeshifter(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	if phase == "shift":
		left -= delta
		z.velocity = Vector3.ZERO
		# Out of the air, if it was the owl.
		var ground := z.world.ground_at(z.position)
		z.position.y = maxf(ground, z.position.y - 6.0 * delta)
		if left <= 0.0:
			phase = "flee" if form == "stag" and fled_once and z.hp < z.max_hp else ""
			left = STAG_FLEE
			_set_form(z, form)
		return true
	if form == "stag":
		if phase == "flee":
			# Away from whoever hurt it, for STAG_FLEE seconds, and then back in a fighting shape.
			left -= delta
			var away := -to.normalized() if dist > 0.1 else Vector3.FORWARD
			z.velocity = away * z._speed * 1.25 * (0.5 if z._slow > 0.0 else 1.0)
			z.move_and_slide()
			z.position.y = z.world.ground_at(z.position)
			z.rotation.y = lerp_angle(z.rotation.y, atan2(away.x, away.z), minf(1.0, delta * 6.0))
			if left <= 0.0:
				# It got away: the mist mends it whole, and it comes back to fight.
				z.hp = z.max_hp
				z.world.fx_mist(z.centre(), 2.4)
				_begin_shift(z, _next_form())
			return true
		if (z._sees and dist < 7.0) or z.hp < z.max_hp:
			_begin_shift(z, _next_form())
			return true
		return false
	if not fled_once and z.hp < z.max_hp * 0.3:
		fled_once = true
		_begin_shift(z, "stag")
		return true
	_form_left -= delta
	if phase == "" and _form_left <= 0.0:
		_begin_shift(z, _next_form())
		return true
	match form:
		"wolf": return _wolf(z, target, dist, delta)
		"owl": return _owl(z, target, dist, delta)
		"boar": return _boar(z, target, dist, delta)
	return false


## Any fighting shape but the one it is in.
func _next_form() -> String:
	var choices: Array = FIGHTING_FORMS.filter(func(f: String) -> bool: return f != form)
	return str(choices.pick_random())


## The Mist Wolf: a crouch, then a lunge that covers the ground between you in a moment; and a howl
## that hastens every creature near it.
func _wolf(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "":
		if kind != "brine_hound" and cooldown_b <= 0.0 and z._sees and dist < HOWL_REACH:
			phase = "howl"
			left = HOWL_TIME
			cooldown_b = HOWL_EVERY
			_show(z, "m_howl", true)
			z.world.sfx_at("howl", z.position, 2.0)
		elif cooldown <= 0.0 and z._sees and dist > LUNGE_RANGE.x and dist < LUNGE_RANGE.y and z.world.has_line_of_sight(z.centre(), target.global_position + Vector3.UP):
			phase = "crouch"
			left = LUNGE_TELL
			cooldown = LUNGE_EVERY
			_show(z, "m_lunge", true)
			z.world.sfx_at("hound_snarl" if kind == "brine_hound" else "beast_growl", z.position, -2.0)
	match phase:
		"howl":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 4.0)
			if left <= 0.0:
				var hastened := 0
				for other: Zombie in z.world.zombies:
					if other != z and other.is_alive() and other.position.distance_to(z.position) <= HOWL_REACH:
						other.hasten(HOWL_HASTE_TIME)
						hastened += 1
				z.world.fx_blast(z.centre(), HOWL_REACH, Color(0.45, 0.95, 0.92, 0.35))
				if Net.is_host():
					Net.blast_fx(z.centre(), HOWL_REACH, Color(0.45, 0.95, 0.92, 0.35))
				phase = ""
				_show(z, "m_wolf")
			return true
		"crouch":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 12.0)
			if left <= 0.0:
				phase = "leap"
				heading = target.global_position - z.position
				heading.y = 0.0
				heading = heading.normalized()
				left = LUNGE_TIME
				struck = false
				_show(z, "m_lunge")
			return true
		"leap":
			left -= delta
			z.velocity = heading * LUNGE_SPEED * (0.5 if z._slow > 0.0 else 1.0)
			z.move_and_slide()
			z.position.y = z.world.ground_at(z.position)
			var flat := target.global_position - z.position
			flat.y = 0.0
			if not struck and flat.length() < 1.7 and absf(target.global_position.y - z.position.y) < 2.0:
				struck = true
				target.hurt(z._damage * LUNGE_POWER, z.position, z)
				z.world.sfx_at("hound_bite" if kind == "brine_hound" else "wolf", z.position, 0.0)
			if left <= 0.0 or _hit_wall(z):
				phase = ""
				_show(z, "m_wolf")
				z.velocity = Vector3.ZERO
			return true
	return false


## The Great Owl: it circles above you, out of reach of a blade; it hangs for a moment and screeches,
## then falls on you talons first, and climbs back up.
func _owl(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	var ground := z.world.ground_at(z.position)
	var speed := z._speed * (0.5 if z._slow > 0.0 else 1.0)
	match phase:
		"hang":
			left -= delta
			_face(z, target.global_position, delta, 10.0)
			if left <= 0.0:
				phase = "dive"
				left = 1.4
				aim = target.global_position + Vector3.UP * 1.1 + target.velocity * 0.25
				_show(z, "m_dive")
		"dive":
			left -= delta
			var to_aim := aim - (z.position + Vector3.UP * 1.0)
			z.position += to_aim.normalized() * minf(to_aim.length(), OWL_DIVE_SPEED * (0.5 if z._slow > 0.0 else 1.0) * delta)
			_face(z, aim, delta, 8.0)
			if to_aim.length() < 0.6 or left <= 0.0:
				if (target.global_position + Vector3.UP).distance_to(z.position + Vector3.UP) < 1.8 and z.world.has_line_of_sight(z.centre(), target.global_position + Vector3.UP):
					target.hurt(z._damage * OWL_POWER, z.position, z)
					z.world.sfx_at("claw_swipe", z.position, 0.0)
				phase = "climb"
				left = 1.0
				cooldown = OWL_EVERY
				_show(z, "m_owl")
		"climb":
			left -= delta
			z.position.y = minf(z.position.y + 5.0 * delta, ground + OWL_HEIGHT)
			if left <= 0.0:
				phase = ""
		_:
			# Round and round above you.
			_orbit += delta * 0.9
			var over := target.global_position + Vector3(cos(_orbit) * 5.0, OWL_HEIGHT, sin(_orbit) * 5.0)
			var drift := over - z.position
			z.position += drift.normalized() * minf(drift.length(), speed * delta)
			var flat := Vector3(drift.x, 0, drift.z)
			if flat.length() > 0.2:
				z.rotation.y = lerp_angle(z.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 5.0))
			if cooldown <= 0.0 and z._sees and dist < 20.0 and z.position.y - ground > OWL_HEIGHT * 0.6 and z.world.has_line_of_sight(z.centre(), target.global_position + Vector3.UP):
				phase = "hang"
				left = OWL_TELL
				_show(z, "m_owl", true)
				z.world.sfx_at("owl_screech", z.position, 2.0)
	z.position.y = maxf(z.position.y, ground + 0.3)
	return true


## The Tusked Boar: it paws the ground and snorts, then charges in a straight line; what it hits is
## knocked down.
func _boar(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "" and cooldown_b <= 0.0 and z._sees and dist > 5.0 and dist < 16.0 and z.world.has_line_of_sight(z.centre(), target.global_position + Vector3.UP):
		phase = "paw"
		left = GORE_TELL
		cooldown_b = GORE_EVERY
		_show(z, "m_paw", true)
		z.world.sfx_at("boar_snort", z.position, 2.0)
	if phase == "paw":
		left -= delta
		_face(z, target.global_position, delta, 10.0)
		z.velocity = Vector3.ZERO
		_trail -= delta
		if _trail <= 0.0:
			_trail = 0.25
			z.world.fx_gore(z.position + Vector3(0, 0.2, 0) + Vector3(sin(z.rotation.y), 0, cos(z.rotation.y)) * 0.6, Color(0.42, 0.36, 0.3))
		if left <= 0.0:
			phase = "charge"
			heading = target.global_position - z.position
			heading.y = 0.0
			heading = heading.normalized()
			left = minf(1.6, (dist + 4.0) / (z._speed * GORE_SPEED))
			struck = false
			_show(z, "m_charge")
		return true
	if phase == "charge":
		left -= delta
		z.velocity = heading * z._speed * GORE_SPEED * (0.5 if z._slow > 0.0 else 1.0)
		z.rotation.y = atan2(heading.x, heading.z)
		z.move_and_slide()
		z.position.y = z.world.ground_at(z.position)
		var flat := target.global_position - z.position
		flat.y = 0.0
		if not struck and flat.length() < 1.8 and absf(target.global_position.y - z.position.y) < 2.0:
			struck = true
			target.hurt(z._damage * GORE_POWER, z.position, z)
			z.world.sfx_at("bear_maul", z.position, 0.0)
			if target is Player:
				var p := target as Player
				p.apply_status(Net.Status.STUN, GORE_KNOCKDOWN)
				p.velocity += heading * 7.0 + Vector3.UP * 3.0
				p.say("Knocked down!")
		if left <= 0.0 or _hit_wall(z):
			phase = ""
			_show(z, "m_boar")
			z.velocity = Vector3.ZERO
		return true
	return false


func _begin_shift(z: Zombie, into: String) -> void:
	form = into
	phase = "shift"
	left = SHIFT_TIME
	_show(z, "m_shift", true)
	z.world.fx_mist(z.centre(), 1.6)
	z.world.sfx_at("shapeshift", z.position, 0.0)


## The stag cannot fight; each other shape strikes as hard as the beast, at its own pace.
func _set_form(z: Zombie, into: String) -> void:
	var d: Dictionary = z.def
	_form_left = FORM_TIME
	z.collision_mask = 0 if into == "owl" else (1 | Terrain.BARRIER | Terrain.ENEMY_ONLY)
	if into == "stag":
		z._damage = 0.0
		z._speed = float(d["speed"]) * 1.15 * Game.enemy_speed()
	else:
		z._damage = float(d["damage"]) * Game.enemy_damage() * (1.0 + ZombieDefs.NIGHT_DAMAGE * z.hero_minute)
		z._speed = float(FORM_SPEED[into]) * Game.enemy_speed()
		cooldown = 1.5
		cooldown_b = 2.5
	if into != "owl":
		z.position.y = z.world.ground_at(z.position)
	_show(z, FORM_STATES[into][0])


## A stun cuts a special move short, tell and all; a change of shape still finishes.
func interrupt(z: Zombie) -> void:
	if phase == "" or phase == "shift" or phase == "flee":
		return
	phase = ""
	_show(z, FORM_STATES[form][0] if kind == "shapeshifter" else "")


func start(z: Zombie) -> void:
	if kind == "shapeshifter":
		form = "stag"
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
	return true


# --- Wyverns -------------------------------------------------------------------------------

## What a wyvern of each element breathes, and what bursts where it dives (MistSeal.Style).
static func element_style(element: String) -> int:
	match element:
		"ice": return MistSeal.Style.FROST
		"storm": return MistSeal.Style.STORM
	return MistSeal.Style.FIRE


const DIVE_BURST_RADIUS := 2.0
const DIVE_BURST_DELAY := 0.5
const DIVE_BURST_POWER := 0.5 # of its blow


## Hover, breathe, and its element comes down in rings along the ground: one under you, more for the
## War Wyvern. (Its riders are creatures of their own: wyvern_rider, in Zombie._tick_carried.)
func _wyvern(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	var war := kind == "war_wyvern"
	var style := element_style(z.element)
	if war:
		_call_eagles(z)
	# Over a stronghold, the War Wyvern breaks off every so often to make a burning pass at its portal.
	var fort := z.world.fort
	if war and fort and phase == "":
		_pass_left -= delta
		if _pass_left <= 0.0 and fort.heart_hp > 0.0:
			phase = "pass"
			left = PASS_GIVE_UP
	if phase == "pass":
		left -= delta
		var over := fort.heart_at + Vector3.UP * float(z.def["fly_height"])
		var drift := over - z.position
		z.position += drift.normalized() * minf(drift.length(), z._speed * 1.3 * delta)
		_face(z, fort.heart_at, delta, 4.0)
		var flat := Vector2(fort.heart_at.x - z.position.x, fort.heart_at.z - z.position.z)
		if flat.length() < 14.0 or left <= 0.0:
			_pass_left = PASS_EVERY
			_at_portal = true
			phase = "breath"
			left = BREATH_TELL + 0.3
			cooldown = BREATH_EVERY * 0.85
			_show(z, "m_breath", true)
			z.world.sfx_at("wyvern_roar", z.position, 3.0)
			var along := Vector3(flat.x, 0.0, flat.y).normalized() if flat.length() > 0.5 else Vector3.FORWARD
			# A line of fire that ends on the portal, coming from where the wyvern came.
			for i in 4:
				MistSeal.cast(z, _ground(z, fort.heart_at - along * (3 - i) * BREATH_RADIUS * 1.6), BREATH_RADIUS * 1.15, BREATH_TELL + i * 0.15, z._damage, 0.0, style)
		return true
	if phase == "" and cooldown <= 0.0 and z._sees and dist < 28.0 and z._dive <= 0.0 and z._windup <= 0.0:
		_at_portal = false
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
			MistSeal.cast(z, _ground(z, spot), BREATH_RADIUS * (1.15 if war else 1.0), BREATH_TELL + i * 0.15, z._damage, 0.0, style)
	if phase == "breath":
		left -= delta
		var focus := fort.heart_at if _at_portal and fort else target.global_position
		var hover := focus + Vector3.UP * float(z.def["fly_height"]) * 0.75
		var drift := hover - z.position
		z.position += drift.normalized() * minf(drift.length(), z._speed * 0.3 * delta)
		_face(z, focus, delta, 6.0)
		if left <= 0.3:
			z.mesenlla_warning = false
		if left <= 0.0:
			phase = ""
			_show(z, "")
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


# --- Port Vael ---------------------------------------------------------------------------------

## A Lantern Jelly drifts at you; close enough, its threads flare (a ring on the ground beneath it shows
## the sting's reach), then everything in the ring is stung and stunned (MistSeal.Style.STING).
func _jelly(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	var reach := float(z.def["sting_reach"])
	if phase == "" and cooldown <= 0.0 and dist < reach - 0.3 and absf(target.global_position.y - z.position.y) < 3.0:
		phase = "flare"
		left = STING_TELL
		cooldown = STING_EVERY
		_show(z, "m_sting", true)
		MistSeal.cast(z, _ground(z, z.position), reach, STING_TELL, z._damage, 0.0, MistSeal.Style.STING)
	match phase:
		"flare":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				phase = "sting"
				left = 0.45
				_show(z, "m_sting")
			return true
		"sting":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	return false


## An Angler, once it is out of the sand: it waddles at you, and close by it rears back with its jaws
## wide (the tell) and then lunges and bites whatever is in front of it.
func _angler(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "" and cooldown <= 0.0 and z._sees and dist < BITE_REACH and z._stun <= 0.0:
		phase = "gape"
		left = BITE_TELL
		cooldown = BITE_EVERY
		_show(z, "m_bite", true)
		z.world.sfx_at("angler_rise", z.position, -6.0)
	match phase:
		"gape":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 6.0)
			if left <= 0.0:
				phase = "bite"
				left = 0.35
				_show(z, "m_bite")
				z.world.sfx_at("angler_bite", z.position, 0.0)
				var flat := target.global_position - z.position
				flat.y = 0.0
				var ahead := Vector3(sin(z.rotation.y), 0, cos(z.rotation.y))
				if flat.length() < BITE_REACH + 0.3 and (flat.length() < 0.6 or flat.normalized().dot(ahead) > 0.4) and absf(target.global_position.y - z.position.y) < 2.0:
					target.hurt(z._damage * BITE_POWER, z.position, z)
			return true
		"bite":
			left -= delta
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	return false
