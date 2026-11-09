@tool
class_name MapIslands
extends MapPiece
## The Mists: tall rock islands standing out of a sea of teal mist, at very different heights. A sunken
## arena in the middle, a white rotunda high to the north, ruined battlements to the east, an old forest
## to the west, a monument to the south, and waterfalls pouring off the highest rock. Some islands are
## joined by bridges, the rest by gates. Stepping stones hang in the air, and they lead to caches.

## x, z, radius, height of the land. The first nine are the islands, the rest are lower shelves of them.
const ISLANDS: Array[Vector4] = [
	Vector4(0, 0, 64, 18), Vector4(0, -122, 40, 40), Vector4(122, -8, 42, 26), Vector4(-124, 8, 46, 14),
	Vector4(8, 124, 34, 24), Vector4(84, -118, 26, 46), Vector4(-96, 100, 30, 8), Vector4(-92, -100, 28, 32),
	Vector4(106, 104, 30, 12),
	Vector4(-46, -104, 24, 28), Vector4(150, 38, 20, 18), Vector4(-30, 146, 18, 14), Vector4(-146, -24, 20, 25),
]
const ROUGH: Array[float] = [0.0, 0.3, 0.5, 2.2, 0.4, 0.5, 0.6, 0.8, 0.7, 0.5, 0.5, 0.5, 1.4]
const WOBBLE: Array[float] = [0.02, 0.05, 0.06, 0.07, 0.05, 0.05, 0.07, 0.07, 0.06, 0.05, 0.05, 0.05, 0.05]
## From a shelf up to its island: x, y, z at each end.
const RAMPS := [
	[Vector3(-56, 28, -104), Vector3(-12, 40, -120)],
	[Vector3(152, 18, 38), Vector3(126, 26, 2)],
	[Vector3(-36, 14, 146), Vector3(4, 24, 118)],
	[Vector3(-130, 14, 2), Vector3(-148, 25, -22)],
]
## Bridges: from, to, how they curve, half their width, and whether they are stone.
const BRIDGES := [
	[Vector2(58, -2), Vector2(88, -6), 0.4, 2.2, true],
	[Vector2(-58, 4), Vector2(-84, 6), -1.2, 1.6, false],
	[Vector2(34, -120), Vector2(64, -118), -1.0, 1.6, false],
	[Vector2(36, 130), Vector2(84, 112), -1.6, 1.6, false],
]
## The islands each bridge joins, and the shelves that belong to each island.
const JOINED := [[0, 2], [0, 3], [1, 5], [4, 8], [1, 9], [2, 10], [4, 11], [3, 12]]
const LINKS := [[0, 1], [0, 4], [0, 6], [0, 7], [3, 6], [3, 7], [2, 5], [2, 8], [1, 7], [4, 6]]

## Rotundas: where, radius, how tall, and the height of the land around them.
const ROTUNDAS := [[Vector2(0, -122), 10.0, 9.0, 40.0], [Vector2(-92, -100), 6.5, 6.5, 32.0], [Vector2(112, 108), 5.5, 5.5, 12.0]]
const ROTUNDA_RISE := 0.5
## Pools: where, how wide, the height of the land, and which ways the water runs off to fall from the edge.
const WATERS := [
	[Vector2(90, -122), 8.0, 46.0, [Vector2(1.0, -0.3), Vector2(0.5, 0.9), Vector2(0.72, -0.86)]],
	[Vector2(-134, 36), 5.0, 14.0, [Vector2(-0.15, 1.0)]],
	[Vector2(146, -2), 4.5, 26.0, [Vector2(1.0, 0.1)]],
	[Vector2(-96, 100), 5.5, 8.0, []],
]

const STONE_RADIUS := 1.8
const STONE_STEP := 5.3 # from one stone's middle to the next: a jump of a little under 2 m
const STONE_RISE := 0.55 # no more than this up from one stone to the next
const CACHE_RADIUS := 3.2
const LANDING_RADIUS := 3.0

const MARBLE := Color(0.76, 0.78, 0.8)
const STONE := Color(0.5, 0.52, 0.55)
const DARK_STONE := Color(0.36, 0.39, 0.45)
const ROCK := Color(0.3, 0.33, 0.38)
const MOSS := Color(0.3, 0.5, 0.42)
const WOOD := Color(0.42, 0.28, 0.16)
const ROPE := Color(0.62, 0.5, 0.3)
const GOLD := Color(0.95, 0.74, 0.28)
const GLOW := Color(0.45, 0.98, 0.92)
const SEA_Y := -9.0

var _rng := RandomNumberGenerator.new()
var _foliage: Array[Vector4] = []


func _init() -> void:
	on_ground = false


func land(t: Terrain, _at: Transform3D) -> void:
	for n in ISLANDS.size():
		t.add_island(ISLANDS[n], WOBBLE[n], ROUGH[n])
	# The arena is a bowl: stone seats going up from a flat floor to the rim.
	t.terrace(Vector2.ZERO, 30.0, 54.0, 10.0, 18.0)
	# The rotundas stand on low mounds you can walk straight up.
	for r: Array in ROTUNDAS:
		var at: Vector2 = r[0]
		t.terrace(at, float(r[1]) + 1.6, float(r[1]) + 6.0, float(r[3]) + ROTUNDA_RISE, float(r[3]))
	for w: Array in WATERS:
		var pool: Vector2 = w[0]
		var bed: float = float(w[2]) - 0.7
		var flat: Array[Vector3] = [Vector3(pool.x, bed, pool.y), Vector3(pool.x + 0.1, bed, pool.y)]
		t.cut(flat, float(w[1]), 1.5)
		for dir: Vector2 in w[3]:
			var far: Vector2 = pool + dir.normalized() * 70.0
			var line: Array[Vector3] = [Vector3(pool.x, bed, pool.y), Vector3(far.x, bed, far.y)]
			t.cut(line, 1.7, 1.0)
	for r: Array in RAMPS:
		var line: Array[Vector3] = [r[0], r[1]]
		t.cut(line, 3.0, 2.0)
	for br: Array in BRIDGES:
		t.bridge(br[0], br[1], br[2], br[3])


func shapes_land() -> bool:
	return true


## Which islands can walk to which without a gate.
static func regions() -> Array[int]:
	var out: Array[int] = []
	for n in ISLANDS.size():
		out.append(n)
	for pair: Array in JOINED:
		var from: int = out[pair[1]]
		var to: int = out[pair[0]]
		for n in out.size():
			if out[n] == from:
				out[n] = to
	return out


## Every line of stones. Each is a list of points in the air, x, y, z, and the stones lie along it at even
## steps. The last stone of a line is the big one, and if the line says so, it holds a cache.
static func stone_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Off the arena's rim, out over the void, to a rock with a cache on it.
	out.append({"points": [Vector3(-46.5, 18.5, -46.5), Vector3(-62, 20.2, -38), Vector3(-76, 22, -50), Vector3(-68, 23.5, -66)], "coins": 25, "reward": "angel"})
	# Round and round the great tree of the forest. A fall only lands you on the grass.
	out.append({"points": _spiral(Vector2(-124, 8), 15.0, 14.5, 28.0, 0.4, 1.55), "coins": 30, "reward": "ghost"})
	# Up around the tall tower of the battlements, to its top.
	var tower := _spiral(Vector2(128, -20), 11.0, 26.5, 39.8, 2.2, 2.1)
	tower.append(Vector3(128, 40.2, -20) + _outward(tower, Vector2(128, -20)) * 7.2)
	out.append({"points": tower, "coins": 30, "weapon": "bell_hammer", "landing": Vector3(128, 40.6, -20)})
	# The long climb around the rotunda, to the top of its dome. Falling only costs you the climb.
	var dome := _spiral(Vector2(0, -122), 20.5, 40.5, 58.0, PI, 2.2)
	dome.append(Vector3(0, 58.7, -122) + _outward(dome, Vector2(0, -122)) * 7.0)
	out.append({"points": dome, "coins": 60, "reward": "daemon", "landing": Vector3(0, 59.6, -122)})
	# West from the monument's lower shelf, over the void.
	out.append({"points": [Vector3(-49.5, 14.5, 150), Vector3(-66, 16.5, 160), Vector3(-90, 19, 152)], "coins": 25, "reward": "thunder"})
	# Up from the hollow, over the void.
	out.append({"points": [Vector3(-73, 8.5, 77), Vector3(-58, 11, 56), Vector3(-66, 14, 40)], "coins": 25, "weapon": "longbow"})
	# Short cuts that need no gate: the arena's south rim to the monument, and its north rim to the rotunda's shelf.
	out.append({"points": [Vector3(12, 18.5, 67), Vector3(38, 19.8, 72), Vector3(44, 21.6, 92), Vector3(26, 24.5, 108)]})
	out.append({"points": [Vector3(-19.5, 18.5, -63), Vector3(-6, 20, -74), Vector3(14, 22, -70), Vector3(16, 24.5, -86), Vector3(-6, 26.5, -88), Vector3(-30, 28.5, -98)]})
	return out


## Which way the end of a line points, away from the middle it goes around.
static func _outward(pts: Array, c: Vector2) -> Vector3:
	var end: Vector3 = pts[pts.size() - 1]
	return Vector3(end.x - c.x, 0, end.z - c.y).normalized()


static func _spiral(c: Vector2, radius: float, y0: float, y1: float, start: float, turns: float) -> Array:
	var pts := []
	var n := int(turns * 24.0)
	for i in n + 1:
		var f := float(i) / n
		var a := start + f * turns * TAU
		pts.append(Vector3(c.x + cos(a) * radius, lerpf(y0, y1, f), c.y + sin(a) * radius))
	return pts


## Each stone: x, y, z of its top, and its radius. They lie at even steps from one end of the line to the
## other, and the climb is even all the way, whatever the line's corners do.
static func stones_of(line: Dictionary) -> Array[Vector4]:
	var pts: Array = line["points"]
	var total := 0.0
	for i in range(1, pts.size()):
		total += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
	var hops := maxi(1, ceili(total / STONE_STEP))
	var out: Array[Vector4] = []
	var first: Vector3 = pts[0]
	var last: Vector3 = pts[pts.size() - 1]
	var seg := 1
	var seg_start := 0.0
	for n in hops + 1:
		var want := total * n / hops
		var seg_len := Vector2(pts[seg].x - pts[seg - 1].x, pts[seg].z - pts[seg - 1].z).length()
		while seg < pts.size() - 1 and want > seg_start + seg_len:
			seg_start += seg_len
			seg += 1
			seg_len = Vector2(pts[seg].x - pts[seg - 1].x, pts[seg].z - pts[seg - 1].z).length()
		var p: Vector3 = (pts[seg - 1] as Vector3).lerp(pts[seg], clampf((want - seg_start) / maxf(seg_len, 0.01), 0.0, 1.0))
		out.append(Vector4(p.x, lerpf(first.y, last.y, float(n) / hops), p.z, STONE_RADIUS))
	if line.has("coins") and not line.has("landing"):
		var tip: Vector4 = out[out.size() - 1]
		out[out.size() - 1] = Vector4(tip.x, tip.y, tip.z, CACHE_RADIUS)
	return out


func build(b: MapBuilder) -> void:
	if b.is_preview:
		return
	var w: World = b.w
	_rng.seed = 90210
	var gates := MistPortals.new(w, ISLANDS, regions())
	w.add_child(gates)
	w.portals = gates
	var used := {}
	for pair: Array in LINKS:
		var ia: int = pair[0]
		var ib: int = pair[1]
		gates.add_link(ia, ib, _end_towards(b, ia, ib, used), _end_towards(b, ib, ia, used))
	gates.open_starting_links()
	for n in 4:
		var a := TAU * n / 4.0 + 0.4
		w.start_spots.append(Vector3(cos(a) * 18.0, 0, sin(a) * 18.0))
	var caches := MistCaches.new(w)
	w.add_child(caches)
	w.caches = caches
	_sea(w)
	for n in ISLANDS.size():
		_cliffs(b, ISLANDS[n])
	_floaters(b)
	_arena(b)
	_rotunda_island(b)
	_battlements(b)
	_forest(b)
	_monument(b)
	_falls(b)
	_hollow(b)
	_terrace_island(b)
	_harbour(b)
	for br: Array in BRIDGES:
		_bridge(b, br)
	for line: Dictionary in stone_lines():
		_stone_line(b, line, caches)
	_reseat_gates(b)
	_waystations(b)
	_scatter_loot(b)


## Plenty of places for things to turn up, spread over every island and well apart.
func _scatter_loot(b: MapBuilder) -> void:
	var w: World = b.w
	for i: Vector4 in ISLANDS:
		var wanted := int(i.z / 3.0)
		for tries in wanted * 8:
			if wanted <= 0:
				break
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * i.z * 0.82
			var at := Vector3(i.x + cos(a) * d, 0, i.y + sin(a) * d)
			if not w.grid.is_free(w.grid.to_cell(at)) or b.terrain.ground_height(at.x, at.z) <= 0.0:
				continue
			var clash := false
			for other: Vector3 in w.loot_spots:
				if Vector2(other.x - at.x, other.z - at.z).length() < 9.0:
					clash = true
					break
			if clash:
				continue
			w.loot_spots.append(at)
			wanted -= 1


func _at(b: MapBuilder, x: float, z: float) -> Vector3:
	return Vector3(x, b.terrain.ground_height(x, z), z)


# --- The sea of mist, and the rock that stands in it ---------------------------------------------------

func _sea(w: World) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600, 1600)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position.y = SEA_Y
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/mist_sea.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 200.0
	w.add_child(mi)


## Great spurs of rock against the cliffs, reaching down into the mist.
func _cliffs(b: MapBuilder, i: Vector4) -> void:
	var l := LowPoly.new()
	for n in int(i.z / 3.0):
		var a := _rng.randf() * TAU
		var reach := i.z * _rng.randf_range(0.98, 1.1)
		var r := _rng.randf_range(3.5, 8.0)
		var top := i.w - _rng.randf_range(3.0, 16.0)
		var tone := ROCK.lerp(DARK_STONE, _rng.randf()).darkened(_rng.randf() * 0.2)
		var at := Vector3(i.x + cos(a) * reach, top, i.y + sin(a) * reach)
		l.prism(at, at + Vector3(_rng.randf_range(-2, 2), -(top - SEA_Y) * 0.5 - 4.0, _rng.randf_range(-2, 2)), r * 0.45, r, 6, tone)
		l.prism(at + Vector3(0, -(top - SEA_Y) * 0.5 - 4.0, 0), Vector3(at.x, SEA_Y - 6.0, at.z), r, r * 1.3, 6, tone.darkened(0.15))
	b.add(l)


## Lumps of rock hanging in the air between the islands, for nobody to stand on.
func _floaters(b: MapBuilder) -> void:
	var l := LowPoly.new()
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 400:
		tries += 1
		var at := Vector3(_rng.randf_range(-200, 200), _rng.randf_range(2, 62), _rng.randf_range(-200, 200))
		var clear := true
		for i: Vector4 in ISLANDS:
			if Vector2(at.x - i.x, at.z - i.y).length() < i.z + 8.0:
				clear = false
				break
		if not clear:
			continue
		placed += 1
		var r := _rng.randf_range(1.5, 6.5)
		l.prism(at, at + Vector3(0, r * 0.35, 0), r, r * 0.7, 6, MOSS.darkened(0.2))
		l.prism(at, at + Vector3(_rng.randf_range(-1, 1), -r * _rng.randf_range(1.2, 2.2), _rng.randf_range(-1, 1)), r, 0.15, 6, ROCK)
	b.add(l)


# --- Bits of building ---------------------------------------------------------------------------------

## A flat ring, or a sloped one, of quads looking up.
static func _annulus(l: LowPoly, c: Vector3, r0: float, r1: float, y0: float, y1: float, col: Color, segments := 40) -> void:
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var p0 := Vector3(c.x + cos(a0) * r0, y0, c.z + sin(a0) * r0)
		var p1 := Vector3(c.x + cos(a1) * r0, y0, c.z + sin(a1) * r0)
		var p2 := Vector3(c.x + cos(a1) * r1, y1, c.z + sin(a1) * r1)
		var p3 := Vector3(c.x + cos(a0) * r1, y1, c.z + sin(a0) * r1)
		var under := (p0 + p2) * 0.5 + Vector3.DOWN * 10.0
		l._tri(p0, p1, p2, under, col)
		l._tri(p0, p2, p3, under, col)


## A round wall seen from inside, like the risers of the seats.
static func _riser(l: LowPoly, c: Vector3, r: float, y0: float, y1: float, col: Color, segments := 40) -> void:
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var p0 := Vector3(c.x + cos(a0) * r, y0, c.z + sin(a0) * r)
		var p1 := Vector3(c.x + cos(a1) * r, y0, c.z + sin(a1) * r)
		var p2 := Vector3(c.x + cos(a1) * r, y1, c.z + sin(a1) * r)
		var p3 := Vector3(c.x + cos(a0) * r, y1, c.z + sin(a0) * r)
		var outside := (p0 + p2) * 0.5 + Vector3(cos(a0), 0, sin(a0)) * 10.0
		l._tri(p0, p1, p2, outside, col)
		l._tri(p0, p2, p3, outside, col)


static func _column(l: LowPoly, at: Vector3, h: float, r: float, col: Color) -> void:
	l.box(at + Vector3(0, 0.2, 0), Vector3(r * 3.0, 0.4, r * 3.0), col.darkened(0.12))
	l.prism(at + Vector3(0, 0.4, 0), at + Vector3(0, h - 0.4, 0), r, r * 0.86, 8, col)
	l.box(at + Vector3(0, h - 0.2, 0), Vector3(r * 2.8, 0.4, r * 2.8), col.darkened(0.06))


## A white hall of columns under a ribbed dome of pale glass, like those of the Mists.
func _rotunda(b: MapBuilder, c: Vector3, r: float, h: float, ribs := 12) -> void:
	var w: World = b.w
	var l := LowPoly.new()
	_ground_ring(b, l, c, 0.0, r + 1.6, MARBLE)
	_ground_ring(b, l, c, r + 1.6, r + 6.5, STONE)
	var floor_y := c.y + 0.1
	for n in ribs:
		var a := TAU * n / ribs
		var foot := _at(b, c.x + cos(a) * r, c.z + sin(a) * r) + Vector3.UP * 0.08
		_column(l, foot, h, r * 0.075 + 0.1, MARBLE)
		w.add_solid(foot + Vector3.UP * h * 0.5, Vector3(1.1, h, 1.1))
	var top := floor_y + h
	l.prism(Vector3(c.x, top, c.z), Vector3(c.x, top + 0.5, c.z), r + 1.0, r + 1.2, 24, MARBLE)
	l.prism(Vector3(c.x, top + 0.5, c.z), Vector3(c.x, top + 1.0, c.z), r + 1.2, r + 0.5, 24, STONE)
	var dome_base := top + 1.0
	var dome_h := r * 0.85
	for n in ribs:
		var a := TAU * n / ribs
		var last := Vector3(c.x + cos(a) * r, dome_base, c.z + sin(a) * r)
		for s in range(1, 7):
			var phi := s / 6.0 * PI * 0.5
			var p := Vector3(c.x + cos(a) * r * cos(phi), dome_base + dome_h * sin(phi), c.z + sin(a) * r * cos(phi))
			l.prism(last, p, r * 0.035 + 0.04, r * 0.03 + 0.04, 5, MARBLE)
			last = p
	var tip := dome_base + dome_h
	l.prism(Vector3(c.x, tip - 0.2, c.z), Vector3(c.x, tip + 0.4, c.z), r * 0.2, r * 0.16, 10, MARBLE)
	l.prism(Vector3(c.x, tip + 0.4, c.z), Vector3(c.x, tip + 1.8, c.z), r * 0.05, 0.0, 6, GOLD)
	b.add(l)
	var glass := SphereMesh.new()
	glass.radius = 1.0
	glass.height = 1.0
	glass.is_hemisphere = true
	glass.radial_segments = 18
	glass.rings = 6
	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.72, 0.95, 0.98, 0.42)
	look.roughness = 0.2
	look.metallic = 0.3
	glass.material = look
	var mi := MeshInstance3D.new()
	mi.mesh = glass
	mi.scale = Vector3(r, dome_h, r)
	mi.position = Vector3(c.x, dome_base, c.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	_rune(b, Vector3(c.x, floor_y + 0.02, c.z), r * 0.5)
	w.loot_spots.append(c)
	w.pois.append(c)
	w.perches.append(Vector3(c.x, tip + 2.0, c.z))


## A glowing ring on the ground, with marks around it.
func _rune(b: MapBuilder, c: Vector3, r: float) -> void:
	var l := LowPoly.new()
	for band: Vector2 in [Vector2(r - 0.28, r), Vector2(r * 0.5 - 0.12, r * 0.5)]:
		for n in 64:
			var points: Array[Vector3] = []
			for corner: Vector2 in [Vector2(band.x, n), Vector2(band.x, n + 1), Vector2(band.y, n + 1), Vector2(band.y, n)]:
				var angle := corner.y / 64.0 * TAU
				var p := Vector3(c.x + cos(angle) * corner.x, 0, c.z + sin(angle) * corner.x)
				p.y = b.w.ground_at(p) + 0.025
				points.append(p)
			var under := (points[0] + points[2]) * 0.5 - Vector3.UP
			l._tri(points[0], points[1], points[2], under, GLOW)
			l._tri(points[0], points[2], points[3], under, GLOW)
	var mi := b.add(l)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.vertex_color_use_as_albedo = true
	mi.material_override = look


## A length of ruined wall: piers and arched windows you can walk through, broken at the top.
func _wall(b: MapBuilder, l: LowPoly, from: Vector2, to: Vector2, h: float) -> void:
	const BAY := 5.5
	var w: World = b.w
	var along := (to - from).normalized()
	var turn := -rad_to_deg(atan2(along.y, along.x))
	var bays := int(from.distance_to(to) / BAY)
	for n in bays + 1:
		var p := from + along * n * BAY
		var y := b.terrain.ground_height(p.x, p.y)
		var tall := h * _rng.randf_range(0.55, 1.0)
		var at := Vector3(p.x, y + tall * 0.5 - 1.0, p.y)
		l.box(at, Vector3(1.5, tall + 2.0, 1.5), STONE.darkened(_rng.randf() * 0.18), Vector3(0, turn, 0))
		w.add_solid(Vector3(p.x, y + tall * 0.5, p.y), Vector3(1.3, tall, 1.3))
		if n == bays or _rng.randf() < 0.25:
			continue
		var q := p + along * BAY
		var y2 := b.terrain.ground_height(q.x, q.y)
		var mid := p + along * BAY * 0.5
		var spring := minf(y, y2) + 4.0
		# The arch over the window, in five stones.
		for s in 5:
			var t0 := PI * s / 5.0
			var t1 := PI * (s + 1) / 5.0
			var a0 := mid + along * cos(t0) * BAY * 0.42
			var a1 := mid + along * cos(t1) * BAY * 0.42
			l.prism(Vector3(a0.x, spring + sin(t0) * 1.9, a0.y), Vector3(a1.x, spring + sin(t1) * 1.9, a1.y), 0.42, 0.42, 4, STONE.darkened(0.08))
		# And above it, the wall as far as it still stands.
		var over := spring + 2.5 + _rng.randf_range(0.0, 2.6)
		l.box(Vector3(mid.x, (spring + 2.0 + over) * 0.5, mid.y), Vector3(BAY - 0.8, over - spring - 2.0 + 0.8, 1.1), STONE.darkened(_rng.randf() * 0.15), Vector3(0, turn, 0))
		for m in 3:
			var c := mid + along * (m - 1) * 1.6
			if _rng.randf() < 0.7:
				l.box(Vector3(c.x, over + 0.55, c.y), Vector3(0.9, 1.1, 1.1), STONE.darkened(0.1), Vector3(0, turn, 0))


func _tower(b: MapBuilder, l: LowPoly, c: Vector3, r: float, h: float, walkable_top := false) -> void:
	l.prism(c + Vector3(0, -2, 0), c + Vector3(0, h, 0), r * 1.08, r, 12, STONE.darkened(0.06))
	l.prism(c + Vector3(0, h, 0), c + Vector3(0, h + 0.7, 0), r, r + 0.6, 12, STONE)
	for n in 12:
		if n % 2 == 0 or (not walkable_top and _rng.randf() < 0.3):
			continue
		var a := TAU * n / 12.0
		l.box(c + Vector3(cos(a) * (r + 0.3), h + 1.3, sin(a) * (r + 0.3)), Vector3(1.0, 1.2, 0.8), STONE.darkened(0.1), Vector3(0, -rad_to_deg(a) + 90.0, 0))
	for n in 4:
		var a := TAU * (n + 0.5) / 4.0
		var y := h * (0.45 + 0.13 * n)
		var f := c + Vector3(cos(a) * r, y, sin(a) * r)
		l.box(f, Vector3(0.9, 2.2, 0.9), Color(0.06, 0.08, 0.1), Vector3(0, -rad_to_deg(a) + 90.0, 0))
	b.w.add_solid(c + Vector3(0, h * 0.5 + 0.35, 0), Vector3(r * 1.5, h + 0.7, r * 1.5))
	b.w.perches.append(c + Vector3(0, h + 1.0, 0))


## A big old tree with a twisted trunk and heavy crowns.
func _great_tree(b: MapBuilder, l: LowPoly, at: Vector3, size: float, leaf: Color) -> void:
	if _near_gate(b.w, at, 7.0 * size): return
	_foliage.append(Vector4(at.x, at.z, 5.0 * size, at.y))
	var p := at
	var r := 0.9 * size
	var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	for s in 4:
		var q := p + Vector3.UP * 2.6 * size + lean * _rng.randf_range(0.3, 1.0) * size
		l.prism(p, q, r, r * 0.74, 7, WOOD.darkened(0.1 * s))
		p = q
		r *= 0.74
		lean = lean.rotated(Vector3.UP, _rng.randf_range(0.8, 2.0))
	var crowns := [p, p + Vector3(3.2, -1.4, 0.8) * size, p + Vector3(-3.0, -1.0, 1.4) * size, p + Vector3(0.6, -1.4, -3.2) * size, p + Vector3(-0.6, 1.8, 0.2) * size]
	for c: Vector3 in crowns:
		if c != p:
			l.prism(p - Vector3.UP * size, c, 0.34 * size, 0.14 * size, 5, WOOD)
		var cr := _rng.randf_range(3.0, 4.2) * size
		var tone := leaf.lerp(leaf.lightened(0.2), _rng.randf())
		l.prism(c + Vector3(0, -cr * 0.55, 0), c, cr * 0.6, cr, 8, tone.darkened(0.14))
		l.prism(c, c + Vector3(0, cr * 0.75, 0), cr, cr * 0.3, 8, tone)
	b.w.add_solid(at + Vector3.UP * 2.0, Vector3(2.0 * size, 4.0, 2.0 * size))
	b.w.perches.append(p + Vector3.UP * 2.0)


func _pine(b: MapBuilder, x: float, z: float, size: float) -> void:
	if _near_gate(b.w, Vector3(x, 0, z), 6.0 * size): return
	if on_masonry(Vector2(x, z)): return
	_foliage.append(Vector4(x, z, 2.8 * size, 0))
	b.stand_at(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), _at(b, x, z)))
	b.tree(MapTree.FILES["fir"], size * 6.5, 1.15, true)


func _brazier(b: MapBuilder, x: float, z: float) -> void:
	var at := _at(b, x, z)
	for ramp: Array in RAMPS:
		var a := Vector2(ramp[0].x, ramp[0].z)
		var end := Vector2(ramp[1].x, ramp[1].z)
		if Vector2(x, z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, end)) < 4.5: return
	at.y = b.w.ground_at(at)
	if b.w.grid.is_free(b.w.grid.to_cell(at)):
		b.stand_at(Transform3D(Basis.IDENTITY, at))
		b.torch()


# --- The places ---------------------------------------------------------------------------------------

func _arena(b: MapBuilder) -> void:
	var l := LowPoly.new()
	var c := Vector3.ZERO
	# A green in the middle, a ring of paving, then the seats going up to the rim.
	_annulus(l, c, 12.95, 30.1, 10.06, 10.06, STONE.lerp(MARBLE, 0.35), 40)
	_annulus(l, c, 12.2, 13.0, 10.1, 10.1, GOLD.darkened(0.2), 40)
	# Sloped masonry follows a single smooth ramp; alternating bands retain the amphitheatre tiers.
	const SEATS := 13
	for n in SEATS:
		var f0 := float(n) / SEATS
		var f1 := float(n + 1) / SEATS
		_annulus(l, c, lerpf(30.0, 54.0, f0), lerpf(30.0, 54.0, f1), lerpf(10.06, 18.1, f0), lerpf(10.06, 18.1, f1), STONE.darkened(0.04 + (n % 2) * 0.07), 96)
	_annulus(l, c, 54.0, 57.0, 18.1, 18.1, STONE.darkened(0.2), 96)
	# Arches around the rim, with gaps where the bridges and gates are.
	var gaps: Array[float] = [atan2(-2.0, 58.0), atan2(4.0, -58.0), atan2(67.0, 12.0), atan2(-65.0, -20.0), atan2(-48.0, -48.0)]
	const BAYS := 28
	for n in BAYS:
		var a := TAU * n / BAYS
		var near_gap := false
		for g: float in gaps:
			if absf(angle_difference(a, g)) < 0.26:
				near_gap = true
		for link_end: Vector3 in b.w.portals.ends_on(0):
			if absf(angle_difference(a, atan2(link_end.z, link_end.x))) < 0.2:
				near_gap = true
		if near_gap:
			continue
		var r := 60.0
		var tall := _rng.randf_range(5.0, 8.0) if n % 3 else _rng.randf_range(2.5, 5.0)
		var at := Vector3(cos(a) * r, 18.0, sin(a) * r)
		_column(l, at, tall, 0.62, STONE)
		b.w.add_solid(at + Vector3.UP * tall * 0.5, Vector3(1.2, tall, 1.2))
		if tall > 6.4 and (n + 1) % 3 and (n + 1) % BAYS != 0:
			var a2 := TAU * (n + 1) / BAYS
			var at2 := Vector3(cos(a2) * r, 18.0 + tall, sin(a2) * r)
			l.prism(at + Vector3.UP * tall, at2, 0.45, 0.45, 4, STONE.darkened(0.1))
	# In the middle, a sword as tall as a house, driven into a stepped stone.
	var o := Vector3(0, 10.0, 0)
	_plinth(b, l, o, 6.0, 1.8, 2.7, 3)
	b.w.add_solid(o + Vector3(0, 8.4, 0), Vector3(1.2, 11.5, 0.5))
	l.box(o + Vector3(0, 8.4, 0), Vector3(1.2, 11.5, 0.3), Color(0.72, 0.78, 0.86))
	l.prism(o + Vector3(0, 2.7, 0), o + Vector3(0, 0.6, 0), 0.6, 0.0, 4, Color(0.72, 0.78, 0.86))
	l.box(o + Vector3(0, 14.3, 0), Vector3(5.2, 0.6, 0.7), GOLD)
	l.box(o + Vector3(0, 16.0, 0), Vector3(0.5, 3.0, 0.5), WOOD)
	l.prism(o + Vector3(0, 17.4, 0), o + Vector3(0, 18.2, 0), 0.5, 0.2, 6, GOLD)
	b.add(l)
	# Only the continuous slope has collision, never the visible tier seams or overhead arches.
	var walking := LowPoly.new()
	_annulus(walking, c, 0.0, 30.0, 10.06, 10.06, STONE, 96)
	_annulus(walking, c, 30.0, 54.0, 10.06, 18.1, STONE, 96)
	_annulus(walking, c, 54.0, 57.0, 18.1, 18.1, STONE, 96)
	_surface_collision(b.w, walking.commit(), "ArenaRampCollision")
	_rune(b, Vector3(0, 10.14, 0), 11.5)
	for n in 8:
		var a := TAU * (n + 0.5) / 8.0
		_brazier(b, cos(a) * 21.0, sin(a) * 21.0)
	for n in 6:
		var a := TAU * n / 6.0 + 0.3
		var at := Vector3(cos(a) * 24.0, 0, sin(a) * 24.0)
		b.w.loot_spots.append(at)
		b.w.pois.append(at)
	b.w.perches.append(o + Vector3(0, 18.4, 0))


func _rotunda_island(b: MapBuilder) -> void:
	var c := _at(b, 0, -122)
	_rotunda(b, c, 10.0, 9.0)
	for n in 4:
		var a := TAU * n / 4.0 + 0.7
		_brazier(b, cos(a) * 19.0, -122.0 + sin(a) * 19.0)
	var l := LowPoly.new()
	# Broken columns along the shelf, and a stair down the ramp.
	for n in 5:
		var p := Vector2(-56, -104).lerp(Vector2(-12, -120), n / 4.0) + Vector2(0, 5.5)
		_column(l, _at(b, p.x, p.y), _rng.randf_range(2.0, 5.0), 0.5, STONE)
		b.w.add_solid(_at(b, p.x, p.y) + Vector3.UP * 2.5, Vector3(1.0, 5.0, 1.0))
	_stairs(b, l, RAMPS[0][0], RAMPS[0][1], 6.0)
	b.add(l)
	for n in 6:
		var at := Vector3(-46 + _rng.randf_range(-12, 12), 0, -104 + _rng.randf_range(-12, 12))
		_great_tree_small(b, at.x, at.z)
	for at: Vector3 in [Vector3(20, 0, -135), Vector3(-20, 0, -140), Vector3(22, 0, -105), Vector3(-46, 0, -104)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)


func _stairs(b: MapBuilder, l: LowPoly, from: Vector3, to: Vector3, width: float) -> void:
	var along := Vector2(to.x - from.x, to.z - from.z).normalized()
	var side := along.orthogonal() * width * 0.5
	var steps := ceili(from.distance_to(to) / 1.2)
	for n in steps:
		var a := Vector2(from.x, from.z).lerp(Vector2(to.x, to.z), float(n) / steps)
		var z := Vector2(from.x, from.z).lerp(Vector2(to.x, to.z), float(n + 1) / steps)
		var points: Array[Vector3] = []
		for p: Vector2 in [a - side, a + side, z + side, z - side]:
			points.append(_at(b, p.x, p.y) + Vector3.UP * 0.08)
		var under := (points[0] + points[2]) * 0.5 - Vector3.UP
		var col := STONE.darkened(0.05 + (n % 2) * 0.08)
		l._tri(points[0], points[1], points[2], under, col)
		l._tri(points[0], points[2], points[3], under, col)


func _great_tree_small(b: MapBuilder, x: float, z: float) -> void:
	if b.w.grid.is_free(b.w.grid.to_cell(Vector3(x, 0, z))):
		_pine(b, x, z, _rng.randf_range(1.0, 1.5))


func _battlements(b: MapBuilder) -> void:
	var l := LowPoly.new()
	_wall(b, l, Vector2(92, -34), Vector2(150, -34), 13.0)
	_wall(b, l, Vector2(150, -34), Vector2(154, 8), 13.0)
	_wall(b, l, Vector2(96, 16), Vector2(114, 22), 10.0)
	_tower(b, l, _at(b, 128, -20), 5.0, 13.5, true)
	_tower(b, l, _at(b, 93, -34), 3.4, 15.0)
	_tower(b, l, _at(b, 152, -32), 4.0, 18.0)
	_tower(b, l, _at(b, 156, 8), 3.0, 9.0)
	_stairs(b, l, RAMPS[1][0], RAMPS[1][1], 6.0)
	_wall(b, l, Vector2(140, 50), Vector2(160, 48), 8.0)
	b.add(l)
	for n in 5:
		var a := TAU * n / 5.0 + 0.5
		_brazier(b, 122.0 + cos(a) * 18.0, -4.0 + sin(a) * 18.0)
	for at: Vector3 in [Vector3(112, 0, -14), Vector3(134, 0, 6), Vector3(150, 0, 38), Vector3(106, 0, 8), Vector3(120, 0, -26)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)


func _forest(b: MapBuilder) -> void:
	var l := LowPoly.new()
	var leaf := Color(0.26, 0.56, 0.44)
	_great_tree(b, l, _at(b, -124, 8), 1.35, leaf)
	var placed := 0
	var tries := 0
	while placed < 8 and tries < 60:
		tries += 1
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(22.0, 38.0)
		var p := Vector2(-124 + cos(a) * d, 8 + sin(a) * d)
		if b.w.grid.is_free(b.w.grid.to_cell(Vector3(p.x, 0, p.y))):
			_great_tree(b, l, _at(b, p.x, p.y), _rng.randf_range(0.8, 1.2), leaf.lerp(Color(0.34, 0.5, 0.26), _rng.randf()))
			placed += 1
	_stairs(b, l, RAMPS[3][0], RAMPS[3][1], 6.0)
	b.add(l)
	placed = 0
	tries = 0
	while placed < 36 and tries < 200:
		tries += 1
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(8.0, 42.0)
		var p := Vector2(-124 + cos(a) * d, 8 + sin(a) * d)
		if Vector2(p.x + 124, p.y - 8).length() < 20.0 and _rng.randf() < 0.5:
			continue
		if b.w.grid.is_free(b.w.grid.to_cell(Vector3(p.x, 0, p.y))):
			_pine(b, p.x, p.y, _rng.randf_range(1.0, 1.7))
			placed += 1
	for n in 4:
		var p := Vector2(-146 + _rng.randf_range(-10, 10), -24 + _rng.randf_range(-10, 10))
		if b.w.grid.is_free(b.w.grid.to_cell(Vector3(p.x, 0, p.y))):
			_pine(b, p.x, p.y, _rng.randf_range(1.2, 1.8))
	for at: Vector3 in [Vector3(-104, 0, 24), Vector3(-140, 0, 22), Vector3(-114, 0, -16), Vector3(-146, 0, -24), Vector3(-100, 0, -4)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)


func _monument(b: MapBuilder) -> void:
	var l := LowPoly.new()
	var c := _at(b, 8, 124)
	_plinth(b, l, c, 8.5, 3.0, 2.4, 4)
	b.w.add_solid(c + Vector3(0, 10.7, 0), Vector3(3.0, 16.6, 3.0))
	l.prism(c + Vector3(0, 2.4, 0), c + Vector3(0, 19.0, 0), 1.9, 0.9, 4, MARBLE)
	l.prism(c + Vector3(0, 19.0, 0), c + Vector3(0, 21.0, 0), 0.9, 0.0, 4, GOLD)
	for n in 4:
		var a := TAU * n / 4.0 + PI * 0.25
		var at := c + Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		_column(l, at, 7.0, 0.5, MARBLE.darkened(0.06))
		b.w.add_solid(at + Vector3.UP * 3.5, Vector3(1.0, 7.0, 1.0))
		l.prism(at + Vector3.UP * 7.0, at + Vector3.UP * 8.1, 0.65, 0.42, 6, GOLD.darkened(0.2))
	_stairs(b, l, RAMPS[2][0], RAMPS[2][1], 6.0)
	b.add(l)
	_rune(b, c + Vector3(0, 0.06, 0), 11.0)
	for n in 4:
		var a := TAU * n / 4.0
		_brazier(b, 8.0 + cos(a) * 15.0, 124.0 + sin(a) * 15.0)
	for at: Vector3 in [Vector3(-8, 0, 110), Vector3(26, 0, 132), Vector3(-30, 0, 146), Vector3(14, 0, 142)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)


## The highest rock, and the pools of the other islands. The water runs to the edge and goes over,
## all the way down to the mist.
func _falls(b: MapBuilder) -> void:
	_terrain_now = b.terrain
	var l := LowPoly.new()
	var c := _at(b, 76, -112)
	_great_tree(b, l, _at(b, 72, -130), 0.9, Color(0.3, 0.6, 0.46))
	_great_tree(b, l, _at(b, 78, -100), 0.8, Color(0.26, 0.52, 0.44))
	var well := Vector3(90, 46.0, -122)
	for n in 4:
		var a := TAU * n / 4.0 + 0.3
		var at := well + Vector3(cos(a) * 10.5, 0, sin(a) * 10.5)
		at.y = b.terrain.ground_height(at.x, at.z)
		var tall := _rng.randf_range(3.0, 7.0)
		_column(l, at, tall, 0.5, MARBLE.darkened(0.08))
		b.w.add_solid(at + Vector3.UP * tall * 0.5, Vector3(1.0, tall, 1.0))
	b.add(l)
	for at: Vector3 in [c, Vector3(90, 0, -102), Vector3(72, 0, -138)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)
	var water := ShaderMaterial.new()
	water.shader = load("res://assets/shaders/island_water.gdshader")
	for w: Array in WATERS:
		_pool(b, w, water)


## A pool with a stone rim, and streams from it that run to the land's edge and fall.
func _pool(b: MapBuilder, w: Array, water: ShaderMaterial) -> void:
	var at: Vector2 = w[0]
	var r: float = w[1]
	var y: float = float(w[2]) - 0.25
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 18
	var centre := Vector3(at.x, y, at.y)
	b.terrain.add_pool(at, r)
	for n in SEGMENTS:
		var a0 := TAU * n / SEGMENTS
		var a1 := TAU * (n + 1) / SEGMENTS
		for p: Vector3 in [centre, centre + Vector3(cos(a1), 0, sin(a1)) * (r + 0.4), centre + Vector3(cos(a0), 0, sin(a0)) * (r + 0.4)]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5 + (p.x - at.x) / 3.8, p.z))
			st.add_vertex(p)
	for dir: Vector2 in w[3]:
		var d := dir.normalized()
		var edge := _edge_of(ISLANDS[_island_at(at)], at, d)
		var side := d.orthogonal() * 1.9
		# From the pool's edge, not its middle, so that streams do not cross on the way out.
		var mouth := at + d * sqrt(maxf(0.0, (r + 0.4) * (r + 0.4) - 1.9 * 1.9))
		var run := mouth.distance_to(edge) + 2.4
		var end := mouth + d * run
		b.terrain.add_stream(mouth, end, 1.9)
		var corners := [[mouth + side, 0.0, 0.0], [mouth - side, 1.0, 0.0], [end + side, 0.0, run], [end - side, 1.0, run]]
		for q: int in [0, 2, 1, 1, 2, 3]:
			var v: Array = corners[q]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(Vector3(v[0].x, y, v[0].y))
		_waterfall(b.w, Vector3(end.x, y, end.y), d, 3.8)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var local_water := water.duplicate() as ShaderMaterial
	local_water.set_shader_parameter("pool_origin", at)
	local_water.set_shader_parameter("pool_radius", r + 0.4)
	mi.material_override = local_water
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.w.add_child(mi)


func _island_at(p: Vector2) -> int:
	for n in ISLANDS.size():
		if Vector2(p.x - ISLANDS[n].x, p.y - ISLANDS[n].y).length() < ISLANDS[n].z:
			return n
	return 0


func _edge_of(i: Vector4, from: Vector2, dir: Vector2) -> Vector2:
	var p := from
	while Vector2(p.x - i.x, p.y - i.y).length() < i.z * 1.3:
		p += dir
		if _height_low(p):
			return p - dir
	return p


var _terrain_now: Terrain


func _height_low(p: Vector2) -> bool:
	return _terrain_now != null and _terrain_now.ground_height(p.x, p.y) < 0.0


func _waterfall(w: World, top: Vector3, out: Vector2, width: float) -> void:
	var h := top.y - SEA_Y + 2.0
	var q := QuadMesh.new()
	q.size = Vector2(width, h)
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/waterfall.gdshader")
	m.set_shader_parameter("tall", h)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = top + Vector3.DOWN * h * 0.5
	mi.rotation.y = atan2(out.x, out.y)
	w.add_child(mi)


func _hollow(b: MapBuilder) -> void:
	var l := LowPoly.new()
	var c := _at(b, -96, 100)
	for n in 10:
		var a := TAU * n / 10.0
		var at := c + Vector3(cos(a) * 14.0, 0, sin(a) * 14.0)
		at.y = b.terrain.ground_height(at.x, at.z)
		var tall := _rng.randf_range(1.5, 7.0)
		_column(l, at, tall, 0.65, STONE.darkened(0.12))
		b.w.add_solid(at + Vector3.UP * tall * 0.5, Vector3(1.2, tall, 1.2))
	_wall(b, l, Vector2(-116, 78), Vector2(-84, 76), 8.0)
	_tower(b, l, _at(b, -118, 112), 3.2, 8.0)
	_great_tree(b, l, _at(b, -80, 112), 1.0, Color(0.32, 0.5, 0.36))
	b.add(l)
	for at: Vector3 in [Vector3(-96, 0, 84), Vector3(-108, 0, 88), Vector3(-82, 0, 96), Vector3(-104, 0, 114)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)


func _terrace_island(b: MapBuilder) -> void:
	var c := _at(b, -92, -100)
	_rotunda(b, c, 6.5, 6.5, 10)
	var l := LowPoly.new()
	for n in 6:
		var a := TAU * n / 6.0 + 0.2
		var at := c + Vector3(cos(a) * 18.0, 0, sin(a) * 18.0)
		at.y = b.terrain.ground_height(at.x, at.z)
		var tall := _rng.randf_range(5.0, 12.0)
		l.prism(at + Vector3.DOWN, at + Vector3.UP * tall, 2.2, 0.3, 6, ROCK)
		b.w.add_solid(at + Vector3.UP * tall * 0.25, Vector3(2.2, tall * 0.5, 2.2))
	b.add(l)
	for at: Vector3 in [Vector3(-104, 0, -110), Vector3(-80, 0, -88), Vector3(-92, 0, -84)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)


func _harbour(b: MapBuilder) -> void:
	var c := _at(b, 112, 108)
	_rotunda(b, c, 5.5, 5.5, 8)
	var l := LowPoly.new()
	_wall(b, l, Vector2(88, 122), Vector2(118, 130), 7.0)
	_great_tree(b, l, _at(b, 94, 92), 0.9, Color(0.28, 0.54, 0.42))
	b.add(l)
	for at: Vector3 in [Vector3(96, 0, 106), Vector3(116, 0, 90), Vector3(100, 0, 122)]:
		b.w.loot_spots.append(at)
		b.w.pois.append(at)


# --- Crossings -----------------------------------------------------------------------------------------

## Nothing at the sides. A blow at the wrong moment and you go over.
func _bridge(b: MapBuilder, br: Array) -> void:
	var t := b.terrain
	var half: float = br[3]
	var stone: bool = br[4]
	var data: Dictionary = t.bridges()[BRIDGES.find(br)]
	var from: Vector2 = data["a"]
	var to: Vector2 = data["b"]
	var along := (to - from).normalized()
	var yaw := atan2(along.x, along.y)
	var length := from.distance_to(to)
	var l := LowPoly.new()
	var side := Vector3(along.y, 0, -along.x)
	const STEP := 1.6
	var parts := int(length / STEP)
	var last := Vector3.ZERO
	var inlays := LowPoly.new()
	for n in parts + 1:
		var s := float(n) / parts
		var p := from.lerp(to, s)
		var at := Vector3(p.x, t.deck_y(data, s), p.y)
		if n > 0:
			var mid := (last + at) * 0.5
			var run := at - last
			var basis := Basis.looking_at(run.normalized(), Vector3.UP)
			b.w.add_ledge(Transform3D(basis, mid + Vector3.DOWN * 0.2), Vector3(half * 2.0, 0.4, run.length() + 0.2))
			if stone:
				l.turned_box(mid + Vector3.DOWN * 0.3, Vector3(half * 2.0, 0.6, run.length() + 0.1), STONE.darkened((n % 2) * 0.1), basis)
			else:
				var planks := 4
				for q in planks:
					var pp := last.lerp(at, (q + 0.5) / planks)
					l.turned_box(pp + Vector3.DOWN * 0.08, Vector3(half * 2.0, 0.12, run.length() / planks + 0.035), WOOD.lightened((n + q) % 3 * 0.06), basis)
				l.prism(last + side * half + Vector3.DOWN * 0.1, at + side * half + Vector3.DOWN * 0.1, 0.07, 0.07, 4, ROPE)
				l.prism(last - side * half + Vector3.DOWN * 0.1, at - side * half + Vector3.DOWN * 0.1, 0.07, 0.07, 4, ROPE)
		# Inset markers follow the existing deck, so the night route has readable edges.
		for edge: float in [-1.0, 1.0]:
			inlays.box(at + side * edge * (half - 0.2) + Vector3.UP * 0.045, Vector3(0.13, 0.035, 0.38), Color(0.14, 0.46, 0.5), Vector3(0, rad_to_deg(yaw), 0))
		last = at
	var edge_mesh := b.add(inlays)
	edge_mesh.name = "MistBridgeInlays"
	var shine := StandardMaterial3D.new()
	shine.vertex_color_use_as_albedo = true
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mesh.material_override = shine
	# A flat step at each end, reaching a little onto the land, so that there is no lip to trip over.
	for s: float in [0.0, 1.0]:
		var p := from.lerp(to, s)
		var out := along * (-1.0 if s == 0.0 else 1.0)
		var flat := Vector3(p.x + out.x * 1.0, t.deck_y(data, s) - 0.2, p.y + out.y * 1.0)
		b.w.add_ledge(Transform3D(Basis(Vector3.UP, yaw), flat), Vector3(half * 2.0, 0.4, 2.4))
	# The ends: posts for a rope bridge, and a great arch under a stone one.
	for s: float in [0.0, 1.0]:
		var p := from.lerp(to, s)
		var at := Vector3(p.x, t.deck_y(data, s), p.y)
		for g: float in [-1.0, 1.0]:
			b.w.add_glow(at + side * g * (half + 0.2) + Vector3.UP * 1.45, Color(0.2, 0.65, 0.7), 0.45)
			if stone:
				l.box(at + side * g * (half + 0.2) + Vector3.UP * 0.6, Vector3(0.7, 1.6, 0.7), STONE, Vector3(0, rad_to_deg(yaw), 0))
			else:
				l.prism(at + side * g * (half + 0.15) + Vector3.DOWN * 0.6, at + side * g * (half + 0.15) + Vector3.UP * 1.4, 0.14, 0.11, 5, WOOD)
	if stone:
		for n in 1:
			var mid := from.lerp(to, 0.5)
			var y := t.deck_y(data, 0.5)
			l.prism(Vector3(mid.x, y - 1.0, mid.y), Vector3(mid.x, SEA_Y - 4.0, mid.y), 2.2, 3.4, 8, DARK_STONE)
	b.add(l)


func _stone_line(b: MapBuilder, line: Dictionary, caches: MistCaches) -> void:
	var l := LowPoly.new()
	var rings := LowPoly.new()
	var w: World = b.w
	var stones := stones_of(line)
	var chain: Array = []
	w.stone_chains.append(chain)
	for s: Vector4 in stones:
		var top := Vector3(s.x, s.y, s.z)
		chain.append(top)
		if chain.size() % 3 == 1 or chain.size() == stones.size():
			_annulus(rings, top, s.w * 0.72, s.w * 0.79, top.y + 0.025, top.y + 0.025, Color(0.12, 0.4, 0.43), 12)
		l.prism(top + Vector3.DOWN * 0.26, top, s.w * 1.05, s.w, 8, MOSS.lightened(0.12))
		l.prism(top + Vector3.DOWN * 0.26, top + Vector3(0.1, -s.w * 0.9 - 0.3, -0.1), s.w * 1.05, 0.25, 7, STONE.darkened(0.25))
		w.add_stone(top, s.w * 0.96, s.w * 0.9 + 0.3)
	b.add(l)
	var rune_mesh := b.add(rings)
	rune_mesh.name = "MistStoneWaymarks"
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rune_mesh.material_override = glow
	if line.has("coins"):
		var spot: Vector3 = line.get("landing", Vector3(stones[stones.size() - 1].x, stones[stones.size() - 1].y, stones[stones.size() - 1].z))
		if line.has("landing"):
			var landing := LowPoly.new()
			landing.prism(spot - Vector3.UP * 0.26, spot, LANDING_RADIUS * 1.05, LANDING_RADIUS, 8, STONE)
			landing.prism(spot - Vector3.UP * 0.26, spot - Vector3.UP * 1.5, LANDING_RADIUS * 1.05, 0.25, 8, DARK_STONE)
			b.add(landing)
			w.add_stone(spot, LANDING_RADIUS, 1.5)
			chain.append(spot)
		caches.add(spot, int(line["coins"]), str(line.get("reward", "")), str(line.get("weapon", "")))


func _end_towards(b: MapBuilder, from: int, to: int, used: Dictionary) -> Vector3:
	var f := ISLANDS[from]
	var t := ISLANDS[to]
	var dir := Vector2(t.x - f.x, t.y - f.y).normalized()
	var origin := Vector2(f.x, f.y)
	var at := origin + dir * f.z * 0.68
	var found := false
	for fraction: float in ([0.91, 0.88, 0.85] if from == 0 else [0.68, 0.78, 0.54, 0.42]):
		for step in 32:
			var angle := ceili(step / 2.0) * 0.16 * (1.0 if step % 2 == 0 else -1.0)
			var candidate := origin + dir.rotated(angle) * f.z * fraction
			var clash := false
			for other: Vector2 in used.get(from, []):
				if other.distance_to(candidate) < 9.0: clash = true
			if clash or not _gate_clear(b, candidate, from): continue
			at = candidate
			found = true
			break
		if found: break
	if not found:
		push_error("No clear portal landing on island %d" % from)
	if not used.has(from): used[from] = []
	used[from].append(at)
	return Vector3(at.x, b.terrain.ground_height(at.x, at.y) + 0.08, at.y)



## Paving, shrines and access ramps reserve their whole footprint, including foliage crowns.
static func on_masonry(p: Vector2) -> bool:
	if p.length() < 58.0: return true
	for r: Array in ROTUNDAS:
		if p.distance_to(r[0]) < float(r[1]) + 8.0: return true
	if p.distance_to(Vector2(8, 124)) < 13.0: return true
	for ramp: Array in RAMPS:
		var a := Vector2(ramp[0].x, ramp[0].z)
		var b := Vector2(ramp[1].x, ramp[1].z)
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < 5.0: return true
	return false


static func _near_gate(w: World, at: Vector3, radius: float) -> bool:
	for link: Dictionary in w.portals.links:
		for side: String in ["a", "b"]:
			var end: Vector3 = link[side]
			if Vector2(at.x - end.x, at.z - end.z).length() < radius: return true
	return false


static func _surface_collision(w: World, mesh: Mesh, label: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = Terrain.LAYER
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	w.add_child(body)


func _ground_ring(b: MapBuilder, l: LowPoly, c: Vector3, inner: float, outer: float, col: Color) -> void:
	# Subdivide radially as well, so the surface follows ramp joins instead of bridging over grass.
	var rings := maxi(1, ceili((outer - inner) / 1.0))
	var floor_mesh := LowPoly.new()
	for ring in rings:
		for n in 64:
			var points: Array[Vector3] = []
			for v: Vector2 in [Vector2(ring, n), Vector2(ring, n + 1), Vector2(ring + 1, n + 1), Vector2(ring + 1, n)]:
				var radius := lerpf(inner, outer, v.x / rings)
				var angle := v.y / 64.0 * TAU
				points.append(_at(b, c.x + cos(angle) * radius, c.z + sin(angle) * radius) + Vector3.UP * 0.1)
			var under := (points[0] + points[2]) * 0.5 - Vector3.UP
			for target: LowPoly in [l, floor_mesh]:
				target._tri(points[0], points[1], points[2], under, col)
				target._tri(points[0], points[2], points[3], under, col)
	_surface_collision(b.w, floor_mesh.commit(), "RotundaWalkingSurface")


func _gate_clear(b: MapBuilder, at: Vector2, island: int) -> bool:
	for r: Array in ROTUNDAS:
		if at.distance_to(r[0]) < float(r[1]) + 9.0: return false
	if at.distance_to(Vector2(8, 124)) < 19.0: return false
	for water: Array in WATERS:
		if at.distance_to(water[0]) < float(water[1]) + 5.0: return false
	for tree: Vector4 in _foliage:
		if at.distance_to(Vector2(tree.x, tree.y)) < tree.z + 3.0: return false
	var y := b.terrain.ground_height(at.x, at.y)
	for dx: float in [-3.0, 0.0, 3.0]:
		for dz: float in [-3.0, 0.0, 3.0]:
			var p := at + Vector2(dx, dz)
			if not b.w.grid.is_free(b.w.grid.to_cell(Vector3(p.x, 0, p.y))): return false
			if absf(b.terrain.ground_height(p.x, p.y) - y) > 0.7: return false
	var centre := ISLANDS[island]
	return y > 0.0 and at.distance_to(Vector2(centre.x, centre.y)) < centre.z - 4.0


func _reseat_gates(b: MapBuilder) -> void:
	var used := {}
	for link: Dictionary in b.w.portals.links:
		for side: String in ["a", "b"]:
			var island := int(link["ia" if side == "a" else "ib"])
			var other := int(link["ib" if side == "a" else "ia"])
			var at := _end_towards(b, island, other, used)
			link[side] = at
			var index := 0 if side == "a" else 1
			var node := link["nodes"][index] as Node3D
			node.position = at
			var centre := ISLANDS[island]
			var normal := Vector2(centre.x - at.x, centre.y - at.z)
			node.rotation.y = atan2(normal.x, normal.y)


## Small supply shrines give each outer island an identifiable resting point and loot anchor.
func _waystations(b: MapBuilder) -> void:
	var l := LowPoly.new()
	var placed: Array[int] = []
	for island in range(1, 9):
		var land := ISLANDS[island]
		for attempt in 48:
			var angle := TAU * (attempt % 24) / 24.0 + island * 0.6
			var p := Vector2(land.x, land.y) + Vector2(cos(angle), sin(angle)) * land.z * (0.62 if attempt < 24 else 0.74)
			var at := _at(b, p.x, p.y)
			if on_masonry(p) or _near_gate(b.w, at, 9.0) or not _gate_clear(b, p, island): continue
			# An urn and paired seats flank the open supply space; its centre stays walkable.
			for side: float in [-1.0, 1.0]:
				var seat := _at(b, p.x + side * 2.4, p.y)
				l.box(seat + Vector3.UP * 0.38, Vector3(0.7, 0.76, 1.8), DARK_STONE)
				b.w.add_solid(seat + Vector3.UP * 0.38, Vector3(0.7, 0.76, 1.8))
			var urn := _at(b, p.x, p.y + 2.5)
			l.prism(urn, urn + Vector3.UP * 0.8, 0.35, 0.5, 7, MARBLE.darkened(0.15))
			l.prism(urn + Vector3.UP * 0.8, urn + Vector3.UP, 0.5, 0.26, 7, GOLD.darkened(0.35))
			b.w.add_solid(urn + Vector3.UP * 0.5, Vector3(0.8, 1.0, 0.8))
			_brazier(b, p.x, p.y - 2.5)
			b.w.loot_spots.append(at)
			b.w.pois.append(at)
			placed.append(island)
			break
	var shrines := b.add(l)
	shrines.name = "IslandSupplyShrines"
	shrines.set_meta("islands", placed)


static func plinth_height(at: Vector3, centre: Vector3, outer: float, inner: float, rise: float) -> float:
	var extent := maxf(absf(at.x - centre.x), absf(at.z - centre.z))
	return centre.y + rise * clampf((outer - extent) / (outer - inner), 0.0, 1.0)

func _plinth(b: MapBuilder, l: LowPoly, c: Vector3, outer: float, inner: float, rise: float, bands: int) -> void:
	var ramp := LowPoly.new()
	for band in bands:
		var f0 := float(band) / bands
		var f1 := float(band + 1) / bands
		for side in 4:
			var yaw := side * PI * 0.5
			var corners: Array[Vector3] = []
			for v: Vector2 in [Vector2(-1, f0), Vector2(1, f0), Vector2(1, f1), Vector2(-1, f1)]:
				var extent := lerpf(outer, inner, v.y)
				corners.append(c + Vector3(v.x * extent, rise * v.y + 0.08, extent).rotated(Vector3.UP, yaw))
			var below := (corners[0] + corners[2]) * 0.5 - Vector3.UP
			for target: LowPoly in [l, ramp]:
				target._tri(corners[0], corners[1], corners[2], below, MARBLE.darkened(0.08 + band * 0.04))
				target._tri(corners[0], corners[2], corners[3], below, MARBLE.darkened(0.08 + band * 0.04))
	for target: LowPoly in [l, ramp]: target.box(c + Vector3(0, rise + 0.04, 0), Vector3(inner * 2, 0.08, inner * 2), MARBLE)
	_surface_collision(b.w, ramp.commit(), "WalkablePlinth")
