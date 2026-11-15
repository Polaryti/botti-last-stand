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
## top of each gate.
const REINFORCED := 1.15
const REINFORCEMENTS := "mist_reinforcements"

var world: World
var next_at := FIRST
var _turns := {} # gate -> how many have stepped out on that lane
var _announced := false
var reinforced := false
var _archers_up := false
## How much stronger (damage and health) every Mist Soldier is.
var power := 1.0


func _init(owner_world: World) -> void:
	world = owner_world
	reinforced = ShopDefs.map_upgrade_on(REINFORCEMENTS)
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


## Mist Reinforcements: a Mist Ranger on top of every gate, there all night, shooting down the lane.
func _man_the_gates() -> void:
	for gate in world.fort.gates.size():
		var g: Dictionary = world.fort.gates[gate]
		var top: Vector3 = (g["at"] as Vector3) + Vector3.UP * Fort.WALL_H - (g["dir"] as Vector3) * 0.2
		var a := world.spawn_garrison("mist_ranger", gate, top, top)
		a.perch = top
		a.global_position = top
		world.fx_blast(top + Vector3.UP, 1.2, Color(0.45, 0.95, 0.92, 0.6))
	world.director.show_banner("Mist Reinforcements: a Mist Ranger stands on every gate", 3.5)
