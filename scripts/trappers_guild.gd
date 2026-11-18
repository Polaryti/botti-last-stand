class_name TrappersGuild
extends Node3D
## The Trappers' Guild (a Map Upgrade of the Valleys of Mesenlla): the trappers and hunters of the
## Lodge work for the players for the whole night. It has levels, one for each player in the match who
## brings it (ShopDefs.MAP_LEVELS):
##   Level 1: snare lines across the ways into the camp, and up the road to the Ring of Stones.
##   Level 2: two Lodge hunters keep watch from the camp's towers with Long Bows; when the camp is lost
##            to the mist (CampSiege), they come down and fall back to the Ring of Stones.
##   Level 3: the hunters leave a cache by the camp's fire every CACHE_EVERY seconds (by the Ring of
##            Stones once the camp is lost): food, arrows or a potion, in turn.
##   Level 4: a fallback camp at the Ring of Stones from the start: a fire that mends friends, a ring of
##            snares round it, and two more hunters on guard.
## Where things go is marked on the map (MapSpot kinds snare, hunter, trap_cache, guild_camp). Every
## phone builds the snares and the camp; the host (or a phone on its own) springs the snares, sends
## the hunters and leaves the caches, and tells the other phones what was sprung.

const ID := "trappers_guild"
const SNARE_GAP := 2.0 # metres between the snares of a line
const SNARE_REACH := 0.9 # how close a creature has to step to be caught
const SNARE_HOLD := 2.5
const SNARE_DAMAGE := 15.0
const SNARE_REARM := 12.0
const CAMP_SNARES := 6
const CAMP_SNARE_RING := 8.0
const CACHE_EVERY := 60.0
const CACHE_ORDER := ["food", "arrows", "potion"]
const CACHE_ARROWS := 8
const FIRE_REACH := 6.0
const FIRE_HEAL := 3.0 # a second
const HUNTER_BACK := 40.0 # seconds before a hunter struck down is replaced, from the Lodge
const TOWER_REACH := 30.0 # towers this close to the camp's middle are the camp's
const COLOR := Color(0.55, 0.7, 0.3)

var world: World
var level := 0
var snares: Array[Dictionary] = [] # {at, yaw, node, armed_at, camp (bool: one of the fallback camp's), lost}
var hunters: Array[Dictionary] = [] # {perch, post, ally, back_at, fall_back}
var camp_at := Vector3.INF # the fallback camp's fire (Level 4)
var _camp_node: Node3D
var _fire_light: OmniLight3D
var _next_cache := CACHE_EVERY
var _caches := 0
var _cache: Pickup # the cache left last, while it is still lying there
var _announced := false
var _fell_back := false
var _tend_clock := 0.0
static var _armed_mesh: Mesh
static var _sprung_mesh: Mesh


func _init(owner_world: World, guild_level: int) -> void:
	world = owner_world
	level = clampi(guild_level, 0, ShopDefs.MAP_LEVELS)
	name = "TrappersGuild"


## Only in the Valleys, and only with the upgrade brought into the match by someone.
static func wanted(w: World) -> bool:
	return w.map_id == "mesenlla" and Game.mode != Game.Mode.MENU and ShopDefs.map_upgrade_level(ID) > 0


func _ready() -> void:
	for m: Dictionary in world.guild_marks:
		match str(m["kind"]):
			"snare":
				_lay_line(m["at"], float(m["yaw"]), int(m["gate"]), false)
			"guild_camp":
				if level >= 4:
					camp_at = _ground(m["at"])
	if camp_at != Vector3.INF:
		_build_camp()
		for i in CAMP_SNARES:
			var a := TAU * float(i) / CAMP_SNARES + 0.3
			_add_snare(camp_at + Vector3(cos(a), 0, sin(a)) * CAMP_SNARE_RING, a + PI * 0.5, true)


func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, world.ground_at(at), at.z)


## A line of snares across a way in, centred on `at`, running along `yaw`'s X.
func _lay_line(at: Vector3, yaw: float, count: int, camp: bool) -> void:
	var along := Vector3(cos(yaw), 0, -sin(yaw))
	for i in maxi(count, 1):
		var off := (float(i) - float(count - 1) * 0.5) * SNARE_GAP
		_add_snare(at + along * off, yaw, camp)


func _add_snare(at: Vector3, yaw: float, camp: bool) -> void:
	var spot := _ground(at)
	var node := MeshInstance3D.new()
	node.mesh = snare_mesh(false)
	node.position = spot
	node.rotation.y = yaw + float(snares.size()) * 1.7 # each sapling leans its own way
	node.scale = Vector3.ONE * 1.25
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 70.0
	add_child(node)
	snares.append({"at": spot, "yaw": yaw, "node": node, "armed_at": 0.0, "camp": camp, "lost": false})


## A snare, set (a sapling bent over to the ground, held by a trigger peg, its noose lying open on
## the ground) or sprung (the sapling whipped upright, the noose hanging pulled tight).
static func snare_mesh(sprung: bool) -> Mesh:
	if (_sprung_mesh if sprung else _armed_mesh) == null:
		var l := LowPoly.new()
		var wood := Color(0.42, 0.3, 0.17)
		var bark := Color(0.32, 0.25, 0.15)
		var cord := Color(0.78, 0.7, 0.5)
		var leaf := Color(0.3, 0.42, 0.18)
		var root := Vector3(-0.85, 0, 0.0)
		# The sapling, in segments: bent in an arc down to the peg, or sprung back up, still bowed
		# towards the noose it hauls on.
		var pts: Array[Vector3] = []
		for k in 6:
			var u := float(k) / 5.0
			if sprung:
				pts.append(root + Vector3(0.55 * u * u, u * 1.7, 0))
			else:
				var a := u * PI * 0.62
				pts.append(root + Vector3(sin(a) * 0.95, sin(a * 1.25) * 1.15 * (1.0 - u * 0.55), 0))
		for k in 5:
			l.prism(pts[k], pts[k + 1], 0.045 - k * 0.006, 0.04 - k * 0.006, 5, bark if k % 2 else wood)
		var tip := pts[5]
		l.box(tip + Vector3(0, 0.06, 0), Vector3(0.18, 0.08, 0.12), leaf)
		l.box(pts[3] + Vector3(0.04, 0.05, 0.05), Vector3(0.14, 0.06, 0.1), leaf)
		# A strip of pale rag tied on where the sapling bends: how a trapper marks a line for those who know.
		l.box(pts[2] + Vector3(0, -0.12, 0.05), Vector3(0.07, 0.26, 0.015), Color(0.9, 0.86, 0.72), Vector3(0, 0, 12))
		# The trigger peg, driven in by the noose.
		l.prism(Vector3(0.18, -0.05, 0.2), Vector3(0.18, 0.28, 0.2), 0.035, 0.03, 4, wood)
		l.box(Vector3(0.18, 0.26, 0.12), Vector3(0.05, 0.04, 0.2), wood)
		# The noose: lying open on the ground, or hanging tight from the tip.
		# Sprung, the noose is drawn tight round whatever stepped in it, a hand's breadth off the ground,
		# with the cord pulled taut up to the tip.
		var noose_at := Vector3(0.15, 0.03, 0.0) if not sprung else Vector3(0.2, 0.22, 0.0)
		var noose_r := 0.34 if not sprung else 0.14
		const PARTS := 10
		for k in PARTS:
			var a0 := TAU * k / PARTS
			var a1 := TAU * (k + 1) / PARTS
			var flat := Vector3(cos(a0), 0, sin(a0)) * noose_r
			var flat1 := Vector3(cos(a1), 0, sin(a1)) * noose_r
			l.prism(noose_at + flat, noose_at + flat1, 0.024, 0.024, 3, cord)
		l.prism(tip, noose_at + Vector3(-noose_r, 0, 0), 0.016, 0.016, 3, cord)
		if sprung:
			_sprung_mesh = l.commit()
		else:
			_armed_mesh = l.commit()
	return _sprung_mesh if sprung else _armed_mesh


## The fallback camp: a ring of stones round a fire, a lean-to of poles and hides, a drying rack with
## pelts, and a Lodge pennant on a pole, so it can be found from the road.
static func camp_model() -> Node3D:
	var root := Node3D.new()
	var l := LowPoly.new()
	var stone := Color(0.5, 0.5, 0.52)
	var wood := Color(0.45, 0.3, 0.17)
	var hide := Color(0.62, 0.5, 0.36)
	for i in 9:
		var a := TAU * i / 9.0
		l.box(Vector3(cos(a) * 0.75, 0.1, sin(a) * 0.75), Vector3(0.3, 0.22, 0.26), stone.darkened(0.1 * (i % 3)), Vector3(0, rad_to_deg(a), 0))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		l.prism(Vector3(cos(a) * 0.5, 0.05, sin(a) * 0.5), Vector3(-cos(a) * 0.35, 0.25, -sin(a) * 0.35), 0.06, 0.05, 5, wood.darkened(0.3))
	# Lean-to, behind the fire: two forked uprights and a ridge pole at the front, poles sloping down to
	# the ground behind, and hides laid over them in strips, open towards the fire.
	for x: float in [-1.1, 1.1]:
		l.prism(Vector3(x, 0, -1.5), Vector3(x, 1.55, -1.5), 0.06, 0.05, 5, wood)
		l.prism(Vector3(x, 1.5, -1.5), Vector3(x + 0.1 * signf(x), 1.75, -1.45), 0.04, 0.03, 4, wood)
	l.prism(Vector3(-1.3, 1.55, -1.5), Vector3(1.3, 1.55, -1.5), 0.06, 0.06, 5, wood)
	for k in 4:
		var x := -1.0 + k * 0.66
		l.prism(Vector3(x, 1.58, -1.45), Vector3(x, 0.0, -2.75), 0.035, 0.035, 4, wood.darkened(0.15))
	var tones := [hide, hide.darkened(0.12), hide.lightened(0.08), hide.darkened(0.2)]
	for k in 4:
		l.box(Vector3(-0.84 + k * 0.56, 0.82, -2.08), Vector3(0.56, 0.04, 1.85), tones[k], Vector3(-50, 0, 0))
	l.box(Vector3(0, 0.05, -2.0), Vector3(1.8, 0.06, 0.9), Color(0.48, 0.4, 0.32))
	# Drying rack with two pelts.
	for x: float in [1.9, 3.3]:
		l.prism(Vector3(x, 0, 0.8), Vector3(x, 1.5, 0.8), 0.05, 0.045, 5, wood)
	l.prism(Vector3(1.8, 1.4, 0.8), Vector3(3.4, 1.4, 0.8), 0.04, 0.04, 5, wood)
	l.box(Vector3(2.25, 1.0, 0.8), Vector3(0.55, 0.8, 0.04), Color(0.5, 0.36, 0.22))
	l.box(Vector3(2.95, 0.95, 0.8), Vector3(0.5, 0.75, 0.04), Color(0.68, 0.6, 0.48))
	# The pennant.
	l.prism(Vector3(-2.4, 0, 0.6), Vector3(-2.4, 3.2, 0.6), 0.05, 0.04, 5, wood)
	l.box(Vector3(-2.05, 2.85, 0.6), Vector3(0.7, 0.45, 0.03), COLOR.darkened(0.2))
	l.box(Vector3(-2.05, 2.85, 0.62), Vector3(0.2, 0.2, 0.02), Color(0.9, 0.82, 0.6), Vector3(0, 0, 45))
	var body := MeshInstance3D.new()
	body.mesh = l.commit()
	root.add_child(body)
	var flame := LowPoly.new()
	flame.prism(Vector3(0, 0.15, 0), Vector3(0, 0.95, 0), 0.32, 0.0, 6, Color(1.0, 0.5, 0.12))
	flame.prism(Vector3(0.05, 0.15, 0.05), Vector3(0.05, 0.62, 0.05), 0.2, 0.0, 6, Color(1.0, 0.86, 0.3))
	var fire := MeshInstance3D.new()
	fire.mesh = flame.commit()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	fire.material_override = glow
	fire.name = "Flame"
	root.add_child(fire)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func _build_camp() -> void:
	_camp_node = camp_model()
	_camp_node.position = camp_at
	var to_stones := Vector3.ZERO
	for m: Dictionary in world.map_marks:
		if m["name"] == "Ring of Stones":
			to_stones = Vector3((m["at"] as Vector2).x - camp_at.x, 0, (m["at"] as Vector2).y - camp_at.z)
	if to_stones.length() > 0.5:
		_camp_node.rotation.y = atan2(-to_stones.x, -to_stones.z) # the lean-to between the fire and the stones, open to the road
	add_child(_camp_node)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.62, 0.3)
	_fire_light.light_energy = 1.6
	_fire_light.omni_range = 9.0
	_fire_light.position = camp_at + Vector3.UP * 1.0
	add_child(_fire_light)
	world.add_glow(camp_at + Vector3.UP * 0.6, Color(1.0, 0.6, 0.25), 2.0, 120.0, true)


func is_host_side() -> bool:
	return not Net.active() or Net.is_host()


func _physics_process(delta: float) -> void:
	var now := world.now
	# Snares: sprung ones are set again in time; and when the camp is lost, those in its ground with it.
	for i in snares.size():
		var s: Dictionary = snares[i]
		var node: MeshInstance3D = s["node"]
		if s["lost"]:
			continue
		if world.camp_fallen and _in_fallen_camp(s["at"]):
			s["lost"] = true
			node.visible = false
			continue
		var sprung: bool = now < float(s["armed_at"])
		if sprung != bool(s.get("shown", false)):
			s["shown"] = sprung
			node.mesh = snare_mesh(sprung)
	if _camp_node:
		var flame := _camp_node.get_node("Flame") as Node3D
		flame.scale = Vector3(1.0 + 0.08 * sin(now * 13.0), 0.85 + 0.25 * sin(now * 9.0) * sin(now * 5.3), 1.0 + 0.08 * cos(now * 11.0))
		_fire_light.light_energy = 1.5 + 0.3 * sin(now * 12.0) * sin(now * 7.1)
		_tend_clock -= delta
		if _tend_clock <= 0.0:
			_tend_clock = 0.25
			for p: Player in world.local_players():
				_warm(p, 0.25)
	if not is_host_side() or world.director == null:
		return
	if not _announced:
		_announced = true
		_muster()
		world.director.show_banner(banner(), 3.5)
		_horn(Vector3.INF)
	_spring()
	if level >= 2:
		_tend_hunters()
		if world.camp_fallen and not _fell_back:
			_fell_back = true
			_fall_back()
	if level >= 3:
		_tick_cache()


## A friend by the camp fire mends.
func _warm(p: Player, secs: float) -> void:
	if p == null or p.dead or camp_at == Vector3.INF:
		return
	if Vector2(p.global_position.x - camp_at.x, p.global_position.z - camp_at.z).length() > FIRE_REACH or absf(p.global_position.y - camp_at.y) > 3.0:
		return
	if p.hp < p.max_hp():
		p.heal(FIRE_HEAL * secs)


func _in_fallen_camp(at: Vector3) -> bool:
	var c := world.fallen_camp
	return c != Vector3.INF and Vector2(at.x - c.x, at.z - c.z).length() <= world.fallen_radius + 2.0


# --- The host's side ---------------------------------------------------------------------

## Creatures that step into a set snare are caught: held where they stand, cut, and nobody's kill.
func _spring() -> void:
	var now := world.now
	for i in snares.size():
		var s: Dictionary = snares[i]
		if s["lost"] or now < float(s["armed_at"]):
			continue
		for z: Zombie in world.zombies_near(s["at"], SNARE_REACH + 0.6, 4):
			if not z.is_alive() or z.flies or z.carrier or z.is_boss():
				continue
			if Vector2(z.position.x - s["at"].x, z.position.z - s["at"].z).length() > SNARE_REACH + z.body_radius() * 0.5:
				continue
			spring_snare(i)
			z.root(SNARE_HOLD, true)
			z.next_hitter = -1
			z.take_damage(SNARE_DAMAGE, Vector3.ZERO, 0.0, z.centre())
			if Net.active():
				Net.snare(i)
			break


## A snare goes off, on this phone: it shows sprung until it is set again.
func spring_snare(i: int) -> void:
	if i < 0 or i >= snares.size():
		return
	var s: Dictionary = snares[i]
	s["armed_at"] = world.now + SNARE_REARM
	s["shown"] = true
	(s["node"] as MeshInstance3D).mesh = snare_mesh(true)
	world.sfx_at("snare_snap", s["at"], -2.0)


## The hunters take their places: on the camp's towers (Level 2), and by the fallback camp (Level 4).
func _muster() -> void:
	if level >= 2:
		for tower: Dictionary in _camp_towers():
			var top: Vector3 = (tower["at"] as Vector3) + Vector3.UP * (float(tower["high"]) + 0.13)
			hunters.append({"perch": top, "post": _fallback_post(hunters.size()), "ally": null, "back_at": 0.0, "tower": tower})
	if level >= 4:
		for m: Dictionary in world.guild_marks:
			if str(m["kind"]) == "hunter" and int(m["gate"]) == 4:
				hunters.append({"perch": Vector3.INF, "post": _ground(m["at"]), "ally": null, "back_at": 0.0})
	for i in hunters.size():
		_send(i)


func _camp_towers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c := Vector3.INF
	for mark: Dictionary in world.map_marks:
		if mark["name"] == CampSiege.CAMP_MARK:
			c = Vector3((mark["at"] as Vector2).x, 0, (mark["at"] as Vector2).y)
	if c == Vector3.INF:
		return out
	for tower: Dictionary in world.watchtowers:
		var at: Vector3 = tower["at"]
		if Vector2(at.x - c.x, at.z - c.z).length() <= TOWER_REACH and not tower.get("ruined", false):
			out.append(tower)
	return out


## Where a tower's hunter goes when the camp is lost: the Ring of Stones (MapSpot hunter, gate 2).
func _fallback_post(n: int) -> Vector3:
	var posts: Array[Vector3] = []
	for m: Dictionary in world.guild_marks:
		if str(m["kind"]) == "hunter" and int(m["gate"]) == 2:
			posts.append(_ground(m["at"]))
	return posts[n % posts.size()] if not posts.is_empty() else Vector3.INF


## A hunter goes to its place: up its tower, or to its post on the ground.
func _send(i: int) -> void:
	var h: Dictionary = hunters[i]
	var perched: bool = h["perch"] != Vector3.INF and not world.camp_fallen
	var at: Vector3 = h["perch"] if perched else h["post"]
	if at == Vector3.INF:
		return
	var a := world.spawn_garrison("lodge_hunter", -1, at, at)
	a.post = h["post"] if not perched else at
	if perched:
		a.perch = at
		a.global_position = at
	a.arm("longbow" if perched else "bow")
	h["ally"] = a
	world.fx_blast(a.global_position + Vector3.UP, 1.0, Color(COLOR, 0.5))


## A hunter struck down is replaced from the Lodge after a while.
func _tend_hunters() -> void:
	for i in hunters.size():
		var h: Dictionary = hunters[i]
		var a: Variant = h["ally"]
		if a != null and is_instance_valid(a) and not (a as Ally).dead and (a as Ally).kind == "lodge_hunter":
			continue
		if float(h["back_at"]) <= 0.0:
			h["back_at"] = world.now + HUNTER_BACK
		elif world.now >= float(h["back_at"]):
			h["back_at"] = 0.0
			_send(i)
			_horn((h["ally"] as Ally).global_position if h["ally"] else Vector3.INF)


## The camp is lost: the hunters on its towers come down and make for the Ring of Stones.
func _fall_back() -> void:
	for h: Dictionary in hunters:
		if h["perch"] == Vector3.INF:
			continue
		var a: Variant = h["ally"]
		if a == null or not is_instance_valid(a) or (a as Ally).dead:
			continue
		var hunter := a as Ally
		hunter.perch = Vector3.INF
		var foot: Vector3 = (h["perch"] as Vector3)
		foot = world.grid.to_world(world.grid.nearest_free(world.grid.to_cell(foot)))
		hunter.global_position = _ground(foot)
		hunter.post = h["post"]
		hunter.arm("bow")
	if not hunters.is_empty():
		world.director.show_banner("The Lodge hunters fall back to the Ring of Stones", 3.5)


## Every so often a cache by the fire: food, arrows or a potion, in turn, if the last was taken.
func _tick_cache() -> void:
	var elapsed := world.director.elapsed
	if elapsed < _next_cache:
		return
	_next_cache = elapsed + CACHE_EVERY
	if _cache != null and is_instance_valid(_cache) and world.pickups.has(_cache):
		return # the last is still lying there
	var at := cache_spot()
	if at == Vector3.INF:
		return
	var what: String = CACHE_ORDER[_caches % CACHE_ORDER.size()]
	_caches += 1
	match what:
		"food": _cache = world.spawn_pickup_at(at, Pickup.Kind.FOOD, PowerDefs.pick_weighted(PowerDefs.FOODS))
		"arrows": _cache = world.spawn_pickup_at(at, Pickup.Kind.ARROWS, "arrows", CACHE_ARROWS)
		_: _cache = world.spawn_pickup_at(at, Pickup.Kind.POWER, PowerDefs.pick_potion(world.spawn_map()))
	world.fx_blast(at + Vector3.UP * 0.5, 0.9, Color(COLOR, 0.5))
	world.sfx_at("cache_drop", at, -2.0)
	if Net.active():
		Net.sound_at("cache_drop", at, -2.0)
	if _caches == 1:
		world.director.show_banner("The Lodge hunters left a cache by the fire", 3.0)


## Where the next cache goes: by the camp's fire (MapSpot trap_cache, gate 0), or once the camp is
## lost, by the Ring of Stones (gate 1).
func cache_spot() -> Vector3:
	var want := 1 if world.camp_fallen else 0
	for m: Dictionary in world.guild_marks:
		if str(m["kind"]) == "trap_cache" and int(m["gate"]) == want:
			return _ground(m["at"])
	return Vector3.INF


func _horn(at: Vector3) -> void:
	var where := at
	if where == Vector3.INF:
		for mark: Dictionary in world.map_marks:
			if mark["name"] == CampSiege.CAMP_MARK:
				where = _ground(Vector3((mark["at"] as Vector2).x, 0, (mark["at"] as Vector2).y))
	if where == Vector3.INF:
		return
	world.sfx_at("trapper_horn", where, 0.0)
	if Net.active():
		Net.sound_at("trapper_horn", where, 0.0)


## What the night says when the Guild arrives, by level.
func banner() -> String:
	match level:
		1: return "Trappers' Guild: snare lines lie across the ways in"
		2: return "Trappers' Guild, Level 2: Lodge hunters keep watch from the towers"
		3: return "Trappers' Guild, Level 3: the hunters will leave caches by the fire"
	return "Trappers' Guild, Level 4: a fallback camp waits at the Ring of Stones"
