class_name MistPortals
extends Node3D
## The gates between the floating islands. They open and close by themselves, but one way round is
## always left open, so nobody is ever cut off. Players, bots and mobs all walk through them.

const REACH := 1.5 # how close counts as stepping in
const OUT := 2.4 # how far past the other end you come out
const CHANGE_EVERY := 16.0
const WARN_TIME := 4.0 # a gate about to close flickers this long first
const SYNC_EVERY := 5.0

var world: World
var islands: Array[Vector4] = []
var links: Array[Dictionary] = [] # a, b: where each end stands. ia, ib: its island. open, closing: seconds left, or 0
var _timer := CHANGE_EVERY
var _sync := 1.0


func _init(owner_world: World, island_list: Array[Vector4]) -> void:
	world = owner_world
	islands = island_list


func add_link(ia: int, ib: int, a: Vector3, b: Vector3) -> void:
	var link := {"ia": ia, "ib": ib, "a": a, "b": b, "open": false, "closing": 0.0, "nodes": [_make_end(a), _make_end(b)]}
	links.append(link)


func _make_end(at: Vector3) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.global_position = at
	var look := at - Vector3(0, at.y, 0)
	if look.length() > 1.0:
		node.rotation.y = atan2(look.x, look.z)
	var stones := MeshInstance3D.new()
	var l := LowPoly.new()
	const SIDES := 10
	for i in SIDES:
		var a0 := PI * 2.0 * i / SIDES
		var a1 := PI * 2.0 * (i + 1) / SIDES
		l.prism(Vector3(cos(a0) * 1.25, 1.3 + sin(a0) * 1.25, 0), Vector3(cos(a1) * 1.25, 1.3 + sin(a1) * 1.25, 0), 0.17, 0.17, 5, Color(0.36, 0.33, 0.46))
	stones.mesh = l.commit()
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(stones)
	var veil := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.12
	disc.bottom_radius = 1.12
	disc.height = 0.04
	disc.radial_segments = 16
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.66, 0.42, 1.0, 0.78)
	disc.material = mat
	veil.mesh = disc
	veil.rotation.x = PI * 0.5
	veil.position.y = 1.3
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(veil)
	node.set_meta("veil", veil)
	node.visible = false
	return node


## Every other island reached from the middle, to begin with.
func open_starting_links() -> void:
	for link: Dictionary in links:
		link["open"] = link["ia"] == 0 or link["ib"] == 0
		_show(link)


func _show(link: Dictionary) -> void:
	for node: Node3D in link["nodes"]:
		node.visible = link["open"]


func _process(delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	for link: Dictionary in links:
		if not link["open"]:
			continue
		var flicker := float(link["closing"]) > 0.0 and fmod(Time.get_ticks_msec() * 0.008, 1.0) < 0.5
		for node: Node3D in link["nodes"]:
			var veil := node.get_meta("veil") as MeshInstance3D
			veil.visible = not flicker
			veil.scale = Vector3.ONE * (0.94 + 0.06 * pulse)
	if Net.is_client():
		return
	for link: Dictionary in links:
		if float(link["closing"]) > 0.0:
			link["closing"] = float(link["closing"]) - delta
			if float(link["closing"]) <= 0.0:
				link["closing"] = 0.0
				link["open"] = false
				_show(link)
				_tell_others()
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHANGE_EVERY
		_change_one()
		_tell_others()
	if Net.is_host():
		_sync -= delta
		if _sync <= 0.0:
			_sync = SYNC_EVERY
			_tell_others()


## One more gate opens, and one that is not needed starts to close.
func _change_one() -> void:
	var closed: Array[Dictionary] = []
	for link: Dictionary in links:
		if not link["open"]:
			closed.append(link)
	if not closed.is_empty():
		var opening: Dictionary = closed.pick_random()
		opening["open"] = true
		_show(opening)
	var spare := links.filter(func(link: Dictionary) -> bool: return link["open"] and float(link["closing"]) <= 0.0)
	spare.shuffle()
	for link: Dictionary in spare:
		link["open"] = false
		var still_joined := _all_joined()
		link["open"] = true
		if still_joined:
			link["closing"] = WARN_TIME
			return


func _usable(link: Dictionary) -> bool:
	return link["open"] and float(link["closing"]) <= 0.0


func _all_joined() -> bool:
	return _hops_from(0).size() == islands.size()


## How to reach every island from this one: island -> the gate to take first.
func _hops_from(start: int) -> Dictionary:
	var seen := {start: {}}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var here: int = queue.pop_front()
		for link: Dictionary in links:
			if not _usable(link):
				continue
			var next := -1
			if int(link["ia"]) == here:
				next = int(link["ib"])
			elif int(link["ib"]) == here:
				next = int(link["ia"])
			if next < 0 or seen.has(next):
				continue
			seen[next] = link if here == start else seen[here]
			queue.append(next)
	return seen


func island_of(at: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in islands.size():
		var d := Vector2(at.x - islands[i].x, at.z - islands[i].y).length() - islands[i].z
		if d < best_d:
			best_d = d
			best = i
	return best


## Where to walk to get to a spot: the spot itself, or the gate that leads towards it.
func waypoint(from: Vector3, to: Vector3) -> Vector3:
	var here := island_of(from)
	var there := island_of(to)
	if here == there:
		return to
	var hops := _hops_from(here)
	if not hops.has(there):
		return from
	var link: Dictionary = hops[there]
	return link["a"] if int(link["ia"]) == here else link["b"]


## If this spot is in an open gate, where it comes out. Otherwise Vector3.INF.
func exit_from(at: Vector3) -> Vector3:
	for link: Dictionary in links:
		if not link["open"]:
			continue
		var a: Vector3 = link["a"]
		var b: Vector3 = link["b"]
		if Vector2(at.x - a.x, at.z - a.z).length() < REACH:
			return _beyond(b, int(link["ib"]))
		if Vector2(at.x - b.x, at.z - b.z).length() < REACH:
			return _beyond(a, int(link["ia"]))
	return Vector3.INF


func _beyond(end: Vector3, island: int) -> Vector3:
	var centre := Vector3(islands[island].x, end.y, islands[island].y)
	var out := end + (centre - end).normalized() * OUT
	out.y = world.ground_at(out) + 0.1
	return out


func state_bits() -> PackedByteArray:
	var bits := PackedByteArray()
	for link: Dictionary in links:
		bits.append((1 if link["open"] else 0) | (2 if float(link["closing"]) > 0.0 else 0))
	return bits


func apply_state(bits: PackedByteArray) -> void:
	for i in mini(bits.size(), links.size()):
		links[i]["open"] = bits[i] & 1 != 0
		links[i]["closing"] = WARN_TIME if bits[i] & 2 != 0 else 0.0
		_show(links[i])


func _tell_others() -> void:
	if Net.is_host():
		Net.send_portals(state_bits())
