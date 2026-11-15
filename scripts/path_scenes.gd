class_name PathScenes
extends RefCounted
## The Store's scenes for the Class Upgrades of the Revenant, the Monk, the Plague Doctor, the Artificer
## and the Commander, and the Horse Archer's Wild Hunt: each one played on an UpgradeShowcase's stage
## with the class's own body and weapon, the night's zombies, and the same coil, sentry, rats and
## clouds the upgrade puts in a night. Layout is in camera space (UpgradeShowcase._at).

## How long one round of each scene lasts.
const LOOP := {"mist_wake": 3.6, "torn_rifts": 3.4, "soul_link": 3.6, "dragon_spin": 3.4, "fighting_body": 3.6,
	"avalanche": 3.6, "healing_mist": 3.6, "plague_censer": 3.8, "rat_tide": 3.4, "great_keg": 3.4,
	"field_turret": 3.4, "tesla_coil": 3.4, "arcane_surge": 3.4, "grapeshot": 3.6, "shield_wall": 3.6,
	"wild_hunt": 4.4, "mist_reinforcements": 3.6}

const MIST := Color(0.62, 0.92, 0.95)
const RIFT := Color(0.42, 0.85, 0.9)
const KI := Color(0.95, 0.75, 0.35)
const STONE := Color(0.8, 0.72, 0.55)
const HEAL := Color(0.45, 0.95, 0.55)
const PLAGUE := Color(0.55, 0.75, 0.2)
const FIRE := Color(1.0, 0.55, 0.15)
const SPARK := Color(0.65, 0.85, 1.0)
const ARCANE := Color(0.62, 0.4, 0.95)
const SHIELD := Color(1.0, 0.85, 0.45)


static func stage_height(id: String) -> float:
	match id:
		"wild_hunt", "great_keg", "tesla_coil", "shield_wall", "avalanche", "grapeshot", "rat_tide": return 4.2
		"mist_reinforcements": return 5.2
	return 3.9


static func camera_tilt(id: String) -> float:
	match id:
		"wild_hunt", "arcane_surge", "grapeshot": return 0.12
	return 0.24


static func view_turn(id: String) -> float:
	match id:
		"wild_hunt": return PI - 0.3
	return PI - 0.35


# --- Shared pieces ---------------------------------------------------------------------------

## The scenes are laid out on a stage this much wider than the numbers below say: the bodies are broad,
## and it keeps them apart.
const SPREAD := 1.0


## A spot on the ground as the camera sees it (UpgradeShowcase._at), spread out.
static func _sp(s: UpgradeShowcase, screen: Vector2) -> Vector3:
	return s._at(screen * SPREAD)


static func _dot(s: UpgradeShowcase, col: Color, radius: float, alpha := 1.0) -> MeshInstance3D:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 10
	ball.rings = 5
	var mi := s._piece(ball, s._glow(col, alpha))
	mi.visible = false
	return mi


## A thin bar, one metre long down its Z, for beams, links, sparks and arrows (see _lay).
static func _bar(s: UpgradeShowcase, col: Color, width: float, alpha := 1.0) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(width, width, 1.0)
	var mi := s._piece(box, s._glow(col, alpha))
	mi.visible = false
	return mi


## Lays a bar from a to b.
static func _lay(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	mi.visible = length > 0.01
	if not mi.visible:
		return
	var dir := (b - a) / length
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	mi.basis = Basis.looking_at(dir, up).scaled(Vector3(1, 1, length))
	mi.position = (a + b) * 0.5


## A jagged spark from a to b: a few short bars, re-jagged each time it is shown.
static func _spark(s: UpgradeShowcase, col: Color) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for i in 4:
		out.append(_bar(s, col, 0.045))
	return out


static func _lay_spark(bars: Array, a: Vector3, b: Vector3, on: bool, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var prev := a
	for i in bars.size():
		var bar: MeshInstance3D = bars[i]
		if not on:
			bar.visible = false
			continue
		var next := b if i == bars.size() - 1 else a.lerp(b, float(i + 1) / bars.size()) + Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
		_lay(bar, prev, next)
		prev = next


## Stars going round a stunned head.
static func _stars(s: UpgradeShowcase) -> Node3D:
	var root := Node3D.new()
	s.add_child(root)
	var star := BoxMesh.new()
	star.size = Vector3.ONE * 0.08
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = star
		mi.material_override = s._glow(Color(1.0, 0.92, 0.35))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	root.visible = false
	return root


static func _show_stars(st: Node3D, at: Vector3, t: float, on: bool) -> void:
	st.visible = on
	if not on:
		return
	st.position = at + Vector3.UP * 2.05
	for i in st.get_child_count():
		var a := t * 6.0 + TAU * i / st.get_child_count()
		(st.get_child(i) as Node3D).position = Vector3(cos(a) * 0.28, 0.04 * sin(a * 2.0), sin(a) * 0.28)


## Flames standing on a body or on the ground.
static func _flames(s: UpgradeShowcase, count: int) -> Array[MeshInstance3D]:
	var flame := s._mesh(func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3.UP * 0.45, 0.13, 0.0, 5, Color(1, 0.42, 0.06))
		l.prism(Vector3.ZERO, Vector3.UP * 0.26, 0.08, 0.0, 5, Color(1, 0.85, 0.15)))
	var out: Array[MeshInstance3D] = []
	for i in count:
		var f := s._piece(flame)
		f.visible = false
		out.append(f)
	return out


static func _show_flames(flames: Array, around: Vector3, spread: float, t: float, on: bool, high := 0.0) -> void:
	for i in flames.size():
		var f: MeshInstance3D = flames[i]
		f.visible = on
		if not on:
			continue
		var a := TAU * i / flames.size() + i * 0.5
		f.position = around + Vector3(cos(a) * spread, high + (i % 3) * 0.18 * signf(high), sin(a) * spread)
		f.scale = Vector3(1.0, 0.75 + 0.35 * sin(t * 17.0 + i * 1.9), 1.0)


## Gold-and-green crosses rising off someone mended.
static func _crosses(s: UpgradeShowcase, col: Color, count: int) -> Array[MeshInstance3D]:
	var cross := s._mesh(func(l: LowPoly) -> void:
		l.box(Vector3.ZERO, Vector3(0.07, 0.24, 0.07), col)
		l.box(Vector3.ZERO, Vector3(0.24, 0.07, 0.07), col))
	var out: Array[MeshInstance3D] = []
	for i in count:
		var c := s._piece(cross, s._glow(col))
		c.visible = false
		out.append(c)
	return out


static func _show_crosses(s: UpgradeShowcase, crosses: Array, body: Vector3, t: float, on: bool) -> void:
	for i in crosses.size():
		var c: MeshInstance3D = crosses[i]
		var k := fmod(t * 0.9 + float(i) / crosses.size(), 1.0)
		c.visible = on
		c.position = body + _sp(s, Vector2(-0.3 + 0.3 * i, 0.15)) + Vector3.UP * (0.9 + k * 1.2)
		c.scale = Vector3.ONE * (1.0 - k * 0.6)
		c.rotation.y = -s.rotation.y


## A low cloud on the ground: a soft disc and puffs drifting in it, radius 1.
static func _cloud(s: UpgradeShowcase, col: Color, puffs: int) -> Node3D:
	var root := Node3D.new()
	s.add_child(root)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.03
	disc.radial_segments = 32
	var wash := MeshInstance3D.new()
	wash.mesh = disc
	wash.material_override = s._glow(col, 0.2)
	wash.position.y = 0.06
	wash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wash)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	for i in puffs:
		var mi := MeshInstance3D.new()
		mi.mesh = ball
		mi.material_override = s._glow(col.lightened(0.2), 0.3)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("a", TAU * i / puffs + i * 0.37)
		mi.set_meta("r", 0.25 + 0.6 * fmod(i * 0.61, 1.0))
		root.add_child(mi)
	root.visible = false
	return root


## The cloud at `size` (its radius), `fade` from 0 to 1, drifting with t.
static func _show_cloud(cloud: Node3D, at: Vector3, size: float, fade: float, t: float) -> void:
	cloud.visible = fade > 0.01 and size > 0.01
	if not cloud.visible:
		return
	cloud.position = at
	var wash := cloud.get_child(0) as MeshInstance3D
	wash.scale = Vector3(size, 1, size)
	(wash.material_override as StandardMaterial3D).albedo_color.a = 0.2 * fade
	for i in range(1, cloud.get_child_count()):
		var mi := cloud.get_child(i) as MeshInstance3D
		var a: float = float(mi.get_meta("a")) + t * 0.6
		var r: float = float(mi.get_meta("r")) * size
		mi.position = Vector3(cos(a) * r, 0.3 + 0.12 * sin(t * 2.0 + a), sin(a) * r)
		mi.scale = Vector3(1.3, 0.65, 1.3) * size * 0.45 * (0.8 + 0.2 * sin(t * 1.7 + a))
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.3 * fade


## A zombie struck: it flinches, and (if `knock`) is pushed along `away`.
static func _struck(s: UpgradeShowcase, z: Dictionary, t: float, at_time: float) -> void:
	if t >= at_time and t < at_time + 0.05:
		s._played.erase(z["anim"])
		s._play(z["anim"], "Hit_A", 1.3)


static func _zombie_at(s: UpgradeShowcase, screen: Vector2, model := "normal_a", face := Vector2(0, 0.6)) -> Dictionary:
	var z := s._make_zombie(_sp(s, screen), model)
	(z["holder"] as Node3D).rotation.y = UpgradeShowcase._facing(_sp(s, screen), _sp(s, face))
	s._play(z["anim"], "Idle")
	z["home"] = screen
	return z


static func _person_at(s: UpgradeShowcase, class_id: String, weapon: String, screen: Vector2, face: Vector2) -> Dictionary:
	var p := s._make_person(class_id, weapon, _sp(s, screen))
	(p["holder"] as Node3D).rotation.y = UpgradeShowcase._facing(_sp(s, screen), _sp(s, face))
	return p


static func _ghostly(person: Dictionary) -> void:
	for part: MeshInstance3D in (person["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
		part.material_override = Ally._ghost()


# --- Building and playing ---------------------------------------------------------------------

static func build(s: UpgradeShowcase, id: String) -> void:
	s._ground_shadow(0.7)
	match id:
		"mist_wake": _build_mist_wake(s)
		"torn_rifts": _build_torn_rifts(s)
		"soul_link": _build_soul_link(s)
		"dragon_spin": _build_dragon_spin(s)
		"fighting_body": _build_fighting_body(s)
		"avalanche": _build_avalanche(s)
		"healing_mist": _build_healing_mist(s)
		"plague_censer": _build_censer(s)
		"rat_tide": _build_rat_tide(s)
		"great_keg": _build_keg(s)
		"field_turret": _build_turret(s)
		"tesla_coil": _build_tesla(s)
		"arcane_surge": _build_surge(s)
		"grapeshot": _build_grapeshot(s)
		"shield_wall": _build_shield_wall(s)
		"wild_hunt": _build_wild_hunt(s)
		"mist_reinforcements": _build_reinforcements(s)


static func play(s: UpgradeShowcase, id: String, t: float) -> void:
	match id:
		"mist_wake": _mist_wake(s, t)
		"torn_rifts": _torn_rifts(s, t)
		"soul_link": _soul_link(s, t)
		"dragon_spin": _dragon_spin(s, t)
		"fighting_body": _fighting_body(s, t)
		"avalanche": _avalanche(s, t)
		"healing_mist": _healing_mist(s, t)
		"plague_censer": _censer(s, t)
		"rat_tide": _rat_tide(s, t)
		"great_keg": _keg(s, t)
		"field_turret": _turret(s, t)
		"tesla_coil": _tesla(s, t)
		"arcane_surge": _surge(s, t)
		"grapeshot": _grapeshot(s, t)
		"shield_wall": _shield_wall(s, t)
		"wild_hunt": _wild_hunt(s, t)
		"mist_reinforcements": _reinforcements(s, t)


# --- Mist Wake: the Revenant bounds in, lands, and the mist it leaves slows and bites -------------

const WAKE_FROM := Vector2(-1.5, -0.7)
const WAKE_TO := Vector2(0.15, 0.05)

static func _build_mist_wake(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "revenant", "claws", WAKE_FROM, WAKE_TO)
	s._parts["pool"] = _cloud(s, MIST, 9)
	s._parts["land"] = s._puff(MIST, 7)
	s._parts["foes"] = [_zombie_at(s, Vector2(2.0, -0.9), "normal_a"), _zombie_at(s, Vector2(1.9, 0.55), "normal_b")]
	var bites: Array[MeshInstance3D] = []
	for i in 4:
		bites.append(_dot(s, MIST, 0.05))
	s._parts["bites"] = bites


static func _mist_wake(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var k := UpgradeShowcase._window(t, 0.25, 0.7)
	var ground := _sp(s, WAKE_FROM).lerp(_sp(s, WAKE_TO), k)
	holder.position = ground + Vector3.UP * sin(k * PI) * 1.2
	holder.rotation.y = UpgradeShowcase._facing(_sp(s, WAKE_FROM), _sp(s, WAKE_TO)) if t < 0.8 else lerp_angle(holder.rotation.y, UpgradeShowcase._facing(_sp(s, WAKE_TO), _sp(s, Vector2(0.6, 1.5))), 0.1)
	s._play(s._person["anim"], "Vault" if t > 0.2 and t < 0.75 else "Idle")
	s._show_puff(s._parts["land"], t - 0.7, 0.6, 0.6)
	(s._parts["land"] as Node3D).position = _sp(s, WAKE_TO) + Vector3.UP * 0.4
	var open := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, 0.7, 1.0)) * (1.0 - UpgradeShowcase._window(t, 3.1, 3.5))
	_show_cloud(s._parts["pool"], _sp(s, WAKE_TO), 1.4 * open, open, t)
	var foes: Array = s._parts["foes"]
	var bites: Array = s._parts["bites"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var from := _sp(s, z["home"])
		var dir := (_sp(s, WAKE_TO) - from).normalized()
		# Walking in at a zombie's pace, then wading at half of it once in the mist.
		var d := t * 0.65 if t < 1.6 else 1.6 * 0.65 + (t - 1.6) * 0.25
		zh.position = from + dir * minf(d, 0.6)
		zh.rotation.y = atan2(-dir.x, -dir.z)
		var inside := zh.position.distance_to(_sp(s, WAKE_TO)) < 1.4 * open
		s._play(z["anim"], "Walking_A", 0.4 if inside else 1.0)
		zh.visible = t < 3.45
		for j in 2:
			var b: MeshInstance3D = bites[i * 2 + j]
			var rise := fmod(t * 1.3 + j * 0.5 + i * 0.25, 1.0)
			b.visible = inside and zh.visible
			b.position = zh.position + Vector3(0.2 * (j * 2 - 1), 0.5 + rise * 1.2, 0)


# --- Torn Rifts: three hops through three zombies, and each one tears open after ---------------

const TORN := [Vector2(-1.2, -0.5), Vector2(0.15, -1.05), Vector2(1.25, -0.35)]
const RIFT_HOME := Vector2(0.0, 0.65)

static func _build_torn_rifts(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "revenant", "claws", RIFT_HOME, Vector2(0, -1))
	var foes: Array[Dictionary] = []
	var tears: Array[MeshInstance3D] = []
	var bursts: Array[Node3D] = []
	var tear := s._mesh(func(l: LowPoly) -> void:
		l.gable(Vector3(-0.05, -0.45, 0), Vector3(0.05, -0.45, 0), Vector3(0.0, 0.45, 0), Color(1, 1, 1))
		l.gable(Vector3(-0.12, 0.0, 0), Vector3(0.0, 0.25, 0), Vector3(0.1, -0.2, 0), Color(1, 1, 1)))
	for i in TORN.size():
		foes.append(_zombie_at(s, TORN[i], "normal_a" if i % 2 == 0 else "normal_b", RIFT_HOME))
		var mark := s._piece(tear, s._glow(RIFT))
		mark.visible = false
		tears.append(mark)
		bursts.append(s._puff(RIFT, 7))
	s._parts["foes"] = foes
	s._parts["tears"] = tears
	s._parts["bursts"] = bursts
	s._parts["blinks"] = [s._puff(MIST, 5), s._puff(MIST, 5), s._puff(MIST, 5), s._puff(MIST, 5)]


static func _torn_rifts(s: UpgradeShowcase, t: float) -> void:
	const HOPS := [0.35, 0.6, 0.85]
	const BURST := 1.35
	var holder: Node3D = s._person["holder"]
	var foes: Array = s._parts["foes"]
	var tears: Array = s._parts["tears"]
	var blinks: Array = s._parts["blinks"]
	var at := _sp(s, RIFT_HOME)
	var hop := -1
	for i in HOPS.size():
		if t >= HOPS[i]:
			hop = i
	if hop >= 0 and t < 2.4:
		var z: Vector3 = (foes[hop]["holder"] as Node3D).position
		at = z + (_sp(s, RIFT_HOME) - z).normalized() * 0.75
		holder.rotation.y = UpgradeShowcase._facing(at, z)
		s._play(s._person["anim"], "Sweep", 1.4)
	else:
		holder.rotation.y = UpgradeShowcase._facing(at, _sp(s, Vector2(0, -1)))
		s._play(s._person["anim"], "Idle")
	holder.position = at
	for i in blinks.size():
		var when: float = HOPS[i] if i < 3 else 2.4
		(blinks[i] as Node3D).position = (_sp(s, RIFT_HOME) if i == 0 or i == 3 else ((foes[i - 1]["holder"] as Node3D).position + (_sp(s, RIFT_HOME) - (foes[i - 1]["holder"] as Node3D).position).normalized() * 0.75)) + Vector3.UP
		s._show_puff(blinks[i], t - when, 0.45, 0.5)
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home: Vector3 = _sp(s, z["home"])
		var torn: bool = t >= HOPS[i] and t < BURST
		var tear: MeshInstance3D = tears[i]
		tear.visible = torn
		tear.position = home + Vector3.UP * 1.05 + (_sp(s, RIFT_HOME) - home).normalized() * 0.3
		tear.rotation.y = -s.rotation.y
		tear.scale = Vector3.ONE * (0.8 + 0.25 * sin(t * 30.0 + i))
		_struck(s, z, t, HOPS[i])
		_struck(s, z, t, BURST)
		var thrown := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, BURST, BURST + 0.3)) * (1.0 - UpgradeShowcase._window(t, 2.8, 3.3))
		zh.position = home + (home - _sp(s, RIFT_HOME)).normalized() * 0.45 * thrown
		s._show_puff(s._parts["bursts"][i], t - BURST, 0.6, 0.7)
		(s._parts["bursts"][i] as Node3D).position = home + Vector3.UP
		if t > BURST + 0.6 and t < BURST + 0.7:
			s._play(z["anim"], "Idle")


# --- Soul Link: a hit on the Summoner is shared down the link; the Revenant falls, and gives back ----

const LINKED := Vector2(-0.55, 0.25)
const CALLED := Vector2(0.7, -0.35)
const LINK_FOE := Vector2(-1.55, -0.35)

static func _build_soul_link(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "revenant", "claws", LINKED, LINK_FOE)
	var called := _person_at(s, "revenant", "claws", CALLED, LINK_FOE)
	_ghostly(called)
	s._parts["called"] = called
	s._parts["links"] = [_bar(s, MIST, 0.035, 0.85), _bar(s, MIST, 0.02, 0.5)]
	s._parts["pulse"] = _dot(s, Color(1, 1, 1), 0.09)
	s._parts["foe"] = _zombie_at(s, LINK_FOE, "normal_b", LINKED)
	s._parts["fade"] = s._puff(MIST, 7)
	s._parts["gift"] = _crosses(s, HEAL, 1)
	s._parts["mends"] = _crosses(s, HEAL, 3)


static func _soul_link(s: UpgradeShowcase, t: float) -> void:
	const BLOW := 1.0
	const FALL := 2.0
	var me := _sp(s, LINKED) + Vector3.UP * 1.1
	var called: Dictionary = s._parts["called"]
	var ch: Node3D = called["holder"]
	var there := _sp(s, CALLED) + Vector3.UP * 1.1
	var alive := t < FALL
	ch.visible = t < FALL + 0.3
	ch.scale = Vector3.ONE * (1.0 - UpgradeShowcase._window(t, FALL, FALL + 0.3) * 0.9)
	var links: Array = s._parts["links"]
	for i in links.size():
		var bar: MeshInstance3D = links[i]
		if alive:
			_lay(bar, me + Vector3.UP * 0.08 * i * sin(t * 9.0), there + Vector3.UP * 0.08 * i * cos(t * 7.0))
		else:
			bar.visible = false
	var pulse: MeshInstance3D = s._parts["pulse"]
	var go := UpgradeShowcase._window(t, BLOW, BLOW + 0.3)
	pulse.visible = go > 0.0 and go < 1.0
	pulse.position = me.lerp(there, go)
	var foe: Dictionary = s._parts["foe"]
	var fh: Node3D = foe["holder"]
	var stand := _sp(s, LINKED) + (_sp(s, LINK_FOE) - _sp(s, LINKED)).normalized() * 0.85
	fh.position = _sp(s, LINK_FOE).lerp(stand, UpgradeShowcase._window(t, 0.0, 0.65))
	if t < 0.65:
		s._play(foe["anim"], "Walking_A")
	elif t < 1.5:
		s._play(foe["anim"], "1H_Melee_Attack_Chop")
	else:
		s._play(foe["anim"], "Idle")
	_struck(s, s._person, t, BLOW)
	_struck(s, called, t, BLOW + 0.3)
	if t > BLOW + 0.8 and t < BLOW + 0.9:
		s._play(s._person["anim"], "Idle")
		s._play(called["anim"], "Idle")
	s._show_puff(s._parts["fade"], t - FALL, 0.7, 0.7)
	(s._parts["fade"] as Node3D).position = there
	var gift: MeshInstance3D = s._parts["gift"][0]
	var back := UpgradeShowcase._window(t, FALL + 0.1, FALL + 0.6)
	gift.visible = back > 0.0 and back < 1.0
	gift.position = there.lerp(me, back) + Vector3.UP * sin(back * PI) * 0.5
	gift.rotation.y = -s.rotation.y
	_show_crosses(s, s._parts["mends"], _sp(s, LINKED), t, t > FALL + 0.6 and t < 3.4)


# --- Dragon Spin: the vault, and three turns of the Bo that drag everything in --------------------

const SPIN_FROM := Vector2(-1.5, 0.3)
const SPIN_AT := Vector2(0.0, -0.1)
const SPIN_HITS := [0.85, 1.35, 1.85]

static func _build_dragon_spin(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "monk", "bo", SPIN_FROM, SPIN_AT)
	var foes: Array[Dictionary] = []
	for i in 3:
		var a := PI * 0.15 + TAU * i / 3.0
		foes.append(_zombie_at(s, SPIN_AT + Vector2(cos(a), sin(a) * 0.8) * 1.45, "normal_a" if i % 2 == 0 else "normal_b", SPIN_AT))
	s._parts["foes"] = foes
	s._parts["rings"] = [s._ring(KI, 0.8, 0.06), s._ring(KI, 0.8, 0.06), s._ring(KI, 0.8, 0.06)]
	s._parts["land"] = s._puff(Color(0.75, 0.68, 0.56), 6)


static func _dragon_spin(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var k := UpgradeShowcase._window(t, 0.15, 0.55)
	holder.position = _sp(s, SPIN_FROM).lerp(_sp(s, SPIN_AT), k) + Vector3.UP * sin(k * PI) * 1.3
	var spin := UpgradeShowcase._window(t, 0.6, 2.1)
	holder.rotation.y = UpgradeShowcase._facing(_sp(s, SPIN_FROM), _sp(s, SPIN_AT)) + spin * TAU * 3.0
	if t < 0.6:
		s._play(s._person["anim"], "Vault" if t > 0.1 else "Idle")
	elif t < 2.1:
		s._play(s._person["anim"], "BoSpin", 1.6)
	else:
		s._play(s._person["anim"], "Idle")
	s._show_puff(s._parts["land"], t - 0.55, 0.5, 0.5)
	(s._parts["land"] as Node3D).position = _sp(s, SPIN_AT) + Vector3.UP * 0.2
	var rings: Array = s._parts["rings"]
	for i in rings.size():
		var r: MeshInstance3D = rings[i]
		var g := UpgradeShowcase._window(t, SPIN_HITS[i], SPIN_HITS[i] + 0.35)
		r.visible = g > 0.0 and g < 1.0
		r.position = _sp(s, SPIN_AT) + Vector3.UP * (0.6 + 0.2 * i)
		r.scale = Vector3.ONE * (0.4 + g * 1.2)
		(r.material_override as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - g)
	var foes: Array = s._parts["foes"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		var pulled := 0.0
		for when: float in SPIN_HITS:
			pulled += UpgradeShowcase._ease_out(UpgradeShowcase._window(t, when, when + 0.2)) * 0.18
			_struck(s, z, t, when)
		pulled *= 1.0 - UpgradeShowcase._window(t, 3.0, 3.35)
		zh.position = home.lerp(_sp(s, SPIN_AT), pulled)
		if t > 2.3 and t < 2.35:
			s._play(z["anim"], "Idle")


# --- Fighting Body: the spirit walks off; the body left sitting strikes what comes for it ----------

const BODY_AT := Vector2(0.25, 0.0)
const SPIRIT_TO := Vector2(-1.3, -0.7)
const BODY_FOE := Vector2(1.7, -0.35)
const BODY_BLOWS := [1.1, 2.1, 3.1]

static func _build_fighting_body(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "monk", "fists", BODY_AT, BODY_FOE)
	var spirit := _person_at(s, "monk", "fists", BODY_AT, SPIRIT_TO)
	_ghostly(spirit)
	s._parts["spirit"] = spirit
	s._parts["foe"] = _zombie_at(s, BODY_FOE, "normal_a", BODY_AT)
	s._parts["impacts"] = [s._puff(KI, 5), s._puff(KI, 5), s._puff(KI, 5)]


static func _fighting_body(s: UpgradeShowcase, t: float) -> void:
	var spirit: Dictionary = s._parts["spirit"]
	var sh: Node3D = spirit["holder"]
	var out := UpgradeShowcase._window(t, 0.15, 1.2)
	var back := UpgradeShowcase._window(t, 3.25, 3.55)
	sh.position = _sp(s, BODY_AT).lerp(_sp(s, SPIRIT_TO), out * (1.0 - back))
	sh.visible = t > 0.1 and t < 3.55
	s._play(spirit["anim"], "Walking_A" if out > 0.0 and out < 1.0 else "Idle")
	var striking := false
	for when: float in BODY_BLOWS:
		if t >= when and t < when + 0.45:
			striking = true
	s._play(s._person["anim"], "Unarmed_Melee_Attack_Punch_A" if striking else ("Meditate" if t > 0.1 else "Idle"), 1.4 if striking else 1.0)
	var foe: Dictionary = s._parts["foe"]
	var fh: Node3D = foe["holder"]
	var reach := _sp(s, BODY_AT) + (_sp(s, BODY_FOE) - _sp(s, BODY_AT)).normalized() * 0.9
	var knock := 0.0
	for when: float in BODY_BLOWS:
		knock += UpgradeShowcase._ease_out(UpgradeShowcase._window(t, when + 0.15, when + 0.35)) * (1.0 - UpgradeShowcase._window(t, when + 0.4, when + 0.9)) * 0.35
		_struck(s, foe, t, when + 0.15)
	fh.position = _sp(s, BODY_FOE).lerp(reach, UpgradeShowcase._window(t, 0.0, 1.0)) + (_sp(s, BODY_FOE) - _sp(s, BODY_AT)).normalized() * knock
	if t < 1.0:
		s._play(foe["anim"], "Walking_A")
	elif fmod(t, 1.0) > 0.55 and fmod(t, 1.0) < 0.6:
		s._play(foe["anim"], "1H_Melee_Attack_Chop")
	var impacts: Array = s._parts["impacts"]
	for i in impacts.size():
		(impacts[i] as Node3D).position = reach + Vector3.UP * 1.1
		s._show_puff(impacts[i], t - BODY_BLOWS[i] - 0.15, 0.35, 0.35)


# --- Avalanche: the stomp, then a wider ring of stone a moment later that stuns ----------------------

const STOMP_AT := Vector2(0.0, 0.1)

static func _build_avalanche(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "monk", "fists", STOMP_AT, Vector2(0, 2))
	var foes: Array[Dictionary] = []
	var stars: Array[Node3D] = []
	for i in 3:
		var a := PI * 0.95 + PI * 1.1 * i / 2.0
		foes.append(_zombie_at(s, STOMP_AT + Vector2(cos(a) * 1.4, sin(a) * 0.9 - 0.15), "normal_a" if i % 2 == 0 else "normal_b", STOMP_AT))
		stars.append(_stars(s))
	s._parts["foes"] = foes
	s._parts["stars"] = stars
	s._parts["first"] = s._ring(STONE, 0.9, 0.08)
	s._parts["second"] = s._ring(STONE, 0.9, 0.05)
	var spike := s._mesh(func(l: LowPoly) -> void:
		l.prism(Vector3.ZERO, Vector3(0.05, 0.55, 0.02), 0.16, 0.02, 5, Color(0.55, 0.5, 0.44))
		l.prism(Vector3(0.12, 0, 0.05), Vector3(0.16, 0.35, 0.06), 0.1, 0.02, 4, Color(0.62, 0.57, 0.5)))
	var spikes: Array[MeshInstance3D] = []
	for i in 16:
		var sp := s._piece(spike)
		sp.set_meta("a", TAU * i / 16.0)
		sp.visible = false
		spikes.append(sp)
	s._parts["spikes"] = spikes
	s._parts["dust"] = s._puff(Color(0.7, 0.62, 0.5), 8)


static func _avalanche(s: UpgradeShowcase, t: float) -> void:
	const STOMP := 0.4
	const SECOND := STOMP + PathUpgrades.AVALANCHE_DELAY
	s._play(s._person["anim"], "Stomp" if t > 0.1 and t < 1.0 else "Idle")
	var centre := _sp(s, STOMP_AT)
	var first: MeshInstance3D = s._parts["first"]
	var g := UpgradeShowcase._window(t, STOMP, STOMP + 0.3)
	first.visible = g > 0.0 and g < 1.0
	first.position = centre + Vector3.UP * 0.04
	first.scale = Vector3.ONE * (0.2 + g * 0.8)
	(first.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - g)
	s._show_puff(s._parts["dust"], t - STOMP, 0.5, 0.7)
	(s._parts["dust"] as Node3D).position = centre + Vector3.UP * 0.2
	var second: MeshInstance3D = s._parts["second"]
	var g2 := UpgradeShowcase._window(t, SECOND, SECOND + 0.35)
	second.visible = g2 > 0.0 and g2 < 1.0
	second.position = centre + Vector3.UP * 0.04
	second.scale = Vector3.ONE * (0.6 + g2 * 1.4)
	(second.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - g2)
	var rise := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, SECOND, SECOND + 0.2)) * (1.0 - UpgradeShowcase._window(t, 2.6, 3.1))
	for sp: MeshInstance3D in s._parts["spikes"]:
		var a: float = sp.get_meta("a")
		sp.visible = rise > 0.02
		sp.position = centre + Vector3(cos(a) * 1.55, -0.6 * (1.0 - rise), sin(a) * 1.55)
		sp.rotation = Vector3(0.25 * sin(a * 3.0), a, 0.25 * cos(a * 2.0))
	var foes: Array = s._parts["foes"]
	var stars: Array = s._parts["stars"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		_struck(s, z, t, SECOND + 0.1)
		var shove := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, SECOND + 0.1, SECOND + 0.3)) * (1.0 - UpgradeShowcase._window(t, 3.0, 3.4)) * 0.25
		zh.position = home + (home - centre).normalized() * shove
		_show_stars(stars[i], zh.position, t, t > SECOND + 0.2 and t < SECOND + 0.2 + PathUpgrades.AVALANCHE_STUN)
		if t > 3.0 and t < 3.05:
			s._play(z["anim"], "Idle")


# --- Healing Mist: a draught of the Tonic, and the cloud it leaves mends and puts out fire ----------

const DOCTOR := Vector2(-0.45, 0.15)
const PATIENT := Vector2(0.75, -0.25)

static func _build_healing_mist(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "plague_doctor", "blowgun", DOCTOR, Vector2(0.3, 2))
	s._parts["friend"] = _person_at(s, "infantry", "dagger", PATIENT, Vector2(0, 2))
	s._parts["cloud"] = _cloud(s, HEAL, 10)
	s._parts["fire"] = _flames(s, 4)
	s._parts["mine"] = _crosses(s, HEAL, 3)
	s._parts["theirs"] = _crosses(s, HEAL, 3)
	s._parts["smoke"] = s._puff(Color(0.5, 0.5, 0.5), 5)


static func _healing_mist(s: UpgradeShowcase, t: float) -> void:
	s._play(s._person["anim"], "Whistle" if t > 0.05 and t < 0.75 else "Idle") # the flask to the beak
	var friend: Dictionary = s._parts["friend"]
	var centre := _sp(s, Vector2(0.15, -0.05))
	var open := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, 0.6, 1.0)) * (1.0 - UpgradeShowcase._window(t, 3.0, 3.5))
	_show_cloud(s._parts["cloud"], centre, 1.5 * open, open, t)
	var burning := t < 1.0
	_show_flames(s._parts["fire"], _sp(s, PATIENT) + Vector3.UP * 0.6, 0.2, t, burning, 0.4)
	s._play(friend["anim"], "Hit_A" if t < 0.9 and fmod(t, 0.45) < 0.05 else "Idle")
	s._show_puff(s._parts["smoke"], t - 1.0, 0.6, 0.45)
	(s._parts["smoke"] as Node3D).position = _sp(s, PATIENT) + Vector3.UP * 1.2
	_show_crosses(s, s._parts["mine"], _sp(s, DOCTOR), t, open > 0.6 and t < 3.0)
	_show_crosses(s, s._parts["theirs"], _sp(s, PATIENT), t + 0.4, open > 0.6 and t < 3.0)


# --- Plague Censer: the cloud goes with the Plague Doctor, and sickens and slows what is in it -------

static func _build_censer(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "plague_doctor", "blowgun", Vector2(-1.0, 0.2), Vector2(1.0, 0.0))
	s._parts["cloud"] = _cloud(s, PLAGUE, 12)
	var censer := s._mesh(func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0.0, 0), Vector3(0, 0.6, 0), 0.01, 0.01, 3, Color(0.3, 0.28, 0.25))
		l.prism(Vector3(0, -0.18, 0), Vector3(0, 0.0, 0), 0.12, 0.09, 8, Color(0.72, 0.56, 0.22))
		l.prism(Vector3(0, 0.0, 0), Vector3(0, 0.08, 0), 0.09, 0.0, 8, Color(0.72, 0.56, 0.22)))
	s._parts["censer"] = s._piece(censer)
	s._parts["fumes"] = s._puff(PLAGUE, 4)
	s._parts["foes"] = [_zombie_at(s, Vector2(0.25, -0.75), "normal_a", Vector2(-1, 0)), _zombie_at(s, Vector2(1.1, 0.55), "normal_b", Vector2(-1, 0))]
	var bubbles: Array[MeshInstance3D] = []
	for i in 6:
		bubbles.append(_dot(s, Color(0.6, 0.95, 0.25), 0.05))
	s._parts["bubbles"] = bubbles


static func _censer(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var walk := UpgradeShowcase._window(t, 0.2, 3.2)
	var here := _sp(s, Vector2(-1.0, 0.2)).lerp(_sp(s, Vector2(0.45, 0.05)), walk)
	holder.position = here
	holder.rotation.y = UpgradeShowcase._facing(_sp(s, Vector2(-1.0, 0.2)), _sp(s, Vector2(1.0, 0.0)))
	s._play(s._person["anim"], "Walking_A" if walk > 0.0 and walk < 1.0 else "Idle", 0.55)
	var censer: MeshInstance3D = s._parts["censer"]
	var swing := sin(t * 4.5) * 0.7
	var forward := (_sp(s, Vector2(1.0, 0.0)) - _sp(s, Vector2(-1.0, 0.2))).normalized()
	var side := forward.cross(Vector3.UP)
	censer.position = here + Vector3.UP * 0.45 + forward * 0.45 + side * -0.25
	censer.rotation = Vector3(0, 0, 0)
	censer.basis = Basis(side, swing)
	var open := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, 0.1, 0.5)) * (1.0 - UpgradeShowcase._window(t, 3.4, 3.8))
	_show_cloud(s._parts["cloud"], here, 1.35 * open, open, t)
	s._show_puff(s._parts["fumes"], fmod(t, 0.5), 0.5, 0.3)
	(s._parts["fumes"] as Node3D).position = censer.position + Vector3.DOWN * 0.1
	var foes: Array = s._parts["foes"]
	var bubbles: Array = s._parts["bubbles"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		var dir := (here - home).normalized()
		var inside := zh.position.distance_to(here) < 1.35 * open
		zh.position = home + dir * minf(t * 0.12, 0.4)
		zh.rotation.y = atan2(-dir.x, -dir.z)
		s._play(z["anim"], "Walking_A", 0.35 if inside else 0.9)
		zh.visible = t < 3.7
		for j in 3:
			var b: MeshInstance3D = bubbles[i * 3 + j]
			var rise := fmod(t * 0.9 + j / 3.0 + i * 0.2, 1.0)
			b.visible = inside and zh.visible
			b.position = zh.position + Vector3(0.15 * (j - 1), 1.9 + rise * 0.5, 0)
			b.scale = Vector3.ONE * (1.0 - rise * 0.5)


# --- Rat Tide: the rats pour out along a line and bowl over what is in it -------------------------

const KING := Vector2(1.25, 0.35)
const TIDE_DIR := Vector2(-1.0, -0.05)

static func _build_rat_tide(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "plague_doctor", "blowgun", KING, KING + TIDE_DIR)
	var dir := (_sp(s, KING + TIDE_DIR) - _sp(s, KING)).normalized()
	var tide := RatTide.new(_sp(s, KING) + dir * 0.4, dir)
	tide.reach = 3.6
	tide.loop = 3.4
	s.add_child(tide)
	s._parts["tide"] = tide
	var foes: Array[Dictionary] = []
	var stars: Array[Node3D] = []
	for x: float in [0.25, -0.75]:
		foes.append(_zombie_at(s, Vector2(x, KING.y - 0.1), "normal_a" if x > 0 else "normal_b", KING))
		stars.append(_stars(s))
	s._parts["foes"] = foes
	s._parts["stars"] = stars


static func _rat_tide(s: UpgradeShowcase, t: float) -> void:
	s._play(s._person["anim"], "Spellcast_Shoot" if t < 0.6 else "Idle")
	var foes: Array = s._parts["foes"]
	var stars: Array = s._parts["stars"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		# The rats reach it a little after they set off: then it goes over backwards, and gets up.
		var reach_at := 0.15 + (KING.x - float((z["home"] as Vector2).x)) / 3.6 * PathUpgrades.RAT_TIDE_TIME
		var down := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, reach_at, reach_at + 0.2)) * (1.0 - UpgradeShowcase._window(t, reach_at + 0.2 + PathUpgrades.RAT_TIDE_STUN + 0.5, reach_at + 1.6))
		zh.rotation.x = 0.0
		(z["node"] as Node3D).rotation.x = -down * 1.2
		zh.position = _sp(s, z["home"]) + Vector3.UP * down * 0.15
		_struck(s, z, t, reach_at)
		_show_stars(stars[i], zh.position + Vector3.DOWN * down * 1.2, t, down > 0.5)


# --- Great Keg: a keg instead of a bomb, and the blast twice as wide ----------------------------------

const THROWER := Vector2(1.15, 0.3)
const KEG_AT := Vector2(-0.55, -0.45)

static func _build_keg(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "artificer", "torch", THROWER, KEG_AT)
	var keg := s._mesh(func(l: LowPoly) -> void:
		l.prism(Vector3(0, -0.22, 0), Vector3(0, 0.22, 0), 0.2, 0.2, 8, Color(0.46, 0.3, 0.16))
		l.prism(Vector3(0, -0.02, 0), Vector3(0, 0.02, 0), 0.23, 0.23, 8, Color(0.3, 0.29, 0.28))
		l.prism(Vector3(0, -0.17, 0), Vector3(0, -0.13, 0), 0.215, 0.215, 8, Color(0.3, 0.29, 0.28))
		l.prism(Vector3(0, 0.13, 0), Vector3(0, 0.17, 0), 0.215, 0.215, 8, Color(0.3, 0.29, 0.28)))
	s._parts["keg"] = s._piece(keg)
	s._parts["fuse"] = _dot(s, Color(1.0, 0.8, 0.3), 0.05)
	s._parts["blast"] = s._puff(FIRE, 9)
	s._parts["fire"] = _flames(s, 8)
	var foes: Array[Dictionary] = []
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		foes.append(_zombie_at(s, KEG_AT + Vector2(cos(a) * 0.95, sin(a) * 0.7), "normal_a" if i % 2 == 0 else "normal_b", THROWER))
	s._parts["foes"] = foes


static func _keg(s: UpgradeShowcase, t: float) -> void:
	const LAND := 1.0
	s._play(s._person["anim"], "Throw" if t > 0.1 and t < 0.7 else "Idle")
	var keg: MeshInstance3D = s._parts["keg"]
	var fly := UpgradeShowcase._window(t, 0.4, LAND)
	var from := _sp(s, THROWER) + Vector3.UP * 1.5
	var to := _sp(s, KEG_AT) + Vector3.UP * 0.25
	keg.visible = fly > 0.0 and fly < 1.0
	keg.position = from.lerp(to, fly) + Vector3.UP * sin(fly * PI) * 1.2
	keg.rotation = Vector3(fly * 9.0, 0, fly * 4.0)
	var fuse: MeshInstance3D = s._parts["fuse"]
	fuse.visible = keg.visible
	fuse.position = keg.position + keg.basis.y * 0.26
	s._show_puff(s._parts["blast"], t - LAND, 0.7, 1.5)
	(s._parts["blast"] as Node3D).position = to
	_show_flames(s._parts["fire"], _sp(s, KEG_AT), 0.75, t, t > LAND + 0.2 and t < 3.0)
	for z: Dictionary in s._parts["foes"]:
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		var away := (home - _sp(s, KEG_AT)).normalized()
		var thrown := UpgradeShowcase._window(t, LAND, LAND + 0.45)
		var lie := t >= LAND + 0.45 and t < 3.0
		zh.position = home + away * (thrown * 0.8 if t < 3.0 else 0.0) + Vector3.UP * sin(thrown * PI) * 0.7 * float(t < LAND + 0.45)
		(z["node"] as Node3D).rotation.x = -1.4 * UpgradeShowcase._window(t, LAND, LAND + 0.45) if t < 3.0 else 0.0
		if lie:
			s._play(z["anim"], "Idle", 0.0)
		elif t >= 3.0:
			s._play(z["anim"], "Idle")
		zh.visible = t < 3.0 or t > 3.15


# --- Field Turret: a Clockwork Sentry set down, turning and shooting --------------------------------

const MECHANIC := Vector2(1.05, 0.35)
const TURRET := Vector2(0.15, 0.0)
const TURRET_FOES := [Vector2(-1.3, -0.45), Vector2(-1.0, 0.55)]

static func _build_turret(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "artificer", "torch", MECHANIC, TURRET)
	s._parts["turret"] = s._piece(World.sentry_model())
	var bolts: Array[MeshInstance3D] = []
	for i in 3:
		bolts.append(_bar(s, Color(0.95, 0.85, 0.55), 0.04))
	s._parts["bolts"] = bolts
	var foes: Array[Dictionary] = []
	for i in TURRET_FOES.size():
		foes.append(_zombie_at(s, TURRET_FOES[i], "normal_a" if i == 0 else "normal_b", TURRET))
	s._parts["foes"] = foes
	s._parts["set"] = s._puff(Color(0.7, 0.62, 0.5), 5)


static func _turret(s: UpgradeShowcase, t: float) -> void:
	const FIRST := 0.75
	const EVERY := 0.35
	s._play(s._person["anim"], "PickUp" if t > 0.05 and t < 0.6 else "Idle")
	var turret: MeshInstance3D = s._parts["turret"]
	var up := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, 0.35, 0.6)) * (1.0 - UpgradeShowcase._window(t, 3.15, 3.35))
	turret.visible = up > 0.02
	turret.scale = Vector3.ONE * up
	turret.position = _sp(s, TURRET)
	s._show_puff(s._parts["set"], t - 0.45, 0.4, 0.4)
	(s._parts["set"] as Node3D).position = _sp(s, TURRET) + Vector3.UP * 0.2
	var foes: Array = s._parts["foes"]
	var shot := int(floor((t - FIRST) / EVERY))
	var aim_at: Dictionary = foes[maxi(shot, 0) % foes.size()]
	var aim := (aim_at["holder"] as Node3D).position
	turret.rotation.y = lerp_angle(turret.rotation.y, UpgradeShowcase._facing(turret.position, aim), 0.25)
	var bolts: Array = s._parts["bolts"]
	for i in bolts.size():
		var n := shot - i
		var bar: MeshInstance3D = bolts[i]
		var k := (t - FIRST - n * EVERY) / 0.18
		if n < 0 or t > 3.1 or k > 1.0:
			bar.visible = false
			continue
		var target: Vector3 = (foes[n % foes.size()]["holder"] as Node3D).position + Vector3.UP * 1.1
		var muzzle := turret.position + Vector3.UP * 1.12
		_lay(bar, muzzle.lerp(target, maxf(0.0, k - 0.25)), muzzle.lerp(target, k))
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		var dir := (_sp(s, TURRET) - home).normalized()
		zh.position = home + dir * minf(t * 0.3, 0.45)
		s._play(z["anim"], "Walking_A", 0.6)
		for n in 8:
			if n % foes.size() == i:
				_struck(s, z, t, FIRST + n * EVERY + 0.18)


# --- Tesla Coil: the coil set down, striking the four nearest of five ------------------------------

const INVENTOR := Vector2(1.35, 0.5)
const COIL := Vector2(-0.2, -0.1)

static func _build_tesla(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "artificer", "torch", INVENTOR, COIL)
	var coil := PathField.coil_model()
	coil.scale = Vector3.ONE * 0.85
	s.add_child(coil)
	s._parts["coil"] = coil
	var foes: Array[Dictionary] = []
	var sparks: Array = []
	var spots := [Vector2(-1.4, -0.25), Vector2(-0.75, 0.85), Vector2(0.7, -0.95), Vector2(-0.6, -1.35), Vector2(-2.2, 0.75)]
	for i in spots.size():
		foes.append(_zombie_at(s, spots[i], "normal_a" if i % 2 == 0 else "normal_b", COIL))
		if i < PathUpgrades.TESLA_TARGETS:
			sparks.append(_spark(s, SPARK))
	s._parts["foes"] = foes
	s._parts["sparks"] = sparks


static func _tesla(s: UpgradeShowcase, t: float) -> void:
	s._play(s._person["anim"], "PickUp" if t > 0.05 and t < 0.55 else "Idle")
	var coil: Node3D = s._parts["coil"]
	var up := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, 0.3, 0.55)) * (1.0 - UpgradeShowcase._window(t, 3.15, 3.35))
	coil.visible = up > 0.02
	coil.scale = Vector3.ONE * 0.85 * maxf(up, 0.02)
	coil.position = _sp(s, COIL)
	var ball := coil.get_node("Ball") as MeshInstance3D
	(ball.material_override as StandardMaterial3D).emission_energy_multiplier = 0.4 + 1.6 * absf(sin(t * 13.0))
	var top := coil.position + Vector3.UP * 1.62 * 0.85
	var phase := fmod(t - 0.7, PathUpgrades.TESLA_EVERY)
	var zapping := t > 0.7 and t < 3.1 and phase < 0.14
	var foes: Array = s._parts["foes"]
	var sparks: Array = s._parts["sparks"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		if i < sparks.size():
			_lay_spark(sparks[i], top, zh.position + Vector3.UP * 1.1, zapping, int((t - phase) * 100.0) + i * 7)
			zh.position = _sp(s, z["home"]) + (Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03)) if zapping else Vector3.ZERO)
			s._play(z["anim"], "Hit_A" if zapping else "Idle", 1.6)
		else:
			# The fifth is out of reach: it just watches.
			s._play(z["anim"], "Idle")


# --- Arcane Surge: three swings of the War Staff, and the third a bolt -----------------------------

const WARLOCK := Vector2(0.95, 0.25)
const SURGE_FOE := Vector2(-1.35, -0.45)
const SURGE_SWINGS := [0.25, 0.9, 1.55]

static func _build_surge(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "commander", "war_staff", WARLOCK, SURGE_FOE)
	s._parts["bolt"] = _dot(s, ARCANE, 0.16)
	s._parts["trail"] = _bar(s, ARCANE, 0.08, 0.6)
	s._parts["burst"] = s._puff(ARCANE, 7)
	s._parts["foe"] = _zombie_at(s, SURGE_FOE, "normal_a", WARLOCK)
	var pips: Array[MeshInstance3D] = []
	for i in 3:
		pips.append(_dot(s, ARCANE, 0.07))
	s._parts["pips"] = pips


static func _surge(s: UpgradeShowcase, t: float) -> void:
	var swing := -1
	for i in SURGE_SWINGS.size():
		if t >= SURGE_SWINGS[i]:
			swing = i
	var swinging: bool = swing >= 0 and t < SURGE_SWINGS[swing] + 0.5
	s._play(s._person["anim"], ("Spellcast_Shoot" if swing == 2 else "Sweep") if swinging else "Idle", 1.3)
	# Three lights over the Warlock's head, one for each attack: the third is the bolt.
	var pips: Array = s._parts["pips"]
	for i in pips.size():
		var pip: MeshInstance3D = pips[i]
		pip.visible = t < 2.6
		pip.position = _sp(s, WARLOCK) + _sp(s, Vector2(-0.22 + 0.22 * i, 0)) + Vector3.UP * 2.25
		var lit := swing >= i
		pip.scale = Vector3.ONE * (1.4 if lit else 0.7)
		(pip.material_override as StandardMaterial3D).albedo_color = ARCANE.lightened(0.4) if lit else Color(0.3, 0.25, 0.4)
	var from := _sp(s, WARLOCK) + Vector3.UP * 1.4 + (_sp(s, SURGE_FOE) - _sp(s, WARLOCK)).normalized() * 0.5
	var to := _sp(s, SURGE_FOE) + Vector3.UP * 1.1
	var go := UpgradeShowcase._window(t, SURGE_SWINGS[2] + 0.15, SURGE_SWINGS[2] + 0.55)
	var bolt: MeshInstance3D = s._parts["bolt"]
	bolt.visible = go > 0.0 and go < 1.0
	bolt.position = from.lerp(to, go)
	if bolt.visible:
		_lay(s._parts["trail"], from.lerp(to, maxf(0.0, go - 0.3)), bolt.position)
	else:
		(s._parts["trail"] as MeshInstance3D).visible = false
	s._show_puff(s._parts["burst"], t - SURGE_SWINGS[2] - 0.55, 0.6, 0.8)
	(s._parts["burst"] as Node3D).position = to
	var foe: Dictionary = s._parts["foe"]
	_struck(s, foe, t, SURGE_SWINGS[2] + 0.55)
	var fh: Node3D = foe["holder"]
	var stagger := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, SURGE_SWINGS[2] + 0.55, SURGE_SWINGS[2] + 0.8)) * (1.0 - UpgradeShowcase._window(t, 3.0, 3.3))
	fh.position = _sp(s, SURGE_FOE) + (_sp(s, SURGE_FOE) - _sp(s, WARLOCK)).normalized() * 0.4 * stagger
	if t > 2.8 and t < 2.85:
		s._play(foe["anim"], "Idle")


# --- Grapeshot: three single balls, and the fourth a spread of six ----------------------------------

const GUNNER := Vector2(1.15, 0.3)
const GRAPE_FOES := [Vector2(-1.3, -0.65), Vector2(-1.55, 0.0), Vector2(-1.2, 0.6)]
const GRAPE_SHOTS := [0.3, 0.85, 1.4, 2.05]

static func _build_grapeshot(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "commander", "musket", GUNNER, Vector2(-1.5, 0.0))
	var balls: Array[MeshInstance3D] = []
	for i in 3 + PathUpgrades.GRAPESHOT_PELLETS:
		balls.append(_dot(s, Color(0.2, 0.2, 0.22), 0.05))
	s._parts["balls"] = balls
	s._parts["flash"] = s._puff(Color(1.0, 0.85, 0.5), 5)
	s._parts["smoke"] = s._puff(Color(0.7, 0.7, 0.7), 6)
	var foes: Array[Dictionary] = []
	for i in GRAPE_FOES.size():
		foes.append(_zombie_at(s, GRAPE_FOES[i], "normal_a" if i % 2 == 0 else "normal_b", GUNNER))
	s._parts["foes"] = foes
	var pips: Array[MeshInstance3D] = []
	for i in 4:
		pips.append(_dot(s, Color(1.0, 0.8, 0.4), 0.065))
	s._parts["pips"] = pips


static func _grapeshot(s: UpgradeShowcase, t: float) -> void:
	var shot := -1
	for i in GRAPE_SHOTS.size():
		if t >= GRAPE_SHOTS[i]:
			shot = i
	s._play(s._person["anim"], "2H_Ranged_Shoot" if shot >= 0 and t < GRAPE_SHOTS[shot] + 0.4 else "Idle", 1.5)
	var muzzle := _sp(s, GUNNER) + Vector3.UP * 1.35 + (_sp(s, Vector2(-1.5, 0.0)) - _sp(s, GUNNER)).normalized() * 0.75
	var foes: Array = s._parts["foes"]
	var balls: Array = s._parts["balls"]
	var pips: Array = s._parts["pips"]
	for i in pips.size():
		var pip: MeshInstance3D = pips[i]
		pip.visible = t < 2.9
		pip.position = _sp(s, GUNNER) + _sp(s, Vector2(-0.3 + 0.2 * i, 0)) + Vector3.UP * 2.2
		pip.scale = Vector3.ONE * (1.3 if shot >= i else 0.65)
		(pip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.8, 0.4) if shot >= i else Color(0.35, 0.3, 0.25)
	# The three plain shots, one ball each at the middle zombie.
	for i in 3:
		var ball: MeshInstance3D = balls[i]
		var k: float = (t - GRAPE_SHOTS[i]) / 0.2
		ball.visible = k >= 0.0 and k < 1.0
		ball.position = muzzle.lerp((foes[1]["holder"] as Node3D).position + Vector3.UP * 1.1, clampf(k, 0.0, 1.0))
		_struck(s, foes[1], t, GRAPE_SHOTS[i] + 0.2)
	# The fourth: six pellets fanning out.
	var k4: float = (t - GRAPE_SHOTS[3]) / 0.25
	for j in PathUpgrades.GRAPESHOT_PELLETS:
		var ball: MeshInstance3D = balls[3 + j]
		var target := (foes[j % 3]["holder"] as Node3D).position + Vector3.UP * (0.8 + 0.15 * (j / 3)) + _sp(s, Vector2(0, (j / 3) * 0.3 - 0.15))
		ball.visible = k4 >= 0.0 and k4 < 1.0
		ball.position = muzzle.lerp(target, clampf(k4, 0.0, 1.0))
	for z: Dictionary in foes:
		_struck(s, z, t, GRAPE_SHOTS[3] + 0.25)
		var zh: Node3D = z["holder"]
		var shove := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, GRAPE_SHOTS[3] + 0.25, GRAPE_SHOTS[3] + 0.45)) * (1.0 - UpgradeShowcase._window(t, 3.1, 3.5))
		zh.position = _sp(s, z["home"]) + (_sp(s, z["home"]) - _sp(s, GUNNER)).normalized() * 0.35 * shove
		if t > 3.0 and t < 3.05:
			s._play(z["anim"], "Idle")
	for i in 2:
		var puff: Node3D = s._parts["flash" if i == 0 else "smoke"]
		puff.position = muzzle
		var last: float = GRAPE_SHOTS[maxi(shot, 0)]
		s._show_puff(puff, t - last if shot >= 0 else -1.0, 0.25 if i == 0 else 0.7, 0.25 if shot < 3 else 0.5)


# --- Shield Wall: Command, and a shield on the Vanguard and every friend near -------------------------

const VANGUARD := Vector2(0.0, 0.3)
const WALL_FRIENDS := [Vector2(-1.05, -0.3), Vector2(1.05, -0.4)]
const WALL_FOE := Vector2(2.0, -1.2)

static func _build_shield_wall(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "commander", "sword", VANGUARD, Vector2(0, 2))
	var friends: Array[Dictionary] = []
	friends.append(_person_at(s, "infantry", "dagger", WALL_FRIENDS[0], Vector2(0, 2)))
	friends.append(_person_at(s, "ranger", "bow", WALL_FRIENDS[1], WALL_FOE))
	s._parts["friends"] = friends
	var bubble := SphereMesh.new()
	bubble.radius = 0.75
	bubble.height = 2.2
	bubble.radial_segments = 16
	bubble.rings = 8
	var shields: Array[MeshInstance3D] = []
	for i in 3:
		var sh := s._piece(bubble, s._glow(SHIELD, 0.18))
		sh.visible = false
		shields.append(sh)
	s._parts["shields"] = shields
	s._parts["ring"] = s._ring(SHIELD, 0.85, 0.05)
	s._parts["foe"] = _zombie_at(s, WALL_FOE, "normal_b", WALL_FRIENDS[1])
	s._parts["spark"] = s._puff(SHIELD, 6)


static func _shield_wall(s: UpgradeShowcase, t: float) -> void:
	const CALL := 0.35
	const BLOW := 1.85
	s._play(s._person["anim"], "Raise" if t > 0.1 and t < 1.2 else "Idle")
	var ring: MeshInstance3D = s._parts["ring"]
	var g := UpgradeShowcase._window(t, CALL + 0.1, CALL + 0.6)
	ring.visible = g > 0.0 and g < 1.0
	ring.position = _sp(s, VANGUARD) + Vector3.UP * 0.05
	ring.scale = Vector3.ONE * (0.3 + g * 1.6)
	(ring.material_override as StandardMaterial3D).albedo_color.a = 0.85 * (1.0 - g)
	var shields: Array = s._parts["shields"]
	var spots := [_sp(s, VANGUARD), _sp(s, WALL_FRIENDS[0]), _sp(s, WALL_FRIENDS[1])]
	for i in shields.size():
		var sh: MeshInstance3D = shields[i]
		var up := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, CALL + 0.25 + i * 0.08, CALL + 0.5 + i * 0.08)) * (1.0 - UpgradeShowcase._window(t, 3.1, 3.5))
		sh.visible = up > 0.02
		sh.position = spots[i] + Vector3.UP * 0.95
		sh.scale = Vector3.ONE * up
		var flash := 1.0 - UpgradeShowcase._window(t, BLOW, BLOW + 0.4) if i == 2 and t >= BLOW else 0.0
		(sh.material_override as StandardMaterial3D).albedo_color.a = 0.18 + 0.45 * flash
	var foe: Dictionary = s._parts["foe"]
	var fh: Node3D = foe["holder"]
	var stand: Vector3 = spots[2] + (_sp(s, WALL_FOE) - spots[2]).normalized() * 0.95
	fh.position = _sp(s, WALL_FOE).lerp(stand, UpgradeShowcase._window(t, 0.2, 1.4))
	if t < 1.4:
		s._play(foe["anim"], "Walking_A")
	elif t < 2.4:
		s._play(foe["anim"], "1H_Melee_Attack_Chop")
	else:
		s._play(foe["anim"], "Idle")
	s._show_puff(s._parts["spark"], t - BLOW, 0.4, 0.4)
	(s._parts["spark"] as Node3D).position = stand.lerp(spots[2], 0.6) + Vector3.UP * 1.2


# --- Wild Hunt: the horse comes at a gallop, the archer is up, and the arrows fly by themselves --------

const HUNTER := Vector2(0.75, 0.15)
const HUNT_FOES := [Vector2(-1.35, -0.55), Vector2(-1.6, 0.35)]
const HUNT_FIRST := 2.3

static func _build_wild_hunt(s: UpgradeShowcase) -> void:
	s._person = _person_at(s, "chivalry", "bow", HUNTER, Vector2(-1.5, 0))
	s._steed = s._make_steed(false)
	s._parts["dust"] = [s._puff(Color(0.62, 0.52, 0.4), 5), s._puff(Color(0.62, 0.52, 0.4), 5)]
	s._parts["mount"] = s._puff(Color(0.75, 0.68, 0.56), 7)
	var foes: Array[Dictionary] = []
	for i in HUNT_FOES.size():
		foes.append(_zombie_at(s, HUNT_FOES[i], "normal_a" if i == 0 else "normal_b", HUNTER))
	s._parts["foes"] = foes
	var arrows: Array[MeshInstance3D] = []
	for i in 3:
		arrows.append(_bar(s, Color(0.85, 0.78, 0.6), 0.035))
	s._parts["arrows"] = arrows
	s._parts["call"] = _dot(s, Color(1.0, 0.95, 0.75), 0.06)


static func _wild_hunt(s: UpgradeShowcase, t: float) -> void:
	var anim: AnimationPlayer = s._person["anim"]
	var from := _sp(s, Vector2(2.6, -2.4))
	var to := _sp(s, Vector2(1.0, -0.45))
	var k := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, 0.35, 1.7))
	var mounted := t >= 2.0 and t < 4.2
	var heading := (to - from).normalized()
	var call: MeshInstance3D = s._parts["call"]
	var c := UpgradeShowcase._window(t, 0.1, 0.8)
	call.visible = c > 0.0 and c < 1.0
	call.position = _sp(s, HUNTER) + Vector3.UP * (1.8 + c * 0.6) + _sp(s, Vector2(c * 0.4, 0))
	if not mounted:
		s._steed.position = from.lerp(to, k)
		s._steed.rotation.y = lerp_angle(atan2(-heading.x, -heading.z), UpgradeShowcase._facing(Vector3.ZERO, _sp(s, Vector2(-1.0, 0.25))), UpgradeShowcase._window(t, 1.2, 1.9))
		s._steed_gait(clampf((1.0 - k) * 1.6, 0.0, 1.0))
		s._steed.position.y = absf(sin(t * 13.0)) * 0.05 * (1.0 - k)
		s._steed.visible = t >= 0.35 and t < 4.2
		s._stand(s._person, _sp(s, HUNTER))
		(s._person["holder"] as Node3D).rotation.y = UpgradeShowcase._facing(_sp(s, HUNTER), _sp(s, Vector2(-1.5, 0)))
		s._play(anim, "Whistle" if t < 0.9 else "Idle")
		(s._person["holder"] as Node3D).visible = t < 4.2
	else:
		if (s._person["holder"] as Node3D).get_parent() != s._steed:
			s._seat(s._person, s._steed)
		s._steed_gait(0.0)
		s._play(anim, "RideShoot" if t > HUNT_FIRST else "Ride")
	var dust: Array = s._parts["dust"]
	for i in dust.size():
		var age := fmod(t + i * 0.4, 0.8)
		(dust[i] as Node3D).position = s._steed.position + Vector3(0, 0.1, 0) - heading * (0.8 + age * 0.5)
		s._show_puff(dust[i], age if t > 0.35 and t < 1.5 else -1.0, 0.8, 0.4)
	s._show_puff(s._parts["mount"], t - 1.95, 0.45, 0.45)
	(s._parts["mount"] as Node3D).position = s._steed.position + Vector3.UP * 0.8
	# The hunt: an arrow every 0.4 s, at one zombie and then the other, without a hand on the string.
	var foes: Array = s._parts["foes"]
	var arrows: Array = s._parts["arrows"]
	var shot := int(floor((t - HUNT_FIRST) / UpgradeKit.HUNT_EVERY))
	var bow := s._steed.position + Vector3.UP * 1.9
	for i in arrows.size():
		var n := shot - i
		var bar: MeshInstance3D = arrows[i]
		var a := (t - HUNT_FIRST - n * UpgradeKit.HUNT_EVERY) / 0.22
		if n < 0 or t > 4.1 or a > 1.0:
			bar.visible = false
			continue
		var target: Vector3 = (foes[n % foes.size()]["holder"] as Node3D).position + Vector3.UP * 1.1
		_lay(bar, bow.lerp(target, maxf(0.0, a - 0.35)), bow.lerp(target, a))
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		zh.position = home + (_sp(s, HUNTER) - home).normalized() * minf(t * 0.2, 0.5)
		s._play(z["anim"], "Walking_A" if t < HUNT_FIRST else "Idle", 0.7)
		for n in 6:
			if n % foes.size() == i:
				_struck(s, z, t, HUNT_FIRST + n * UpgradeKit.HUNT_EVERY + 0.22)


# --- Mist Reinforcements: a Mist Ranger on top of the gate, and the soldiers before it stronger -------

const WALL_TOP := 2.7 # the scene's wall is lower than Mist Bastion's, to keep everyone in view
const GATE_RANGER := Vector2(0.0, -0.9)
const LANE_FOES := [Vector2(-1.6, 1.0), Vector2(0.9, 1.35)]
const MIST_GREEN := Color(0.45, 0.95, 0.92)

static func _build_reinforcements(s: UpgradeShowcase) -> void:
	var wall := s._mesh(func(l: LowPoly) -> void:
		var slate := Color(0.33, 0.33, 0.4)
		var dark := Color(0.2, 0.2, 0.27)
		var iron := Color(0.27, 0.2, 0.2)
		var band := Color(0.16, 0.3, 0.33)
		# Two wall pieces either side of the gateway, a lintel over it, and battlements along the top.
		l.box(Vector3(-1.75, WALL_TOP * 0.5, 0), Vector3(1.3, WALL_TOP, 0.9), slate)
		l.box(Vector3(1.75, WALL_TOP * 0.5, 0), Vector3(1.3, WALL_TOP, 0.9), slate)
		l.box(Vector3(0, WALL_TOP - 0.45, 0), Vector3(2.2, 0.9, 0.9), slate.darkened(0.05))
		for k in 7:
			l.box(Vector3(-2.2 + k * 0.73, WALL_TOP + 0.18, 0.32), Vector3(0.42, 0.36, 0.22), dark)
		# The gate: ironwood planks bound in mist-green iron.
		for k in 4:
			l.box(Vector3(-0.82 + k * 0.55, (WALL_TOP - 0.9) * 0.5, 0.1), Vector3(0.52, WALL_TOP - 0.9, 0.3), iron.lightened(0.05 * (k % 2)))
		for y: float in [0.4, 1.2]:
			l.box(Vector3(0, y, 0.28), Vector3(2.15, 0.12, 0.06), band))
	var piece := s._piece(wall)
	piece.position = _sp(s, GATE_RANGER)
	piece.rotation.y = -s.rotation.y
	s._parts["wall"] = piece
	var ranger := _person_at(s, "mist_ranger", "bow", GATE_RANGER, Vector2(0, 2))
	(ranger["holder"] as Node3D).position += Vector3.UP * WALL_TOP
	s._person = ranger
	var guards: Array[Dictionary] = []
	for x: float in [-0.75, 0.75]:
		guards.append(_person_at(s, "mist_infantry", "sword", Vector2(x, 0.15), Vector2(x * 1.5, 2)))
	s._parts["guards"] = guards
	var foes: Array[Dictionary] = []
	for i in LANE_FOES.size():
		foes.append(_zombie_at(s, LANE_FOES[i], "normal_a" if i == 0 else "normal_b", Vector2(0, 0)))
	s._parts["foes"] = foes
	var arrows: Array[MeshInstance3D] = []
	for i in 2:
		arrows.append(_bar(s, Color(0.85, 0.95, 0.9), 0.035))
	s._parts["arrows"] = arrows
	var motes: Array[MeshInstance3D] = []
	for i in 9:
		motes.append(_dot(s, MIST_GREEN, 0.05))
	s._parts["motes"] = motes
	s._parts["muster"] = s._puff(MIST_GREEN, 7)


static func _reinforcements(s: UpgradeShowcase, t: float) -> void:
	const EVERY := 1.1
	const FIRST := 0.4
	var ranger: Dictionary = s._person
	var rh: Node3D = ranger["holder"]
	var top := rh.position
	var up := UpgradeShowcase._ease_out(UpgradeShowcase._window(t, 0.0, 0.3))
	rh.scale = Vector3.ONE * maxf(up, 0.05)
	s._show_puff(s._parts["muster"], t, 0.6, 0.6)
	(s._parts["muster"] as Node3D).position = top + Vector3.UP
	var foes: Array = s._parts["foes"]
	var shot := int(floor((t - FIRST) / EVERY))
	var aim: Vector3 = (foes[maxi(shot, 0) % foes.size()]["holder"] as Node3D).position
	rh.rotation.y = lerp_angle(rh.rotation.y, UpgradeShowcase._facing(top, aim), 0.2)
	s._play(ranger["anim"], "2H_Ranged_Shoot" if t > FIRST and fmod(t - FIRST, EVERY) < 0.4 else "Idle", 1.5)
	var arrows: Array = s._parts["arrows"]
	for i in arrows.size():
		var n := shot - i
		var bar: MeshInstance3D = arrows[i]
		var k := (t - FIRST - n * EVERY) / 0.3
		if n < 0 or k > 1.0 or t > 3.4:
			bar.visible = false
			continue
		var target: Vector3 = (foes[n % foes.size()]["holder"] as Node3D).position + Vector3.UP * 1.1
		var bow := top + Vector3.UP * 1.3
		_lay(bar, bow.lerp(target, maxf(0.0, k - 0.3)), bow.lerp(target, k))
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		var guard_at := (s._parts["guards"][i]["holder"] as Node3D).position
		var stand := guard_at + (home - guard_at).normalized() * 0.9
		zh.position = home.lerp(stand, UpgradeShowcase._window(t, 0.0, 1.4))
		zh.rotation.y = UpgradeShowcase._facing(zh.position, guard_at)
		s._play(z["anim"], "Walking_A" if t < 1.4 else "1H_Melee_Attack_Chop", 1.0)
		for n in 4:
			if n % foes.size() == i:
				_struck(s, z, t, FIRST + n * EVERY + 0.3)
	# The soldiers before the gate fight, the mist about them a little brighter: stronger, and harder to put down.
	var guards: Array = s._parts["guards"]
	var motes: Array = s._parts["motes"]
	for i in guards.size():
		var g: Dictionary = guards[i]
		var gh: Node3D = g["holder"]
		var foe_at := (foes[i]["holder"] as Node3D).position
		gh.rotation.y = lerp_angle(gh.rotation.y, UpgradeShowcase._facing(gh.position, foe_at), 0.2)
		s._play(g["anim"], "1H_Melee_Attack_Chop" if t > 1.4 and fmod(t, 0.9) < 0.45 else "Idle", 1.3)
	for j in motes.size():
		var m: MeshInstance3D = motes[j]
		var who: Node3D = (guards[j % 2]["holder"] if j < 6 else rh) as Node3D
		var rise := fmod(t * 0.7 + j * 0.37, 1.0)
		var a := j * 2.1 + t
		m.visible = t > 0.3
		m.position = who.position + Vector3(cos(a) * 0.35, 0.3 + rise * 1.7, sin(a) * 0.35)
		m.scale = Vector3.ONE * (1.0 - rise * 0.6)
