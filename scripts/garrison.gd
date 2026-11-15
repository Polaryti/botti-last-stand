class_name Garrison
extends RefCounted
## Mist Bastion's garrison. Every so often a Mist Soldier steps out of each lane's waystone and walks
## down to that lane's post, until the lane has its full guard: an Infantry, then a Ranger, and from
## 3:00 a Heavy in turn. Only the host (or a phone playing alone) musters them; the other phones see
## them as the host's soldiers.

const FIRST := 20.0
const EVERY := 40.0
const PER_LANE := 2
const HEAVY_FROM := 180.0
const ORDER := ["mist_infantry", "mist_ranger", "mist_heavy"]
const NAMES := {"mist_infantry": "Mist Infantry", "mist_ranger": "Mist Ranger", "mist_heavy": "Mist Heavy"}
## Mist Reinforcements (a Map Upgrade): every Mist Soldier this much stronger, and a Mist Ranger on
## top of each gate. It has levels, one for each player in the match who brings it (ShopDefs.MAP_LEVELS):
## Level 2 puts GATE_ARCHERS Rangers on each gate, Level 3 gives those two Fire and Poison Arrows, and
## Level 4 sets PORTAL_HEAVIES Mist Heavies to guard the Great Portal in the courtyard.
const REINFORCED := 1.15
const REINFORCEMENTS := "mist_reinforcements"
const GATE_ARCHERS := 2
const ARCHERS_APART := 2.6 # metres between the two Rangers on a gate, along its wall, before each
## steps into the gap between merlons nearest it (Fort.crenel_near)
const ARCHER_ARROWS := ["fire", "poison"] # Level 3: what each of a gate's two Rangers shoots
const PORTAL_HEAVIES := 3
const PORTAL_RING := 4.5 # how far from the portal they stand

var world: World
var next_at := FIRST
var _turns := {} # gate -> how many have stepped out on that lane
var _announced := false
var reinforced := false
## Mist Reinforcements' level in this match: 0 without it, up to ShopDefs.MAP_LEVELS.
var level := 0
var _archers_up := false
## How much stronger (damage and health) every Mist Soldier is.
var power := 1.0


func _init(owner_world: World) -> void:
	world = owner_world
	set_level(ShopDefs.map_upgrade_level(REINFORCEMENTS))


func set_level(n: int) -> void:
	level = clampi(n, 0, ShopDefs.MAP_LEVELS)
	reinforced = level > 0
	power = REINFORCED if reinforced else 1.0


## Where on a lane: its "muster" or "post", or INF if the map does not say.
func mark(gate: int, kind: String) -> Vector3:
	for m: Dictionary in world.lane_marks:
		if m["kind"] == kind and int(m["gate"]) == gate:
			return m["at"]
	return Vector3.INF


func on_lane(gate: int) -> int:
	var n := 0
	for a: Ally in world.allies:
		if not a.dead and a.remote_owner == 0 and a.lane == gate and a.is_garrison() and a.perch == Vector3.INF:
			n += 1
	return n


## Which soldier the lane gets next: they take turns, and the Heavy waits for 3:00.
func next_kind(gate: int, elapsed: float) -> String:
	var turn: int = _turns.get(gate, 0)
	var kind: String = ORDER[turn % ORDER.size()]
	if kind == "mist_heavy" and elapsed < HEAVY_FROM:
		kind = "mist_infantry"
	return kind


func tick(elapsed: float) -> void:
	if reinforced and not _archers_up and world.fort != null:
		_archers_up = true
		_man_the_gates()
	if elapsed < next_at or world.fort == null:
		return
	next_at = elapsed + EVERY
	var any := false
	for gate in world.fort.gates.size():
		if on_lane(gate) >= PER_LANE:
			continue
		var muster := mark(gate, "muster")
		var post := mark(gate, "post")
		if muster == Vector3.INF or post == Vector3.INF:
			continue
		var kind := next_kind(gate, elapsed)
		_turns[gate] = int(_turns.get(gate, 0)) + 1
		world.spawn_garrison(kind, gate, muster, post)
		world.fx_blast(muster + Vector3.UP, 1.6, Color(0.45, 0.95, 0.92, 0.6))
		world.sfx_at("mist_muster", muster, 0.0)
		if Net.is_host():
			Net.blast_fx(muster + Vector3.UP, 1.6, Color(0.45, 0.95, 0.92, 0.6))
			Net.sound_at("mist_muster", muster, 0.0)
		any = true
	if any and not _announced:
		_announced = true
		world.director.show_banner("Mist Soldiers step out of the waystones to hold the lanes", 3.5)


## Mist Reinforcements: Mist Rangers on top of every gate, there all night, with a Long Bow for the lane
## and a Crossbow for the foot of the gate; from Level 4, Mist Heavies around the portal as well.
func _man_the_gates() -> void:
	var archers := GATE_ARCHERS if level >= 2 else 1
	for gate in world.fort.gates.size():
		var g: Dictionary = world.fort.gates[gate]
		var out: Vector3 = g["dir"]
		var along := out.cross(Vector3.UP).normalized()
		var top: Vector3 = (g["at"] as Vector3) + Vector3.UP * Fort.WALL_H - out * 0.2
		var stood: Array[Vector3] = []
		for i in archers:
			# Each stands in a gap between the merlons, so it can lean out through it.
			var spot := world.fort.crenel_near(top + along * ARCHERS_APART * (float(i) - float(archers - 1) * 0.5), along, stood)
			stood.append(spot)
			var a := world.spawn_garrison("mist_ranger", gate, spot, spot)
			a.perch = spot
			a.perch_out = out
			a.global_position = spot
			a.arm("longbow")
			a.arrow_kind = ARCHER_ARROWS[i] if level >= 3 else ""
			world.fx_blast(spot + Vector3.UP, 1.2, Color(0.45, 0.95, 0.92, 0.6))
	if level >= 4:
		_guard_the_portal()
	world.director.show_banner(banner(), 3.5)


## Level 4: Mist Heavies in the courtyard, around the portal, for whatever gets inside.
func _guard_the_portal() -> void:
	var heart := world.fort.heart_at
	for i in PORTAL_HEAVIES:
		var turn := TAU * float(i) / float(PORTAL_HEAVIES) + PI / 4.0
		var spot := heart + Vector3(sin(turn), 0.0, cos(turn)) * PORTAL_RING
		var a := world.spawn_garrison("mist_heavy", -1, spot, spot)
		a.post = a.global_position
		a.fell_back = true # its place is the portal, and what it fights is whatever is inside
		world.fx_blast(a.global_position + Vector3.UP, 1.6, Color(0.45, 0.95, 0.92, 0.6))


## What the night says when the Reinforcements arrive, by level.
func banner() -> String:
	match level:
		1: return "Mist Reinforcements: a Mist Ranger stands on every gate"
		2: return "Mist Reinforcements, Level 2: two Mist Rangers stand on every gate"
		3: return "Mist Reinforcements, Level 3: Fire and Poison Arrows from every gate"
	return "Mist Reinforcements, Level 4: Mist Heavies guard the Great Portal"
