class_name CrownScenes
extends RefCounted
## The Store's scenes for the Class Upgrades of the Adept, the Cartographer and the Bandit
## (CrownUpgrades), and the Trappers' Guild of the Valleys: each played on an UpgradeShowcase's stage
## with the class's own body and weapon, the night's zombies, and the same rift, stones, gates, stakes,
## seal and knives the upgrade puts in a night. Layout is in camera space (UpgradeShowcase._at), with
## the shared pieces of PathScenes.

const LOOP := {"encore": 3.6, "shattered_mirror": 3.6, "event_horizon": 4.0, "star_shower": 4.0, "open_door": 3.8,
	"trailblazer": 4.0, "lucky_fingers": 3.6, "contract": 4.0, "toll_road": 3.8, "trappers_guild": 4.4}

const GLASS := Color(0.72, 0.9, 1.0)
const BLOOD := Color(0.75, 0.08, 0.06)
const HEAL := Color(0.45, 0.95, 0.55)
const STARLIGHT := Color(1.0, 0.9, 0.6)
const AZURE := Color(0.42, 0.74, 1.0)


static func stage_height(id: String) -> float:
	match id:
		"encore", "event_horizon", "star_shower", "trailblazer", "contract": return 4.6
		"open_door": return 5.0
		"trappers_guild": return 5.4
	return 4.0


static func camera_tilt(id: String) -> float:
	match id:
		"star_shower", "open_door", "trappers_guild": return 0.3
		"trailblazer": return 0.34
	return 0.24


static func view_turn(_id: String) -> float:
	return PI - 0.35


static func build(s: UpgradeShowcase, id: String) -> void:
	match id:
		"encore": _build_encore(s)
		"shattered_mirror": _build_mirror(s)
		"event_horizon": _build_horizon(s)
		"star_shower": _build_shower(s)
		"open_door": _build_door(s)
		"trailblazer": _build_trail(s)
		"lucky_fingers": _build_lucky(s)
		"contract": _build_contract(s)
		"toll_road": _build_toll(s)
		"trappers_guild": TrapperScenes.build(s)


static func play(s: UpgradeShowcase, id: String, t: float) -> void:
	match id:
		"encore": _encore(s, t)
		"shattered_mirror": _mirror(s, t)
		"event_horizon": _horizon(s, t)
		"star_shower": _shower(s, t)
		"open_door": _door(s, t)
		"trailblazer": _trail(s, t)
		"lucky_fingers": _lucky(s, t)
		"contract": _contract(s, t)
		"toll_road": _toll(s, t)
		"trappers_guild": TrapperScenes.play(s, t)


# --- Shared --------------------------------------------------------------------------------

static func _sp(s: UpgradeShowcase, screen: Vector2) -> Vector3:
	return PathScenes._sp(s, screen)


static func _w(t: float, from: float, to: float) -> float:
	return UpgradeShowcase._window(t, from, to)


static func _ease(k: float) -> float:
	return UpgradeShowcase._ease_out(k)


## Marks over someone's head counting to the special one: `need` dots, `have` lit, the last one big
## and bright when `primed`, all of them flaring when `burst` (0 to 1) runs.
static func _pips(s: UpgradeShowcase, need: int, col: Color) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for i in need:
		out.append(PathScenes._dot(s, col, 0.075))
	return out


static func _show_pips(s: UpgradeShowcase, pips: Array, over: Vector3, have: int, primed: bool, burst: float) -> void:
	var need := pips.size()
	for i in need:
		var pip: MeshInstance3D = pips[i]
		pip.visible = true
		pip.position = over + _sp(s, Vector2((float(i) - float(need - 1) * 0.5) * 0.26, 0.0)) + Vector3.UP * (2.25 + 0.15 * burst)
		var lit := i < have or burst > 0.0
		var big := (i == need - 1 and primed) or burst > 0.0
		pip.scale = Vector3.ONE * ((1.6 if big else 1.0) * (1.0 + burst * 0.8) if lit else 0.7)
		(pip.material_override as StandardMaterial3D).albedo_color.a = (1.0 - burst * 0.7) if lit else 0.35


## A zombie knocked off its feet: tipped back on its heels, then up again.
static func _knock_down(z: Dictionary, k: float, away: Vector3, yaw: float) -> void:
	var holder: Node3D = z["holder"]
	var lean := sin(clampf(k, 0.0, 1.0) * PI) if k > 0.0 and k < 1.0 else 0.0
	var side := away.cross(Vector3.UP).normalized()
	holder.basis = Basis(side, -lean * 1.2) * Basis(Vector3.UP, yaw)
	holder.position.y = lean * 0.15


static func _upright(z: Dictionary, yaw: float) -> void:
	var holder: Node3D = z["holder"]
	holder.basis = Basis(Vector3.UP, yaw)
	holder.position.y = 0.0


# --- Encore: three changes of stance, and the third the Encore -----------------------------------

const DANCER := Vector2(0.1, 0.1)
const ENCORE_CHANGES := [0.35, 1.3, 2.25]
const ENCORE_INNER := [Vector2(-1.25, -0.55), Vector2(1.35, -0.45)]
const ENCORE_OUTER := [Vector2(-2.25, 0.55), Vector2(0.25, -1.75), Vector2(2.2, 0.65)]
const INNER_RING := 1.75
const OUTER_RING := 2.85

static func _build_encore(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "adept", "sword", DANCER, Vector2(0, 2))
	var foes: Array[Dictionary] = []
	for spot: Vector2 in ENCORE_INNER + ENCORE_OUTER:
		foes.append(PathScenes._zombie_at(s, spot, "normal_a" if foes.size() % 2 == 0 else "normal_b", DANCER))
	s._parts["foes"] = foes
	var rings: Array[MeshInstance3D] = []
	for i in 3:
		rings.append(s._ring(Player.STANCE_COLOURS[["stone", "flame", "wind"][i]].lightened(0.25), 0.95, 0.11 if i == 2 else 0.08))
	s._parts["rings"] = rings
	s._parts["blast"] = s._puff(Player.STANCE_COLOURS["wind"].lightened(0.2), 9)
	s._parts["pips"] = _pips(s, 3, Player.STANCE_COLOURS["wind"])
	var stars: Array[Node3D] = []
	for i in 5:
		stars.append(PathScenes._stars(s))
	s._parts["stars"] = stars


static func _encore(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var turning := false
	var done := 0
	for i in 3:
		if t >= ENCORE_CHANGES[i]:
			done = i + 1
		if t >= ENCORE_CHANGES[i] and t < ENCORE_CHANGES[i] + 0.55:
			turning = true
	s._play(s._person["anim"], "Sweep" if turning else "Idle", 1.5 if done == 3 else 1.3)
	holder.rotation.y = UpgradeShowcase._facing(holder.position, _sp(s, Vector2(0, 2))) + (sin(_w(t, ENCORE_CHANGES[2], ENCORE_CHANGES[2] + 0.5) * PI) * TAU if done == 3 else 0.0)
	var rings: Array = s._parts["rings"]
	for i in 3:
		var ring: MeshInstance3D = rings[i]
		var k := _w(t, ENCORE_CHANGES[i] + 0.05, ENCORE_CHANGES[i] + 0.4)
		ring.visible = k > 0.0 and k < 1.0
		ring.position = holder.position + Vector3.UP * 0.04
		var reach := OUTER_RING if i == 2 else INNER_RING
		ring.scale = Vector3.ONE * (0.4 + _ease(k) * (reach - 0.4))
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - k * k)
	s._show_puff(s._parts["blast"], t - ENCORE_CHANGES[2] - 0.1, 0.55, 1.6)
	(s._parts["blast"] as Node3D).position = holder.position + Vector3.UP * 0.7
	# The marks: one more lit at each change, the Encore's flaring.
	var burst := _w(t, ENCORE_CHANGES[2], ENCORE_CHANGES[2] + 0.45)
	_show_pips(s, s._parts["pips"], holder.position, done if done < 3 else 0, done == 2, burst if burst < 1.0 and done == 3 else 0.0)
	var foes: Array = s._parts["foes"]
	var stars: Array = s._parts["stars"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home: Vector2 = z["home"]
		var yaw := UpgradeShowcase._facing(_sp(s, home), holder.position)
		var inner := i < ENCORE_INNER.size()
		var down := _w(t, ENCORE_CHANGES[2] + 0.15, ENCORE_CHANGES[2] + 0.15 + 0.95)
		var away := (_sp(s, home) - holder.position).normalized()
		if down > 0.0 and down < 1.0:
			_knock_down(z, down, away, yaw)
			zh.position = _sp(s, home) + away * 0.35 * sin(down * PI * 0.5) + Vector3.UP * zh.position.y
			s._play(z["anim"], "Hit_A", 0.6)
		else:
			_upright(z, yaw)
			zh.position = _sp(s, home) + (away * 0.35 if t > ENCORE_CHANGES[2] else Vector3.ZERO) * (1.0 - _w(t, 3.3, 3.6))
			s._play(z["anim"], "Idle")
			if inner:
				for c in 2:
					PathScenes._struck(s, z, t, ENCORE_CHANGES[c] + 0.15)
		PathScenes._show_stars(stars[i], zh.position, t, down > 0.25 and down < 0.95)


# --- Shattered Mirror: a blow undone, and the mirror flies apart at three of them -------------------

const MIRROR_ADEPT := Vector2(0.75, 0.3)
const MIRROR_FOES := [Vector2(-0.25, -0.45), Vector2(-1.6, 0.6), Vector2(-1.15, -1.35)]
const MIRROR_BLOW := 0.55
const MIRROR_UNDO := 0.95
const MIRROR_BREAK := 1.45

static func _build_mirror(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "adept", "sword", MIRROR_ADEPT, MIRROR_FOES[0])
	var foes: Array[Dictionary] = []
	for spot: Vector2 in MIRROR_FOES:
		foes.append(PathScenes._zombie_at(s, spot, "normal_b" if foes.is_empty() else "normal_a", MIRROR_ADEPT))
	s._parts["foes"] = foes
	# The mirror: a pane of silvered glass in a thin frame, standing in front of the Adept.
	var pane := s._mesh(func(l: LowPoly) -> void:
		l.box(Vector3.ZERO, Vector3(0.9, 1.3, 0.03), Color(0.78, 0.9, 1.0))
		l.box(Vector3(0, 0.67, 0), Vector3(0.98, 0.05, 0.05), Color(0.85, 0.85, 0.9))
		l.box(Vector3(0, -0.67, 0), Vector3(0.98, 0.05, 0.05), Color(0.85, 0.85, 0.9))
		l.box(Vector3(0.47, 0, 0), Vector3(0.05, 1.38, 0.05), Color(0.85, 0.85, 0.9))
		l.box(Vector3(-0.47, 0, 0), Vector3(0.05, 1.38, 0.05), Color(0.85, 0.85, 0.9)))
	s._parts["pane"] = s._piece(pane, s._glow(GLASS, 0.55))
	var shard := s._mesh(func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, 0.22), Vector3(0, 0, -0.3), 0.09, 0.0, 3, Color(0.85, 0.95, 1.0)))
	var shards: Array[MeshInstance3D] = []
	for i in CrownUpgrades.SHARDS:
		var mi := s._piece(shard, s._glow(GLASS, 0.95))
		mi.visible = false
		shards.append(mi)
	s._parts["shards"] = shards
	var drops: Array[MeshInstance3D] = []
	for i in 9:
		drops.append(PathScenes._dot(s, BLOOD, 0.045))
	s._parts["drops"] = drops
	s._parts["mend"] = PathScenes._crosses(s, HEAL, 3)
	s._parts["fog"] = s._puff(GLASS, 7)


static func _mirror(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var me := _sp(s, MIRROR_ADEPT)
	holder.position = me
	var foes: Array = s._parts["foes"]
	var striker: Dictionary = foes[0]
	s._play(striker["anim"], "1H_Melee_Attack_Chop" if t > MIRROR_BLOW - 0.35 and t < MIRROR_BLOW + 0.25 else "Idle", 1.2)
	if t < MIRROR_UNDO:
		s._play(s._person["anim"], "Hit_A" if t > MIRROR_BLOW else "Idle", 1.3)
	else:
		s._play(s._person["anim"], "Stance" if t < MIRROR_BREAK + 0.5 else "Idle", 1.2)
	s._show_puff(s._parts["fog"], t - MIRROR_UNDO, 0.6, 0.8)
	(s._parts["fog"] as Node3D).position = me + Vector3.UP * 1.0
	PathScenes._show_crosses(s, s._parts["mend"], me, t, t > MIRROR_UNDO and t < MIRROR_UNDO + 1.0)
	# The pane rises between the Adept and the blow, then flies apart.
	var pane: MeshInstance3D = s._parts["pane"]
	var up := _ease(_w(t, MIRROR_UNDO, MIRROR_UNDO + 0.2))
	pane.visible = t > MIRROR_UNDO and t < MIRROR_BREAK
	var front := me.lerp(_sp(s, MIRROR_FOES[0]), 0.38)
	pane.position = front + Vector3.UP * 1.05
	pane.rotation.y = UpgradeShowcase._facing(me, _sp(s, MIRROR_FOES[0]))
	pane.scale = Vector3(1.0, maxf(0.02, up), 1.0) * (1.0 + 0.05 * sin(t * 40.0) * _w(t, MIRROR_BREAK - 0.12, MIRROR_BREAK))
	var shards: Array = s._parts["shards"]
	for i in shards.size():
		var sh: MeshInstance3D = shards[i]
		var target: Vector2 = MIRROR_FOES[i % MIRROR_FOES.size()]
		var to := _sp(s, target) + Vector3.UP * 1.05
		var from := front + Vector3.UP * (0.75 + 0.12 * (i % 3)) + _sp(s, Vector2((float(i % 2) - 0.5) * 0.4, 0.0))
		var k := _w(t, MIRROR_BREAK + i * 0.03, MIRROR_BREAK + 0.32 + i * 0.03)
		sh.visible = k > 0.0 and k < 1.0
		var at := from.lerp(to, k) + Vector3.UP * sin(k * PI) * 0.25
		sh.position = at
		sh.basis = Basis.looking_at((to - from).normalized(), Vector3.UP) * Basis(Vector3.FORWARD, t * 20.0 + i)
	var drops: Array = s._parts["drops"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		if i > 0:
			s._play(z["anim"], "Idle")
		PathScenes._struck(s, z, t, MIRROR_BREAK + 0.3 + i * 0.03)
		# Bleeding after: drops falling from each.
		for d in 3:
			var drop: MeshInstance3D = drops[i * 3 + d]
			var k := fmod(t * 1.4 + d * 0.33 + i * 0.2, 1.0)
			drop.visible = t > MIRROR_BREAK + 0.35 and t < 3.3
			drop.position = _sp(s, MIRROR_FOES[i]) + _sp(s, Vector2(0.15 * (d - 1), 0.1)) + Vector3.UP * (1.1 - k * 1.05)


# --- Event Horizon: Void ends, and the rift it leaves draws them in and falls -----------------------

const VOID_SPOT := Vector2(0.0, -0.15)
const VOID_STEP := Vector2(1.95, 0.85)
const HORIZON_FOES := [Vector2(-2.0, -0.7), Vector2(-1.15, 1.0), Vector2(1.6, -1.35), Vector2(-0.35, -1.9)]
const HORIZON_OPEN := 0.45
const HORIZON_FALL := 3.0
const RIFT_SIZE := 2.2

static func _build_horizon(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "adept", "sword", VOID_SPOT, Vector2(0, 2))
	var rift := PathField.rift_model(RIFT_SIZE)
	s.add_child(rift)
	s._parts["rift"] = rift
	var foes: Array[Dictionary] = []
	for spot: Vector2 in HORIZON_FOES:
		foes.append(PathScenes._zombie_at(s, spot, "normal_a" if foes.size() % 2 == 0 else "normal_b", VOID_SPOT))
	s._parts["foes"] = foes
	s._parts["leave"] = s._puff(CrownUpgrades.VOID, 8)
	s._parts["fall"] = s._puff(CrownUpgrades.VOID.lightened(0.3), 10)
	s._parts["ring"] = s._ring(CrownUpgrades.VOID.lightened(0.3), 0.9, 0.07)


static func _horizon(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	# Out of Void: the Adept is seen again, stepping clear of the rift it leaves.
	var step := _ease(_w(t, HORIZON_OPEN, HORIZON_OPEN + 0.45))
	holder.position = _sp(s, VOID_SPOT).lerp(_sp(s, VOID_STEP), step) * (1.0 - _w(t, 3.6, 4.0)) + _sp(s, VOID_SPOT) * _w(t, 3.6, 4.0)
	holder.rotation.y = UpgradeShowcase._facing(holder.position, _sp(s, VOID_SPOT) if t > HORIZON_OPEN + 0.3 else _sp(s, Vector2(0, 2)))
	s._play(s._person["anim"], "Stance" if t > HORIZON_OPEN - 0.1 and t < HORIZON_OPEN + 0.45 else "Idle", 1.3)
	var ghost := t < HORIZON_OPEN
	(s._person["node"] as Node3D).visible = not ghost or fmod(t * 6.0, 1.0) < 0.35
	s._show_puff(s._parts["leave"], t - HORIZON_OPEN, 0.6, 0.9)
	(s._parts["leave"] as Node3D).position = _sp(s, VOID_SPOT) + Vector3.UP * 1.0
	var rift: Node3D = s._parts["rift"]
	var fade := _w(t, HORIZON_OPEN, HORIZON_OPEN + 0.35) * (1.0 - _w(t, HORIZON_FALL - 0.12, HORIZON_FALL + 0.05))
	rift.visible = fade > 0.01
	rift.position = _sp(s, VOID_SPOT)
	rift.scale = Vector3.ONE * (1.0 - 0.3 * _w(t, HORIZON_FALL - 0.4, HORIZON_FALL))
	PathField.show_rift(rift, t, fade, RIFT_SIZE)
	s._show_puff(s._parts["fall"], t - HORIZON_FALL, 0.6, 1.8)
	(s._parts["fall"] as Node3D).position = _sp(s, VOID_SPOT) + Vector3.UP * 1.0
	var ring: MeshInstance3D = s._parts["ring"]
	var r := _w(t, HORIZON_FALL, HORIZON_FALL + 0.45)
	ring.visible = r > 0.0 and r < 1.0
	ring.position = _sp(s, VOID_SPOT) + Vector3.UP * 0.04
	ring.scale = Vector3.ONE * (0.4 + _ease(r) * 1.6)
	(ring.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - r)
	var heart := _sp(s, VOID_SPOT)
	for i in (s._parts["foes"] as Array).size():
		var z: Dictionary = s._parts["foes"][i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, z["home"])
		var pull := _ease(_w(t, HORIZON_OPEN + 0.2, HORIZON_FALL - 0.2))
		var near := home.lerp(heart, 0.72 * pull)
		var thrown := _w(t, HORIZON_FALL, HORIZON_FALL + 0.5)
		var away := (home - heart).normalized()
		var yaw := UpgradeShowcase._facing(home, heart)
		if t < HORIZON_FALL:
			zh.position = near + Vector3(sin(t * 23.0 + i) * 0.03, 0, cos(t * 19.0 + i) * 0.03) * pull
			_upright(z, yaw + sin(t * 3.0 + i) * 0.4 * pull)
			s._play(z["anim"], "Hit_A" if pull > 0.05 else "Idle", 0.7)
		else:
			zh.position = near.lerp(home, _ease(_w(t, HORIZON_FALL, 3.85)) * 0.6) if t < 3.85 else home.lerp(near, 0.4 * (1.0 - _w(t, 3.85, 4.0)))
			var lift := zh.position
			_knock_down(z, thrown, away, yaw)
			zh.position.x = lift.x
			zh.position.z = lift.z
			s._play(z["anim"], "Hit_A" if thrown < 1.0 else "Idle", 0.8)


# --- Star Shower: the third stone closes the sky, and five stars come down ---------------------------

const STONES := [Vector2(-1.9, -1.1), Vector2(1.9, -1.1)]
const THIRD_STONE := Vector2(0.1, 1.0)
const READER := Vector2(0.75, 1.55)
const SHOWER_PLANT := 0.45
const SHOWER_FIRST := 0.95
const SHOWER_FOES := [Vector2(-0.35, -0.55), Vector2(0.75, -0.3), Vector2(-0.95, -0.3)]
const SHOWER_GROUND := [Vector2(0.25, 0.35), Vector2(-0.4, 0.15)]

static func _build_shower(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "cartographer", "spear", READER, THIRD_STONE)
	var stones: Array[Node3D] = []
	for spot: Vector2 in STONES + [THIRD_STONE]:
		var stone := SurveyNet.marker_model("stars")
		stone.scale = Vector3.ONE * 0.75
		s.add_child(stone)
		stone.position = _sp(s, spot)
		stones.append(stone)
	s._parts["stones"] = stones
	var lines: Array[MeshInstance3D] = []
	for i in 3:
		lines.append(PathScenes._bar(s, STARLIGHT, 0.06, 0.85))
	s._parts["lines"] = lines
	# The constellation: the sky held between the three stones, faint gold on the ground.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [_sp(s, STONES[0]), _sp(s, STONES[1]), _sp(s, THIRD_STONE)]:
		st.add_vertex(v + Vector3.UP * 0.05)
	var sky := s._piece(st.commit(), s._glow(STARLIGHT, 0.16))
	sky.visible = false
	s._parts["sky"] = sky
	var foes: Array[Dictionary] = []
	for spot: Vector2 in SHOWER_FOES:
		foes.append(PathScenes._zombie_at(s, spot, "normal_b" if foes.is_empty() else "normal_a", READER))
	(foes[0]["holder"] as Node3D).scale = Vector3.ONE * 1.18 # the toughest, struck first
	s._parts["foes"] = foes
	var falls: Array = []
	for i in CrownUpgrades.SHOWER_STARS:
		falls.append({"streak": PathScenes._bar(s, STARLIGHT, 0.09, 0.9), "head": PathScenes._dot(s, Color(1, 0.97, 0.85), 0.14),
			"ring": s._ring(STARLIGHT, 0.85, 0.08), "flash": s._puff(STARLIGHT, 6)})
	s._parts["falls"] = falls
	var stars: Array[Node3D] = []
	for i in 3:
		stars.append(PathScenes._stars(s))
	s._parts["stars"] = stars


static func _shower(s: UpgradeShowcase, t: float) -> void:
	s._play(s._person["anim"], "PickUp" if t > SHOWER_PLANT - 0.35 and t < SHOWER_PLANT + 0.2 else "Idle")
	var stones: Array = s._parts["stones"]
	var third: Node3D = stones[2]
	var up := _ease(_w(t, SHOWER_PLANT, SHOWER_PLANT + 0.2)) * (1.0 - _w(t, 3.7, 3.95))
	third.visible = up > 0.02
	third.scale = Vector3(0.75, 0.75 * maxf(up, 0.02), 0.75)
	var closed := t > SHOWER_PLANT + 0.15 and t < 3.75
	var spots := [_sp(s, STONES[0]), _sp(s, STONES[1]), _sp(s, THIRD_STONE)]
	# The line between the first two stands from the start; the third stone links to both.
	var lines: Array = s._parts["lines"]
	PathScenes._lay(lines[0], spots[0] + Vector3.UP * 1.32, spots[1] + Vector3.UP * 1.32)
	PathScenes._lay(lines[1], spots[1] + Vector3.UP * 1.32, spots[2] + Vector3.UP * 1.32)
	PathScenes._lay(lines[2], spots[2] + Vector3.UP * 1.32, spots[0] + Vector3.UP * 1.32)
	(lines[1] as MeshInstance3D).visible = closed
	(lines[2] as MeshInstance3D).visible = closed
	var sky: MeshInstance3D = s._parts["sky"]
	sky.visible = closed
	(sky.material_override as StandardMaterial3D).albedo_color.a = 0.16 * _w(t, SHOWER_PLANT + 0.15, SHOWER_PLANT + 0.5) * (1.0 - _w(t, 3.5, 3.75))
	var foes: Array = s._parts["foes"]
	var falls: Array = s._parts["falls"]
	for i in falls.size():
		var at: Vector3 = (foes[i]["holder"] as Node3D).position if i < foes.size() else _sp(s, SHOWER_GROUND[i - foes.size()])
		var lands := SHOWER_FIRST + i * CrownUpgrades.SHOWER_EVERY
		var f: Dictionary = falls[i]
		var k := _w(t, lands - 0.32, lands)
		var high := at + Vector3(-1.1, 3.4, 0.5)
		var head := high.lerp(at + Vector3.UP * 0.2, k * k)
		(f["head"] as MeshInstance3D).visible = k > 0.0 and k < 1.0
		(f["head"] as MeshInstance3D).position = head
		var tail := high.lerp(head, maxf(0.0, k - 0.35) / maxf(k, 0.01))
		PathScenes._lay(f["streak"], tail, head)
		(f["streak"] as MeshInstance3D).visible = k > 0.0 and k < 1.0
		var r := _w(t, lands, lands + 0.4)
		var ring: MeshInstance3D = f["ring"]
		ring.visible = r > 0.0 and r < 1.0
		ring.position = at + Vector3.UP * 0.05
		ring.scale = Vector3.ONE * (0.3 + _ease(r) * 0.9)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - r)
		s._show_puff(f["flash"], t - lands, 0.45, 0.7)
		(f["flash"] as Node3D).position = at + Vector3.UP * 0.6
	var stars: Array = s._parts["stars"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var lands := SHOWER_FIRST + i * CrownUpgrades.SHOWER_EVERY
		s._play(z["anim"], "Hit_A" if t > lands and t < lands + CrownUpgrades.SHOWER_STUN + 0.3 else "Idle", 1.0)
		PathScenes._show_stars(stars[i], (z["holder"] as Node3D).position, t, t > lands and t < lands + CrownUpgrades.SHOWER_STUN + 0.4)


# --- Open Door: a blow that would leave the Traveler low lands on nothing ----------------------------

const GATE_NEAR := Vector2(-1.35, 0.55)
const GATE_FAR := Vector2(1.9, -1.6)
const TRAVELER := Vector2(-0.6, 0.15)
const DOOR_BRUTE := Vector2(-1.35, -0.75)
const DOOR_SWING := 0.9
const DOOR_GO := 1.3

static func _build_door(s: UpgradeShowcase) -> void:
	for spot: Vector2 in [GATE_NEAR, GATE_FAR]:
		var gate := SurveyNet.marker_model("gates")
		gate.scale = Vector3.ONE * 0.8
		s.add_child(gate)
		gate.position = _sp(s, spot)
		gate.rotation.y = UpgradeShowcase._facing(_sp(s, spot), _sp(s, Vector2(0, 2.5)))
		s._parts["gate_%d" % (0 if spot == GATE_NEAR else 1)] = gate
	s._person = PathScenes._person_at(s, "cartographer", "spear", TRAVELER, DOOR_BRUTE)
	var brute := PathScenes._zombie_at(s, DOOR_BRUTE, "normal_b", TRAVELER)
	(brute["holder"] as Node3D).scale = Vector3.ONE * 1.35
	s._parts["brute"] = brute
	s._parts["out"] = s._puff(AZURE, 8)
	s._parts["in"] = s._puff(AZURE, 8)
	s._parts["ring"] = s._ring(AZURE, 0.9, 0.07)
	s._parts["mend"] = PathScenes._crosses(s, HEAL, 3)
	var bubble := SphereMesh.new()
	bubble.radius = 0.7
	bubble.height = 2.1
	bubble.radial_segments = 16
	bubble.rings = 8
	var guard := s._piece(bubble, s._glow(AZURE, 0.16))
	guard.visible = false
	s._parts["guard"] = guard
	s._parts["whiff"] = s._puff(Color(0.85, 0.8, 0.7), 5)


static func _door(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var brute: Dictionary = s._parts["brute"]
	s._play(brute["anim"], "1H_Melee_Attack_Chop" if t > DOOR_SWING - 0.4 and t < DOOR_SWING + 0.45 else ("Walking_A" if t < DOOR_SWING - 0.4 else "Idle"), 0.9)
	var gone := t >= DOOR_GO and t < 3.5
	var there := _sp(s, GATE_FAR) + _sp(s, Vector2(-0.4, 0.75))
	holder.position = there if gone else _sp(s, TRAVELER)
	holder.rotation.y = UpgradeShowcase._facing(holder.position, _sp(s, DOOR_BRUTE))
	s._play(s._person["anim"], ("Hit_A" if t > DOOR_SWING + 0.15 and t < DOOR_GO else "Idle") if not gone else ("PickUp" if t < DOOR_GO + 0.3 else "Idle"), 1.4)
	for i in 2:
		var gate: Node3D = s._parts["gate_%d" % i]
		var flare := sin(_w(t, DOOR_GO - 0.1, DOOR_GO + 0.5) * PI)
		gate.scale = Vector3.ONE * 0.8 * (1.0 + 0.1 * flare)
		var swirl := gate.get_node_or_null("Swirl") as Node3D
		if swirl:
			swirl.scale = Vector3.ONE * (1.0 + 0.35 * flare)
	s._show_puff(s._parts["out"], t - DOOR_GO, 0.55, 0.9)
	(s._parts["out"] as Node3D).position = _sp(s, TRAVELER) + Vector3.UP * 1.0
	s._show_puff(s._parts["in"], t - DOOR_GO - 0.05, 0.55, 0.9)
	(s._parts["in"] as Node3D).position = there + Vector3.UP * 1.0
	s._show_puff(s._parts["whiff"], t - DOOR_SWING - 0.4, 0.4, 0.45)
	(s._parts["whiff"] as Node3D).position = _sp(s, TRAVELER) + Vector3.UP * 0.2
	var ring: MeshInstance3D = s._parts["ring"]
	var r := _w(t, DOOR_GO, DOOR_GO + 0.5)
	ring.visible = r > 0.0 and r < 1.0
	ring.position = there + Vector3.UP * 0.05
	ring.scale = Vector3.ONE * (0.3 + _ease(r) * 1.2)
	(ring.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - r)
	PathScenes._show_crosses(s, s._parts["mend"], there, t, t > DOOR_GO + 0.1 and t < DOOR_GO + 1.2)
	var guard: MeshInstance3D = s._parts["guard"]
	var g := 1.0 - _w(t, DOOR_GO + CrownUpgrades.DOOR_GUARD, DOOR_GO + CrownUpgrades.DOOR_GUARD + 0.3)
	guard.visible = t > DOOR_GO and g > 0.02
	guard.position = there + Vector3.UP * 0.95
	(guard.material_override as StandardMaterial3D).albedo_color.a = 0.18 * g * (0.75 + 0.25 * sin(t * 14.0))


# --- Trailblazer: stakes along the way, a friend runs, a creature wades ------------------------------

const TRAIL_FROM := Vector2(-2.6, 0.9)
const TRAIL_TO := Vector2(2.6, -0.55)
const TRAIL_STAKES := 6
const TRAIL_FRIEND_FROM := Vector2(-3.4, 1.15)
const TRAIL_FOE_FROM := Vector2(0.5, -2.2)

static func _build_trail(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "cartographer", "spear", TRAIL_FROM, TRAIL_TO)
	var friend := PathScenes._person_at(s, "ranger", "bow", TRAIL_FRIEND_FROM, TRAIL_TO)
	s._parts["friend"] = friend
	var stakes: Array[Node3D] = []
	for i in TRAIL_STAKES:
		var stake := PathField.blaze_model()
		s.add_child(stake)
		stakes.append(stake)
	s._parts["stakes"] = stakes
	s._parts["foe"] = PathScenes._zombie_at(s, TRAIL_FOE_FROM, "normal_a", TRAIL_FROM)
	var swirl: Array[MeshInstance3D] = []
	for i in 4:
		swirl.append(PathScenes._dot(s, AZURE, 0.05, 0.8))
	s._parts["swirl"] = swirl
	var dashes: Array[MeshInstance3D] = []
	for i in 3:
		dashes.append(PathScenes._bar(s, Color(0.9, 0.95, 1.0), 0.025, 0.7))
	s._parts["dashes"] = dashes


static func _trail_at(s: UpgradeShowcase, k: float) -> Vector3:
	return _sp(s, TRAIL_FROM).lerp(_sp(s, TRAIL_TO), k)


static func _trail(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var walk := _w(t, 0.1, 2.6)
	holder.position = _trail_at(s, walk)
	holder.rotation.y = UpgradeShowcase._facing(_sp(s, TRAIL_FROM), _sp(s, TRAIL_TO))
	s._play(s._person["anim"], "Running_A" if walk > 0.0 and walk < 1.0 else "Idle", 1.0)
	var stakes: Array = s._parts["stakes"]
	for i in stakes.size():
		var stake: Node3D = stakes[i]
		var k := (float(i) + 0.4) / float(TRAIL_STAKES)
		var placed := 0.1 + k * 2.5
		var stand := _ease(_w(t, placed, placed + 0.18)) * (1.0 - _w(t, 3.6, 3.95))
		stake.visible = stand > 0.02
		stake.position = _trail_at(s, k)
		stake.rotation.y = holder.rotation.y
		stake.scale = Vector3(1.35, 1.35 * maxf(stand, 0.02), 1.35)
	# The friend comes along behind on the trail, quicker than the Pathfinder.
	var friend: Dictionary = s._parts["friend"]
	var fh: Node3D = friend["holder"]
	var run := _ease(_w(t, 0.9, 3.0))
	fh.position = _sp(s, TRAIL_FRIEND_FROM).lerp(_trail_at(s, 0.88), run)
	fh.rotation.y = UpgradeShowcase._facing(_sp(s, TRAIL_FRIEND_FROM), _sp(s, TRAIL_TO))
	s._play(friend["anim"], "Running_A" if run > 0.0 and run < 1.0 else "Idle", 1.5)
	var dashes: Array = s._parts["dashes"]
	var back := (_sp(s, TRAIL_FROM) - _sp(s, TRAIL_TO)).normalized()
	for i in dashes.size():
		var d: MeshInstance3D = dashes[i]
		var at := fh.position + Vector3.UP * (0.6 + i * 0.35) + back * (0.5 + 0.1 * i)
		PathScenes._lay(d, at, at + back * (0.5 + 0.15 * sin(t * 20.0 + i)))
		d.visible = run > 0.05 and run < 0.98
	# The creature: it walks at the trail, and once on it, wades.
	var foe: Dictionary = s._parts["foe"]
	var zh: Node3D = foe["holder"]
	var cross := _trail_at(s, 0.56)
	var reach := _w(t, 0.0, 1.5)
	var on_trail := t > 1.5
	var wade := _w(t, 1.5, 4.0) * 0.45
	zh.position = _sp(s, TRAIL_FOE_FROM).lerp(cross, reach) + (cross - _sp(s, TRAIL_FOE_FROM)).normalized() * wade
	zh.rotation.y = UpgradeShowcase._facing(_sp(s, TRAIL_FOE_FROM), cross)
	s._play(foe["anim"], "Walking_A", 0.35 if on_trail else 1.0)
	var swirl: Array = s._parts["swirl"]
	for i in swirl.size():
		var m: MeshInstance3D = swirl[i]
		var a := t * 3.0 + TAU * i / swirl.size()
		m.visible = on_trail and t < 3.7
		m.position = zh.position + Vector3(cos(a) * 0.4, 0.15 + 0.08 * i, sin(a) * 0.4)


# --- Lucky Fingers: three Steals counted, the fourth picks a pocket and comes straight back ------------

const THIEF_FROM := Vector2(1.55, 0.85)
const MARK := Vector2(-0.6, -0.55)
const LUCKY_STEAL := 0.55
const LUCKY_BACK := 1.75

static func _build_lucky(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "bandit", "dagger", THIEF_FROM, MARK)
	var mark := PathScenes._zombie_at(s, MARK, "clever", THIEF_FROM)
	s._parts["mark"] = mark
	s._parts["from_puff"] = s._puff(Color(0.5, 0.45, 0.55), 7)
	s._parts["to_puff"] = s._puff(Color(0.5, 0.45, 0.55), 7)
	var coin := s._piece(ContractSeal.coin_mesh())
	coin.visible = false
	coin.scale = Vector3.ONE * 0.35
	s._parts["coin"] = coin
	# What fell out of the pocket: a red potion with a cork, lying at the Thief's feet.
	var potion := s._mesh(func(l: LowPoly) -> void:
		l.prism(Vector3(0, 0, 0), Vector3(0, 0.16, 0), 0.09, 0.09, 8, Color(0.75, 0.12, 0.16))
		l.prism(Vector3(0, 0.16, 0), Vector3(0, 0.26, 0), 0.09, 0.035, 8, Color(0.8, 0.18, 0.2))
		l.prism(Vector3(0, 0.26, 0), Vector3(0, 0.31, 0), 0.03, 0.03, 6, Color(0.6, 0.45, 0.28)))
	var drop := s._piece(potion)
	drop.visible = false
	s._parts["potion"] = drop
	s._parts["glint"] = s._puff(CrownUpgrades.COIN, 6)
	s._parts["pips"] = _pips(s, CrownUpgrades.LUCKY_ONE_IN, CrownUpgrades.COIN)
	s._parts["sword"] = s._piece(WeaponDefs.mesh("sword"))
	(s._parts["sword"] as MeshInstance3D).visible = false


static func _lucky(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var mark: Dictionary = s._parts["mark"]
	var mark_at := _sp(s, MARK)
	var beside := _sp(s, MARK + Vector2(0.95, 0.3)) # in front of it and to its side, both in view
	var stolen := t >= LUCKY_STEAL and t < 3.3
	holder.position = beside if stolen else _sp(s, THIEF_FROM)
	holder.rotation.y = UpgradeShowcase._facing(holder.position, mark_at)
	s._play(s._person["anim"], "1H_Melee_Attack_Chop" if t > LUCKY_STEAL and t < LUCKY_STEAL + 0.5 else ("PickUp" if t > LUCKY_BACK - 0.4 and t < LUCKY_BACK + 0.2 else "Idle"), 1.4)
	s._show_puff(s._parts["from_puff"], t - LUCKY_STEAL, 0.5, 0.8)
	(s._parts["from_puff"] as Node3D).position = _sp(s, THIEF_FROM) + Vector3.UP
	s._show_puff(s._parts["to_puff"], t - LUCKY_STEAL, 0.5, 0.8)
	(s._parts["to_puff"] as Node3D).position = beside + Vector3.UP
	s._play(mark["anim"], "Hit_A" if t > LUCKY_STEAL + 0.15 and t < LUCKY_STEAL + 0.6 else "Idle", 1.2)
	# The coin flicked up off the pocket, turning, and the potion it came with lying on the ground.
	var coin: MeshInstance3D = s._parts["coin"]
	var c := _w(t, LUCKY_STEAL + 0.2, LUCKY_STEAL + 1.0)
	coin.visible = c > 0.0 and c < 1.0
	coin.position = mark_at.lerp(holder.position, c) + Vector3.UP * (1.2 + sin(c * PI) * 0.9)
	coin.rotation = Vector3(t * 14.0, t * 3.0, 0)
	var potion: MeshInstance3D = s._parts["potion"]
	var drop := _w(t, LUCKY_STEAL + 0.2, LUCKY_STEAL + 0.55)
	potion.visible = drop > 0.0 and t < 3.3
	var lies := holder.position.lerp(mark_at, 0.45) + _sp(s, Vector2(0.35, 0.3))
	potion.position = mark_at.lerp(lies, drop) + Vector3.UP * (sin(drop * PI) * 0.5)
	potion.rotation.z = drop * 1.4
	s._show_puff(s._parts["glint"], t - LUCKY_STEAL - 0.6, 0.5, 0.35)
	(s._parts["glint"] as Node3D).position = lies + Vector3.UP * 0.25
	var sword: MeshInstance3D = s._parts["sword"]
	var fall := _w(t, LUCKY_STEAL + 0.15, LUCKY_STEAL + 0.45)
	sword.visible = fall > 0.0 and t < 3.3
	sword.position = mark_at + _sp(s, Vector2(-0.45, 0.2)) + Vector3.UP * (0.9 * (1.0 - fall) + 0.05)
	sword.rotation = Vector3(PI * 0.5 * fall, 0.4, 0)
	# Three Steals were counted; this one is the fourth: all the marks flare, and the button is back.
	var burst := _w(t, LUCKY_BACK - 0.6, LUCKY_BACK)
	_show_pips(s, s._parts["pips"], holder.position, 3 if t < LUCKY_STEAL else 4, t < LUCKY_STEAL, burst if burst > 0.0 and burst < 1.0 else 0.0)
	if t > LUCKY_BACK:
		for pip: MeshInstance3D in s._parts["pips"]:
			pip.visible = false


# --- Contract: the dome falls, the biggest is named, and its end pays everyone inside ----------------

const MERC := Vector2(0.75, 0.55)
const CONTRACT_BIG := Vector2(-0.6, -0.55)
const CONTRACT_OTHERS := [Vector2(1.15, -1.05), Vector2(-1.5, 0.65)]
const DOME_AT := Vector2(0.0, 0.0)
const DOME_SIZE := 2.6
const NIGHT := 0.3
const NAMED := 0.7
const CONTRACT_BLOWS := [1.35, 1.9]
const CONTRACT_DIES := 2.35

static func _build_contract(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "bandit", "dagger", MERC, CONTRACT_BIG)
	var big := PathScenes._zombie_at(s, CONTRACT_BIG, "normal_b", MERC)
	(big["holder"] as Node3D).scale = Vector3.ONE * 1.35
	s._parts["big"] = big
	var others: Array[Dictionary] = []
	for spot: Vector2 in CONTRACT_OTHERS:
		others.append(PathScenes._zombie_at(s, spot, "normal_a", MERC))
	s._parts["others"] = others
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 1.0
	dome_mesh.height = 2.0
	dome_mesh.radial_segments = 28
	dome_mesh.rings = 14
	var dome := s._piece(dome_mesh, _dome_look())
	dome.visible = false
	s._parts["dome"] = dome
	s._parts["rim"] = s._ring(Color(0.72, 0.5, 0.95), 0.9, 0.025)
	var seal := s._piece(ContractSeal.coin_mesh())
	seal.visible = false
	s._parts["seal"] = seal
	s._parts["feet"] = s._ring(CrownUpgrades.COIN, 0.7, 0.07)
	s._parts["paid"] = s._ring(CrownUpgrades.COIN, 0.9, 0.05)
	s._parts["mend"] = PathScenes._crosses(s, HEAL, 3)
	s._parts["coins"] = s._puff(CrownUpgrades.COIN, 8)


## Dark glass, deepest at its edge: Nightfall's dome as the Store shows it.
static func _dome_look() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(vec3(0.05, 0.02, 0.1), vec3(0.42, 0.26, 0.62), edge * edge);
	ALPHA = (0.22 + 0.55 * edge * edge) * fade;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func _contract(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	var big: Dictionary = s._parts["big"]
	var bh: Node3D = big["holder"]
	var striking := false
	for b: float in CONTRACT_BLOWS:
		if t > b - 0.25 and t < b + 0.25:
			striking = true
	var close := bh.position + (_sp(s, MERC) - bh.position).normalized() * 1.2
	holder.position = _sp(s, MERC).lerp(close, _ease(_w(t, 1.0, 1.2))) if t < 3.0 else close.lerp(_sp(s, MERC), _ease(_w(t, 3.0, 3.5)))
	holder.rotation.y = UpgradeShowcase._facing(holder.position, bh.position)
	s._play(s._person["anim"], "Stance" if t > NIGHT - 0.2 and t < NIGHT + 0.35 else ("1H_Melee_Attack_Chop" if striking else "Idle"), 1.4)
	var open := _ease(_w(t, NIGHT, NIGHT + 0.4)) * (1.0 - _w(t, 3.45, 3.8))
	var dome: MeshInstance3D = s._parts["dome"]
	dome.visible = open > 0.02
	dome.position = _sp(s, DOME_AT)
	dome.scale = Vector3.ONE * DOME_SIZE * maxf(open, 0.02)
	(dome.material_override as ShaderMaterial).set_shader_parameter("fade", open)
	var rim: MeshInstance3D = s._parts["rim"]
	rim.visible = open > 0.02
	rim.position = _sp(s, DOME_AT) + Vector3.UP * 0.03
	rim.scale = Vector3.ONE * DOME_SIZE * maxf(open, 0.02)
	# The seal: struck over the biggest, turning, gone when it falls.
	var named := t > NAMED and t < CONTRACT_DIES
	var seal: MeshInstance3D = s._parts["seal"]
	seal.visible = named
	var pop := _ease(_w(t, NAMED, NAMED + 0.25))
	seal.position = bh.position + Vector3.UP * (1.8 * 1.35 + 0.75 + 0.08 * sin(t * 3.0))
	seal.rotation.y = t * 2.2
	seal.scale = Vector3.ONE * 1.5 * maxf(0.02, pop) * (1.0 + 0.4 * (1.0 - pop))
	var feet: MeshInstance3D = s._parts["feet"]
	feet.visible = named
	feet.position = bh.position + Vector3.UP * 0.05
	feet.scale = Vector3.ONE * 0.75 * (1.0 + 0.06 * sin(t * 4.0))
	if t < CONTRACT_DIES:
		s._play(big["anim"], "Idle")
		for b: float in CONTRACT_BLOWS:
			PathScenes._struck(s, big, t, b + 0.1)
	else:
		s._play(big["anim"], "Death_A" if t < 3.6 else "Idle", 1.2)
	bh.visible = t < 3.55
	for z: Dictionary in s._parts["others"]:
		s._play(z["anim"], "Idle")
	# Paid: a ring of gold through the dome, coins over the body, and everyone inside mended.
	var paid: MeshInstance3D = s._parts["paid"]
	var r := _w(t, CONTRACT_DIES + 0.1, CONTRACT_DIES + 0.6)
	paid.visible = r > 0.0 and r < 1.0
	paid.position = _sp(s, DOME_AT) + Vector3.UP * 0.05
	paid.scale = Vector3.ONE * (0.4 + _ease(r) * (DOME_SIZE - 0.4))
	(paid.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - r)
	s._show_puff(s._parts["coins"], t - CONTRACT_DIES, 0.6, 0.7)
	(s._parts["coins"] as Node3D).position = bh.position + Vector3.UP * 1.6
	PathScenes._show_crosses(s, s._parts["mend"], holder.position, t, t > CONTRACT_DIES + 0.15 and t < CONTRACT_DIES + 1.1)


# --- Toll Road: three fans, and the third pins them in gold -------------------------------------------

const HIGHWAYMAN := Vector2(1.5, 0.75)
const TOLL_FOES := [Vector2(-0.75, -0.8), Vector2(-1.45, 0.25), Vector2(0.2, -1.65)]
const TOLL_FANS := [0.3, 1.1, 1.9]
const TOLL_KNIVES := 5
const TOLL_DIES := 2.8

static func _build_toll(s: UpgradeShowcase) -> void:
	s._person = PathScenes._person_at(s, "bandit", "dagger", HIGHWAYMAN, TOLL_FOES[0])
	var foes: Array[Dictionary] = []
	for spot: Vector2 in TOLL_FOES:
		foes.append(PathScenes._zombie_at(s, spot, "normal_a" if foes.size() % 2 == 0 else "normal_b", HIGHWAYMAN))
	s._parts["foes"] = foes
	var knife := WeaponDefs.mesh("dagger")
	var knives: Array[MeshInstance3D] = []
	for i in TOLL_KNIVES * 3:
		var mi := s._piece(knife)
		mi.visible = false
		if i >= TOLL_KNIVES * 2:
			mi.material_overlay = s._glow(CrownUpgrades.COIN, 0.6)
		knives.append(mi)
	s._parts["knives"] = knives
	var chains: Array[MeshInstance3D] = []
	for i in foes.size():
		chains.append(s._ring(CrownUpgrades.COIN, 0.8, 0.1))
	s._parts["chains"] = chains
	s._parts["pips"] = _pips(s, CrownUpgrades.TOLL_EVERY, CrownUpgrades.COIN)
	var bundle := s._mesh(func(l: LowPoly) -> void:
		for k in 5:
			l.prism(Vector3(-0.06 + k * 0.03, 0.02, -0.28), Vector3(-0.06 + k * 0.03, 0.02, 0.28), 0.012, 0.012, 4, Color(0.6, 0.45, 0.28))
		l.box(Vector3(0, 0.03, 0), Vector3(0.18, 0.05, 0.05), Color(0.35, 0.25, 0.15)))
	var plunder := s._piece(bundle)
	plunder.visible = false
	s._parts["plunder"] = plunder
	s._parts["glint"] = s._puff(CrownUpgrades.COIN, 6)


static func _toll(s: UpgradeShowcase, t: float) -> void:
	var holder: Node3D = s._person["holder"]
	holder.position = _sp(s, HIGHWAYMAN)
	holder.rotation.y = UpgradeShowcase._facing(holder.position, _sp(s, TOLL_FOES[0]))
	var throwing := false
	var thrown := 0
	for f: float in TOLL_FANS:
		if t >= f:
			thrown += 1
		if t > f - 0.15 and t < f + 0.3:
			throwing = true
	s._play(s._person["anim"], "Throw" if throwing else "Idle", 1.5)
	var burst := _w(t, TOLL_FANS[2], TOLL_FANS[2] + 0.4)
	_show_pips(s, s._parts["pips"], holder.position, thrown if thrown < 3 else 0, thrown == 2, burst if burst > 0.0 and burst < 1.0 else 0.0)
	var foes: Array = s._parts["foes"]
	var knives: Array = s._parts["knives"]
	var from := holder.position + Vector3.UP * 1.3
	var aim := (_sp(s, TOLL_FOES[0]) - holder.position).normalized()
	for fan in 3:
		for i in TOLL_KNIVES:
			var mi: MeshInstance3D = knives[fan * TOLL_KNIVES + i]
			var spread := deg_to_rad(lerpf(-28.0, 28.0, float(i) / float(TOLL_KNIVES - 1)))
			var dir := aim.rotated(Vector3.UP, spread)
			var k := _w(t, TOLL_FANS[fan], TOLL_FANS[fan] + 0.35)
			mi.visible = k > 0.0 and k < 1.0
			mi.position = from + dir * k * 3.4 + Vector3.DOWN * k * 0.3
			mi.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, t * 25.0)
	var chains: Array = s._parts["chains"]
	for i in foes.size():
		var z: Dictionary = foes[i]
		var zh: Node3D = z["holder"]
		var home := _sp(s, TOLL_FOES[i])
		# They come on through the first two fans, flinching; the Toll stops them where they stand.
		var pinned_at := TOLL_FANS[2] + 0.2
		var walk := minf(t, pinned_at) / pinned_at
		var toward := (holder.position - home).normalized()
		zh.position = home + toward * walk * 0.5
		zh.rotation.y = UpgradeShowcase._facing(home, holder.position)
		var pinned := t > pinned_at and t < pinned_at + CrownUpgrades.TOLL_PIN
		var dying := i == 0 and t > TOLL_DIES
		zh.visible = not (i == 0 and t > 3.55)
		if dying:
			s._play(z["anim"], "Death_A", 1.2)
		elif pinned:
			s._play(z["anim"], "Hit_A", 0.5)
		else:
			s._play(z["anim"], "Walking_A" if t < pinned_at else "Idle", 0.9)
			for f in 2:
				PathScenes._struck(s, z, t, TOLL_FANS[f] + 0.25)
		var chain: MeshInstance3D = chains[i]
		chain.visible = pinned and not dying
		chain.position = zh.position + Vector3.UP * 0.06
		chain.scale = Vector3.ONE * 0.45 * (1.0 + 0.08 * sin(t * 9.0 + i))
	var plunder: MeshInstance3D = s._parts["plunder"]
	var lies := _sp(s, TOLL_FOES[0]) + (holder.position - _sp(s, TOLL_FOES[0])).normalized() * 0.9
	var drop := _w(t, TOLL_DIES + 0.2, TOLL_DIES + 0.5)
	plunder.visible = drop > 0.0 and t < 3.7
	plunder.position = lies + Vector3.UP * (0.6 * (1.0 - drop) + 0.02)
	plunder.rotation.y = 0.6
	s._show_puff(s._parts["glint"], t - TOLL_DIES - 0.5, 0.45, 0.35)
	(s._parts["glint"] as Node3D).position = lies + Vector3.UP * 0.2
