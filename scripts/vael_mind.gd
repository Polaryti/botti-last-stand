class_name VaelMind
extends MesenllaMind
## What the drowned court of Port Vael does beyond walking up and striking (Stage 3 of "The Sunken
## Crown"), worked out on the host (or alone), on the same footing as MesenllaMind: tick() runs before
## the ordinary walk-and-strike and returns true while a special move has the creature's attention.
## Every special has a tell first, and most of them land as a ring on the ground (MistSeal):
##   Siren              sings (m_song): every phone draws its own players toward her while she does
##                      (VaelMind.sing). A stun, or a fifth of her health lost, breaks it.
##   Press Gang         a weighted net (MistSeal NET) that holds you where you stand.
##   Tide Witch         a line of waves rolling at you (WAVE); at high tide, Drowned Sailors from the water.
##   Harbourmaster      a hook on a chain (HOOK) that drags you to him; below half, his bell calls a
##                      Press Gang.
##   Lighthouse Keeper  burning oil lamps (LAMP); and his great lamp lifted (FLASH): whoever is looking at
##                      him when it blazes is dazzled.
##   Kraken's Arm       rooted in the flooded flats: rears up and slams down (SLAM); sinks when the tide
##                      goes out.
##   Hollow Sovereign   waves in a line (WAVE); twice a royal decree that calls the tide in and raises his
##                      court; below half, the crown's judgement (CROWN).
## The humanoid ones (Press Gang, Tide Witch, Harbourmaster, Keeper, Sovereign) show their moves with the
## body's own animations (BodyAnim), which other phones are sent like any other; the Siren and the
## Kraken's Arm are built of parts (VaelModels) and show theirs as Zombie._current_anim states.

const KINDS := ["siren", "press_gang", "tide_witch", "harbourmaster", "lighthouse_keeper", "kraken_arm", "hollow_sovereign", "leviathan", "kraken"]

# The Siren
const SONG_EVERY := 9.0
const SONG_TELL := 0.8 # she draws breath, head back
const SONG_TIME := 3.5
const SONG_REACH := 16.0
const SONG_PULL := 2.6 # metres a second toward her
const SONG_CLOSE := 2.0 # no nearer than this
const SONG_BREAK := 0.2 # of her health, struck off while she sings
const SIREN_RANGE := Vector2(6.0, 12.0) # the distance she likes to keep while she is not singing
# The Press Gang
const NET_EVERY := 9.0
const NET_TELL := 0.9 # from the wind-up to the net landing
const NET_RADIUS := 1.8
const NET_HOLD := 1.6
const NET_POWER := 0.5 # of its blow
const NET_RANGE := Vector2(4.0, 13.0)
# Something thrown (a net, a hook, a lamp) is in the air for this long at the end of its ring's tell.
const THROW_FLIGHT := 0.55
# The Tide Witch
const WAVES := 3
const WAVE_RADIUS := 2.2
const WAVE_TELL := 1.0
const WAVE_STEP := 0.25 # each wave a little after the one before it
const WAVE_EVERY := 7.0
const WAVE_POWER := 1.2
const WAVE_SLOW := 2.0
const WAVE_KNOCK := 7.0
const WAVE_RANGE := Vector2(6.0, 24.0)
const WITCH_RANGE := Vector2(9.0, 16.0)
const RAISE_EVERY := 18.0
const RAISE_COUNT := 2
const RAISE_MAX := 4 # of her raised sailors standing at once
# The Harbourmaster
const HOOK_EVERY := 8.0
const HOOK_TELL := 1.0
const HOOK_RADIUS := 1.6
const HOOK_RANGE := Vector2(6.0, 22.0)
const HOOK_POWER := 0.8
const HOOK_STUN := 0.5
const HOOK_STOP := 2.4 # how far in front of him the chain stops you
const BELL_GANG := 3
# The Mad Lighthouse Keeper
const LAMP_EVERY := 4.5
const LAMP_TELL := 1.1
const LAMP_RADIUS := 2.2
const LAMP_BURN := 3.0
const LAMP_RANGE := Vector2(5.0, 24.0)
const FLASH_EVERY := 13.0
const FLASH_TELL := 1.2
const FLASH_REACH := 14.0
const FLASH_STUN := 1.5
const FLASH_CONE := 60.0 # degrees either side of looking straight at him
# The Kraken's Arm
const ARMS := 4
const KRAKEN_EVERY := 5.0
const KRAKEN_TELL := 1.2
const KRAKEN_RADIUS := 2.4
const KRAKEN_REACH := 7.0 # as far as the arm comes down in front of it
const KRAKEN_POWER := 1.3
const KRAKEN_STUN := 0.5
const SWEEP_REACH := 3.2
const SWEEP_EVERY := 2.6
const SINK_TIME := 1.6
const RISE_TIME := 1.4
# The Hollow Sovereign
const UNDERTOW_WAVES := 4
const UNDERTOW_RADIUS := 2.6
const UNDERTOW_EVERY := 6.0
const DECREES := [0.66, 0.33] # of his health
const COURT := 4
const SURGE := 45.0 # seconds the tide stands in at his decree
const JUDGEMENT_EVERY := 11.0
const JUDGEMENT_TELL := 1.6
const JUDGEMENT_RADIUS := 3.2
const JUDGEMENT_POWER := 1.8
const JUDGEMENT_STUN := 0.6

# The Leviathan of the Mists (Last Light, at the Isle of Lamps)
const BITE_EVERY_L := 4.0
const BITE_TELL_L := 1.3
const BITE_RADIUS_L := 3.2
const BITE_REACH_L := 10.0 # as far as its neck comes down
const BITE_POWER_L := 1.5
const TIDAL_EVERY := 10.0
const TIDAL_WAVES := 5
const DOUSE_EVERY := 22.0
const DIVE_EVERY := 28.0
const DIVE_RAISES := 3

# The Kraken of Vael: the end of it all
const KRAKEN_RISE := 3.2 # seconds out of the sea
const KRAKEN_ROAR := 2.0
const KRAKEN_BODY := 3.4 # metres from its middle to the edge of its mantle (KrakenModels.BODY_SCALE)
const KRAKEN_PHASES := [0.66, 0.33] # of its health: it roars and raises the drowned at each
const KRAKEN_SLAM_EVERY := [4.2, 3.6, 3.0]
const KRAKEN_SLAMS := [1, 2, 3] # arms that come down at once, in each third of its health
const KRAKEN_SLAM_TELL := 1.4
const KRAKEN_SLAM_RADIUS := 2.8
const KRAKEN_SLAM_POWER := 1.3
const KRAKEN_SLAM_REACH := 17.0 # as far as its arms come down
const KRAKEN_SWEEP_EVERY := 9.0
const KRAKEN_SWEEP_REACH := 7.5
const KRAKEN_SWEEP_TELL := 1.5
const KRAKEN_GRASP_EVERY := 14.0
const KRAKEN_GRASP_REACH := 26.0
const KRAKEN_GRASP_RADIUS := 2.2
const KRAKEN_GRASP_TELL := 1.2
const KRAKEN_INK_EVERY := 12.0
const KRAKEN_INK_RADIUS := 3.6
const KRAKEN_INK_TELL := 1.1
const KRAKEN_INK_BLIND := 3.5
const KRAKEN_INK_SLOW := 2.0
const KRAKEN_PULL := 1.6 # metres a second toward it, in its whirlpool
const KRAKEN_PULL_TIME := 6.0
const KRAKEN_PULL_REACH := 24.0
const KRAKEN_BROOD := 4 # Drowned Sailors it raises at each third
const KRAKEN_WRATH_EVERY := 11.0
const KRAKEN_WRATH_WAVES := 4
const KRAKEN_HOARD := 6 # potions and food that wash up where it sank

var _song_from := 0.0
var _dives := 0
var _cooldown_d := DIVE_EVERY
var _cooldown_e := 12.0 # her health when she began to sing
var _cooldown_c := 0.0
var _decreed := 0
var _raised: Array[Zombie] = []
var _sinking := false


static func handles(id: String) -> bool:
	return id in KINDS


func _init(id: String) -> void:
	super(id)
	_cooldown_c = randf_range(4.0, 8.0)


func tick(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	cooldown -= delta
	cooldown_b -= delta
	_cooldown_c -= delta
	match kind:
		"siren": return _siren(z, target, to, dist, delta)
		"press_gang": return _press(z, target, dist, delta)
		"tide_witch": return _witch(z, target, to, dist, delta)
		"harbourmaster": return _harbourmaster(z, target, dist, delta)
		"lighthouse_keeper": return _keeper(z, target, dist, delta)
		"kraken_arm": return _arm(z, target, dist, delta)
		"hollow_sovereign": return _sovereign(z, target, dist, delta)
		"leviathan": return _leviathan(z, target, delta)
		"kraken": return _kraken(z, target, delta)
	return false


func after(z: Zombie) -> void:
	if phase != "":
		return
	if kind in ["siren", "kraken_arm"]:
		_show(z, "m_swipe" if z._attack_left > 0.0 else "")


func on_death(z: Zombie) -> void:
	if kind == "kraken":
		# It sinks; the harbour lets go of the tide; what it hoarded under the sea washes up.
		var w := z.world
		if w.tide:
			w.tide.surge(0.0)
		w.fx_water(z.position + Vector3.UP, 6.0, Color(0.72, 0.9, 0.92), true)
		for i in KRAKEN_HOARD:
			var a := TAU * i / KRAKEN_HOARD + z.rotation.y
			var at := _ground(z, z.position + Vector3(sin(a), 0, cos(a)) * (KRAKEN_BODY + 1.5))
			if i % 2 == 0:
				w.spawn_pickup_at(at, Pickup.Kind.POWER, PowerDefs.pick_potion(w.spawn_map()))
			else:
				w.spawn_pickup_at(at, Pickup.Kind.FOOD, PowerDefs.pick_weighted(PowerDefs.FOODS))
		return
	if kind == "hollow_sovereign":
		# The Sunken Crown rolls from his empty hood, for whoever dares to wear it.
		z.world.spawn_pickup_at(z.position + Vector3(0, 0, 1.2), Pickup.Kind.POWER, "sunken_crown")


## A stun cuts a special move short, tell and all; the Siren's song with it. A Kraken's Arm going
## back under the sea goes on going.
func interrupt(z: Zombie) -> void:
	if phase == "" or phase == "sink" or phase == "rise":
		return
	if kind == "siren" and phase == "song":
		z.world.sfx_at("siren_shriek", z.position, 0.0)
	phase = ""
	z.mesenlla_warning = false
	if z._custom:
		_show(z, "")
	else:
		z._current_anim = ""


func start(z: Zombie) -> void:
	if kind == "kraken":
		# The harbour heaves and it comes up out of it, the water pouring off its crown.
		phase = "rise"
		left = KRAKEN_RISE
		cooldown = 2.0
		cooldown_b = 7.0
		_cooldown_c = 5.0
		_cooldown_d = 5.0
		_cooldown_e = 9.0
		_show(z, "m_rise")
		z.world.sfx_at("kraken_emerge", z.position, 6.0)
		return
	if kind == "kraken_arm" or kind == "leviathan":
		# Up out of the water.
		phase = "rise"
		left = RISE_TIME
		_show(z, "m_rise")
		z.world.sfx_at("kraken_rise" if kind == "kraken_arm" else "leviathan_rise", z.position, 0.0)


## The Sirens' songs, on every phone for its own players: while one sings (her state "m_song" once her
## tell is over, which every phone is sent), each of them within SONG_REACH is drawn toward her
## (Player.lure). Run by World every frame.
static func sing(w: World) -> void:
	for z: Zombie in w.zombies:
		if z.type_id != "siren" or not z.is_alive() or z._current_anim != "m_song" or z.is_warning():
			continue
		for p: Player in w.local_players():
			if p.dead:
				continue
			var d := Vector2(p.global_position.x - z.position.x, p.global_position.z - z.position.z).length()
			if d < SONG_REACH and d > SONG_CLOSE and absf(p.global_position.y - z.position.y) < 4.0:
				p.lure(z.position, SONG_PULL)


## Whether there is a clear line from it to someone.
func _clear(z: Zombie, target: Target) -> bool:
	return z.world.has_line_of_sight(z.centre(), target.global_position + Vector3.UP)


## Where someone will be a moment from now, on the ground.
func _lead(z: Zombie, target: Target, ahead: float) -> Vector3:
	return _ground(z, target.global_position + target.velocity * ahead)


## A body with bones plays one of its animations, which other phones are sent like any other.
func _pose(z: Zombie, anim_name: String, speed := 1.0) -> void:
	z._play(anim_name, speed, 0.12)


## Keep to a band of distance from someone: back off when they come too close, close in when they are
## too far, and stand when they are within it. Bodies with bones walk or run there.
func _keep(z: Zombie, to: Vector3, dist: float, band: Vector2, delta: float, target: Target) -> void:
	var want := 0.0
	if dist < band.x:
		want = -1.0
	elif dist > band.y:
		want = 1.0
	# Cover must not make a ranged creature idle forever inside its preferred distance band.
	if not _clear(z, target) and dist > 2.4: want = 1.0
	var dir := to.normalized() * want if dist > 0.1 else Vector3.ZERO
	if want < 0.0:
		# Backing away, round whatever is behind it; cornered, it stands (_back_way).
		dir = _back_way(z, -to)
		if dir == Vector3.ZERO:
			want = 0.0
	dir.y = 0.0
	var speed := z._speed * (0.5 if z._slow > 0.0 else 1.0) * (z.world.tide.quickens(z) if z.world.tide else 1.0)
	if want < 0.0:
		speed *= 0.8 # backing away
	z.velocity = dir * speed
	if want > 0 and z.world.vael_sites and not z.world.grid.line_is_open(z.position, z.position + dir * 2.0) and z._try_vael_vault(to, dist):
		return
	var from := z.position
	z.move_and_slide()
	if want < 0.0:
		_backed(z, from, speed * delta)
	z.position.y = z.world.ground_at(z.position)
	_face(z, target.global_position, delta, 6.0)
	if not z._custom:
		if z.velocity.length_squared() < 0.04:
			_pose(z, "Idle")
		else:
			_pose(z, "Walking_A" if want < 0.0 else "Running_A", maxf(0.55, z.velocity.length() / 3.0))


# --- The Siren ---------------------------------------------------------------------------------

func _siren(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	match phase:
		"draw":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 6.0)
			if left <= 0.0:
				phase = "song"
				left = SONG_TIME
				_song_from = z.hp
				_show(z, "m_song")
			return true
		"song":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 3.0)
			if z.hp <= _song_from - z.max_hp * SONG_BREAK:
				# Hurt enough, she breaks off with a shriek.
				interrupt(z)
				cooldown = SONG_EVERY * 0.5
			elif left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	if cooldown <= 0.0 and z._sees and dist < SONG_REACH and dist > SONG_CLOSE + 1.0 and _clear(z, target):
		phase = "draw"
		left = SONG_TELL
		cooldown = SONG_EVERY
		_show(z, "m_song", true)
		z.world.sfx_at("siren_song", z.position, 2.0)
		return true
	if dist < 2.4:
		return false # close enough to claw: the ordinary walk and strike
	_keep(z, to, dist, SIREN_RANGE, delta, target)
	return true


# --- The Press Gang ----------------------------------------------------------------------------

## A wind-up with the net, then a throw; the net lands where you were about to be.
func _press(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "" and cooldown <= 0.0 and z._sees and dist > NET_RANGE.x and dist < NET_RANGE.y and _clear(z, target) and z._stun <= 0.0:
		phase = "windup"
		left = NET_TELL - THROW_FLIGHT
		cooldown = NET_EVERY
		z.mesenlla_warning = true
		_pose(z, "WindUp", 1.6)
		MistSeal.cast(z, _lead(z, target, NET_TELL), NET_RADIUS, NET_TELL, z._damage * NET_POWER, 0.0, MistSeal.Style.NET)
		z.world.sfx_at("press_shout", z.position, 0.0)
	return _throwing(z, target, delta, "net_throw")


## The wind-up and the throw, for anything thrown at the end of a ring's tell.
func _throwing(z: Zombie, target: Target, delta: float, sound: String) -> bool:
	match phase:
		"windup":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 8.0)
			if left <= 0.0:
				phase = "throw"
				left = THROW_FLIGHT
				z.mesenlla_warning = false
				_pose(z, "Throw", 1.0)
				z.world.sfx_at(sound, z.position, 0.0)
			return true
		"throw":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				phase = ""
				z._current_anim = ""
			return true
	return false


# --- The Tide Witch ----------------------------------------------------------------------------

func _witch(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	match phase:
		"cast":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 6.0)
			if left <= 0.0:
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
		"call":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
				_raise_drowned(z, target)
			return true
	_raised = _raised.filter(func(r: Zombie) -> bool: return is_instance_valid(r) and r.is_alive() and r.type_id == "drowned_sailor")
	if _cooldown_c <= 0.0 and z._sees and z.world.tide and z.world.tide.high() and _raised.size() < RAISE_MAX:
		phase = "call"
		left = 1.2
		_cooldown_c = RAISE_EVERY
		z.mesenlla_warning = true
		_pose(z, "Raise", 1.0)
		z.world.sfx_at("witch_call", z.position, 0.0)
		return true
	if cooldown <= 0.0 and z._sees and dist > WAVE_RANGE.x and dist < WAVE_RANGE.y and z._stun <= 0.0:
		phase = "cast"
		left = 0.8
		cooldown = WAVE_EVERY
		z.mesenlla_warning = true
		_pose(z, "Spellcast_Shoot", 0.7)
		_undertow(z, target, WAVES, WAVE_RADIUS, WAVE_POWER)
		z.world.sfx_at("witch_call", z.position, -2.0)
		return true
	if dist < 2.2:
		return false
	_keep(z, to, dist, WITCH_RANGE, delta, target)
	return true


## A line of waves rolling from the caster toward someone, the last where they will be.
func _undertow(z: Zombie, target: Target, count: int, radius: float, power: float) -> void:
	var at := _lead(z, target, WAVE_TELL)
	var along := at - z.position
	along.y = 0.0
	along = along.normalized() if along.length() > 0.1 else Vector3.FORWARD
	for i in count:
		var spot := at - along * (count - 1 - i) * radius * 1.7
		MistSeal.cast(z, _ground(z, spot), radius, WAVE_TELL + i * WAVE_STEP, z._damage * power, 0.0, MistSeal.Style.WAVE)


## Drowned Sailors, up out of the water near whoever she hunts.
func _raise_drowned(z: Zombie, target: Target) -> void:
	var w := z.world
	for i in RAISE_COUNT:
		var at := w.spawn_point_near(target.global_position, 5.0, 11.0, func(p: Vector3) -> bool: return w.tide != null and w.tide.flooded(p))
		if at == Vector3.INF:
			at = w.spawn_point_near(target.global_position, 6.0, 12.0)
		if at == Vector3.INF:
			continue
		if w.spawn_zombie("drowned_sailor", at):
			_raised.append(w.zombies.back())
			w.fx_water(at, 1.4, Color(0.72, 0.9, 0.92), true)


# --- The Harbourmaster -------------------------------------------------------------------------

func _harbourmaster(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "bell":
		left -= delta
		z.velocity = Vector3.ZERO
		if left <= 0.0:
			phase = ""
			z.mesenlla_warning = false
			z._current_anim = ""
			_call_gang(z, target)
		return true
	if phase == "" and not called and z.hp <= z.max_hp * 0.5:
		called = true
		phase = "bell"
		left = 1.2
		z.mesenlla_warning = true
		_pose(z, "Raise", 1.0)
		z.world.sfx_at("harbour_bell", z.position, 4.0)
		z.world.director.show_banner("The Harbourmaster rings his bell", 3.0)
		return true
	if phase == "" and cooldown <= 0.0 and z._sees and dist > HOOK_RANGE.x and dist < HOOK_RANGE.y and _clear(z, target) and z._stun <= 0.0:
		phase = "windup"
		left = HOOK_TELL - THROW_FLIGHT
		cooldown = HOOK_EVERY
		z.mesenlla_warning = true
		_pose(z, "WindUp", 1.4)
		MistSeal.cast(z, _lead(z, target, HOOK_TELL * 0.5), HOOK_RADIUS, HOOK_TELL, z._damage * HOOK_POWER, 0.0, MistSeal.Style.HOOK)
		z.world.sfx_at("chain_rattle", z.position, 0.0)
	return _throwing(z, target, delta, "hook_throw")


## A Press Gang, come up out of the water at his bell.
func _call_gang(z: Zombie, target: Target) -> void:
	var w := z.world
	var at := w.spawn_point_near(z.position, 7.0, 14.0)
	if at == Vector3.INF:
		return
	for i in BELL_GANG:
		var spot := at + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		if w.spawn_zombie("press_gang", spot):
			w.fx_water(spot, 1.2, Color(0.72, 0.9, 0.92), true)
	if target:
		w.make_noise(target.global_position, 30.0)


# --- The Mad Lighthouse Keeper -----------------------------------------------------------------

func _keeper(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	if phase == "lift":
		left -= delta
		z.velocity = Vector3.ZERO
		_face(z, target.global_position, delta, 4.0)
		if left <= 0.0:
			phase = ""
			z.mesenlla_warning = false
			z._current_anim = ""
		return true
	if phase == "" and _cooldown_c <= 0.0 and z._sees and dist < FLASH_REACH - 2.0 and z._stun <= 0.0:
		# Up goes the great lamp, brighter and brighter, and then it blazes.
		phase = "lift"
		left = FLASH_TELL + 0.2
		_cooldown_c = FLASH_EVERY
		z.mesenlla_warning = true
		_pose(z, "Raise", 1.2 / (FLASH_TELL + 0.2))
		MistSeal.cast(z, _ground(z, z.position), FLASH_REACH, FLASH_TELL, 0.0, 0.0, MistSeal.Style.FLASH)
		z.world.sfx_at("keeper_laugh", z.position, 2.0)
		return true
	if phase == "" and cooldown <= 0.0 and z._sees and dist > LAMP_RANGE.x and dist < LAMP_RANGE.y and z._stun <= 0.0:
		phase = "windup"
		left = LAMP_TELL - THROW_FLIGHT
		cooldown = LAMP_EVERY
		z.mesenlla_warning = true
		_pose(z, "WindUp", 1.4)
		MistSeal.cast(z, _lead(z, target, LAMP_TELL * 0.6), LAMP_RADIUS, LAMP_TELL, z._damage, 0.0, MistSeal.Style.LAMP)
		if z.hp <= z.max_hp * 0.5:
			var other := _second_target(z, target)
			var spot := other.global_position if other else target.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			MistSeal.cast(z, _ground(z, spot), LAMP_RADIUS, LAMP_TELL + 0.2, z._damage, 0.0, MistSeal.Style.LAMP)
	return _throwing(z, target, delta, "lamp_throw")


# --- The Kraken's Arm --------------------------------------------------------------------------

func _arm(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	z.velocity = Vector3.ZERO
	match phase:
		"rise":
			left -= delta
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
		"sink":
			left -= delta
			if left <= 0.0:
				z.release() # back under the sea: it is gone, and nobody killed it
			return true
		"rear":
			left -= delta
			_face(z, target.global_position, delta, 3.0)
			if left <= 0.0:
				phase = "slam"
				left = 0.5
				_show(z, "m_slam")
				z.world.sfx_at("kraken_slam", z.position, 2.0)
			return true
		"slam", "sweep":
			left -= delta
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	# The tide has gone out: back under the sea.
	if z.world.tide and not z.world.tide.high() and not z.world.tide.always_high:
		phase = "sink"
		left = SINK_TIME
		_show(z, "m_sink")
		z.world.sfx_at("kraken_rise", z.position, -2.0)
		return true
	_face(z, target.global_position, delta, 1.5)
	if cooldown_b <= 0.0 and z._sees and dist < SWEEP_REACH and absf(target.global_position.y - z.position.y) < 3.0:
		# Close by, a sweep that throws you away.
		phase = "sweep"
		left = 0.6
		cooldown_b = SWEEP_EVERY
		_show(z, "m_swipe")
		target.hurt(z._damage, z.position, z)
		z.world.sfx_at("kraken_slam", z.position, -4.0)
	elif cooldown <= 0.0 and z._sees and dist < KRAKEN_REACH:
		phase = "rear"
		left = KRAKEN_TELL - 0.25
		cooldown = KRAKEN_EVERY
		_show(z, "m_slam", true)
		MistSeal.cast(z, _lead(z, target, KRAKEN_TELL * 0.4), KRAKEN_RADIUS, KRAKEN_TELL, z._damage * KRAKEN_POWER, 0.0, MistSeal.Style.SLAM)
	return true


# --- The Hollow Sovereign ----------------------------------------------------------------------

func _sovereign(z: Zombie, target: Target, dist: float, delta: float) -> bool:
	match phase:
		"decree":
			left -= delta
			z.velocity = Vector3.ZERO
			if left <= 0.0:
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
				_decree(z)
			return true
		"wave", "judge":
			left -= delta
			z.velocity = Vector3.ZERO
			_face(z, target.global_position, delta, 4.0)
			if left <= 0.0:
				phase = ""
				z.mesenlla_warning = false
				z._current_anim = ""
			return true
	if _decreed < DECREES.size() and z.hp <= z.max_hp * float(DECREES[_decreed]):
		_decreed += 1
		phase = "decree"
		left = 1.2
		z.mesenlla_warning = true
		_pose(z, "Raise", 1.0)
		z.world.sfx_at("sovereign_decree", z.position, 4.0)
		return true
	if z.hp <= z.max_hp * 0.5 and _cooldown_c <= 0.0 and z._sees:
		# The crown's judgement, on whichever of you is furthest from him.
		phase = "judge"
		left = 0.9
		_cooldown_c = JUDGEMENT_EVERY
		z.mesenlla_warning = true
		_pose(z, "Thrust", 0.8)
		var judged := _furthest(z, target)
		MistSeal.cast(z, _ground(z, judged.global_position), JUDGEMENT_RADIUS, JUDGEMENT_TELL, z._damage * JUDGEMENT_POWER, 0.0, MistSeal.Style.CROWN)
		z.world.sfx_at("crown_toll", z.position, 2.0)
		return true
	if cooldown <= 0.0 and z._sees and dist > 6.0 and dist < 30.0 and z._stun <= 0.0:
		phase = "wave"
		left = 0.8
		cooldown = UNDERTOW_EVERY
		z.mesenlla_warning = true
		_pose(z, "Thrust", 0.9)
		_undertow(z, target, UNDERTOW_WAVES, UNDERTOW_RADIUS, WAVE_POWER)
		z.world.sfx_at("witch_call", z.position, 2.0)
		return true
	return false


## The tide comes in at his word, and his court rises round him out of it.
func _decree(z: Zombie) -> void:
	var w := z.world
	if w.tide:
		w.tide.surge(SURGE)
	w.director.show_banner("The Hollow Sovereign calls in the tide: “Rise, my court!”", 3.5)
	for i in COURT:
		var a := TAU * i / float(COURT) + z.rotation.y
		var at := _ground(z, z.position + Vector3(cos(a), 0, sin(a)) * 4.0)
		if w.terrain.is_walkable(at.x, at.z) and w.spawn_zombie("drowned_sailor", at):
			w.fx_water(at, 1.4, Color(0.72, 0.9, 0.92), true)


## Whoever is furthest from him that he can see (else whoever he hunts).
func _furthest(z: Zombie, fallback: Target) -> Target:
	var best: Target = fallback
	var far := -1.0
	for t in z.world.players:
		if t.dead or t.is_unseen():
			continue
		var d := t.global_position.distance_to(z.position)
		if d > far and d < 40.0:
			far = d
			best = t
	return best


# --- The Leviathan of the Mists ----------------------------------------------------------------

## Rooted in the sea off the Isle of Lamps. Strikes down with its head where you stand, sends waves
## across the isle, spits the sea over the Lantern Barge to put its light down, and now and then sinks
## and comes up somewhere else round the isle with Drowned Sailors.
func _leviathan(z: Zombie, target: Target, delta: float) -> bool:
	z.velocity = Vector3.ZERO
	_cooldown_d -= delta
	_cooldown_e -= delta
	var dist := Vector2(target.global_position.x - z.position.x, target.global_position.z - z.position.z).length()
	match phase:
		"rise":
			left -= delta
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
		"sink":
			left -= delta
			if left <= 0.0:
				# Up again somewhere else round the isle, with Drowned Sailors.
				_dives += 1
				var ll := z.world.last_light
				var at := ll.leviathan_spot(_dives) if ll else z.position
				z.position = at
				z.world.fx_water(at, 4.0, Color(0.72, 0.9, 0.92), true)
				for i in DIVE_RAISES:
					var spot := z.world.spawn_point_near(target.global_position, 5.0, 11.0)
					if spot != Vector3.INF and z.world.spawn_zombie("drowned_sailor", spot):
						z.world.fx_water(spot, 1.4, Color(0.72, 0.9, 0.92), true)
				phase = "rise"
				left = RISE_TIME
				_show(z, "m_rise")
				z.world.sfx_at("leviathan_rise", z.position, 2.0)
			return true
		"rear":
			left -= delta
			_face(z, target.global_position, delta, 2.5)
			if left <= 0.0:
				phase = "strike"
				left = 0.7
				_show(z, "m_bite")
				z.world.sfx_at("leviathan_bite", z.position, 3.0)
			return true
		"strike", "spit", "call":
			left -= delta
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	_face(z, target.global_position, delta, 1.2)
	if _cooldown_d <= 0.0:
		_cooldown_d = DIVE_EVERY
		phase = "sink"
		left = SINK_TIME
		_show(z, "m_sink")
		z.world.sfx_at("leviathan_roar", z.position, 2.0)
	elif _cooldown_e <= 0.0 and z.world.last_light:
		# It spits the sea over the barge: the light shrinks for a while.
		_cooldown_e = DOUSE_EVERY
		phase = "spit"
		left = 1.2
		_show(z, "m_breath")
		z.world.last_light.douse()
		z.world.fx_water(z.world.last_light.barge_at(), 3.0, Color(0.72, 0.9, 0.92), true)
		z.world.sfx_at("leviathan_roar", z.position, 3.0)
		z.world.director.show_banner("The Leviathan drowns the barge's light!", 3.0)
	elif cooldown_b <= 0.0 and z._sees:
		cooldown_b = TIDAL_EVERY
		phase = "call"
		left = 1.0
		_show(z, "m_breath")
		_undertow(z, target, TIDAL_WAVES, WAVE_RADIUS + 0.4, 1.0)
		z.world.sfx_at("wave_rise", z.position, 4.0)
	elif cooldown <= 0.0 and z._sees and dist < BITE_REACH_L:
		cooldown = BITE_EVERY_L
		phase = "rear"
		left = BITE_TELL_L - 0.3
		_show(z, "m_slam", true)
		MistSeal.cast(z, _lead(z, target, BITE_TELL_L * 0.4), BITE_RADIUS_L, BITE_TELL_L, z._damage * BITE_POWER_L, 0.0, MistSeal.Style.SLAM)
		z.world.sfx_at("leviathan_roar", z.position, 0.0)
	return true


# --- The Kraken of Vael --------------------------------------------------------------------------

## Rooted in the harbour, the last of Vael. Eight arms each strike where it means them to: an arm rears
## over the water above each ring and whips down on it. Whoever comes close is thrown back by its
## sweep; from the start it hooks whoever stands furthest off and drags them in. Each third of its
## health it roars, holds the tide in, draws everyone near toward it in a whirlpool and raises the
## drowned round it; below two thirds it spits ink that blinds; in its last third its arms come down
## three at a time and the sea rolls out from it in waves.
func _kraken(z: Zombie, target: Target, delta: float) -> bool:
	z.velocity = Vector3.ZERO
	_cooldown_d -= delta
	_cooldown_e -= delta
	var dist := Vector2(target.global_position.x - z.position.x, target.global_position.z - z.position.z).length()
	match phase:
		"rise":
			left -= delta
			if left <= 0.0:
				phase = "roar"
				left = KRAKEN_ROAR
				_show(z, "m_roar")
				z.world.sfx_at("kraken_roar", z.position, 6.0)
			return true
		"roar", "slam", "sweep", "ink", "grasp", "wrath":
			left -= delta
			_face(z, target.global_position, delta, 0.8)
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
		"pull":
			left -= delta
			if left <= 0.0:
				phase = ""
				_show(z, "")
			return true
	var stage := kraken_stage(z)
	if stage > _decreed:
		# A third of it gone: it roars, the tide stands in, the sea turns round it, the drowned rise.
		_decreed = stage
		phase = "pull"
		left = KRAKEN_PULL_TIME
		_show(z, "m_pull")
		z.world.sfx_at("kraken_roar", z.position, 6.0)
		z.world.sfx_at("kraken_whirlpool", z.position, 4.0)
		z.world.director.show_banner("The Kraken drags the sea round itself!" if stage == 1 else "The Kraken rages: the whole harbour churns!", 3.5)
		for i in KRAKEN_BROOD:
			var a := TAU * i / float(KRAKEN_BROOD) + z.rotation.y + 0.4
			var at := _ground(z, z.position + Vector3(cos(a), 0, sin(a)) * 9.0)
			if z.world.terrain.is_walkable(at.x, at.z) and z.world.spawn_zombie("drowned_sailor", at):
				z.world.fx_water(at, 1.4, Color(0.72, 0.9, 0.92), true)
		return true
	_face(z, target.global_position, delta, 0.6)
	if not z._sees:
		return true
	var near := _players_within(z, KRAKEN_SWEEP_REACH)
	if _cooldown_d <= 0.0 and near > 0:
		# Too close: every arm sweeps round low and throws you back into the sea.
		_cooldown_d = KRAKEN_SWEEP_EVERY
		phase = "sweep"
		left = KRAKEN_SWEEP_TELL + 0.6
		_show(z, "m_sweep", true)
		MistSeal.cast(z, _ground(z, z.position), KRAKEN_SWEEP_REACH, KRAKEN_SWEEP_TELL, z._damage, KRAKEN_BODY, MistSeal.Style.WAVE)
		z.world.sfx_at("kraken_roar", z.position, 0.0)
		return true
	if stage >= 2 and _cooldown_c <= 0.0:
		# The sea rolls out from it in waves, a line toward each of you.
		_cooldown_c = KRAKEN_WRATH_EVERY
		phase = "wrath"
		left = 1.2
		_show(z, "m_roar", true)
		for t: Target in z.world.players:
			if t.dead or t.is_unseen() or t.global_position.distance_to(z.position) > KRAKEN_GRASP_REACH:
				continue
			var along := (t.global_position - z.position) * Vector3(1, 0, 1)
			along = along.normalized() if along.length() > 0.1 else Vector3.FORWARD
			for i in KRAKEN_WRATH_WAVES:
				var spot := z.position + along * (KRAKEN_BODY + 2.5 + i * WAVE_RADIUS * 1.7)
				MistSeal.cast(z, _ground(z, spot), WAVE_RADIUS, WAVE_TELL + i * WAVE_STEP, z._damage, 0.0, MistSeal.Style.WAVE)
		z.world.sfx_at("wave_rise", z.position, 4.0)
		return true
	if _cooldown_e <= 0.0:
		var far := _furthest(z, target)
		var gap := far.global_position.distance_to(z.position)
		if gap > KRAKEN_SWEEP_REACH + 2.0 and gap < KRAKEN_GRASP_REACH:
			# An arm reaches out flat for whoever stands furthest off, and drags them in.
			_cooldown_e = KRAKEN_GRASP_EVERY
			phase = "grasp"
			left = KRAKEN_GRASP_TELL + 0.4
			_show(z, "m_grab", true)
			MistSeal.cast(z, _lead(z, far, KRAKEN_GRASP_TELL * 0.3), KRAKEN_GRASP_RADIUS, KRAKEN_GRASP_TELL, z._damage * 0.6, 0.0, MistSeal.Style.HOOK)
			z.world.sfx_at("kraken_rise", z.position, 2.0)
			return true
	if stage >= 1 and cooldown_b <= 0.0 and dist < KRAKEN_GRASP_REACH:
		# A cloud of ink, spat over whoever it hunts.
		cooldown_b = KRAKEN_INK_EVERY
		phase = "ink"
		left = KRAKEN_INK_TELL + 0.3
		_show(z, "m_ink", true)
		MistSeal.cast(z, _lead(z, target, KRAKEN_INK_TELL * 0.4), KRAKEN_INK_RADIUS, KRAKEN_INK_TELL, z._damage * 0.4, 0.0, MistSeal.Style.INK)
		z.world.sfx_at("kraken_ink", z.position, 2.0)
		return true
	if cooldown <= 0.0 and dist < KRAKEN_SLAM_REACH:
		# Its arms rear up over each of you, and come down.
		cooldown = float(KRAKEN_SLAM_EVERY[stage])
		phase = "slam"
		left = KRAKEN_SLAM_TELL + 0.5
		_show(z, "m_slam", true)
		var hunted: Array[Target] = [target]
		for t: Target in z.world.players:
			if t != target and not t.dead and not t.is_unseen() and t.global_position.distance_to(z.position) < KRAKEN_SLAM_REACH:
				hunted.append(t)
		for i in int(KRAKEN_SLAMS[stage]):
			var who: Target = hunted[i % hunted.size()]
			var spot := _lead(z, who, KRAKEN_SLAM_TELL * 0.4)
			if i >= hunted.size():
				# More arms than people: the next lands just ahead of where they are going.
				var aside := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * KRAKEN_SLAM_RADIUS * 1.6
				spot = _ground(z, spot + aside)
			MistSeal.cast(z, spot, KRAKEN_SLAM_RADIUS, KRAKEN_SLAM_TELL + i * 0.25, z._damage * KRAKEN_SLAM_POWER, 0.0, MistSeal.Style.SLAM)
		z.world.sfx_at("kraken_rise", z.position, 0.0)
		return true
	return true


## 0 above two thirds of its health, 1 to one third, 2 below.
static func kraken_stage(z: Zombie) -> int:
	var f := z.hp / maxf(z.max_hp, 1.0)
	return 2 if f <= float(KRAKEN_PHASES[1]) else 1 if f <= float(KRAKEN_PHASES[0]) else 0


func _players_within(z: Zombie, reach: float) -> int:
	var n := 0
	for t: Target in z.world.players:
		if not t.dead and Vector2(t.global_position.x - z.position.x, t.global_position.z - z.position.z).length() < reach + 0.5:
			n += 1
	return n


## The whirlpool round the Kraken, on every phone for its own players: while it turns (its state
## "m_pull", which every phone is sent), each of them within reach is drawn toward it. Run by World
## every frame, with the Sirens' songs.
static func whirl(w: World) -> void:
	for z: Zombie in w.zombies:
		if z.type_id != "kraken" or not z.is_alive() or z._current_anim != "m_pull":
			continue
		for p: Player in w.local_players():
			if p.dead:
				continue
			var d := Vector2(p.global_position.x - z.position.x, p.global_position.z - z.position.z).length()
			if d < KRAKEN_PULL_REACH and d > KRAKEN_BODY + 1.5:
				p.lure(z.position, KRAKEN_PULL, "The whirlpool drags you in...")
