@tool
class_name Terrain
extends RefCounted
## The ground: one height function that the mesh, the player's collision, zombies, items and
## pathing all share. walk is what you stand on, including bridge decks. visual is what is
## drawn, so the river bed stays visible under a bridge.

static var HALF := 110
const CELL := 2.0
const DECK_FLAT := 2.6
static var SIZE := 111 # vertices per side
const WATER_Y := -0.7
const VOID_Y := -40.0
const ISLAND_RIM := 2.0
const BED_Y := -1.25 # shallow enough for anyone to wade across
const LAYER := 16 # the ground: blocks the player, sight and shots
const BARRIER := 32 # the river and the cliffs: block bodies, but not sight or shots
const ENEMY_ONLY := 128 # blocks enemies and nothing else
const STEEP := 0.86 # height per metre: steeper than about 40 degrees cannot be walked
const BANK := 5.0
const WADE := 0.6 # how deep the water can be before it stops you
const CURRENT := 1.7 # metres a second the river carries you

var islands: Array[Vector4] = [] # x, z, radius and height. With any at all, the rest of the map is empty sky.
var _island_wobble: Array[float] = []
var _island_rough: Array[float] = []
var _terraces: Array[Dictionary] = []
var river: Array[Vector2] = [] # flows from the first point to the last
var river_width := 4.2
var roughness := 5.5
var calm_radius := 30.0
var walk := PackedFloat32Array()
var visual := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _hills: Array[Vector4] = []
var _pads: Array[Dictionary] = [] # levelled at a height given by the map
var _auto_pads: Array[Dictionary] = [] # levelled at whatever height the land has there
var _cuts: Array[Dictionary] = []
var _bridges: Array[Dictionary] = []
var _fords: Array[Dictionary] = []


var _pools: Array[Vector3] = []
var _streams: Array = []


func _init() -> void:
	_noise.seed = 71
	_noise.frequency = 0.011
	_noise.fractal_octaves = 3
	_detail.seed = 13
	_detail.frequency = 0.05
	_detail.fractal_octaves = 1
	walk.resize(SIZE * SIZE)
	visual.resize(SIZE * SIZE)


## How big the land is, from the centre to its edge. Set before making a Terrain for a map.
static func use_half(half: int) -> void:
	HALF = half
	SIZE = int(half * 2.0 / CELL) + 1


func add_island(island: Vector4, wobble: float, rough := 0.5) -> void:
	islands.append(island)
	_island_wobble.append(wobble)
	_island_rough.append(rough)


## A bowl: flat at y0 inside r0, rising to y1 at r1.
func terrace(c: Vector2, r0: float, r1: float, y0: float, y1: float) -> void:
	_terraces.append({"c": c, "r0": r0, "r1": r1, "y0": y0, "y1": y1})


## The land of the islands: the top of whichever is highest here, then the edge, then a long way down.
## Stairs and bowls belong to every island they cross, so that a stair going over an island's edge onto
## a lower shelf carries on as one slope.
func _island_shape(x: float, z: float) -> float:
	var best := VOID_Y
	for i in islands.size():
		var g := islands[i]
		var a := atan2(z - g.y, x - g.x)
		var edge := g.z * (1.0 + _noise.get_noise_2d(cos(a) * 60.0 + g.x, sin(a) * 60.0 + g.y) * _island_wobble[i] * 2.0)
		var past := Vector2(x - g.x, z - g.y).length() - edge
		if past >= ISLAND_RIM:
			continue
		var top := g.w + (_detail.get_noise_2d(x, z) * 0.5 + _noise.get_noise_2d(x * 2.0, z * 2.0)) * _island_rough[i] * clampf(-past / 6.0, 0.0, 1.0)
		for t: Dictionary in _terraces:
			var d := Vector2(x, z).distance_to(t["c"])
			if d < float(t["r1"]):
				top = lerpf(float(t["y0"]), float(t["y1"]), clampf((d - float(t["r0"])) / (float(t["r1"]) - float(t["r0"])), 0.0, 1.0))
		for c: Dictionary in _cuts:
			top = _apply_cut(c, x, z, top)
		best = maxf(best, lerpf(top, VOID_Y, smoothstep(-0.5, ISLAND_RIM, past)))
	return best


func has_islands() -> bool:
	return not islands.is_empty()


## The height of the nearest island: what something hovering over the void should stay level with.
func island_floor(x: float, z: float) -> float:
	var best := INF
	var y := 0.0
	for g: Vector4 in islands:
		var d := Vector2(x - g.x, z - g.y).length() - g.z
		if d < best:
			best = d
			y = g.w
	return y


func hill(x: float, z: float, height_m: float, sigma: float) -> void:
	_hills.append(Vector4(x, z, height_m, sigma))


## A level platform, blended into the land around it. half is half its size, yaw how far it is turned.
func level(centre: Vector2, half: Vector2, yaw: float, y: float, margin := 5.0) -> void:
	_pads.append(_pad(centre, half, yaw, y, margin))


## The same, at about the height the land has there, for something that has just been set down.
func level_auto(centre: Vector2, half: Vector2, yaw: float, margin := 3.0) -> void:
	_auto_pads.append(_pad(centre, half, yaw, 0.0, margin))


func _pad(centre: Vector2, half: Vector2, yaw: float, y: float, margin: float) -> Dictionary:
	var reach := half.length() + margin
	return {"c": centre, "h": half, "cos": cos(yaw), "sin": sin(yaw), "y": y, "margin": margin, "reach2": reach * reach}


func set_river(line: Array[Vector2], width: float) -> void:
	river = line
	river_width = width


## A road cut into the land. Points are (x, y, z), and the height runs along them.
func cut(points: Array[Vector3], half_width: float, margin := 3.0) -> void:
	_cuts.append({"p": points, "w": half_width, "margin": margin})


func bridge(a: Vector2, b: Vector2, hump: float, half := 5.0) -> void:
	_bridges.append({"a": a, "b": b, "hump": hump, "ya": 0.0, "yb": 0.0, "half": half})


func ford(centre: Vector2, half: Vector2, yaw: float) -> void:
	_fords.append(_pad(centre, half, yaw, 0.0, 1.0))


func bake() -> void:
	for p: Dictionary in _auto_pads:
		p["y"] = _natural(p["c"].x, p["c"].y)
	for j in SIZE:
		for i in SIZE:
			var h := _shape(i * CELL - HALF, j * CELL - HALF)
			visual[j * SIZE + i] = h
			walk[j * SIZE + i] = h
	for b: Dictionary in _bridges:
		if not islands.is_empty():
			var from: Vector2 = b["a"]
			var to: Vector2 = b["b"]
			b["a"] = _rim_towards(from, to)
			b["b"] = _rim_towards(to, from)
		b["ya"] = _sample(visual, b["a"].x, b["a"].y)
		b["yb"] = _sample(visual, b["b"].x, b["b"].y)
		_lay_deck(b)
	for f: Dictionary in _fords:
		_lay_ford(f)


## The land before anything is set down on it: hills, roughness, and the map's own platforms.
func _natural(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var h := (_noise.get_noise_2d(x, z) * roughness + _detail.get_noise_2d(x, z) * 0.5) * smoothstep(calm_radius, calm_radius + 48.0, d)
	for g in _hills:
		var dx := x - g.x
		var dz := z - g.y
		h += g.z * exp(-(dx * dx + dz * dz) / (2.0 * g.w * g.w))
	for p: Dictionary in _pads:
		h = _apply_pad(p, x, z, h)
	return h


func _apply_pad(p: Dictionary, x: float, z: float, h: float) -> float:
	var c: Vector2 = p["c"]
	var dx := x - c.x
	var dz := z - c.y
	if dx * dx + dz * dz > float(p["reach2"]):
		return h
	var half: Vector2 = p["h"]
	var lx := absf(dx * float(p["cos"]) - dz * float(p["sin"])) - half.x
	var lz := absf(dx * float(p["sin"]) + dz * float(p["cos"])) - half.y
	var dist := Vector2(maxf(lx, 0.0), maxf(lz, 0.0)).length()
	var margin: float = p["margin"]
	if dist >= margin:
		return h
	return lerpf(float(p["y"]), h, smoothstep(0.0, margin, dist))


func _shape(x: float, z: float) -> float:
	if not islands.is_empty():
		return _island_shape(x, z)
	var h := _natural(x, z)
	for p: Dictionary in _auto_pads:
		h = _apply_pad(p, x, z, h)
	for c: Dictionary in _cuts:
		h = _apply_cut(c, x, z, h)
	if river.is_empty():
		return h
	# Hollows in the land stay above the water, or they would be pits with no water in them.
	h = maxf(h, WATER_Y + 0.3)
	var dist := river_distance(x, z)
	if dist < river_width + BANK:
		h = lerpf(BED_Y, minf(h, 2.2), smoothstep(river_width - 1.2, river_width + BANK, dist))
	return h


func _apply_cut(c: Dictionary, x: float, z: float, h: float) -> float:
	var pts: Array[Vector3] = c["p"]
	var best := INF
	var best_y := h
	var at := Vector2(x, z)
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var ab := b - a
		var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := at.distance_to(a + ab * t)
		if d < best:
			best = d
			best_y = lerpf(pts[i].y, pts[i + 1].y, t)
	var w: float = c["w"]
	var margin: float = c["margin"]
	if best >= w + margin:
		return h
	return lerpf(best_y, h, smoothstep(w, w + margin, best))


func river_distance(x: float, z: float) -> float:
	var best := INF
	var at := Vector2(x, z)
	for i in river.size() - 1:
		var ab := river[i + 1] - river[i]
		var t := clampf((at - river[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, at.distance_to(river[i] + ab * t))
	return best


## Standing in the river, shallows and ford included. A bridge is well above this.
## A pool on an island, with its streams: nothing to do with crossing, but nothing should lie in one.
func add_pool(at: Vector2, radius: float) -> void:
	_pools.append(Vector3(at.x, at.y, radius))


func add_stream(from: Vector2, to: Vector2, half_width: float) -> void:
	_streams.append([from, to, half_width])


func in_pool(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for w: Vector3 in _pools:
		if p.distance_to(Vector2(w.x, w.y)) < w.z + 1.0:
			return true
	for st: Array in _streams:
		if Geometry2D.get_closest_point_to_segment(p, st[0], st[1]).distance_to(p) < float(st[2]) + 0.8:
			return true
	return false


func in_water(x: float, z: float) -> bool:
	return height(x, z) < WATER_Y + 0.03 and not river.is_empty()


## Which way the river runs at the nearest point to here.
func river_flow(x: float, z: float) -> Vector2:
	var best := INF
	var flow := Vector2.ZERO
	var at := Vector2(x, z)
	for i in river.size() - 1:
		var ab := river[i + 1] - river[i]
		var t := clampf((at - river[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := at.distance_squared_to(river[i] + ab * t)
		if d < best:
			best = d
			flow = ab.normalized()
	return flow


func deck_y(b: Dictionary, s: float) -> float:
	if not islands.is_empty():
		# Dead level for the first and last few metres, right over the land's edge, so that the
		# slope only starts once you are clear of it and there is no lip to walk into.
		var length := Vector2(b["a"]).distance_to(b["b"])
		var flat := minf(DECK_FLAT / maxf(length, 0.01), 0.3)
		var r := clampf((s - flat) / (1.0 - flat * 2.0), 0.0, 1.0)
		var bulge := sin(r * PI)
		return lerpf(float(b["ya"]), float(b["yb"]), r) + float(b["hump"]) * bulge * bulge + 0.03
	return lerpf(float(b["ya"]), float(b["yb"]), s) + float(b["hump"]) * sin(s * PI)


func bridges() -> Array[Dictionary]:
	return _bridges


## A bridge starts where the land stops, level with it, so that it meets the ground on both sides.
func _rim_towards(from: Vector2, to: Vector2) -> Vector2:
	var along := (to - from).normalized()
	var level := _sample(visual, from.x, from.y)
	var last := from
	for n in int(from.distance_to(to) / 0.25):
		var p := from + along * n * 0.25
		if _sample(visual, p.x, p.y) < level - 0.35:
			break
		last = p
	# And a little further in, so that the deck passes over the land's rounded edge.
	return last - along * 1.2


func _lay_deck(b: Dictionary) -> void:
	var a: Vector2 = b["a"]
	var e: Vector2 = b["b"]
	var along := (e - a).normalized()
	var length := a.distance_to(e)
	for j in SIZE:
		for i in SIZE:
			var at := Vector2(i * CELL - HALF, j * CELL - HALF) - a
			var run := at.dot(along)
			var side := absf(at.dot(along.orthogonal()))
			if not islands.is_empty():
				# Over the void this is only where mobs stand, a little wider than the deck so that they
				# never read the bottom of the sky. The player stands on the deck itself.
				if run < -CELL or run > length + CELL or side > float(b["half"]) + CELL * 1.5:
					continue
				walk[j * SIZE + i] = maxf(deck_y(b, clampf(run / length, 0.0, 1.0)), visual[j * SIZE + i])
				continue
			if run < 0.0 or run > length or side > 5.0:
				continue
			var y := deck_y(b, run / length)
			# The very ends meet the road, whatever the land is doing there.
			if run < 2.0 or length - run < 2.0:
				y = maxf(y, walk[j * SIZE + i])
			walk[j * SIZE + i] = y


## The stream runs over it, ankle deep, so you can wade across but feel the current as you do.
func _lay_ford(f: Dictionary) -> void:
	var c: Vector2 = f["c"]
	var half: Vector2 = f["h"]
	for j in SIZE:
		for i in SIZE:
			var dx := i * CELL - HALF - c.x
			var dz := j * CELL - HALF - c.y
			if dx * dx + dz * dz > float(f["reach2"]) * 1.2:
				continue
			var lx := absf(dx * float(f["cos"]) - dz * float(f["sin"]))
			var lz := absf(dx * float(f["sin"]) + dz * float(f["cos"]))
			var y := WATER_Y - 0.2
			if lx < half.x + 1.0 and lz < half.y + 1.0 and visual[j * SIZE + i] < y:
				visual[j * SIZE + i] = y
				walk[j * SIZE + i] = y


func _sample(a: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + HALF) / CELL, 0.0, SIZE - 1.001)
	var fz := clampf((z + HALF) / CELL, 0.0, SIZE - 1.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := j * SIZE + i
	return lerpf(lerpf(a[k], a[k + 1], u), lerpf(a[k + SIZE], a[k + SIZE + 1], u), v)


## Standing height at a point. Called very often, so it is only a little arithmetic.
func height(x: float, z: float) -> float:
	return _sample(walk, x, z)


func ground_height(x: float, z: float) -> float:
	return _sample(visual, x, z)


func slope(x: float, z: float) -> float:
	var dx := height(x + 0.5, z) - height(x - 0.5, z)
	var dz := height(x, z + 0.5) - height(x, z - 0.5)
	return Vector2(dx, dz).length()


## How far along a bridge, and how far to its side, a point is.
func _deck_place(b: Dictionary, x: float, z: float) -> Vector2:
	var a: Vector2 = b["a"]
	var e: Vector2 = b["b"]
	var along := (e - a).normalized()
	var at := Vector2(x, z) - a
	return Vector2(at.dot(along), absf(at.dot(along.orthogonal())))


func on_deck(x: float, z: float) -> bool:
	for b: Dictionary in _bridges:
		var q := _deck_place(b, x, z)
		var length := (b["a"] as Vector2).distance_to(b["b"])
		if not islands.is_empty():
			if q.x > 0.0 and q.x < length and q.y < float(b["half"]) + 0.2:
				return true
			continue
		if q.x > -5.0 and q.x < length + 5.0 and q.y < 5.0:
			return true
	return false


## On a bridge or just coming up to one.
func near_deck(x: float, z: float) -> bool:
	for b: Dictionary in _bridges:
		var q := _deck_place(b, x, z)
		if q.x > -6.0 and q.x < (b["a"] as Vector2).distance_to(b["b"]) + 6.0 and q.y < float(b["half"]) + 3.0:
			return true
	return false


func over_water_on_deck(x: float, z: float) -> bool:
	for b: Dictionary in _bridges:
		var q := _deck_place(b, x, z)
		if q.x > 0.0 and q.x < (b["a"] as Vector2).distance_to(b["b"]) and q.y < 3.0:
			return true
	return false


func is_walkable(x: float, z: float) -> bool:
	if not islands.is_empty():
		if on_deck(x, z):
			return true
		var dx := ground_height(x + 0.5, z) - ground_height(x - 0.5, z)
		var dz := ground_height(x, z + 0.5) - ground_height(x, z - 0.5)
		return ground_height(x, z) > 0.0 and Vector2(dx, dz).length() < STEEP
	if height(x, z) < WATER_Y - WADE:
		return false
	return on_deck(x, z) or slope(x, z) < STEEP


## The physics ground, 1 m a sample, as big as the map.
func collision_shape() -> HeightMapShape3D:
	var side := HALF * 2 + 1
	var data := PackedFloat32Array()
	data.resize(side * side)
	for j in side:
		for i in side:
			# On the islands the bridges are separate solid things: there is nothing under them.
			data[j * side + i] = ground_height(i - HALF, j - HALF) if not islands.is_empty() else height(i - HALF, j - HALF)
	var shape := HeightMapShape3D.new()
	shape.map_width = side
	shape.map_depth = side
	shape.map_data = data
	return shape


## Every metre that cannot be walked: runs of cells merged, so few boxes are needed.
## Returns rectangles in map coordinates.
func blocked_rects() -> Array[Rect2i]:
	var side := HALF * 2
	var open := {}
	var out: Array[Rect2i] = []
	for z in side:
		var runs := {}
		var x := 0
		while x < side:
			if is_walkable(x - HALF + 0.5, z - HALF + 0.5):
				x += 1
				continue
			var start := x
			while x < side and not is_walkable(x - HALF + 0.5, z - HALF + 0.5):
				x += 1
			runs[Vector2i(start, x)] = true
		for key: Vector2i in open.keys():
			if not runs.has(key):
				var r: Rect2i = open[key]
				out.append(r)
				open.erase(key)
		for key: Vector2i in runs:
			if open.has(key):
				var r: Rect2i = open[key]
				r.size.y += 1
				open[key] = r
			else:
				open[key] = Rect2i(key.x, z, key.y - key.x, 1)
	for key: Vector2i in open:
		out.append(open[key])
	return out


func _tint(x: float, z: float, h: float, steep: float, river_dist: float) -> Color:
	var n := _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var far := _noise.get_noise_2d(z, x) * 0.5 + 0.5
	var col := Color(0.25, 0.4, 0.19).lerp(Color(0.34, 0.44, 0.2), n).lerp(Color(0.2, 0.33, 0.2), far * 0.7)
	if h > 3.0:
		col = col.lerp(Color(0.36, 0.42, 0.26), clampf((h - 3.0) / 6.0, 0.0, 0.6))
	col = col.lerp(Color(0.36, 0.34, 0.32), smoothstep(0.42, 0.72, steep))
	if not islands.is_empty():
		var mossy := Color(0.13, 0.3, 0.17).lerp(Color(0.24, 0.4, 0.2), clampf(_noise.get_noise_2d(x * 2.0, z * 2.0) * 1.2 + 0.5, 0.0, 1.0))
		mossy = mossy.lerp(Color(0.34, 0.36, 0.32), clampf(_detail.get_noise_2d(x * 0.6, z * 0.6) * 2.0 - 0.35, 0.0, 0.55))
		return mossy.lerp(Color(0.34, 0.36, 0.38), smoothstep(0.42, 0.72, steep))
	if river_dist < river_width + BANK * 0.65:
		col = col.lerp(Color(0.32, 0.28, 0.2), 1.0 - smoothstep(river_width, river_width + BANK * 0.65, river_dist))
	return col


func _vertex_steep(i: int, j: int) -> float:
	var l := visual[j * SIZE + maxi(i - 1, 0)]
	var r := visual[j * SIZE + mini(i + 1, SIZE - 1)]
	var d := visual[maxi(j - 1, 0) * SIZE + i]
	var u := visual[mini(j + 1, SIZE - 1) * SIZE + i]
	return Vector2(r - l, u - d).length() / (2.0 * CELL)


## One mesh per patch of ground: a light then only costs shading on the patches it touches.
func patch_mesh(i0: int, j0: int, cells: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := mini(cells, SIZE - 1 - i0) + 1
	var d := mini(cells, SIZE - 1 - j0) + 1
	for j in range(j0, j0 + d):
		for i in range(i0, i0 + w):
			var x := i * CELL - HALF
			var z := j * CELL - HALF
			var h := visual[j * SIZE + i]
			var l := visual[j * SIZE + maxi(i - 1, 0)]
			var r := visual[j * SIZE + mini(i + 1, SIZE - 1)]
			var b := visual[maxi(j - 1, 0) * SIZE + i]
			var f := visual[mini(j + 1, SIZE - 1) * SIZE + i]
			st.set_normal(Vector3(l - r, 2.0 * CELL, b - f).normalized())
			st.set_color(_tint(x, z, h, _vertex_steep(i, j), river_distance(x, z)))
			st.set_uv(Vector2(x, z) / 4.0)
			st.add_vertex(Vector3(x, h, z))
	for j in d - 1:
		for i in w - 1:
			var a := j * w + i
			if not islands.is_empty() and _all_void(i0 + i, j0 + j):
				continue
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + w)
			st.add_index(a + 1)
			st.add_index(a + w + 1)
			st.add_index(a + w)
	return st.commit()


func _all_void(i: int, j: int) -> bool:
	var low := VOID_Y + 1.0
	return visual[j * SIZE + i] < low and visual[j * SIZE + i + 1] < low and visual[(j + 1) * SIZE + i] < low and visual[(j + 1) * SIZE + i + 1] < low


## Land beyond the edge of the map, rising away so the world seems to go on.
func skirt_mesh(sector: int) -> ArrayMesh:
	const STEP := 10.0
	const RINGS := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := int(float(HALF * 2 + RINGS * STEP * 2) / STEP)
	var points := {}
	for u in along + 1:
		for v in RINGS + 1:
			var p := _skirt_point(sector, u, v, STEP, along)
			var near := Vector2(clampf(p.x, -HALF, HALF), clampf(p.y, -HALF, HALF))
			var out := p.distance_to(near)
			var y := ground_height(near.x, near.y) + out * 0.16 + (_noise.get_noise_2d(p.x, p.y) + 0.5) * minf(out * 0.2, 14.0)
			points[Vector2i(u, v)] = Vector3(p.x, y, p.y)
	for u in along:
		for v in RINGS:
			var a: Vector3 = points[Vector2i(u, v)]
			var b: Vector3 = points[Vector2i(u + 1, v)]
			var c: Vector3 = points[Vector2i(u, v + 1)]
			var d: Vector3 = points[Vector2i(u + 1, v + 1)]
			for tri: Array in [[a, b, c], [b, d, c]]:
				var n: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
				if n.y > 0.0:
					tri.reverse()
				else:
					n = -n
				for q: Vector3 in tri:
					st.set_normal(n)
					st.set_color(Color(0.17, 0.27, 0.16).lerp(Color(0.28, 0.33, 0.24), clampf(q.y / 30.0, 0.0, 1.0)))
					st.set_uv(Vector2(q.x, q.z) / 4.0)
					st.add_vertex(q)
	return st.commit()


func _skirt_point(sector: int, u: int, v: int, step: float, along: int) -> Vector2:
	var s := -float(along) * step * 0.5 + u * step
	var o := float(HALF) + v * step
	match sector:
		0: return Vector2(s, -o)
		1: return Vector2(s, o)
		2: return Vector2(-o, s)
	return Vector2(o, s)


## The strip of water along the river.
func water_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := river_width + BANK * 0.5
	var flow := 0.0
	for i in river.size() - 1:
		var a := river[i]
		var b := river[i + 1]
		var d := (b - a).normalized()
		var before := (a - river[i - 1]).normalized() if i > 0 else d
		var after := (river[i + 2] - b).normalized() if i < river.size() - 2 else d
		var na := (d + before).normalized().orthogonal()
		var nb := (d + after).normalized().orthogonal()
		var flow2 := flow + a.distance_to(b)
		var quad := [[a + na * half, 0.0, flow], [a - na * half, 1.0, flow], [b + nb * half, 0.0, flow2], [b - nb * half, 1.0, flow2]]
		for q: int in [0, 1, 2, 1, 3, 2]:
			var v: Array = quad[q]
			var p: Vector2 = v[0]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(Vector3(p.x, WATER_Y, p.y))
		flow = flow2
	return st.commit()
