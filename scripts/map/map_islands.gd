@tool
class_name MapIslands
extends MapPiece
## Floating islands in an empty sky, in the manner of the Mists. Each island is x, z, radius and
## height. Everything else is a long way down. Island 0 is the middle one.

const ISLANDS: Array[Vector4] = [
	Vector4(0, 0, 34, 4), Vector4(72, -8, 24, 6), Vector4(-70, 10, 24, 2.5), Vector4(8, 74, 23, 5.5),
	Vector4(-6, -72, 26, 3), Vector4(62, 62, 19, 8), Vector4(-60, -62, 20, 6), Vector4(-62, 66, 17, 3),
]
## Small stepping stones: a brave jump takes you across, and nothing else can follow.
const STONES: Array[Vector4] = [Vector4(41, -3.5, 5.5, 5), Vector4(-3, -40, 4.5, 3.5)]
const LINKS := [[0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [0, 7], [1, 5], [5, 3], [3, 7], [7, 2], [2, 6], [6, 4], [4, 1]]
const ROCK := Color(0.2, 0.17, 0.27)
const STONE := Color(0.42, 0.39, 0.52)
const GLOW := Color(0.66, 0.42, 1.0)


func _init() -> void:
	on_ground = false


func land(t: Terrain, _at: Transform3D) -> void:
	for i: Vector4 in ISLANDS:
		t.add_island(i, 0.03)
	for i: Vector4 in STONES:
		t.add_island(i, 0.0)


func shapes_land() -> bool:
	return true


func build(b: MapBuilder) -> void:
	for i: Vector4 in ISLANDS + STONES:
		_underside(b, i)
	if b.is_preview:
		return
	var w: World = b.w
	var portals := MistPortals.new(w, ISLANDS)
	w.add_child(portals)
	w.portals = portals
	var used := {}
	for pair: Array in LINKS:
		var ia: int = pair[0]
		var ib: int = pair[1]
		portals.add_link(ia, ib, _end_towards(b, ia, ib, used), _end_towards(b, ib, ia, used))
	portals.open_starting_links()
	for n in 4:
		var a := TAU * n / 4.0 + 0.4
		w.start_spots.append(Vector3(cos(a) * 4.0, 0, sin(a) * 4.0))
	for n in ISLANDS.size():
		_dress(b, ISLANDS[n], n)


func _underside(b: MapBuilder, i: Vector4) -> void:
	var l := LowPoly.new()
	var r := i.z * 0.95
	var y := i.w - 1.0
	l.prism(Vector3(i.x, y, i.y), Vector3(i.x, y - r * 0.5, i.y), r, r * 0.55, 9, ROCK)
	l.prism(Vector3(i.x, y - r * 0.5, i.y), Vector3(i.x + r * 0.1, y - r * 1.15, i.y - r * 0.08), r * 0.55, 0.3, 7, ROCK.darkened(0.25))
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(mi)


## Each gate stands near the edge that faces where it goes, shifted along if the place is taken.
func _end_towards(b: MapBuilder, from: int, to: int, used: Dictionary) -> Vector3:
	var f := ISLANDS[from]
	var t := ISLANDS[to]
	var dir := Vector2(t.x - f.x, t.y - f.y).normalized()
	var at := Vector2(f.x, f.y) + dir * f.z * 0.68
	var tries := 0
	while tries < 8:
		var clash := false
		for other: Vector2 in used.get(from, []):
			if other.distance_to(at) < 6.0:
				clash = true
		if not clash:
			break
		tries += 1
		at = Vector2(f.x, f.y) + dir.rotated(0.45 * tries * (1.0 if tries % 2 == 0 else -1.0)) * f.z * 0.68
	if not used.has(from):
		used[from] = []
	used[from].append(at)
	return Vector3(at.x, b.terrain.height(at.x, at.y), at.y)


## Old stones, lights and things worth finding.
func _dress(b: MapBuilder, i: Vector4, index: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7700 + index
	var w: World = b.w
	for n in int(i.z / 3.5):
		var a := r.randf() * TAU
		var at := Vector3(i.x + cos(a) * i.z * r.randf_range(0.2, 0.6), 0, i.y + sin(a) * i.z * r.randf_range(0.2, 0.6))
		w.loot_spots.append(at)
		w.pois.append(at)
	for n in 3 if index == 0 else 2:
		var a := r.randf() * TAU
		var at := Vector3(i.x + cos(a) * i.z * 0.45, 0, i.y + sin(a) * i.z * 0.45)
		_pillar(b, at, r.randf_range(4.0, 6.5))
	for n in 4 if index == 0 else 2:
		var a := TAU * (n + r.randf()) / 4.0
		var at := Vector3(i.x + cos(a) * i.z * 0.55, 0, i.y + sin(a) * i.z * 0.55)
		at.y = b.terrain.height(at.x, at.z)
		if b.w.grid.is_free(b.w.grid.to_cell(at)):
			b.stand_at(Transform3D(Basis.IDENTITY, at))
			b.torch()
	for n in 2:
		var a := r.randf() * TAU
		var at := Vector3(i.x + cos(a) * i.z * 0.7, 0, i.y + sin(a) * i.z * 0.7)
		at.y = b.terrain.height(at.x, at.z)
		var yaw := r.randf() * TAU
		b.stand_at(Transform3D(Basis(Vector3.UP, yaw), at))
		b.mesh()
		var l := b.mesh()
		l.box(Vector3(0, 0.45, 0), Vector3(4.0, 0.9, 0.6), STONE)
		l.box(Vector3(-1.2, 1.05, 0), Vector3(1.4, 0.4, 0.55), STONE.darkened(0.1))
		b.add(l)
		b.solid(Vector3(0, 0.6, 0), Vector3(4.0, 1.2, 0.6))


func _pillar(b: MapBuilder, at: Vector3, tall: float) -> void:
	at.y = b.terrain.height(at.x, at.z)
	b.stand_at(Transform3D(Basis.IDENTITY, at))
	var l := b.mesh()
	l.box(Vector3(0, 0.2, 0), Vector3(1.5, 0.4, 1.5), STONE.darkened(0.15))
	l.prism(Vector3(0, 0.4, 0), Vector3(0, tall, 0), 0.5, 0.42, 7, STONE)
	l.box(Vector3(0, tall + 0.12, 0), Vector3(1.2, 0.24, 1.2), STONE.lightened(0.08))
	b.add(l)
	b.solid(Vector3(0, tall * 0.5, 0), Vector3(1.1, tall, 1.1))
	b.w.perches.append(at + Vector3.UP * (tall + 0.3))
