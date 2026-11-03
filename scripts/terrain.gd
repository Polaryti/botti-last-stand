class_name Terrain
extends RefCounted
## The ground: one height function that the mesh, the player's collision, zombies, items and
## pathing all share. walk is what you stand on, including bridge decks. visual is what is
## drawn, so the river bed stays visible under a bridge.

const HALF := 110
const CELL := 2.0
const SIZE := 111 # vertices per side
const WATER_Y := -0.7
const BED_Y := -2.3
const LAYER := 16 # the ground: blocks the player, sight and shots
const BARRIER := 32 # the river and the cliffs: block bodies, but not sight or shots
const ENEMY_ONLY := 128 # blocks enemies and nothing else
const STEEP := 0.86 # height per metre: steeper than about 40 degrees cannot be walked
const RIVER: Array[Vector2] = [Vector2(122, -48), Vector2(94, -30), Vector2(76, -12), Vector2(71, 6), Vector2(73, 26), Vector2(66, 46),
	Vector2(50, 59), Vector2(24, 64), Vector2(0, 64), Vector2(-24, 64), Vector2(-44, 60), Vector2(-60, 68), Vector2(-72, 86), Vector2(-86, 122)]
const RIVER_WIDTH := 4.2
const BANK := 5.0
const CASTLE := Rect2(-96, -94, 48, 48)
const CASTLE_Y := 8.5

var use_river := true
var walk := PackedFloat32Array()
var visual := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _hills: Array[Vector4] = []
var _pads: Array[Dictionary] = []
var _cuts: Array[Dictionary] = []
var _bridges: Array[Dictionary] = []
var _fords: Array[Rect2] = []


func _init() -> void:
	_noise.seed = 71
	_noise.frequency = 0.011
	_noise.fractal_octaves = 3
	_detail.seed = 13
	_detail.frequency = 0.05
	_detail.fractal_octaves = 1
	walk.resize(SIZE * SIZE)
	visual.resize(SIZE * SIZE)


func hill(x: float, z: float, height_m: float, sigma: float) -> void:
	_hills.append(Vector4(x, z, height_m, sigma))


## A level platform for something to stand on, blended into the land around it.
func pad(r: Rect2, y: float, margin := 5.0) -> void:
	_pads.append({"r": r, "y": y, "margin": margin})


## A road cut into the land. Points are (x, y, z), and the height runs along them.
func cut(points: Array[Vector3], half_width: float, margin := 3.0) -> void:
	_cuts.append({"p": points, "w": half_width, "margin": margin})


func bridge(a: Vector2, b: Vector2, hump: float) -> void:
	_bridges.append({"a": a, "b": b, "hump": hump, "ya": 0.0, "yb": 0.0})


func ford(r: Rect2) -> void:
	_fords.append(r)


func bake() -> void:
	for j in SIZE:
		for i in SIZE:
			var h := _shape(i * CELL - HALF, j * CELL - HALF)
			visual[j * SIZE + i] = h
			walk[j * SIZE + i] = h
	for b: Dictionary in _bridges:
		b["ya"] = _sample(visual, b["a"].x, b["a"].y)
		b["yb"] = _sample(visual, b["b"].x, b["b"].y)
		_lay_deck(b)
	for r in _fords:
		_lay_ford(r)


func _shape(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	var h := (_noise.get_noise_2d(x, z) * 5.5 + _detail.get_noise_2d(x, z) * 0.5) * smoothstep(30.0, 78.0, d)
	for g in _hills:
		var dx := x - g.x
		var dz := z - g.y
		h += g.z * exp(-(dx * dx + dz * dz) / (2.0 * g.w * g.w))
	for p: Dictionary in _pads:
		var r: Rect2 = p["r"]
		var dist := Vector2(maxf(maxf(r.position.x - x, x - r.end.x), 0.0), maxf(maxf(r.position.y - z, z - r.end.y), 0.0)).length()
		var margin: float = p["margin"]
		if dist < margin:
			h = lerpf(float(p["y"]), h, smoothstep(0.0, margin, dist))
	for c: Dictionary in _cuts:
		h = _apply_cut(c, x, z, h)
	var river := river_distance(x, z)
	if river < RIVER_WIDTH + BANK:
		h = lerpf(BED_Y, minf(h, 2.2), smoothstep(RIVER_WIDTH - 1.2, RIVER_WIDTH + BANK, river))
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
	if not use_river:
		return INF
	var best := INF
	var at := Vector2(x, z)
	for i in RIVER.size() - 1:
		var ab := RIVER[i + 1] - RIVER[i]
		var t := clampf((at - RIVER[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, at.distance_to(RIVER[i] + ab * t))
	return best


func deck_y(b: Dictionary, s: float) -> float:
	return lerpf(float(b["ya"]), float(b["yb"]), s) + float(b["hump"]) * sin(s * PI)


func bridges() -> Array[Dictionary]:
	return _bridges


func _lay_deck(b: Dictionary) -> void:
	var a: Vector2 = b["a"]
	var e: Vector2 = b["b"]
	var along_x := absf(a.x - e.x) > absf(a.y - e.y)
	var length := a.distance_to(e)
	for j in SIZE:
		for i in SIZE:
			var x := i * CELL - HALF
			var z := j * CELL - HALF
			var s := ((x - a.x) / (e.x - a.x)) if along_x else ((z - a.y) / (e.y - a.y))
			var side := absf(z - a.y) if along_x else absf(x - a.x)
			if s < 0.0 or s > 1.0 or side > 5.0:
				continue
			var y := deck_y(b, s)
			# The very ends meet the road, whatever the land is doing there.
			if s * length < 2.0 or (1.0 - s) * length < 2.0:
				y = maxf(y, walk[j * SIZE + i])
			walk[j * SIZE + i] = y


func _lay_ford(r: Rect2) -> void:
	for j in SIZE:
		for i in SIZE:
			var x := i * CELL - HALF
			var z := j * CELL - HALF
			if r.grow(1.0).has_point(Vector2(x, z)) and visual[j * SIZE + i] < WATER_Y + 0.14:
				visual[j * SIZE + i] = WATER_Y + 0.14
				walk[j * SIZE + i] = WATER_Y + 0.14


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


func on_deck(x: float, z: float) -> bool:
	for b: Dictionary in _bridges:
		var a: Vector2 = b["a"]
		var e: Vector2 = b["b"]
		var r := Rect2(minf(a.x, e.x), minf(a.y, e.y), absf(a.x - e.x), absf(a.y - e.y))
		if r.grow(5.0).has_point(Vector2(x, z)):
			return true
	return false


func over_water_on_deck(x: float, z: float) -> bool:
	for b: Dictionary in _bridges:
		var a: Vector2 = b["a"]
		var e: Vector2 = b["b"]
		var r := Rect2(minf(a.x, e.x), minf(a.y, e.y), absf(a.x - e.x), absf(a.y - e.y))
		if r.grow(0.1).has_point(Vector2(x, z)) or (absf(a.x - e.x) > 0.5 and absf(z - a.y) < 3.0 and x > r.position.x and x < r.end.x) or (absf(a.y - e.y) > 0.5 and absf(x - a.x) < 3.0 and z > r.position.y and z < r.end.y):
			return true
	return false


func is_walkable(x: float, z: float) -> bool:
	if height(x, z) < WATER_Y + 0.1:
		return false
	return on_deck(x, z) or slope(x, z) < STEEP


## The physics ground, 1 m a sample, as big as the map.
func collision_shape() -> HeightMapShape3D:
	var side := HALF * 2 + 1
	var data := PackedFloat32Array()
	data.resize(side * side)
	for j in side:
		for i in side:
			data[j * side + i] = height(i - HALF, j - HALF)
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


func _tint(x: float, z: float, h: float, steep: float, river: float) -> Color:
	var n := _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var far := _noise.get_noise_2d(z, x) * 0.5 + 0.5
	var col := Color(0.25, 0.4, 0.19).lerp(Color(0.34, 0.44, 0.2), n).lerp(Color(0.2, 0.33, 0.2), far * 0.7)
	if h > 3.0:
		col = col.lerp(Color(0.36, 0.42, 0.26), clampf((h - 3.0) / 6.0, 0.0, 0.6))
	col = col.lerp(Color(0.36, 0.34, 0.32), smoothstep(0.42, 0.72, steep))
	if river < RIVER_WIDTH + BANK * 0.65:
		col = col.lerp(Color(0.32, 0.28, 0.2), 1.0 - smoothstep(RIVER_WIDTH, RIVER_WIDTH + BANK * 0.65, river))
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
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + w)
			st.add_index(a + 1)
			st.add_index(a + w + 1)
			st.add_index(a + w)
	return st.commit()


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
	var half := RIVER_WIDTH + BANK * 0.5
	var flow := 0.0
	for i in RIVER.size() - 1:
		var a := RIVER[i]
		var b := RIVER[i + 1]
		var d := (b - a).normalized()
		var before := (a - RIVER[i - 1]).normalized() if i > 0 else d
		var after := (RIVER[i + 2] - b).normalized() if i < RIVER.size() - 2 else d
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
