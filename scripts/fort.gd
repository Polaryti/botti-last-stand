@tool
class_name Fort
extends Node
## Defend the Fort: wooden gates and a heart to protect. The host decides what happens to them. Each
## player repairs gates by coming close with wood, and the gate mends as they stand there.
## The Fort is a square with four gates round its keep (add_gate). Other strongholds, like Mist
## Bastion, give their own wall outline, floor height, gates, small doors and the lanes their enemies
## come up (set_region, add_gate_at, add_door, add_lane).

signal fallen

const HALF := 26.0 # from the centre to the wall
const WALL_H := 6.5
const WALL_T := 2.2
const GATE_W := 5.5
const GATE_H := 4.2
const GATE_HP := 1100.0
const HEART_HP := 2400.0
## Claws do little to oak and stone. A crowd still gets through a gate in about a minute, and
## through the heart in two or three, which leaves time to come back and deal with them.
const WOOD_TOUGHNESS := 0.4
const HEART_TOUGHNESS := 0.3
const CLOSES_AT := 0.35 # a broken gate shuts again when it has this much of its strength back
const WOOD_MAX := 12
const WOOD_PER_PICKUP := 2
const REPAIR_PER_WOOD := 110.0
const REPAIR_EVERY := 0.3
const REPAIR_REACH := 6.5
const NAMES := ["north", "east", "south", "west"]
const DOORS := [-15.0, 15.0, -15.0, 15.0] # where each side's small door is, away from its stairs
const DIRS: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]

var world: World
var gates: Array[Dictionary] = []
var heart_hp := HEART_HP
var heart_at := Vector3.ZERO
var _heart_mesh: Node3D
var _repair_timer := 0.0
var _sync_timer := 0.0
var _dirty := true
var _banner_left := 0.0
var _over := false
var repairing := -1 # the gate the local player is mending right now
## The wall's outline seen from above, for a stronghold that is not the square Fort. Empty: the square.
var region := PackedVector2Array()
## The height of the ground inside the walls. Higher than this by 3 m is up on the wall.
var floor_y := 0.0
## Small doors only players fit through: {at: on the wall's line, out: which way is outside}.
var doors: Array[Dictionary] = []


func _init(owner_world: World) -> void:
	world = owner_world


func add_gate(i: int, node: Node3D, rows: Array[Node3D]) -> void:
	add_gate_at(NAMES[i], DIRS[i] * HALF, DIRS[i], node, rows)


## A gate anywhere: at is the middle of the gateway on the ground, dir the way out. Gates on a
## stronghold that is not the square face along the X or Z axis too.
func add_gate_at(gate_name: String, at: Vector3, dir: Vector3, node: Node3D, rows: Array[Node3D]) -> void:
	var i := gates.size()
	var along_x := absf(dir.z) > 0.5
	var size := Vector3(GATE_W, GATE_H, WALL_T) if along_x else Vector3(WALL_T, GATE_H, GATE_W)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = at + Vector3.UP * GATE_H * 0.5
	body.add_child(cs)
	world.add_child(body)
	gates.append({"i": i, "name": gate_name, "short": gate_name.left(1).to_upper(), "at": at, "dir": dir, "size": size, "hp": GATE_HP, "closed": true,
		"node": node, "rows": rows, "shape": cs, "lane": [] as Array[Vector3]})
	world.grid.set_box(at, size, true)
	var sign_board := Label3D.new()
	sign_board.text = gate_name.to_upper()
	sign_board.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign_board.font_size = 96
	sign_board.outline_size = 24
	sign_board.pixel_size = 0.012
	sign_board.modulate = Color(0.95, 0.8, 0.5)
	# Above the wall and a little outside it, so the battlements never stand in front of it.
	sign_board.position = at + dir * (WALL_T * 0.5 + 0.6) + Vector3.UP * (WALL_H + 1.5)
	world.add_child(sign_board)
	# How much wood the gate needs, painted flat on the wall above the gateway on both sides. A label
	# that turns to face the camera would swing into the wall when seen from the side.
	var requirement := _wall_label("GateWood%d" % i, at + dir * (WALL_T * 0.5 + 0.06), dir)
	var inner := _wall_label("GateWoodInner%d" % i, at - dir * (WALL_T * 0.5 + 0.06), -dir)
	gates.back()["requirement"] = requirement
	gates.back()["inner_requirement"] = inner
	_show_gate(gates.back())


## The outline of a stronghold's walls, and the height of the ground inside them.
func set_region(outline: PackedVector2Array, ground_y: float) -> void:
	region = outline
	floor_y = ground_y


func add_door(at: Vector3, out: Vector3) -> void:
	doors.append({"at": at, "out": out})


## Whether this fort's enemies come up long lanes (Mist Bastion) rather than out of the woods round it.
func has_lanes() -> bool:
	for g in gates:
		if not (g["lane"] as Array).is_empty():
			return true
	return false


## Where the enemies sent against a gate come from: the foot of its lane.
func add_lane(gate: int, foot: Vector3) -> void:
	if gate >= 0 and gate < gates.size():
		(gates[gate]["lane"] as Array[Vector3]).append(foot)


func _wall_label(label_name: String, at: Vector3, facing: Vector3) -> Label3D:
	var l := Label3D.new()
	l.name = label_name
	l.font_size = 64
	l.outline_size = 14
	l.pixel_size = 0.01
	l.modulate = Color(1.0, 0.8, 0.45)
	l.double_sided = false
	l.position = at + Vector3.UP * (GATE_H + (WALL_H - GATE_H) * 0.5)
	l.basis = Basis.looking_at(-facing, Vector3.UP) # the text reads from the side it faces
	world.add_child(l)
	return l


## How much wood it would take to mend this gate completely.
func wood_needed(g: Dictionary) -> int:
	return ceili(maxf(0.0, GATE_HP - float(g["hp"])) / REPAIR_PER_WOOD)


func set_heart(at: Vector3, mesh: Node3D) -> void:
	heart_at = at
	_heart_mesh = mesh


func inside(p: Vector3) -> bool:
	if region.is_empty():
		return absf(p.x) < HALF and absf(p.z) < HALF
	return Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), region)


## How far outside the walls a point is, in metres from their outer face (less than 0 inside).
func outside_by(p: Vector3) -> float:
	if region.is_empty():
		return maxf(absf(p.x), absf(p.z)) - HALF - WALL_T * 0.5
	var flat := Vector2(p.x, p.z)
	var best := INF
	for i in region.size():
		var a := region[i]
		var b := region[(i + 1) % region.size()]
		best = minf(best, flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, a, b)))
	return (-best if inside(p) else best) - WALL_T * 0.5


## A point just outside the walls that every lane and the woods connect to.
func outside_point() -> Vector3:
	if region.is_empty() or gates.is_empty():
		return DIRS[0] * (HALF + 8.0)
	var g: Dictionary = gates[0]
	return (g["at"] as Vector3) + (g["dir"] as Vector3) * 8.0


## Up on the wall, where nothing on foot can reach.
func on_wall(p: Vector3) -> bool:
	return p.y > floor_y + 3.0


func any_open() -> bool:
	for g in gates:
		if not g["closed"]:
			return true
	return false


## The gate a zombie attacks: the one it was given. When the gate nearest it is already open, about a
## quarter of zombies (decided once each, so they don't waver) take that breach instead.
func gate_for(z: Zombie) -> Dictionary:
	if z.fort_gate < 0 or z.fort_gate >= gates.size():
		z.fort_gate = gate_nearest(z.position)["i"]
	var g: Dictionary = gates[z.fort_gate]
	if g["closed"] and z.fort_shortcut and any_open():
		var near := gate_nearest(z.position)
		if not near["closed"]:
			return near
	return g


## The gate with the fewest zombies sent against it right now; ties are broken at random.
func least_pressed_gate(zombies: Array[Zombie]) -> int:
	var counts: Array[int] = []
	counts.resize(gates.size())
	counts.fill(0)
	for z in zombies:
		if z.is_alive() and z.fort_gate >= 0 and z.fort_gate < counts.size():
			counts[z.fort_gate] += 1
	var low: int = counts.min()
	var options: Array[int] = []
	for i in gates.size():
		if counts[i] == low:
			options.append(i)
	return options[randi() % options.size()] if not options.is_empty() else randi() % maxi(1, gates.size())


func gate_nearest(p: Vector3) -> Dictionary:
	var best := gates[0]
	for g in gates:
		if p.distance_squared_to(g["at"]) < p.distance_squared_to(best["at"]):
			best = g
	return best


## Where to stand when hitting this gate, on whichever side you are.
func gate_front(g: Dictionary, from: Vector3) -> Vector3:
	var dir: Vector3 = g["dir"]
	var out_side := 1.0 if (from - (g["at"] as Vector3)).dot(dir) >= 0.0 else -1.0
	return (g["at"] as Vector3) + dir * out_side * (WALL_T * 0.5 + 0.9)


func hit_gate(g: Dictionary, damage: float, from: Vector3) -> void:
	if Net.is_client() or not g["closed"]:
		return
	g["hp"] = maxf(0.0, float(g["hp"]) - damage)
	_dirty = true
	world.sfx_at("thunk", from, -2.0)
	if float(g["hp"]) <= 0.0:
		_set_closed(g, false)
		world.sfx_at("blast", g["at"], 0.0)
		world.fx_blast((g["at"] as Vector3) + Vector3.UP * 2.0, 3.0, Color(0.5, 0.34, 0.18, 0.5))
		world.banner("The %s gate has fallen!" % g["name"], 3.5)
	_show_gate(g)


func hit_heart(damage: float) -> void:
	if Net.is_client() or _over:
		return
	heart_hp = maxf(0.0, heart_hp - damage)
	_dirty = true
	if _banner_left <= 0.0:
		_banner_left = 12.0
		if world.map_id == "bastion":
			world.banner("The Great Portal is under attack!", 3.0)
			world.sfx_at("portal_wound", heart_at, -2.0)
			if Net.is_host():
				Net.sound_at("portal_wound", heart_at, -2.0)
		else:
			world.banner("They are at the portal!", 3.0)
			world.sfx_at("banshee", heart_at, -6.0)
	if heart_hp <= 0.0:
		_over = true
		if _heart_mesh:
			_heart_mesh.visible = false
		world.fx_blast(heart_at + Vector3.UP * 1.5, 6.0, Color(0.9, 0.3, 0.2, 0.5))
		world.sfx_at("blast", heart_at, 4.0)
		fallen.emit()


## Mending: only the host writes the result, whoever is holding the wood.
func repair(i: int, amount: float) -> void:
	if i < 0 or i >= gates.size() or not is_finite(amount) or amount <= 0.0:
		return
	if Net.is_client():
		Net.repair_gate(i, amount)
		return
	var g := gates[i]
	g["hp"] = minf(GATE_HP, float(g["hp"]) + amount)
	_dirty = true
	if not g["closed"] and float(g["hp"]) >= GATE_HP * CLOSES_AT and not _doorway_busy(g):
		_set_closed(g, true)
		world.sfx_at("hammer", g["at"], -2.0)
	_show_gate(g)


func _doorway_busy(g: Dictionary) -> bool:
	for target: Target in world.players:
		if not target.dead and target.global_position.distance_to(g["at"]) < GATE_W * 0.7: return true
	for ally: Ally in world.allies:
		if not ally.dead and ally.global_position.distance_to(g["at"]) < GATE_W * 0.7: return true
	for z in world.zombies:
		if z.is_alive() and not z.flies and z.position.distance_to(g["at"]) < GATE_W * 0.7:
			return true
	return false


func _set_closed(g: Dictionary, closed: bool) -> void:
	_dirty = true
	g["closed"] = closed
	(g["shape"] as CollisionShape3D).set_deferred("disabled", not closed)
	world.grid.set_box(g["at"], g["size"], closed)
	_show_gate(g)


## A gate loses its planks from the top down as it takes damage.
func _show_gate(g: Dictionary) -> void:
	var requirement: Label3D = g.get("requirement")
	if requirement:
		var needed := wood_needed(g)
		requirement.text = "%d WOOD\nto repair" % needed
		requirement.visible = needed > 0
		var inner: Label3D = g.get("inner_requirement")
		if inner:
			inner.text = requirement.text
			inner.visible = requirement.visible
	var f := float(g["hp"]) / GATE_HP
	var rows: Array[Node3D] = g["rows"]
	for r in rows.size():
		rows[r].visible = g["closed"] and f > float(r) / rows.size() - 0.001 or (not g["closed"] and r == 0 and f > 0.05)


func damaged_gate_near(p: Vector3) -> int:
	for g in gates:
		if float(g["hp"]) < GATE_HP and Vector2(p.x - (g["at"] as Vector3).x, p.z - (g["at"] as Vector3).z).length() < REPAIR_REACH:
			return g["i"]
	return -1


func _process(delta: float) -> void:
	_banner_left -= delta
	_tick_repair(delta)
	if Net.is_client():
		return
	if Net.is_host():
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = 0.2
			if _dirty:
				_dirty = false
				Net.send_fort(_state())
	# A gate that got its strength back waits only for the doorway to clear.
	for g in gates:
		if not g["closed"] and float(g["hp"]) >= GATE_HP * CLOSES_AT and not _doorway_busy(g):
			_set_closed(g, true)


func _tick_repair(delta: float) -> void:
	repairing = -1
	_repair_timer -= delta
	var mend := _repair_timer <= 0.0
	if mend:
		_repair_timer = REPAIR_EVERY
	# Everyone this phone moves mends what they stand by: its player, and on the host its bots.
	for p: Player in world.local_players():
		if p.dead or p.wood <= 0:
			continue
		var i := damaged_gate_near(p.global_position)
		if i < 0:
			continue
		if p == world.player:
			repairing = i
		if mend:
			p.wood -= 1
			repair(i, REPAIR_PER_WOOD)
			p.sfx("hammer", -10.0, 1.3, 0.2)


func _state() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(gates.size() * 3 + 2)
	var at := 0
	for g in gates:
		b.encode_u16(at, int(g["hp"]))
		b.encode_u8(at + 2, 1 if g["closed"] else 0)
		at += 3
	b.encode_u16(at, int(heart_hp))
	return b


func apply_state(b: PackedByteArray) -> void:
	var at := 0
	for g in gates:
		if at + 3 > b.size():
			return
		g["hp"] = float(b.decode_u16(at))
		var closed := b.decode_u8(at + 2) == 1
		if closed != g["closed"]:
			_set_closed(g, closed)
		_show_gate(g)
		at += 3
	if at + 2 <= b.size():
		heart_hp = float(b.decode_u16(at))
