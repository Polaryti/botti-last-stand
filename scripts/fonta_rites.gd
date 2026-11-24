class_name FontaRites
extends Node3D
## Fontanova's rites: what keeps you moving round the island through the night.
##   The Oracle's Grotto: three cold braziers along the way in. Stand by one for BRAZIER_HOLD seconds
##     to light it; when all three burn, the sanctum's door of stone sinks into the floor, and on the
##     oracle's altar behind it lie a rare weapon and the Oracle's Eye (a relic).
##   The waking altars: from ALTAR_FIRST, every ALTAR_EVERY seconds one of the four lesser gods' altars
##     wakes for ALTAR_AWAKE seconds, a pillar of its god's light over it, and mutants come to it. Whoever
##     holds it (stands within ALTAR_REACH for ALTAR_HOLD seconds in all, more slowly while mutants are
##     there too) is blessed by its god (Player.bless) for a minute: Thaleon heals, Ilyria strikes harder,
##     Orvane quickens and hardens, Kerys sharpens the aim.
##   The rising tide: at each of TIDES the sea rises TIDE_RISE metres for TIDE_HIGH seconds, after
##     TIDE_WARN seconds' warning, drowning the beaches and the coves.
##   The transmutation blooms: from BLOOM_FIRST, every BLOOM_EVERY seconds Al'quimelea's violet flowers bud
##     over one of the island's places (BLOOM_PLACES, in turn) and after BLOOM_WARN seconds open: for
##     BLOOM_TIME seconds whoever stands among them is poisoned and hurt.
## The tide and the blooms keep the clock, the same on every phone. The braziers and altars are decided
## by the host (or a phone alone) and sent to every phone (Net.fonta_rites); each phone blesses and
## poisons its own players.

const BRAZIER_REACH := 2.4
const BRAZIER_HOLD := 3.0
const DOOR_SINK := 2.5 # seconds for the sanctum's door to sink away
const ALTAR_FIRST := 150.0
const ALTAR_EVERY := 120.0
const ALTAR_AWAKE := 60.0
const ALTAR_REACH := 4.5
const ALTAR_HOLD := 10.0
const ALTAR_CONTESTED := 0.4 # how fast it is held while mutants stand there too
const ALTAR_GUARDS := 3 # mutants drawn to an altar when it wakes
const ALTAR_ORDER := [2, 3, 1, 4] # Ilyria, Orvane, Thaleon, Kerys, round and round
const GOD_NAMES := {1: "Thaleon", 2: "Ilyria", 3: "Orvane", 4: "Kerys"}
const GOD_COLOURS := {1: Color(0.35, 0.85, 0.95), 2: Color(1.0, 0.82, 0.35), 3: Color(0.75, 0.6, 1.0), 4: Color(0.55, 1.0, 0.5)}
const TIDES := [240.0, 480.0, 720.0]
const TIDE_WARN := 15.0
const TIDE_RAMP := 8.0
const TIDE_HIGH := 60.0
const TIDE_RISE := 2.4
const BLOOM_FIRST := 200.0
const BLOOM_EVERY := 150.0
const BLOOM_WARN := 12.0
const BLOOM_TIME := 40.0
const BLOOM_RADIUS := 11.0
const BLOOM_POISON := 3.0
const BLOOM_HURT := 4.0 # health a second among the open blooms
const BLOOM_PLACES := ["Olive Terraces", "Fallen Colossus", "Worshippers' Village", "Ilyria's Grove", "The Landing", "Holm Wood", "Sacred Way"]
const SEND_EVERY := 0.25

var world: World
var lit := 0 # the braziers burning, a bit each
var door_open := false
var altar_god := 0 # the god whose altar is awake now, or 0
var altar_hold := 0.0
var claims := 0 # how many altars have been held this night
var _brazier_hold: Array[float] = [0.0, 0.0, 0.0]
var _braziers: Array[Dictionary] = [] # {at, fire, light}
var _door: Node3D
var _door_body: StaticBody3D
var _door_sink := 0.0
var _altar_fx: Node3D
var _altar_ring: MeshInstance3D
var _altar_fill: MeshInstance3D
var _waking := -1 # which waking of the altars it is, counted from the first
var _seen_claims := 0
var _bloom_n := -1
var _bloom: Node3D
var _bloom_flowers: MultiMeshInstance3D
var _bloom_at := Vector3.ZERO
var _tide_warned := -1
var _send := 0.0
var _hurt_tick := 0.0
var _rewarded := false


func _init(owner_world: World) -> void:
	world = owner_world
	name = "FontaRites"


func _ready() -> void:
	_build_grotto()


## This phone's own players: its player, and on the deciding phone its bots.
func _mine(p: Target) -> bool:
	return p == world.player or (p is Player and (p as Player).is_bot() and _deciding())


func _deciding() -> bool:
	return not Net.active() or Net.is_host()


func _elapsed() -> float:
	return world.director.elapsed if world.director else 0.0


func _physics_process(delta: float) -> void:
	_tick_tide()
	_tick_blooms(delta)
	if _deciding():
		_tick_braziers(delta)
		_tick_altars(delta)
		_send -= delta
		if Net.active() and _send <= 0.0:
			_send = SEND_EVERY
			Net.fonta_rites(lit, door_open, altar_god, altar_hold, claims)
	_show_altar()
	_tick_door(delta)
	_bless_claimed()


## A phone following the host: what it says.
func follow(new_lit: int, open: bool, god: int, hold: float, new_claims: int) -> void:
	for i in 3:
		if new_lit & (1 << i) and not lit & (1 << i):
			_light(i)
	lit = new_lit
	if open and not door_open:
		_open_door()
	altar_god = god
	altar_hold = hold
	claims = new_claims


# --- The Oracle's Grotto ---------------------------------------------------------------------------

func _build_grotto() -> void:
	var g := world.grotto_rites
	if g.is_empty():
		return
	for at: Vector3 in g["braziers"]:
		var foot := Vector3(at.x, world.ground_at(at), at.z)
		var node := Node3D.new()
		node.position = foot
		add_child(node)
		var stand := MeshInstance3D.new()
		stand.mesh = brazier_mesh()
		node.add_child(stand)
		var fire := MeshInstance3D.new()
		fire.mesh = _flame_mesh()
		fire.material_override = MesenllaModels.glow_material()
		fire.position = Vector3(0, 1.05, 0)
		fire.visible = false
		node.add_child(fire)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.3)
		light.omni_range = 7.0
		light.light_energy = 0.0
		light.position = Vector3(0, 1.5, 0)
		node.add_child(light)
		_braziers.append({"at": foot, "fire": fire, "light": light})
	# The sanctum's door: a slab of marble filling the passage, the god's sign cut in it, glowing.
	var door_at: Transform3D = g["door"]
	var wide: float = g["wide"]
	_door = Node3D.new()
	_door.transform = door_at
	_door.position.y = world.ground_at(door_at.origin)
	add_child(_door)
	var slab := MeshInstance3D.new()
	slab.mesh = door_mesh(wide)
	_door.add_child(slab)
	_door_body = StaticBody3D.new()
	_door_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(wide + 2.0, 4.6, 0.8)
	shape.shape = box
	shape.position = Vector3(0, 2.3, 0)
	_door_body.add_child(shape)
	_door.add_child(_door_body)
	world.grid.block_turned(door_at, Vector3(wide + 2.0, 2.0, 1.0)) # turned with the grotto


static var _brazier: Mesh
## A bronze brazier on three legs, its bowl full of old ash.
static func brazier_mesh() -> Mesh:
	if _brazier:
		return _brazier
	var l := LowPoly.new()
	var bronze := Color(0.6, 0.42, 0.2)
	for k in 3:
		var a := TAU * k / 3.0
		l.prism(Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5), Vector3(cos(a) * 0.22, 0.85, sin(a) * 0.22), 0.05, 0.04, 5, bronze.darkened(0.2))
	l.prism(Vector3(0, 0.82, 0), Vector3(0, 1.1, 0), 0.32, 0.55, 10, bronze)
	l.prism(Vector3(0, 1.1, 0), Vector3(0, 1.14, 0), 0.57, 0.57, 10, bronze.lightened(0.15))
	l.prism(Vector3(0, 1.0, 0), Vector3(0, 1.08, 0), 0.5, 0.5, 10, Color(0.2, 0.19, 0.18))
	_brazier = l.commit()
	return _brazier


static func _flame_mesh() -> Mesh:
	var l := LowPoly.new()
	for k in 5:
		var a := TAU * k / 5.0
		l.prism(Vector3(cos(a) * 0.22, 0.0, sin(a) * 0.22), Vector3(cos(a) * 0.08, 0.7 + 0.2 * (k % 2), sin(a) * 0.08), 0.16, 0.0, 5, Color(1.0, 0.55 + 0.1 * (k % 2), 0.2))
	l.prism(Vector3(0, 0, 0), Vector3(0, 1.0, 0), 0.26, 0.0, 6, Color(1.0, 0.85, 0.45))
	return l.commit()


static func door_mesh(wide: float) -> Mesh:
	var l := LowPoly.new()
	var marble := Color(0.8, 0.77, 0.72)
	l.box(Vector3(0, 2.3, 0), Vector3(wide + 1.6, 4.6, 0.7), marble)
	for k in 4:
		l.box(Vector3(0, 0.6 + k * 1.1, 0.36), Vector3(wide + 1.6, 0.06, 0.04), marble.darkened(0.25))
	# The god's sign: a hexagon, a ring within it.
	l.prism(Vector3(0, 2.5, 0.35), Vector3(0, 2.5, 0.42), 0.9, 0.9, 6, Color(0.55, 0.35, 0.75))
	l.prism(Vector3(0, 2.5, 0.42), Vector3(0, 2.5, 0.46), 0.5, 0.5, 6, Color(0.85, 0.6, 1.0))
	return l.commit()


func _tick_braziers(delta: float) -> void:
	for i in _braziers.size():
		if lit & (1 << i):
			continue
		var at: Vector3 = _braziers[i]["at"]
		var near := false
		for p: Target in world.players:
			if not p.dead and p.global_position.distance_to(at) < BRAZIER_REACH:
				near = true
				if p == world.player:
					world.player.say("Lighting the brazier...")
		_brazier_hold[i] = _brazier_hold[i] + delta if near else maxf(0.0, _brazier_hold[i] - delta * 0.5)
		if _brazier_hold[i] >= BRAZIER_HOLD:
			lit |= 1 << i
			_light(i)
	if lit == 7 and not door_open:
		_open_door()


func _light(i: int) -> void:
	if i >= _braziers.size():
		return
	(_braziers[i]["fire"] as MeshInstance3D).visible = true
	(_braziers[i]["light"] as OmniLight3D).light_energy = 1.6
	world.sfx_at("brazier_lit", _braziers[i]["at"], 0.0)
	var count := 0
	for k in 3:
		if lit & (1 << k):
			count += 1
	if world.player:
		world.player.say("A brazier burns (%d of 3)" % count if count < 3 else "The sanctum's door is opening...")


func _open_door() -> void:
	door_open = true
	_door_sink = DOOR_SINK
	if _door:
		world.sfx_at("sanctum_open", _door.global_position, 0.0)
		world.grid.block_turned(world.grotto_rites["door"], Vector3(float(world.grotto_rites["wide"]) + 2.0, 2.0, 1.0), false)
	if _deciding() and not _rewarded:
		_rewarded = true
		var relic: Vector3 = world.grotto_rites["relic"]
		relic.y = world.ground_at(relic)
		var weapon := WeaponDefs.pick_rare(world.map_id)
		if weapon != "":
			world.spawn_pickup_at(relic + Vector3(-0.8, 0, 0), Pickup.Kind.WEAPON, weapon)
		world.spawn_pickup_at(relic + Vector3(0.8, 0, 0), Pickup.Kind.POWER, PowerDefs.EYE)


func _tick_door(delta: float) -> void:
	if _door == null or _door_sink <= 0.0:
		return
	_door_sink -= delta
	var k := 1.0 - clampf(_door_sink / DOOR_SINK, 0.0, 1.0)
	_door.position.y = world.ground_at(_door.global_position) - 4.8 * k * k
	if _door_sink <= 0.0 and _door_body:
		_door_body.queue_free()
		_door_body = null


# --- The waking altars ---------------------------------------------------------------------------

func _altar_at(god: int) -> Vector3:
	for a: Dictionary in world.altar_spots:
		if int(a["god"]) == god:
			var at: Vector3 = a["at"]
			return Vector3(at.x, world.ground_at(at), at.z)
	return Vector3.INF


## Which god's altar is awake at this time of the night (0 for none), and for how much longer.
static func awake_at(elapsed: float) -> Vector2:
	if elapsed < ALTAR_FIRST:
		return Vector2.ZERO
	var n := int((elapsed - ALTAR_FIRST) / ALTAR_EVERY)
	var into := elapsed - ALTAR_FIRST - n * ALTAR_EVERY
	if into >= ALTAR_AWAKE:
		return Vector2(0, 0)
	return Vector2(ALTAR_ORDER[n % ALTAR_ORDER.size()], ALTAR_AWAKE - into)


func _tick_altars(delta: float) -> void:
	var now := _elapsed()
	var awake := awake_at(now)
	var n := int((now - ALTAR_FIRST) / ALTAR_EVERY) if now >= ALTAR_FIRST else -1
	if int(awake.x) != 0 and n != _waking:
		# A new waking: its god's altar lights, and the island's creatures are drawn to it.
		_waking = n
		altar_god = int(awake.x)
		altar_hold = 0.0
		var at := _altar_at(altar_god)
		if at != Vector3.INF:
			world.director.show_banner("%s's altar wakes %s: hold it for the god's blessing!" % [GOD_NAMES[altar_god], _bearing(at)], 4.0)
			world.sfx_at("altar_wake", at, 4.0)
			for k in ALTAR_GUARDS:
				var a := TAU * k / ALTAR_GUARDS + randf() * 0.5
				var spot := at + Vector3(cos(a), 0, sin(a)) * 14.0
				spot.y = world.ground_at(spot)
				world.spawn_zombie(ZombieDefs.pick_roamer(maxf(now, 300.0), world.map_id), spot)
	if int(awake.x) == 0:
		altar_god = 0
		return
	if altar_god == 0:
		return # held already this waking
	var at := _altar_at(altar_god)
	if at == Vector3.INF:
		return
	var holders := 0
	for p: Target in world.players:
		if not p.dead and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < ALTAR_REACH:
			holders += 1
	if holders == 0:
		altar_hold = maxf(0.0, altar_hold - delta * 0.25)
		return
	var contested := false
	for z: Zombie in world.zombies:
		if z.is_alive() and Vector2(z.position.x - at.x, z.position.z - at.z).length() < ALTAR_REACH:
			contested = true
			break
	altar_hold += delta * (ALTAR_CONTESTED if contested else 1.0)
	if altar_hold >= ALTAR_HOLD:
		claims += 1
		altar_god = 0
		altar_hold = 0.0


## Every phone: when an altar has been held, its god blesses that phone's own players standing at it.
var _last_god := 0
func _bless_claimed() -> void:
	if altar_god != 0:
		_last_god = altar_god
	if claims == _seen_claims:
		return
	_seen_claims = claims
	var at := _altar_at(_last_god)
	if at == Vector3.INF:
		return
	world.sfx_at("altar_bless", at, 2.0)
	world.fx_ring(at + Vector3.UP * 0.2, ALTAR_REACH * 1.6, GOD_COLOURS.get(_last_god, Color.WHITE))
	for p: Target in world.players:
		if _mine(p) and not p.dead:
			if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < ALTAR_REACH * 1.6:
				(p as Player).bless("god_%d" % _last_god)


func _show_altar() -> void:
	if altar_god == 0:
		if _altar_fx:
			_altar_fx.visible = false
		return
	var at := _altar_at(altar_god)
	if at == Vector3.INF:
		return
	if _altar_fx == null:
		_altar_fx = Node3D.new()
		add_child(_altar_fx)
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.9
		cyl.bottom_radius = 1.3
		cyl.height = 40.0
		beam.mesh = cyl
		beam.position.y = 20.0
		beam.name = "Beam"
		_altar_fx.add_child(beam)
		_altar_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = ALTAR_REACH - 0.15
		ring.outer_radius = ALTAR_REACH
		_altar_ring.mesh = ring
		_altar_ring.position.y = 0.12
		_altar_fx.add_child(_altar_ring)
		_altar_fill = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = ALTAR_REACH
		disc.bottom_radius = ALTAR_REACH
		disc.height = 0.04
		_altar_fill.mesh = disc
		_altar_fill.position.y = 0.08
		_altar_fx.add_child(_altar_fill)
		var light := OmniLight3D.new()
		light.omni_range = 14.0
		light.light_energy = 1.6
		light.position.y = 4.0
		light.name = "Light"
		_altar_fx.add_child(light)
	_altar_fx.visible = true
	_altar_fx.global_position = at
	var col: Color = GOD_COLOURS.get(altar_god, Color.WHITE)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(col.r, col.g, col.b, 0.28 + 0.08 * sin(world.now * 3.0))
	(_altar_fx.get_node("Beam") as MeshInstance3D).material_override = glow
	_altar_ring.material_override = glow
	var fill := glow.duplicate() as StandardMaterial3D
	fill.albedo_color = Color(col.r, col.g, col.b, 0.35)
	_altar_fill.material_override = fill
	var k := clampf(altar_hold / ALTAR_HOLD, 0.0, 1.0)
	_altar_fill.scale = Vector3(maxf(k, 0.01), 1.0, maxf(k, 0.01))
	(_altar_fx.get_node("Light") as OmniLight3D).light_color = col


## Which way something is from the middle of the island, in words.
static func _bearing(at: Vector3) -> String:
	var words := ["in the east", "in the south-east", "in the south", "in the south-west", "in the west", "in the north-west", "in the north", "in the north-east"]
	return words[int(round(fposmod(atan2(at.z, at.x), TAU) / (TAU / 8.0))) % 8]


# --- The rising tide -----------------------------------------------------------------------------

## How far the sea has risen at this time of the night.
static func tide_at(elapsed: float) -> float:
	for t: float in TIDES:
		if elapsed >= t and elapsed < t + TIDE_HIGH + TIDE_RAMP:
			var rise := smoothstep(t, t + TIDE_RAMP, elapsed)
			var fall := 1.0 - smoothstep(t + TIDE_HIGH, t + TIDE_HIGH + TIDE_RAMP, elapsed)
			return TIDE_RISE * minf(rise, fall)
	return 0.0


func _tick_tide() -> void:
	if world.isle_sea == null:
		return
	var now := _elapsed()
	world.isle_sea.set_level(Terrain.ISLE_SEA_Y + tide_at(now))
	for i in TIDES.size():
		var t: float = TIDES[i]
		if now >= t - TIDE_WARN and now < t and _tide_warned != i:
			_tide_warned = i
			world.director.show_banner("The sea is rising! Get off the beaches.", 4.0)
			world.sfx_at("tide_rising", world.player.global_position if world.player else Vector3.ZERO, 0.0)


# --- The transmutation blooms --------------------------------------------------------------------

## Which bloom it is at this time (or -1), where, and whether it is still budding.
static func bloom_at(elapsed: float) -> Vector3i:
	if elapsed < BLOOM_FIRST:
		return Vector3i(-1, 0, 0)
	var n := int((elapsed - BLOOM_FIRST) / BLOOM_EVERY)
	var into := elapsed - BLOOM_FIRST - n * BLOOM_EVERY
	if into >= BLOOM_WARN + BLOOM_TIME:
		return Vector3i(-1, 0, 0)
	return Vector3i(n, (n * 3) % BLOOM_PLACES.size(), 1 if into < BLOOM_WARN else 2)


func _place_named(name_text: String) -> Vector3:
	for mark: Dictionary in world.map_marks:
		if mark["name"] == name_text:
			var at := Vector3(mark["at"].x, 0, mark["at"].y)
			at.y = world.ground_at(at)
			return at
	return Vector3.INF


func _tick_blooms(delta: float) -> void:
	var b := bloom_at(_elapsed())
	if b.x < 0:
		if _bloom:
			_bloom.queue_free()
			_bloom = null
		return
	if b.x != _bloom_n:
		_bloom_n = b.x
		_bloom_at = _place_named(BLOOM_PLACES[b.y])
		if _bloom:
			_bloom.queue_free()
			_bloom = null
		if _bloom_at == Vector3.INF:
			return
		_build_bloom()
		world.director.show_banner("Violet buds are breaking through the ground at %s..." % BLOOM_PLACES[b.y], 4.0)
	if _bloom == null:
		return
	var open := b.z == 2
	var grow := 1.0 if open else 0.35 + 0.1 * sin(world.now * 4.0)
	_bloom_flowers.scale = Vector3(1.0, grow, 1.0)
	var ring := _bloom.get_node("Ring") as MeshInstance3D
	(ring.material_override as StandardMaterial3D).albedo_color.a = 0.75 if open else 0.35 + 0.35 * sin(world.now * 6.0)
	if not open:
		return
	_hurt_tick -= delta
	if _hurt_tick > 0.0:
		return
	_hurt_tick = 0.5
	for p: Target in world.players:
		if _mine(p) and not p.dead:
			if in_bloom(p.global_position):
				(p as Player).poison_by_creature(BLOOM_POISON)
				(p as Player).drown(BLOOM_HURT * 0.5, "the blooms")


func in_bloom(at: Vector3) -> bool:
	return _bloom != null and bloom_at(_elapsed()).z == 2 and Vector2(at.x - _bloom_at.x, at.z - _bloom_at.z).length() < BLOOM_RADIUS


func _build_bloom() -> void:
	_bloom = Node3D.new()
	add_child(_bloom)
	_bloom.global_position = Vector3.ZERO
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bloom_mesh()
	var count := 340
	mm.instance_count = count
	var r := RandomNumberGenerator.new()
	r.seed = _bloom_n * 31 + 7
	for i in count:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * BLOOM_RADIUS
		var at := _bloom_at + Vector3(cos(a) * d, 0, sin(a) * d)
		at.y = world.ground_at(at)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.8, 1.4)), at))
	_bloom_flowers = MultiMeshInstance3D.new()
	_bloom_flowers.multimesh = mm
	_bloom.add_child(_bloom_flowers)
	# The ring that marks where they will open: pulsing while they bud, steady once open.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = BLOOM_RADIUS - 0.25
	torus.outer_radius = BLOOM_RADIUS
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.75, 0.4, 1.0, 0.7)
	ring.material_override = mat
	ring.name = "Ring"
	_bloom.add_child(ring)
	ring.global_position = _bloom_at + Vector3.UP * 0.25
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.45, 1.0)
	light.omni_range = BLOOM_RADIUS + 4.0
	light.light_energy = 1.2
	_bloom.add_child(light)
	light.global_position = _bloom_at + Vector3.UP * 3.0


static var _bloom_mesh: Mesh
## One of Al'quimelea's flowers: a pale stem, a cup of violet petals, a green-gold heart.
static func bloom_mesh() -> Mesh:
	if _bloom_mesh:
		return _bloom_mesh
	var l := LowPoly.new()
	l.prism(Vector3(0, -0.2, 0), Vector3(0, 0.55, 0), 0.03, 0.025, 4, Color(0.4, 0.6, 0.35))
	for k in 6:
		var a := TAU * k / 6.0
		var out := Vector3(cos(a), 0.5, sin(a)) * 0.28
		var side := Vector3(-sin(a), 0, cos(a)) * 0.11
		l.leaf(Vector3(0, 0.55, 0), Vector3(0, 0.55, 0) + out + side, Vector3(0, 0.55, 0) + out - side, Color(0.72, 0.4, 1.0))
		l.leaf(Vector3(0, 0.55, 0), Vector3(0, 0.55, 0) + out - side, Vector3(0, 0.55, 0) + out + side, Color(0.62, 0.32, 0.92))
	l.box(Vector3(0, 0.6, 0), Vector3(0.07, 0.06, 0.07), Color(0.7, 1.0, 0.4))
	_bloom_mesh = l.commit()
	return _bloom_mesh
