class_name SurveyNet
extends Node3D
## One Cartographer's beacons and the lines of light between them. Every phone keeps its own copy and
## looks after its own people (the host after its bots too): friends near a beacon run faster,
## friends on a line mend, and enemies near a beacon are marked for the Cartographer's side.
## A Star Reader's stones hold constellations, a Worlds Traveler's are Waygates, and a Pathfinder's
## unearth finds (CartographerKit). What hurts enemies is worked out on the Cartographer's own phone
## (or the host, for a bot), so it is counted once; the other phones only show it.

const LIFE := 60.0
const LINE_REACH := 1.5 # how close to a line counts as standing on it
const GATE_REACH := 1.1
const STAR_EVERY := 2.0
const QUICK_STAR_EVERY := 1.5
const STAR_GUARD := 0.15
const STAR_HEAL := 2.0
const STAR_SLOW := 1.0
const FALL_EVERY := 6.0
const FALL_DAMAGE := 120.0
const FALL_RADIUS := 3.0
const FALL_STUN := 1.0
const GATE_BURST := 30.0
const GATE_BURST_RADIUS := 3.0
const GATE_HIDE := 2.0
const RIFT_STUN := 2.0
const TICK := 0.25 # marks and constellations are looked at four times a second
## The tree's switches, sent as bits.
const FLAGS := ["quick_stars", "stars_guard", "stars_heal", "star_slow", "star_lines", "falling_star", "gate_burst", "gate_hide", "rift_road"]
const AZURE := Color(0.42, 0.74, 1.0)
const STARLIGHT := Color(1.0, 0.9, 0.6)

var world: World
var owner_peer := 0
var cfg := {}
var beacons: Array[Dictionary] = [] # {at, age, node, yaw}
var _lines: Array[Node3D] = []
var _tick := 0.0
var _star_clock := 0.0
var _fall_clock := 0.0
static var _glow: StandardMaterial3D
static var _line_mat: StandardMaterial3D
static var _star_line_mat: StandardMaterial3D
static var _ring_mat: StandardMaterial3D
static var _portal_mat: ShaderMaterial
static var _post_meshes := {}


func _init(owner_world: World, peer: int) -> void:
	world = owner_world
	owner_peer = peer
	name = "Survey%d" % peer


## Beacon settings from another phone, held to what the skill tree can reach.
static func sane(cfg: Dictionary) -> Dictionary:
	var kind := str(cfg.get("kind", ""))
	return {"kind": kind if kind in ["", "stars", "gates", "finds"] else "",
		"max": clampi(int(cfg.get("max", CartographerKit.BEACONS)), 1, CartographerKit.BEACONS + 1),
		"link": clampf(float(cfg.get("link", CartographerKit.LINK)), 4.0, CartographerKit.LINK + 20.0),
		"radius": clampf(float(cfg.get("radius", CartographerKit.RADIUS)), 1.0, CartographerKit.RADIUS + 2.0),
		"heal": clampf(float(cfg.get("heal", CartographerKit.LINE_HEAL)), 0.0, CartographerKit.LINE_HEAL + 2.0),
		"mark": clampf(float(cfg.get("mark", CartographerKit.MARK)), 0.0, CartographerKit.MARK + 6.0),
		"bonus": clampf(float(cfg.get("bonus", CartographerKit.STAR_BONUS)), 0.0, CartographerKit.STAR_BONUS + 0.15),
		"power": clampf(float(cfg.get("power", CartographerKit.STAR_DAMAGE)), 0.0, CartographerKit.STAR_DAMAGE * 1.6),
		"gate_speed": clampf(float(cfg.get("gate_speed", CartographerKit.GATE_SPEED)), 0.0, CartographerKit.GATE_SPEED + 0.2),
		"gate_rest": clampf(float(cfg.get("gate_rest", CartographerKit.GATE_REST)), 0.5, CartographerKit.GATE_REST),
		"gate_heal": clampf(float(cfg.get("gate_heal", 0.0)), 0.0, 15.0),
		"bits": int(cfg.get("bits", 0)) & ((1 << FLAGS.size()) - 1)}


func has(flag: String) -> bool:
	return int(cfg.get("bits", 0)) & (1 << FLAGS.find(flag)) != 0


func kind() -> String:
	return str(cfg.get("kind", ""))


## A new beacon. The settings travel with it, so a Cartographer who has grown since keeps the lot up to date.
func add(at: Vector3, settings: Dictionary, yaw: float) -> void:
	var was_kind := kind()
	cfg = settings
	if was_kind != kind():
		# A new profession: the old markers are pulled up.
		for b: Dictionary in beacons:
			(b["node"] as Node3D).queue_free()
		beacons.clear()
	var node := _post(at, yaw)
	beacons.append({"at": at, "age": 0.0, "node": node, "yaw": yaw})
	while beacons.size() > int(cfg.get("max", CartographerKit.BEACONS)):
		(beacons.pop_front()["node"] as Node3D).queue_free()
	_rebuild_lines()
	if owner_is_here():
		world.show_ring(at, float(cfg.get("radius", CartographerKit.RADIUS)), Color(AZURE, 0.5))
		world.sfx_at("beacon_plant", at, -3.0)


## The Cartographer learned something: the beacons already standing work the new way too (a gate
## raised before Veiled Passage hides you all the same). A new profession waits for the next beacon,
## which pulls the old markers up.
func refresh(settings: Dictionary) -> void:
	if str(settings.get("kind", "")) != kind():
		return
	cfg = settings
	while beacons.size() > int(cfg.get("max", CartographerKit.BEACONS)):
		(beacons.pop_front()["node"] as Node3D).queue_free()
	_rebuild_lines()


## Whether this phone does the Cartographer's sums: its own player, or a bot on the host.
func owner_is_here() -> bool:
	if not Net.active():
		return true
	return owner_peer == Net.my_id() or (Net.is_host() and Net.is_bot(owner_peer))


func owner_player() -> Player:
	if world.player and world.player.net_id() == owner_peer:
		return world.player
	for bot: Player in Net.bot_pawns():
		if bot.net_id() == owner_peer:
			return bot
	return null


func is_friend(p: Player) -> bool:
	var peer := p.net_id()
	return peer == owner_peer or not Net.active() or not Net.bots_foes(owner_peer, peer)


func linked(i: int, j: int) -> bool:
	return i != j and _flat(beacons[i]["at"], beacons[j]["at"]) <= float(cfg.get("link", CartographerKit.LINK))


func links() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in beacons.size():
		for j in range(i + 1, beacons.size()):
			if linked(i, j):
				out.append(Vector2i(i, j))
	return out


## Three stones, each linked to the other two.
func triangles() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if kind() != "stars":
		return out
	var n := beacons.size()
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				if linked(i, j) and linked(j, k) and linked(i, k):
					out.append(Vector3i(i, j, k))
	return out


func in_constellation(at: Vector3) -> bool:
	for t in triangles():
		if _inside(at, beacons[t.x]["at"], beacons[t.y]["at"], beacons[t.z]["at"]):
			return true
	return false


func on_line(at: Vector3) -> bool:
	for l in links():
		if _to_segment(at, beacons[l.x]["at"], beacons[l.y]["at"]) <= LINE_REACH:
			return true
	return false


func near_beacon(at: Vector3, radius: float) -> bool:
	for b: Dictionary in beacons:
		if _flat(at, b["at"]) <= radius:
			return true
	return false


## Where starlight falls: inside a constellation, and with Star Lines on any line between stones.
func starlit(at: Vector3) -> bool:
	return in_constellation(at) or (kind() == "stars" and has("star_lines") and on_line(at))


func _physics_process(delta: float) -> void:
	var changed := false
	for i in range(beacons.size() - 1, -1, -1):
		beacons[i]["age"] = float(beacons[i]["age"]) + delta
		if float(beacons[i]["age"]) >= LIFE:
			(beacons[i]["node"] as Node3D).queue_free()
			beacons.remove_at(i)
			changed = true
	if changed:
		_rebuild_lines()
	if beacons.is_empty():
		return
	for p: Player in world.local_players():
		_tend(p, delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_mark()
	if kind() == "stars":
		_stars(delta)
	elif kind() == "gates" and has("rift_road") and (Net.is_host() or not Net.active()):
		_rift_road()


## One person on this phone, or a bot on the host.
func _tend(p: Player, delta: float) -> void:
	if p == null or p.dead or not is_friend(p):
		return
	var here := p.global_position
	if near_beacon(here, float(cfg.get("radius", CartographerKit.RADIUS))):
		p._act({"do": "buff", "key": "beacon_speed", "stat": "speed", "val": CartographerKit.SPEED, "secs": 0.3}, {})
	if p.hp < p.max_hp() and on_line(here):
		p.heal(float(cfg.get("heal", CartographerKit.LINE_HEAL)) * delta)
	match kind():
		"stars":
			if in_constellation(here):
				var bonus := float(cfg.get("bonus", CartographerKit.STAR_BONUS))
				for stat: String in ["melee_damage", "ranged_damage", "spell_damage"]:
					p._act({"do": "buff", "key": "stars_" + stat, "stat": stat, "val": bonus, "secs": 0.3}, {})
				if has("stars_guard"):
					p._act({"do": "buff", "key": "stars_guard", "stat": "damage_taken", "val": -STAR_GUARD, "secs": 0.3}, {})
				if has("stars_heal") and p.hp < p.max_hp():
					p.heal(STAR_HEAL * delta)
		"gates":
			_gate(p)


## Enemies close to a beacon show through walls for everyone on the Cartographer's side.
func _mark() -> void:
	if world.player == null or not is_friend(world.player):
		return
	var reach := float(cfg.get("mark", CartographerKit.MARK))
	for b: Dictionary in beacons:
		for z: Zombie in world.zombies_near(b["at"], reach, 30):
			z.reveal_left = maxf(z.reveal_left, TICK * 2.0)


# --- Star Reader ---------------------------------------------------------------

func _stars(delta: float) -> void:
	_star_clock += delta
	var every := QUICK_STAR_EVERY if has("quick_stars") else STAR_EVERY
	if _star_clock >= every:
		_star_clock -= every
		_starlight()
	if has("falling_star"):
		_fall_clock += delta
		if _fall_clock >= FALL_EVERY:
			_fall_clock -= FALL_EVERY
			if owner_is_here():
				_falling_star()


## Seconds until the next Falling Star, or -1 while none is coming (no Star Stones up, or not learned).
func next_fall() -> float:
	if kind() != "stars" or not has("falling_star") or beacons.is_empty():
		return -1.0
	return maxf(0.0, FALL_EVERY - _fall_clock)


## Every phone shows the starlight on the creatures it sees; only the Cartographer's phone deals it.
func _starlight() -> void:
	var dealing := owner_is_here()
	var who := owner_player() if dealing else null
	var dmg := float(cfg.get("power", CartographerKit.STAR_DAMAGE))
	var struck := 0
	for z: Zombie in _zombies_in_sky():
		show_starlight(world, z.position, z.centre().y - z.position.y)
		struck += 1
		if dealing:
			z.take_damage(dmg, Vector3.ZERO, 0.0, z.centre())
			if has("star_slow"):
				z.slow(STAR_SLOW)
	if dealing and who and Net.pvp():
		var was := world.begin_act(who)
		for r in world.rivals_near(_centre(), 60.0):
			if starlit(r.global_position):
				world.hit_rival(r, dmg, r.global_position + Vector3.UP * 6.0)
				show_starlight(world, r.global_position, 0.9)
				if has("star_slow"):
					world.status_rival(r, Net.Status.SLOW, STAR_SLOW)
				struck += 1
		world.end_act(was)
	if struck > 0 and dealing:
		world.sfx_at("starlight", _centre(), -6.0)


func _zombies_in_sky() -> Array[Zombie]:
	var out: Array[Zombie] = []
	for z: Zombie in world.zombies_near(_centre(), _span() + 2.0, 40):
		if z.is_alive() and starlit(z.position):
			out.append(z)
	return out


## The toughest creature under the stars has one fall on it.
func _falling_star() -> void:
	var best: Zombie = null
	for z: Zombie in _zombies_in_sky():
		if best == null or z.max_hp > best.max_hp:
			best = z
	if best == null:
		return
	var at := best.position
	show_falling_star(world, at)
	if Net.active():
		Net.survey_fx(0, at)
	for z: Zombie in world.zombies_near(at, FALL_RADIUS, 20):
		if z.is_alive():
			z.take_damage(FALL_DAMAGE, z.position - at, 3.0, z.centre())
			z.stun(FALL_STUN)
	var who := owner_player()
	if who and Net.pvp():
		var was := world.begin_act(who)
		for r in world.rivals_near(at, FALL_RADIUS):
			world.hit_rival(r, FALL_DAMAGE, at)
			world.status_rival(r, Net.Status.STUN, FALL_STUN)
		world.end_act(was)


## Starlight striking one creature: a shaft of pale gold light drops from high above onto it, a
## four-pointed star flares where it lands and a ring of light spreads on the ground under it.
## Only Star Stones make it, so it reads as theirs at a glance.
static func show_starlight(w: World, at: Vector3, chest := 0.9) -> void:
	if w == null or not w.is_inside_tree():
		return
	var root := Node3D.new()
	w.add_child(root)
	root.global_position = at
	var beam := MeshInstance3D.new()
	beam.mesh = _beam_mesh()
	beam.material_override = (_starlight_material("beam") as Material).duplicate()
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0, chest + BEAM_HEIGHT * 0.5, 0)
	beam.scale = Vector3(0.3, 1.0, 0.3)
	root.add_child(beam)
	# A wider, fainter sheath of light around the shaft.
	var halo := MeshInstance3D.new()
	halo.mesh = _beam_mesh()
	halo.material_override = (_starlight_material("halo") as Material).duplicate()
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = beam.position
	halo.scale = Vector3(1.0, 1.0, 1.0) * Vector3(0.9, 1.0, 0.9)
	root.add_child(halo)
	var star := MeshInstance3D.new()
	star.mesh = _quad(1.0)
	star.material_override = (_starlight_material("star") as Material).duplicate()
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.position = Vector3(0, chest * 1.6, 0) # on top of the creature, where the shaft strikes it
	star.scale = Vector3.ONE * 0.2
	root.add_child(star)
	var ring := MeshInstance3D.new()
	ring.mesh = _quad(1.0)
	ring.material_override = (_starlight_material("ring") as Material).duplicate()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.rotation.x = -PI * 0.5
	ring.position = Vector3(0, 0.06, 0)
	ring.scale = Vector3.ONE * 0.4
	root.add_child(ring)
	# One tween per part, each running its steps in turn.
	# The shaft lands in a blink, then thins away.
	var t := beam.create_tween()
	t.tween_property(beam, "scale", Vector3.ONE, 0.06)
	t.tween_interval(0.04)
	t.tween_property(beam, "scale", Vector3(0.05, 1.0, 0.05), 0.34).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(beam.material_override, "albedo_color:a", 0.0, 0.34)
	var th := halo.create_tween().set_parallel(true)
	th.tween_property(halo, "scale", Vector3(3.2, 1.0, 3.2), 0.42).set_ease(Tween.EASE_OUT)
	th.tween_property(halo.material_override, "albedo_color:a", 0.0, 0.42)
	# The star flares, turns a little and goes out.
	var ts := star.create_tween()
	ts.tween_interval(0.03)
	ts.tween_property(star, "scale", Vector3.ONE * 1.6, 0.09).set_ease(Tween.EASE_OUT)
	ts.tween_property(star, "scale", Vector3.ONE * 0.1, 0.34).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	ts.parallel().tween_property(star.material_override, "albedo_color:a", 0.0, 0.34)
	# The ring spreads on the ground; when it is gone, so is the rest.
	var tr := ring.create_tween()
	tr.tween_interval(0.04)
	tr.tween_property(ring, "scale", Vector3.ONE * 2.4, 0.5).set_ease(Tween.EASE_OUT)
	tr.parallel().tween_property(ring.material_override, "albedo_color:a", 0.0, 0.5)
	tr.tween_callback(root.queue_free)


const BEAM_HEIGHT := 9.0
static var _starlight_look := {}
static var _starlight_beam: Mesh
static var _starlight_quad: Mesh


static func _beam_mesh() -> Mesh:
	if _starlight_beam == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.04
		c.bottom_radius = 0.16
		c.height = BEAM_HEIGHT
		c.radial_segments = 8
		c.rings = 1
		c.cap_top = false
		c.cap_bottom = false
		_starlight_beam = c
	return _starlight_beam


static func _quad(size: float) -> Mesh:
	if _starlight_quad == null:
		var q := QuadMesh.new()
		q.size = Vector2.ONE * size
		_starlight_quad = q
	return _starlight_quad


## Additive, unlit and drawn over the fog: "beam" plain gold, "star" a four-pointed glint that always
## faces the camera, "ring" a thin circle of light for the ground.
static func _starlight_material(which: String) -> StandardMaterial3D:
	if not _starlight_look.has(which):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		m.no_depth_test = false
		match which:
			"beam":
				m.albedo_color = Color(1.0, 0.92, 0.66, 0.95)
			"halo":
				m.albedo_color = Color(1.0, 0.82, 0.45, 0.28)
			"star", "twinkle":
				m.albedo_color = Color(1.0, 0.94, 0.72, 1.0 if which == "star" else 0.85)
				m.albedo_texture = _glint_texture(true)
				m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				m.billboard_keep_scale = true
			"ring":
				m.albedo_color = Color(1.0, 0.86, 0.5, 0.8)
				m.albedo_texture = _glint_texture(false)
		_starlight_look[which] = m
	return _starlight_look[which]


## Made once: a four-pointed star with a soft middle, or a thin soft ring.
static func _glint_texture(star: bool) -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var a := 0.0
			if star:
				var r := sqrt(u * u + v * v)
				var arms := exp(-absf(u) * 22.0) * maxf(0.0, 1.0 - absf(v)) + exp(-absf(v) * 22.0) * maxf(0.0, 1.0 - absf(u))
				var diag := (exp(-absf(u - v) * 30.0) + exp(-absf(u + v) * 30.0)) * maxf(0.0, 1.0 - r * 1.8) * 0.5
				a = clampf(arms + diag + exp(-r * r * 30.0), 0.0, 1.0)
			else:
				var r2 := sqrt(u * u + v * v)
				a = exp(-pow((r2 - 0.82) / 0.07, 2.0)) + exp(-pow((r2 - 0.82) / 0.2, 2.0)) * 0.3
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func show_falling_star(w: World, at: Vector3) -> void:
	w.fx_spark(at + Vector3(-2.0, 14.0, 1.0), at + Vector3.UP * 0.2)
	w.fx_spark(at + Vector3(-1.6, 12.0, 0.6), at + Vector3.UP * 0.2)
	w.fx_blast(at + Vector3.UP * 0.4, FALL_RADIUS, Color(STARLIGHT, 0.6))
	if w.player:
		Sfx.play_at("falling_star", at, w.player.camera.global_position, -1.0)


# --- Worlds Traveler -----------------------------------------------------------------

## Stepping into a gate brings you out of the next one it is linked to.
func _gate(p: Player) -> void:
	if p.gate_rest_left > 0.0:
		return
	for i in beacons.size():
		if _flat(p.global_position, beacons[i]["at"]) > GATE_REACH:
			continue
		var j := _next_gate(i)
		if j < 0:
			return
		_travel(p, j)
		return


func _next_gate(i: int) -> int:
	for step in range(1, beacons.size()):
		var j := (i + step) % beacons.size()
		if linked(i, j):
			return j
	return -1


func _travel(p: Player, j: int) -> void:
	var from := p.global_position
	var ahead := -p.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
	var to: Vector3 = beacons[j]["at"] + ahead * 1.6
	to.y = world.ground_at(to) + 0.05
	p.global_position = to
	p.velocity = Vector3.ZERO
	p.gate_rest_left = float(cfg.get("gate_rest", CartographerKit.GATE_REST))
	p._act({"do": "buff", "key": "gate_speed", "stat": "speed", "val": float(cfg.get("gate_speed", CartographerKit.GATE_SPEED)), "secs": 2.0}, {})
	var mend := float(cfg.get("gate_heal", 0.0))
	if mend > 0.0:
		p.heal(mend)
	if has("gate_hide") and p.can_vanish():
		p.invis_left = maxf(p.invis_left, GATE_HIDE)
	world.fx_mist(from + Vector3.UP, 0.8)
	world.fx_mist(to + Vector3.UP, 0.8)
	world.sfx_at("waygate", to, -3.0)
	if has("gate_burst"):
		var was := world.begin_act(p)
		world.blast(to, GATE_BURST_RADIUS, GATE_BURST)
		world.end_act(was)
	if p == world.player:
		p.say("Through the Waygate")


## Rift Road: creatures stepping into a gate are thrown out of the farthest one, stunned.
func _rift_road() -> void:
	if beacons.size() < 2:
		return
	for i in beacons.size():
		for z: Zombie in world.zombies_near(beacons[i]["at"], GATE_REACH + 0.4, 6):
			if not z.is_alive() or float(z.get_meta("gate_rest", -10.0)) > world.now or z.is_boss() or z.def.get("hero", false):
				continue
			var far := i
			for j in beacons.size():
				if _flat(beacons[j]["at"], beacons[i]["at"]) > _flat(beacons[far]["at"], beacons[i]["at"]):
					far = j
			if far == i:
				continue
			var to: Vector3 = beacons[far]["at"] + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			to.y = world.ground_at(to)
			world.fx_mist(z.position + Vector3.UP, 0.8)
			z.position = to
			z.velocity = Vector3.ZERO
			z.set_meta("gate_rest", world.now + 4.0)
			z.stun(RIFT_STUN)
			world.fx_mist(to + Vector3.UP, 0.8)
			if Net.active():
				Net.survey_fx(1, to)
			world.sfx_at("waygate", to, -6.0)


# --- Shapes --------------------------------------------------------------------

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


static func _inside(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var pt := Vector2(p.x, p.z)
	var d1 := _side(pt, Vector2(a.x, a.z), Vector2(b.x, b.z))
	var d2 := _side(pt, Vector2(b.x, b.z), Vector2(c.x, c.z))
	var d3 := _side(pt, Vector2(c.x, c.z), Vector2(a.x, a.z))
	var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (neg and pos)


static func _side(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)


func _centre() -> Vector3:
	var sum := Vector3.ZERO
	for b: Dictionary in beacons:
		sum += b["at"]
	return sum / maxf(1.0, beacons.size())


func _span() -> float:
	var c := _centre()
	var r := 0.0
	for b: Dictionary in beacons:
		r = maxf(r, _flat(c, b["at"]))
	return r


# --- Looks ---------------------------------------------------------------------

## How high above the ground each kind's line of light runs.
func _lamp_height() -> float:
	return {"stars": 1.78, "gates": 2.25}.get(kind(), 1.7)


func _post(at: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh(kind())
	root.add_child(body)
	var lamp := MeshInstance3D.new()
	lamp.mesh = _lamp_mesh(kind())
	lamp.material_override = _glow_material()
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lamp)
	if kind() == "gates":
		var swirl := MeshInstance3D.new()
		var disc := QuadMesh.new()
		disc.size = Vector2(1.3, 1.9)
		swirl.mesh = disc
		swirl.material_override = _portal_material()
		swirl.position = Vector3(0, 1.05, 0)
		swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(swirl)
	# A faint pillar of light over the lamp, so a marker can be found across the map.
	if kind() != "gates":
		var pillar := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.03
		tube.bottom_radius = 0.09
		tube.height = 6.0
		tube.radial_segments = 8
		tube.rings = 1
		pillar.mesh = tube
		pillar.material_override = _pillar_material(kind() == "stars")
		pillar.position.y = _lamp_height() + 3.1
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pillar)
	# The reach of its light, faint on the ground.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.97
	torus.outer_radius = 1.0
	torus.rings = 40
	ring.mesh = torus
	ring.material_override = _ring_material()
	var r := float(cfg.get("radius", CartographerKit.RADIUS))
	ring.scale = Vector3(r, 0.4, r)
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = STARLIGHT if kind() == "stars" else AZURE
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.position.y = _lamp_height()
	root.add_child(light)
	return root


## Wood and stone, coloured in the mesh: a survey post, a standing stone or a stone arch.
static func _body_mesh(k: String) -> Mesh:
	if _post_meshes.has("body_" + k):
		return _post_meshes["body_" + k]
	var l := LowPoly.new()
	var wood := Color(0.48, 0.32, 0.18)
	var stone := Color(0.52, 0.53, 0.56)
	match k:
		"stars":
			l.prism(Vector3(0, 0, 0), Vector3(0, 1.45, 0), 0.32, 0.18, 5, stone)
			l.prism(Vector3(0, 1.45, 0), Vector3(0, 1.6, 0), 0.18, 0.08, 5, stone.lightened(0.1))
			l.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.8), stone.darkened(0.25))
		"gates":
			for x: float in [-0.75, 0.75]:
				l.box(Vector3(x, 1.05, 0), Vector3(0.26, 2.1, 0.32), stone)
				l.box(Vector3(x, 0.06, 0), Vector3(0.38, 0.12, 0.42), stone.darkened(0.25))
			l.box(Vector3(0, 2.18, 0), Vector3(1.9, 0.28, 0.36), stone.lightened(0.08))
			l.box(Vector3(0, 2.38, 0), Vector3(0.36, 0.14, 0.4), stone.darkened(0.1))
		_:
			l.prism(Vector3(0, 0, 0), Vector3(0, 1.5, 0), 0.055, 0.045, 6, wood)
			l.box(Vector3(0, 1.1, 0), Vector3(0.5, 0.06, 0.06), wood.lightened(0.1))
			l.box(Vector3(0.22, 1.32, 0), Vector3(0.36, 0.2, 0.015), Color(0.95, 0.75, 0.25))
			l.prism(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 0.2, 0.16, 6, stone.darkened(0.2))
			l.prism(Vector3(0, 1.5, 0), Vector3(0, 1.54, 0), 0.08, 0.08, 6, Color(0.78, 0.6, 0.24))
	var m := l.commit()
	_post_meshes["body_" + k] = m
	return m


## The part that glows: a crystal on the post, a star sign on the stone, a keystone on the arch.
static func _lamp_mesh(k: String) -> Mesh:
	if _post_meshes.has("lamp_" + k):
		return _post_meshes["lamp_" + k]
	var l := LowPoly.new()
	match k:
		"stars":
			l.prism(Vector3(0, 1.6, 0), Vector3(0, 1.78, 0), 0.0, 0.14, 4, STARLIGHT)
			l.prism(Vector3(0, 1.78, 0), Vector3(0, 1.98, 0), 0.14, 0.0, 4, STARLIGHT)
			l.box(Vector3(0, 0.85, 0.27), Vector3(0.05, 0.36, 0.02), STARLIGHT)
			l.box(Vector3(0, 0.88, 0.27), Vector3(0.3, 0.05, 0.02), STARLIGHT)
		"gates":
			l.box(Vector3(0, 2.38, 0.21), Vector3(0.18, 0.1, 0.02), AZURE)
			for x: float in [-0.75, 0.75]:
				l.box(Vector3(x, 1.4, 0.17), Vector3(0.06, 0.6, 0.02), AZURE)
		_:
			l.prism(Vector3(0, 1.54, 0), Vector3(0, 1.7, 0), 0.0, 0.12, 6, AZURE)
			l.prism(Vector3(0, 1.7, 0), Vector3(0, 1.92, 0), 0.12, 0.0, 6, AZURE)
	var m := l.commit()
	_post_meshes["lamp_" + k] = m
	return m


static func _glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.vertex_color_use_as_albedo = true
		_glow.disable_fog = true
	return _glow


static func _pillar_material(stars: bool) -> StandardMaterial3D:
	var key := "pillar_stars" if stars else "pillar"
	if not _post_meshes.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(STARLIGHT if stars else AZURE, 0.22)
		m.disable_fog = true
		_post_meshes[key] = m
	return _post_meshes[key]


static func _ring_material() -> StandardMaterial3D:
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.albedo_color = Color(AZURE, 0.35)
		_ring_mat.disable_fog = true
	return _ring_mat


static func _line_material(stars: bool) -> StandardMaterial3D:
	if stars and _star_line_mat:
		return _star_line_mat
	if not stars and _line_mat:
		return _line_mat
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(STARLIGHT if stars else AZURE, 0.75)
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if stars:
		_star_line_mat = m
	else:
		_line_mat = m
	return m


## The world beyond a Waygate: a slow azure swirl, brightest at its heart.
static func _portal_material() -> ShaderMaterial:
	if _portal_mat:
		return _portal_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	c.y *= 0.72;
	float r = length(c);
	float a = atan(c.y, c.x);
	float swirl = 0.5 + 0.5 * sin(a * 3.0 + r * 9.0 - TIME * 2.4);
	float body = smoothstep(1.0, 0.55, r);
	ALBEDO = mix(vec3(0.15, 0.4, 0.95), vec3(0.85, 0.95, 1.0), swirl * (1.0 - r));
	ALPHA = body * (0.35 + 0.45 * swirl);
}
"""
	_portal_mat = ShaderMaterial.new()
	_portal_mat.shader = sh
	return _portal_mat


func _rebuild_lines() -> void:
	for n in _lines:
		n.queue_free()
	_lines.clear()
	var h := _lamp_height()
	var stars := kind() == "stars"
	for l in links():
		var a: Vector3 = beacons[l.x]["at"] + Vector3.UP * h
		var b: Vector3 = beacons[l.y]["at"] + Vector3.UP * h
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, 1.0)
		beam.mesh = box
		beam.material_override = _line_material(stars)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		beam.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT)
		beam.scale = Vector3(1, 1, a.distance_to(b))
		_lines.append(beam)
	# Stars twinkle over each constellation.
	for t in triangles():
		var pts: Array[Vector3] = [beacons[t.x]["at"], beacons[t.y]["at"], beacons[t.z]["at"]]
		for i in 9:
			var u := randf()
			var v := randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			var spot: Vector3 = pts[0] + (pts[1] - pts[0]) * u + (pts[2] - pts[0]) * v
			spot.y = world.ground_at(spot) + randf_range(2.2, 3.4)
			# Little four-pointed stars, each twinkling in its own time.
			var mote := MeshInstance3D.new()
			mote.mesh = _quad(1.0)
			mote.material_override = _starlight_material("twinkle")
			mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mote.position = spot
			var size := randf_range(0.4, 0.62)
			mote.scale = Vector3.ONE * size
			add_child(mote)
			var tw := mote.create_tween().set_loops()
			tw.tween_interval(randf_range(0.0, 1.6))
			tw.tween_property(mote, "scale", Vector3.ONE * size * 0.35, 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(mote, "scale", Vector3.ONE * size, 0.5).set_trans(Tween.TRANS_SINE)
			_lines.append(mote)
