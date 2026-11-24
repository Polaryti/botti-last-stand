class_name LastLight
extends Node3D
## Last Light: the Lantern Road (Survive the Night's map at the end of the Mists' sea road, alone or
## together). The Mist Tide never goes out here, and it drowns whoever strays from the light of the
## Lantern Barge. The barge goes up its channel beside the road toward the Isle of Lamps, but only
## while one of you walks with it (within NEAR) and nothing of the sea clings to it. It lights the
## road's old lanterns as it passes. At each of the three waystations it stops, everyone is healed a
## little and each chooses one of three boons (Boons). At the Isle of Lamps the Leviathan of the Mists
## rises; when it falls the lighthouse is lit again, and that is the dawn.
##
## The host (or a phone alone) moves the barge and decides when it stops and goes; every phone is sent
## where it is (Net.last_light) and moves its own copy between, lights its own lanterns and drowns its
## own players. A boon is chosen on each phone for its own player; the host is told who has chosen.

const BARGE_SPEED := 1.7 # metres a second
const NEAR := 13.0 # how close to the barge's middle one of you must be for it to go on
const LIGHT_RADIUS := 15.0
const DIM_RADIUS := 10.0 # while the Leviathan has doused it
const DIM_TIME := 8.0
const OUT_GRACE := 3.0 # seconds outside the light before the tide starts to drown you
const DROWN := 6.0 # health a second, outside the light, after that
const CLING := Vector2(3.6, 6.6) # half the barge's breadth and length, and a little more: anything of the sea in it holds the barge
const WAY_WAIT := 25.0 # the longest the barge waits at a waystation for everyone to choose
const WAY_HEAL := 0.4 # of everyone's health, at each waystation
const BOARD_EVERY := 30.0 # Drowned Sailors climbing out of the water to hold the barge back
const BOARDERS := 2
const SEND_EVERY := 0.25
const ISLE_RING := 18.0 # how far out from the lighthouse the Leviathan rises: in the sea off the isle
const DECK_Y := 0.42 # the deck's top above the water
const LEVIATHAN := "leviathan"
const BEAM_TURN := 0.9 # how fast the lit lighthouse's beam goes round, in radians a second
## What comes at each waystation, as you leave it (VaelMind and the court of Port Vael).
const WAY_FOES := [["press_gang", 3], ["harbourmaster", 1], ["lighthouse_keeper", 1]]

var world: World
var path := Curve3D.new()
var length := 1.0
var progress := 0.0
var moving := false
var docked := -1 # the waystation the barge waits at, or -1
var ways_done := 0
var arrived := false # at the Isle of Lamps: the Leviathan has risen
var lit := false # and has fallen: the lighthouse burns again
var dim_left := 0.0
var way_at: Array[float] = [] # how far along the barge's course each waystation is
var held := false # something of the sea clings to the barge
var chosen := {} # host: who has chosen at this waystation (peer id, or a bot's)
var offer: Array[String] = [] # this phone's player: the boons it may choose from now, or none
var barge: AnimatableBody3D
var _lamp: OmniLight3D
var _ring: MeshInstance3D
var _lanterns: Array[Dictionary] = []
var _out := {}
var _dock_left := 0.0
var _board_at := BOARD_EVERY
var _send := 0.0
var _goal := 0.0 # a phone following the host: where it says the barge is
var _offered_at := -1
var _beam: Node3D # the lighthouse's turning beam, once it is lit
static var _barge_mesh: Mesh


func _init(owner_world: World) -> void:
	world = owner_world
	name = "LastLight"


func _ready() -> void:
	_lay_course()
	_build_barge()
	_build_lanterns()
	_place(0.0)
	if world.director:
		world.director.local_banner("Keep to the Lantern Barge's light, and walk with it to the Isle of Lamps", 5.0)


## The barge's course from the map's "barge" marks, in order, and where along it each waystation is.
func _lay_course() -> void:
	var marks := world.lane_marks.filter(func(m: Dictionary) -> bool: return m["kind"] == "barge")
	marks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["gate"]) < int(b["gate"]))
	for m: Dictionary in marks:
		var at: Vector3 = m["at"]
		path.add_point(Vector3(at.x, MistTide.HIGH_Y, at.z))
	path.bake_interval = 0.5
	length = maxf(1.0, path.get_baked_length())
	for w: Transform3D in world.waystations:
		way_at.append(path.get_closest_offset(Vector3(w.origin.x, MistTide.HIGH_Y, w.origin.z)))
	way_at.sort()


func barge_at() -> Vector3:
	return barge.global_position if barge else path.sample_baked(progress)


func light_radius() -> float:
	return DIM_RADIUS if dim_left > 0.0 else LIGHT_RADIUS


## Whether a spot is inside the barge's light.
func in_light(at: Vector3) -> bool:
	var b := barge_at()
	return Vector2(at.x - b.x, at.z - b.z).length() <= light_radius()


## How far there is still to go.
func left() -> float:
	return maxf(0.0, length - progress)


func _physics_process(delta: float) -> void:
	dim_left = maxf(0.0, dim_left - delta)
	if _beam:
		_beam.rotate_y(delta * BEAM_TURN)
	if _follows():
		# Between what the host says, the barge goes on at its own pace.
		if moving:
			progress = minf(progress + BARGE_SPEED * delta, _goal + BARGE_SPEED * 0.6)
		progress = lerpf(progress, _goal, minf(1.0, delta * 2.0)) if absf(progress - _goal) > 0.02 else progress
	else:
		_steer(delta)
	_place(delta)
	_light_lanterns()
	_drown(delta)
	_offer()


func _follows() -> bool:
	return Net.is_client() or (world.director and world.director._follows_host)


## The host decides whether the barge goes on: it waits at a waystation until everyone has chosen,
## stops while nobody walks with it or something clings to it, and at the end of the road wakes the
## Leviathan.
func _steer(delta: float) -> void:
	if world.director and world.director.sandbox:
		return
	held = _clinging()
	var near := false
	for p: Target in world.players:
		if not p.dead and Vector2(p.global_position.x - barge_at().x, p.global_position.z - barge_at().z).length() <= NEAR:
			near = true
			break
	if docked >= 0:
		_dock_left -= delta
		if _dock_left <= 0.0 or _all_chosen():
			_leave(docked)
	elif not arrived:
		moving = near and not held
		if moving:
			progress = minf(length, progress + BARGE_SPEED * delta)
			_board_at -= delta
			if _board_at <= 0.0:
				_board_at = BOARD_EVERY
				_send_boarders()
		if ways_done < way_at.size() and progress >= way_at[ways_done]:
			_dock(ways_done)
		elif progress >= length:
			_arrive()
	else:
		moving = false
		if not lit and world.director and world.director._mist_boss_defeated:
			_light_up()
	_send -= delta
	if _send <= 0.0 and Net.is_host():
		_send = SEND_EVERY
		Net.last_light(progress, state_bits(), dim_left)


## moving 1, held 2, arrived 4, lit 8; the waystation docked at, plus one, in the bits above those.
func state_bits() -> int:
	return (1 if moving else 0) | (2 if held else 0) | (4 if arrived else 0) | (8 if lit else 0) | ((docked + 1) << 4)


## What the host says (a phone following it).
func follow(at: float, bits: int, dim: float) -> void:
	_goal = clampf(at, 0.0, length)
	if absf(_goal - progress) > 12.0:
		progress = _goal # too far behind (or just joined): jump there
	moving = bits & 1 != 0
	held = bits & 2 != 0
	dim_left = dim
	var was_docked := docked
	docked = (bits >> 4) - 1
	if docked >= 0 and was_docked != docked:
		_docked_here(docked)
	if bits & 4 != 0 and not arrived:
		arrived = true
		Sfx.play("leviathan_rise", 0.0)
	if bits & 8 != 0 and not lit:
		_light_up()


## Anything of the sea in the barge or clinging to its sides.
func _clinging() -> bool:
	var inv := barge.global_transform.affine_inverse()
	for z: Zombie in world.zombies:
		if not z.is_alive() or z.is_boss():
			continue
		var at := inv * z.position
		if absf(at.x) <= CLING.x and absf(at.z) <= CLING.y:
			return true
	return false


## Drowned Sailors out of the water at its sides, to cling to it.
func _send_boarders() -> void:
	var b := barge_at()
	var side := barge.global_basis.x
	for i in BOARDERS:
		var at := b + side * (3.4 if i % 2 == 0 else -3.4) + barge.global_basis.z * randf_range(-3.0, 3.0)
		at.y = world.ground_at(at)
		if world.terrain.is_walkable(at.x, at.z) and world.spawn_zombie("drowned_sailor", at):
			world.fx_water(at, 1.2, Color(0.72, 0.9, 0.92), true)


# --- The waystations ----------------------------------------------------------------------------

func _dock(i: int) -> void:
	docked = i
	ways_done = i + 1
	moving = false
	chosen.clear()
	_dock_left = WAY_WAIT
	# Bots choose there and then.
	for p: Player in world.local_players():
		if p.bot_peer != 0:
			Boons.grant(p, Boons.offer_for(p, i).pick_random())
			chosen[world.peer_of(p)] = true
	_docked_here(i)


## On every phone: the waystation's brazier is lit, everyone here is healed a little, and this
## phone's player is offered its three boons.
func _docked_here(i: int) -> void:
	for p: Player in world.local_players():
		if not p.dead:
			p.hp = minf(p.max_hp(), p.hp + p.max_hp() * WAY_HEAL)
	if i < world.waystations.size():
		var w: Transform3D = world.waystations[i]
		_glow_at(w * Vector3(0, 2.75, 0), 3.0, 9.0)
	Sfx.play("waystation", 0.0)
	if world.director:
		world.director.local_banner("Waystation %d of %d: choose a boon" % [i + 1, world.waystations.size()], 4.0)


func _offer() -> void:
	if docked < 0 or _offered_at == docked or world.player == null or world.player.dead:
		if docked < 0:
			offer.clear()
		return
	_offered_at = docked
	offer = Boons.offer_for(world.player, docked)


## This phone's player chooses (from the HUD's cards).
func choose(id: String) -> void:
	if offer.is_empty() or not offer.has(id) or world.player == null:
		return
	Boons.grant(world.player, id)
	offer.clear()
	if Net.is_client():
		Net.boon_chosen()
	else:
		chosen[world.peer_of(world.player)] = true


## The host: someone on another phone has chosen.
func peer_chose(peer: int) -> void:
	chosen[peer] = true


func _all_chosen() -> bool:
	for p: Target in world.players:
		if not p.dead and not chosen.has(world.peer_of(p)):
			return false
	return true


func _leave(i: int) -> void:
	docked = -1
	offer.clear()
	if i < WAY_FOES.size():
		# Something has been waiting for the barge to come out again.
		var id: String = WAY_FOES[i][0]
		var at := world.spawn_point_near(barge_at() + barge.global_basis.z * -24.0, 4.0, 12.0)
		if at != Vector3.INF:
			for n in int(WAY_FOES[i][1]):
				var spot := at + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
				if world.spawn_zombie(id, spot):
					world.fx_water(spot, 1.6, Color(0.72, 0.9, 0.92), true)
			if world.director:
				world.director.show_banner({"press_gang": "A Press Gang waits on the road ahead", "harbourmaster": "The Harbourmaster bars the road: “Papers!”",
					"lighthouse_keeper": "The Lighthouse Keeper has come to meet you"}.get(id, ""), 3.5)


# --- The Isle of Lamps --------------------------------------------------------------------------

func _arrive() -> void:
	arrived = true
	moving = false
	var spot := leviathan_spot(0)
	if world.spawn_zombie(LEVIATHAN, spot):
		world.fx_water(spot, 4.0, Color(0.72, 0.9, 0.92), true)
	if world.director:
		world.director._mist_boss_spawned = true
		world.director.show_banner("The barge has reached the Isle of Lamps. Something vast rises from the deep...", 4.5)
	Sfx.play("leviathan_rise", 0.0)
	if Net.is_host():
		Net.sound_all("leviathan_rise", 0.0, 1.0)


## Where the Leviathan comes up out of the sea round the Isle of Lamps (its n-th time).
func leviathan_spot(n: int) -> Vector3:
	var centre := world.lighthouse_top if world.lighthouse_top != Vector3.INF else path.sample_baked(length)
	# First off the isle's south-west, in sight of the barge at the end of the road; then round the isle.
	var a := 2.4 + (n % 4) * 1.3
	var at := Vector3(centre.x + cos(a) * ISLE_RING, 0, centre.z + sin(a) * ISLE_RING)
	at.z = maxf(at.z, -world.play_half + 3.0)
	at.y = world.ground_at(at)
	return at


## The Leviathan has fallen: the lighthouse is lit, and that is the dawn (Director).
func _light_up() -> void:
	lit = true
	if world.lighthouse_top != Vector3.INF:
		_glow_at(world.lighthouse_top, 7.0, 60.0)
		_build_beam(world.lighthouse_top)
	Sfx.play("lighthouse_lit", 0.0)
	if world.director:
		world.director.local_banner("The lighthouse burns again!", 5.0)


## The Leviathan spits the sea over the barge: its light gutters for a while.
func douse() -> void:
	dim_left = DIM_TIME
	if Net.is_host():
		Net.last_light(progress, state_bits(), dim_left)


# --- The light, and the tide outside it ---------------------------------------------------------

## Each of this phone's players outside the light: a few seconds' grace, then the tide drowns them.
func _drown(delta: float) -> void:
	if lit:
		return
	for p: Player in world.local_players():
		if p.dead:
			_out.erase(p)
			continue
		var reach := light_radius() + Boons.light_bonus(p)
		var b := barge_at()
		if Vector2(p.global_position.x - b.x, p.global_position.z - b.z).length() <= reach:
			_out.erase(p)
			continue
		_out[p] = float(_out.get(p, 0.0)) + delta
		if float(_out[p]) > Boons.grace(p):
			p.drown(DROWN * Boons.drown_share(p) * delta)


## How long this phone's player has been outside the light (0 inside).
func out_for(p: Player) -> float:
	return float(_out.get(p, 0.0))


func _place(delta: float) -> void:
	if barge == null:
		return
	var at := path.sample_baked(progress, true)
	var ahead := path.sample_baked(minf(length, progress + 2.0), true)
	if ahead.distance_to(at) < 0.1:
		ahead = at + (at - path.sample_baked(maxf(0.0, progress - 2.0), true))
	var bob := sin(Time.get_ticks_msec() * 0.0012) * 0.04
	var t := Transform3D(Basis.looking_at(Vector3(ahead.x - at.x, 0, ahead.z - at.z).normalized(), Vector3.UP), Vector3(at.x, MistTide.HIGH_Y + bob, at.z))
	barge.global_transform = barge.global_transform.interpolate_with(t, minf(1.0, delta * 6.0)) if delta > 0.0 else t
	var want := 2.8 if dim_left <= 0.0 else 1.0
	_lamp.light_energy = move_toward(_lamp.light_energy, want + sin(Time.get_ticks_msec() * 0.007) * 0.15, delta * 4.0)
	_lamp.omni_range = light_radius() + 6.0
	_ring.scale = Vector3.ONE * (light_radius() / LIGHT_RADIUS)


## Each road lantern is lit as the barge comes level with it.
func _light_lanterns() -> void:
	for l: Dictionary in _lanterns:
		if not l["lit"] and progress >= float(l["along"]):
			l["lit"] = true
			(l["glow"] as MeshInstance3D).visible = true


# --- How it looks -------------------------------------------------------------------------------

func _build_barge() -> void:
	barge = AnimatableBody3D.new()
	barge.name = "LanternBarge"
	barge.sync_to_physics = false
	barge.collision_layer = 1
	barge.collision_mask = 0
	var deck := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.2, 0.5, 10.0)
	deck.shape = box
	deck.position = Vector3(0, DECK_Y - 0.25, 0)
	barge.add_child(deck)
	var hull := MeshInstance3D.new()
	hull.mesh = barge_mesh()
	barge.add_child(hull)
	var glass := MeshInstance3D.new()
	glass.mesh = _lantern_glass()
	glass.material_override = MesenllaModels.glow_material()
	barge.add_child(glass)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.8, 0.45)
	_lamp.light_energy = 2.8
	_lamp.omni_range = LIGHT_RADIUS + 6.0
	_lamp.omni_attenuation = 0.9
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0, 4.3, 1.6)
	barge.add_child(_lamp)
	# The edge of the light, faint on the water.
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = LIGHT_RADIUS - 0.25
	torus.outer_radius = LIGHT_RADIUS + 0.25
	torus.rings = 48
	torus.ring_segments = 4
	_ring.mesh = torus
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.albedo_color = Color(1.0, 0.75, 0.35, 0.28)
	look.disable_fog = true
	_ring.material_override = look
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	barge.add_child(_ring)
	add_child(barge)


## The Lantern Barge: a broad, flat-bottomed river barge of tarred planks, square-ended, with low
## sides and a gap amidships either side to step aboard; a deck of pale planks; a long steering sweep
## at the stern; coils of rope and a few barrels; and forward, on an iron post, the Great Lantern in its
## brass cage. Built along -Z (its bow), the deck's top DECK_Y above the water.
static func barge_mesh() -> Mesh:
	if _barge_mesh:
		return _barge_mesh
	var l := LowPoly.new()
	var tar := Color(0.16, 0.13, 0.11)
	var plank := Color(0.52, 0.43, 0.32)
	var brass := Color(0.72, 0.55, 0.24)
	var iron := Color(0.2, 0.21, 0.22)
	# The hull: a long box, its ends raked, a red stripe at the wale.
	l.box(Vector3(0, -0.15, 0), Vector3(4.2, 0.9, 9.0), tar)
	for e: float in [-1.0, 1.0]:
		l.box(Vector3(0, -0.05, e * 4.85), Vector3(4.0, 0.7, 0.8), tar.lightened(0.04), Vector3(e * 28.0, 0, 0))
	l.box(Vector3(2.12, 0.18, 0), Vector3(0.06, 0.12, 9.0), Color(0.45, 0.16, 0.12))
	l.box(Vector3(-2.12, 0.18, 0), Vector3(0.06, 0.12, 9.0), Color(0.45, 0.16, 0.12))
	# The deck, in planks.
	for i in 9:
		l.box(Vector3(-1.8 + i * 0.45, DECK_Y - 0.06, 0), Vector3(0.42, 0.1, 9.4), plank.darkened((i % 3) * 0.05))
	# Low sides, gapped amidships to step aboard.
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			l.box(Vector3(x * 2.0, DECK_Y + 0.18, z * 3.0), Vector3(0.18, 0.36, 3.2), tar.lightened(0.08))
	for z: float in [-1.0, 1.0]:
		l.box(Vector3(0, DECK_Y + 0.18, z * 4.7), Vector3(4.2, 0.36, 0.18), tar.lightened(0.08))
	# The steering sweep at the stern, and its post.
	l.prism(Vector3(0, DECK_Y, 4.4), Vector3(0, DECK_Y + 1.1, 4.4), 0.1, 0.08, 6, Color(0.3, 0.22, 0.15))
	l.prism(Vector3(0, DECK_Y + 1.0, 4.4), Vector3(0.4, -0.3, 7.6), 0.07, 0.06, 6, Color(0.42, 0.32, 0.22))
	l.box(Vector3(0.45, -0.35, 7.75), Vector3(0.1, 0.5, 0.9), Color(0.42, 0.32, 0.22))
	# Cargo: barrels, a coil of rope, a sea chest.
	for b: Vector3 in [Vector3(-1.4, 0, 2.6), Vector3(-1.0, 0, 3.3), Vector3(1.3, 0, -2.6)]:
		l.prism(Vector3(b.x, DECK_Y, b.z), Vector3(b.x, DECK_Y + 0.75, b.z), 0.3, 0.3, 8, Color(0.46, 0.33, 0.2))
	l.prism(Vector3(1.2, DECK_Y, 2.8), Vector3(1.2, DECK_Y + 0.2, 2.8), 0.4, 0.4, 10, Color(0.6, 0.5, 0.34))
	l.box(Vector3(-1.2, DECK_Y + 0.25, -3.0), Vector3(0.9, 0.5, 0.6), Color(0.36, 0.26, 0.17))
	# The Great Lantern's post forward, its arm, and its brass cage.
	l.prism(Vector3(0, DECK_Y, 1.6), Vector3(0, DECK_Y + 3.4, 1.6), 0.12, 0.1, 6, iron)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		l.prism(Vector3(0, DECK_Y, 1.6) + Vector3(cos(a), 0, sin(a)) * 0.9, Vector3(0, DECK_Y + 1.6, 1.6), 0.04, 0.04, 4, iron)
	l.prism(Vector3(0, DECK_Y + 3.4, 1.6), Vector3(0, DECK_Y + 3.5, 1.6), 0.55, 0.55, 8, brass)
	for k in 6:
		var a := TAU * k / 6.0
		l.prism(Vector3(cos(a) * 0.48, DECK_Y + 3.5, 1.6 + sin(a) * 0.48), Vector3(cos(a) * 0.42, DECK_Y + 4.7, 1.6 + sin(a) * 0.42), 0.04, 0.04, 4, brass)
	l.prism(Vector3(0, DECK_Y + 4.7, 1.6), Vector3(0, DECK_Y + 4.85, 1.6), 0.58, 0.5, 8, brass)
	l.prism(Vector3(0, DECK_Y + 4.85, 1.6), Vector3(0, DECK_Y + 5.4, 1.6), 0.5, 0.05, 8, brass.darkened(0.2))
	l.prism(Vector3(0, DECK_Y + 5.4, 1.6), Vector3(0, DECK_Y + 5.7, 1.6), 0.1, 0.1, 6, brass)
	# A carved figure at the bow: a lantern-bearer's head and hand.
	l.prism(Vector3(0, DECK_Y + 0.1, -4.9), Vector3(0, DECK_Y + 0.9, -5.3), 0.18, 0.14, 6, Color(0.5, 0.42, 0.3))
	l.prism(Vector3(0, DECK_Y + 0.9, -5.3), Vector3(0, DECK_Y + 1.15, -5.35), 0.15, 0.08, 6, Color(0.55, 0.46, 0.33))
	# Weed and barnacles at the waterline.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2501
	for x: float in [-1.0, 1.0]:
		VaelModels.barnacles(l, Vector3(x * 2.1, -0.2, rng.randf_range(-3.0, 3.0)), Vector3(x, 0, 0), 6, 0.06, rng)
		VaelModels.kelp(l, Vector3(x * 2.1, 0.0, rng.randf_range(-3.0, 3.0)), 0.5, 2, rng)
	_barge_mesh = l.commit()
	return _barge_mesh


func _lantern_glass() -> Mesh:
	var l := LowPoly.new()
	l.prism(Vector3(0, DECK_Y + 3.55, 1.6), Vector3(0, DECK_Y + 4.65, 1.6), 0.4, 0.36, 8, Color(1.0, 0.82, 0.45))
	l.prism(Vector3(0, DECK_Y + 3.8, 1.6), Vector3(0, DECK_Y + 4.4, 1.6), 0.16, 0.0, 6, Color(1.0, 0.97, 0.8))
	return l.commit()


func _build_lanterns() -> void:
	var flame := LowPoly.new()
	flame.prism(Vector3(0, -0.18, 0), Vector3(0, 0.18, 0), 0.12, 0.12, 6, Color(1.0, 0.82, 0.45))
	var mesh := flame.commit()
	for at: Vector3 in world.road_lanterns:
		var glow := MeshInstance3D.new()
		glow.mesh = mesh
		glow.material_override = MesenllaModels.glow_material()
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = false
		add_child(glow)
		glow.global_position = at
		_lanterns.append({"at": at, "lit": false, "glow": glow, "along": path.get_closest_offset(Vector3(at.x, MistTide.HIGH_Y, at.z)) - 1.0})


## Two long cones of light, back to back, sweeping round from the top of the lighthouse.
func _build_beam(at: Vector3) -> void:
	_beam = Node3D.new()
	_beam.name = "Beam"
	add_child(_beam)
	_beam.global_position = at
	var cone := CylinderMesh.new()
	cone.top_radius = 0.4
	cone.bottom_radius = 7.0
	cone.height = 70.0
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	look.albedo_color = Color(1.0, 0.85, 0.5, 0.16)
	look.disable_fog = true
	look.disable_receive_shadows = true
	for side: float in [-1.0, 1.0]:
		var ray := MeshInstance3D.new()
		ray.mesh = cone
		ray.material_override = look
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The cone's narrow end (its top) at the lamp, its wide end out over the sea.
		ray.rotation = Vector3(-side * PI * 0.5, 0, 0)
		ray.position = Vector3(0, 0, side * 35.0)
		_beam.add_child(ray)


func lanterns_lit() -> int:
	return _lanterns.filter(func(l: Dictionary) -> bool: return l["lit"]).size()


## A fire burning at a spot: a glowing ball and a light round it.
func _glow_at(at: Vector3, size: float, reach: float) -> void:
	var glow := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = size * 0.18
	ball.height = size * 0.36
	ball.radial_segments = 8
	ball.rings = 4
	glow.mesh = ball
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_color = Color(1.0, 0.85, 0.5)
	look.disable_fog = true
	glow.material_override = look
	add_child(glow)
	glow.global_position = at
	if Game.quality > 0:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.45)
		light.light_energy = 2.4
		light.omni_range = reach
		light.shadow_enabled = false
		add_child(light)
		light.global_position = at
