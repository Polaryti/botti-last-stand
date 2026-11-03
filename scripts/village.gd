class_name Village
extends RefCounted
## Builds the night village from code: enterable buildings, fields, fences, trees.
## Anything solid goes through World.add_solid so collision and pathing always match.

const THATCH := Color(0.52, 0.42, 0.22)
const SHINGLE := Color(0.27, 0.2, 0.2)
const PLASTER := Color(0.68, 0.62, 0.5)
const PLASTER_B := Color(0.6, 0.55, 0.47)
const PLANK := Color(0.42, 0.2, 0.13)
const BEAM := Color(0.2, 0.13, 0.08)
const STONE := Color(0.4, 0.4, 0.42)
const FLOOR := Color(0.3, 0.22, 0.15)
const HAY := Color(0.72, 0.6, 0.26)
const DIRT := Color(0.27, 0.2, 0.13)
const WHEAT := Color(0.74, 0.62, 0.28)
const GRASS := Color(0.27, 0.44, 0.19)
const GRASS_TIP := Color(0.42, 0.56, 0.24)

var w: World
var rng := RandomNumberGenerator.new()
var _props := {}
var _trees := {}
var _indoors: Array[Rect2] = []
var _ground_meshes := {}
var _cells := {} # small furniture and clutter, merged by map area into one mesh each
var _y := 0.0 # floor height of the building being built
var _roads_now: Array = ROADS
var _copses: Array[Vector3] = []
var _land := RandomNumberGenerator.new() # for what is solid: the same on every phone, whatever its quality


func _init(world: World) -> void:
	w = world
	rng.seed = 1337
	_land.seed = 4242


func build() -> void:
	_ground()
	_boundary()
	_paths()
	_river()
	_buildings()
	_square()
	_fields()
	_scatter_props()
	if w.mode != Game.Mode.MENU:
		Landmarks.new(self).build()
	_trees_and_rocks()
	_flush_props()
	for key: Vector2i in _cells:
		_add(_cells[key])
	w.indoors = _indoors


## The other map: the wood around the fort.
func build_fort() -> void:
	_roads_now = FortMap.ROADS
	_ground()
	_boundary()
	var map := FortMap.new(self)
	map.build()
	for road: Array in _roads_now:
		_road(road, 4.0)
	_copses = FortMap.COPSES
	_trees_and_rocks()
	_flush_props()
	for key: Vector2i in _cells:
		_add(_cells[key])
	w.indoors = _indoors


## Everything about the shape of the land. Buildings and fields get level ground to stand on.
static func plan_land(t: Terrain) -> void:
	# Hills that give the map its shape.
	t.hill(-72, -70, 4.5, 34)
	t.hill(-92, 10, 3.0, 24)
	t.hill(94, 42, 5.5, 15)
	t.hill(49, -81, 2.4, 22)
	t.hill(90, -78, 7.0, 20)
	t.hill(0, -97, 4.0, 15)
	t.hill(60, 94, 6.0, 18)
	t.hill(-22, 112, 5.0, 15)
	t.hill(-100, 62, 6.5, 16)
	t.hill(-30, -100, 3.5, 13)
	# The village.
	t.pad(Rect2(-13, -13, 26, 26), 0.0, 5.0)
	t.pad(Rect2(-22, -20, 44, 42), 0.0, 5.0)
	t.pad(Rect2(-46, -44, 18, 24), 0.0, 6.0)
	t.pad(Rect2(26, -39, 22, 15), 0.0, 6.0)
	t.pad(Rect2(-7, -61, 14, 26), 0.0, 6.0)
	t.pad(Rect2(26, 6, 11, 11), 0.0, 4.0)
	t.pad(Rect2(9, -40, 14, 13), 0.0, 4.0)
	t.pad(Rect2(-17, 37, 13, 14), 0.0, 4.0)
	t.pad(Rect2(4, 37, 13, 14), 0.0, 4.0)
	# Fields.
	t.pad(Rect2(-52, 20, 34, 32), 0.0, 5.0)
	t.pad(Rect2(18, 24, 34, 28), 0.0, 5.0)
	t.pad(Rect2(-56, -12, 22, 24), 0.0, 5.0)
	t.pad(Rect2(20, -18, 32, 22), 0.0, 5.0)
	# Beyond the village.
	t.pad(Terrain.CASTLE, Terrain.CASTLE_Y, 7.0)
	t.pad(Rect2(32, -96, 34, 30), 3.0, 9.0)
	t.pad(Rect2(-72, -21, 15, 14), 1.0, 5.0)
	t.pad(Rect2(-74, 7, 15, 14), 1.4, 5.0)
	t.pad(Rect2(-106, -8, 34, 32), 3.4, 8.0)
	t.pad(Rect2(-98, 55, 11, 11), 5.0, 6.0)
	t.pad(Rect2(81, -10, 15, 13), 0.8, 5.0)
	t.pad(Rect2(91, 8, 15, 13), 1.6, 5.0)
	t.pad(Rect2(87, 35, 14, 14), 6.5, 8.0)
	t.pad(Rect2(72, -70, 18, 14), 2.0, 6.0)
	t.pad(Rect2(20, 74, 16, 13), 0.9, 3.0)
	t.pad(Rect2(-20, 80, 14, 12), 1.0, 5.0)
	t.pad(Rect2(4, 88, 20, 14), 1.2, 5.0)
	t.pad(Rect2(-52, 77, 30, 25), 1.2, 6.0)
	t.pad(Rect2(-18, 95, 20, 12), 1.5, 5.0)
	t.pad(Rect2(28, 90, 26, 16), 2.0, 6.0)
	# Roads cut into the slopes.
	t.cut([Vector3(-47, Terrain.CASTLE_Y, -70), Vector3(-39, 6.0, -68.5), Vector3(-30, 1.8, -60), Vector3(-25, 0.2, -48)], 3.2, 3.5)
	t.cut([Vector3(8, 0.0, -36), Vector3(22, 0.2, -44), Vector3(36, 2.8, -64)], 2.6, 4.0)
	t.cut([Vector3(86, 2.0, 18), Vector3(90, 6.5, 36)], 2.4, 4.0)
	# Three ways over the river.
	t.bridge(Vector2(0, 53), Vector2(0, 75), 1.1)
	t.bridge(Vector2(61.5, 0), Vector2(83.5, 0), 0.9)
	t.ford(Rect2(-59, 54, 9, 22))
	t.bake()


func on_ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.terrain.height(at.x, at.z) + at.y, at.z)


func solid(at: Vector3, size: Vector3) -> void:
	w.add_solid(at + Vector3.UP * _y, size)


func collider(at: Vector3, size: Vector3) -> void:
	w.add_collider(at + Vector3.UP * _y, size)


## Patches instead of one big plane: a light only costs shading time on objects it touches, so
## a lantern now costs the few patches around it rather than all the ground on screen.
func _ground() -> void:
	const CELLS := 12
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://assets/sprites/ground_tile.png")
	mat.roughness = 1.0
	var t := w.terrain
	var j := 0
	while j < Terrain.SIZE - 1:
		var i := 0
		while i < Terrain.SIZE - 1:
			_ground_mesh(t.patch_mesh(i, j, CELLS), mat)
			i += CELLS
		j += CELLS
	for sector in 4:
		_ground_mesh(t.skirt_mesh(sector), mat)


func _ground_mesh(m: Mesh, mat: Material) -> void:
	var g := MeshInstance3D.new()
	g.mesh = m
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(g)


func _boundary() -> void:
	var h := World.HALF_SIZE
	var t := 2.0
	w.add_collider(Vector3(0, 15, -h - t * 0.5), Vector3(h * 2 + 4, 70, t))
	w.add_collider(Vector3(0, 15, h + t * 0.5), Vector3(h * 2 + 4, 70, t))
	w.add_collider(Vector3(-h - t * 0.5, 15, 0), Vector3(t, 70, h * 2 + 4))
	w.add_collider(Vector3(h + t * 0.5, 15, 0), Vector3(t, 70, h * 2 + 4))
	# Cliffs and deep water.
	for r in w.terrain.blocked_rects():
		var c := Vector2(r.position) + Vector2(r.size) * 0.5 - Vector2.ONE * World.HALF_SIZE
		var y := w.terrain.height(c.x, c.y)
		w.add_barrier(Vector3(c.x, y, c.y), Vector3(r.size.x, 60.0, r.size.y))


const ROADS: Array = [
	[Vector2(0, -36), Vector2(0, -9)], [Vector2(0, 9), Vector2(0, 53), Vector2(0, 75), Vector2(-2, 84), Vector2(-4, 94)],
	[Vector2(9, 0), Vector2(61.5, 0), Vector2(83.5, 0), Vector2(94, 2)], [Vector2(-9, 0), Vector2(-60, 0), Vector2(-74, 2)],
	[Vector2(-37, -24), Vector2(-7, -24)], [Vector2(5, -24), Vector2(35, -24)],
	[Vector2(-3, -30), Vector2(-16, -36), Vector2(-25, -48), Vector2(-30, -60), Vector2(-39, -68.5), Vector2(-47, -70), Vector2(-53, -70)],
	[Vector2(3, -31), Vector2(22, -44), Vector2(36, -64), Vector2(44, -70)],
	[Vector2(84, 3), Vector2(87, 18), Vector2(90, 36)], [Vector2(0, 79), Vector2(20, 81)], [Vector2(-2, 87), Vector2(-12, 87)],
	[Vector2(-2, 88), Vector2(12, 91)], [Vector2(85, -4), Vector2(82, -28), Vector2(80, -62)],
]


func _paths() -> void:
	_add(LowPoly.new().box(Vector3(0, 0.02, 0), Vector3(18, 0.04, 18), DIRT.lightened(0.05))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for road: Array in ROADS:
		_road(road, 4.0)


## A strip that follows the land. It is cut every 24 m or so, for the same reason as the ground patches.
func _road(points: Array, width: float) -> void:
	const STEP := 1.6
	const ACROSS := 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row: Array[Vector3] = []
	var since := 0.0
	var used := false
	var t := w.terrain
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var d := (b - a).normalized()
		var side := d.orthogonal() * width * 0.5
		var steps := maxi(1, int(a.distance_to(b) / STEP))
		# A bridge is its own road.
		if t.over_water_on_deck((a.x + b.x) * 0.5, (a.y + b.y) * 0.5):
			row.clear()
			continue
		for s in steps + 1:
			var c := a.lerp(b, float(s) / steps)
			var next: Array[Vector3] = []
			for q in ACROSS + 1:
				var at := c + side * (float(q) / ACROSS * 2.0 - 1.0)
				var y := t.height(at.x, at.y)
				# Never under the land: the land between two samples can be higher than either.
				for off: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					y = maxf(y, t.height(at.x + off.x, at.y + off.y))
				next.append(Vector3(at.x, y + 0.05, at.y))
			if not row.is_empty():
				for q in ACROSS:
					var tint := DIRT.lerp(DIRT.lightened(0.07), 1.0 - absf(float(q) + 0.5 - ACROSS * 0.5) / (ACROSS * 0.5))
					var tris: Array[Vector3] = [row[q], next[q], row[q + 1], row[q + 1], next[q], next[q + 1]]
					if (row[q + 1] - row[q]).cross(next[q] - row[q]).y < 0.0:
						tris = [row[q], row[q + 1], next[q], row[q + 1], next[q + 1], next[q]]
					for v: Vector3 in tris:
						st.set_color(tint)
						st.set_normal(Vector3.UP)
						st.add_vertex(v)
				used = true
			row = next
			since += STEP
			if since > 24.0 and used:
				since = 0.0
				_commit_road(st)
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				used = false
	if used:
		_commit_road(st)


func _commit_road(st: SurfaceTool) -> void:
	var mesh := st.commit()
	mesh.surface_set_material(0, LowPoly.material())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)


func _river() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = w.terrain.water_mesh()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/water.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	w.set_water(m)
	var bridges := w.terrain.bridges()
	_bridge(bridges[0], true)
	_bridge(bridges[1], false)
	_ford(Rect2(-59, 54, 9, 22))
	_reeds()


## A stone bridge with a parapet, or a timber one on trestles. Nothing else crosses the water.
func _bridge(b: Dictionary, stone_built: bool) -> void:
	var a: Vector2 = b["a"]
	var e: Vector2 = b["b"]
	var along := (e - a).normalized()
	var side := along.orthogonal()
	var length := a.distance_to(e)
	var l := LowPoly.new()
	var deck_col := Color(0.42, 0.41, 0.4) if stone_built else Color(0.4, 0.28, 0.17)
	var rail_col := Color(0.36, 0.36, 0.37) if stone_built else BEAM.lightened(0.1)
	const STEP := 1.2
	var s := 0.0
	var i := 0
	var t := w.terrain
	while s < length:
		var s1 := minf(s + STEP, length)
		var p0 := a + along * s
		var p1 := a + along * s1
		var y0 := t.height(p0.x, p0.y)
		var y1 := t.height(p1.x, p1.y)
		var m := (p0 + p1) * 0.5
		var pitch := rad_to_deg(atan2(y1 - y0, s1 - s))
		var rot := Vector3(0, 0, pitch) if absf(along.x) > 0.5 else Vector3(-pitch, 0, 0)
		var tone := deck_col.lightened(0.05 * (i % 3))
		var size := Vector3(s1 - s + 0.1, 0.4, 5.8) if absf(along.x) > 0.5 else Vector3(5.8, 0.4, s1 - s + 0.1)
		l.box(Vector3(m.x, (y0 + y1) * 0.5 - 0.14, m.y), size, tone, rot)
		for f: float in [-2.75, 2.75]:
			var edge := m + side * f
			if stone_built:
				var wall := Vector3(s1 - s + 0.06, 1.0, 0.35) if absf(along.x) > 0.5 else Vector3(0.35, 1.0, s1 - s + 0.06)
				l.box(Vector3(edge.x, (y0 + y1) * 0.5 + 0.48, edge.y), wall, rail_col.lightened(0.04 * (i % 2)), rot)
			elif i % 2 == 0:
				l.box(Vector3(edge.x, (y0 + y1) * 0.5 + 0.55, edge.y), Vector3(0.18, 1.2, 0.18), BEAM)
			if not stone_built:
				var bar := Vector3(s1 - s + 0.06, 0.1, 0.1) if absf(along.x) > 0.5 else Vector3(0.1, 0.1, s1 - s + 0.06)
				l.box(Vector3(edge.x, (y0 + y1) * 0.5 + 1.05, edge.y), bar, rail_col, rot)
		s = s1
		i += 1
	# What holds it up.
	for f: float in [0.34, 0.5, 0.66]:
		var p := a + along * length * f
		var top := t.height(p.x, p.y) - 0.3
		if stone_built:
			if absf(f - 0.5) > 0.01:
				var size := Vector3(1.6, top - Terrain.BED_Y, 6.0) if absf(along.x) > 0.5 else Vector3(6.0, top - Terrain.BED_Y, 1.6)
				l.box(Vector3(p.x, (top + Terrain.BED_Y) * 0.5, p.y), size, deck_col.darkened(0.15))
		else:
			for g: float in [-2.2, 2.2]:
				var q := p + side * g
				l.box(Vector3(q.x, (top + Terrain.BED_Y) * 0.5, q.y), Vector3(0.3, top - Terrain.BED_Y, 0.3), BEAM)
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	w.add_child(mi)
	# Nothing walks off the side.
	var mid := (a + e) * 0.5
	var y := t.height(mid.x, mid.y)
	for f: float in [-4.5, 4.5]:
		var c := mid + side * f
		var size := Vector3(length, 60.0, 3.2) if absf(along.x) > 0.5 else Vector3(3.2, 60.0, length)
		w.add_barrier(Vector3(c.x, y, c.y), size)
		w.grid.block_box(Vector3(c.x, 0, c.y), size)


func _ford(r: Rect2) -> void:
	var l := LowPoly.new()
	var t := w.terrain
	var z := r.position.y
	while z < r.end.y:
		for k in 2:
			var x := rng.randf_range(r.position.x + 0.5, r.end.x - 0.5)
			var y := t.ground_height(x, z)
			if y < 0.0:
				var size := rng.randf_range(0.5, 1.1)
				l.prism(Vector3(x, y - 0.1, z), Vector3(x, y + 0.2, z), size, size * 0.6, 6, Color(0.44, 0.43, 0.42).lightened(rng.randf() * 0.1))
		z += 1.7
	_add(l).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Reeds on the banks, where the land meets the water.
func _reeds() -> void:
	var l := LowPoly.new()
	for i in 5:
		var a := TAU * i / 5.0
		var off := Vector3(cos(a), 0, sin(a)) * 0.1
		var side := Vector3(-sin(a), 0, cos(a)) * 0.04
		l.gable(off - side, off + side, off * 2.2 + Vector3.UP * (0.95 + 0.2 * (i % 2)), Color(0.3, 0.38, 0.17))
	var mesh := l.commit()
	var chunks := {}
	var t := w.terrain
	for i in Game.grass_count():
		var seg := rng.randi_range(0, Terrain.RIVER.size() - 2)
		var p := Terrain.RIVER[seg].lerp(Terrain.RIVER[seg + 1], rng.randf())
		var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(Terrain.RIVER_WIDTH + 0.2, Terrain.RIVER_WIDTH + 1.8)
		p += off
		if absf(p.x) > World.HALF_SIZE or absf(p.y) > World.HALF_SIZE or t.on_deck(p.x, p.y):
			continue
		var y := t.ground_height(p.x, p.y)
		if y < Terrain.WATER_Y - 0.5 or y > 0.5:
			continue
		var key := Vector2i(int(floor(p.x / 24.0)), int(floor(p.y / 24.0)))
		if not chunks.has(key):
			chunks[key] = [[], PackedColorArray()]
		var s := rng.randf_range(0.8, 1.5)
		(chunks[key][0] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, y, p.y)))
		chunks[key][1] = (chunks[key][1] as PackedColorArray) + PackedColorArray([Color.WHITE.darkened(rng.randf() * 0.25)])
	for key: Vector2i in chunks:
		var list: Array[Transform3D] = []
		list.assign(chunks[key][0])
		var node := Crops.plant(mesh, list, chunks[key][1])
		node.visibility_range_end = 50.0
		w.add_child(node)


## Small things share one mesh per 24 m square, which saves a draw call for each of them.
func _cell(at: Vector3) -> LowPoly:
	var key := Vector2i(int(floor(at.x / 24.0)), int(floor(at.z / 24.0)))
	if not _cells.has(key):
		_cells[key] = LowPoly.new()
	return _cells[key]


func _add(l: LowPoly) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	mi.position.y = _y
	w.add_child(mi)
	return mi


# --- Buildings ---------------------------------------------------------------

func door(at: float, width := 2.2, top := 2.5) -> Dictionary:
	return {"at": at, "width": width, "sill": 0.0, "top": top}


func window(at: float) -> Dictionary:
	return {"at": at, "width": 1.1, "sill": 1.15, "top": 2.0}


func _buildings() -> void:
	var a := {"plaster": PLASTER, "roof": THATCH}
	var b := {"plaster": PLASTER_B, "roof": SHINGLE}
	var h5 := _house(Vector3(16, 0, -33), 8, 7, 3.0, "x", a, {"s": [door(1)], "w": [window(0)], "e": [window(0)]})
	_bed(h5 + Vector3(-2.4, 0, -2.0))
	_loot(h5 + Vector3(2, 0, -1.2))
	var h6 := _house(Vector3(-10.5, 0, 44), 8, 8, 3.0, "z", b, {"e": [door(-1)], "n": [window(0)], "s": [window(0)]})
	_table(h6 + Vector3(-1.8, 0, 2))
	_loot(h6 + Vector3(-2.4, 0, -2))
	var h7 := _house(Vector3(10.5, 0, 44), 8, 8, 3.0, "z", a, {"w": [door(1)], "n": [window(0)], "s": [window(1)]})
	_bed(h7 + Vector3(2.4, 0, -2.4))
	_loot(h7 + Vector3(2.4, 0, 2))
	var h1 := _house(Vector3(-15, 0, -14), 9, 7, 3.0, "x", a, {"s": [door(0)], "n": [window(-2), window(2)], "w": [door(0)], "e": [window(0)]})
	_table(h1 + Vector3(2.4, 0, -1.6))
	_bed(h1 + Vector3(-2.8, 0, -2.3))
	_loot(h1 + Vector3(-2.5, 0, 1.5))
	_loot(h1 + Vector3(1.8, 0, 1.2))
	_prop_at("props/barrel", h1 + Vector3(3.6, 0, 2.6), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))

	var h2 := _house(Vector3(14, 0, -15), 10, 7, 3.0, "x", b, {"s": [door(-2)], "n": [window(0)], "e": [window(-1)], "w": [window(1)]})
	_table(h2 + Vector3(-2.5, 0, -1.7))
	_bed(h2 + Vector3(3.2, 0, -2.3))
	_loot(h2 + Vector3(3.2, 0, 1.6))
	_prop_at("props/crate_A_big", h2 + Vector3(4.1, 0, 2.5), 4.0, 0.2, Vector3(0.9, 0.85, 0.9))

	var h3 := _house(Vector3(-16, 0, 14), 8, 8, 3.0, "z", b, {"n": [door(0)], "s": [window(0)], "w": [window(-2), window(2)], "e": [window(-1)]})
	_bed(h3 + Vector3(-2.2, 0, 2.6))
	_table(h3 + Vector3(2, 0, 2))
	_loot(h3 + Vector3(2.5, 0, -2))
	_loot(h3 + Vector3(-2.5, 0, -1.5))

	var h4 := _house(Vector3(15, 0, 15), 8, 8, 3.0, "z", a, {"n": [door(1)], "s": [door(-1)], "e": [window(0)], "w": [window(1)]})
	_table(h4 + Vector3(-2, 0, -2))
	_bed(h4 + Vector3(2.2, 0, 1.6))
	_loot(h4 + Vector3(-2.5, 0, 2))

	var shed := _house(Vector3(31, 0, 11), 5, 5, 2.6, "x", {"plaster": PLANK.lightened(0.15), "roof": SHINGLE, "beams": false}, {"w": [door(0, 2.0, 2.3)]})
	_loot(shed + Vector3(1, 0, 0))
	_prop_at("props/crate_B_small", shed + Vector3(1.4, 0, 1.5), 4.0, 0.4, Vector3(0.6, 0.6, 0.6))
	_prop_at("props/resource_lumber", shed + Vector3(0.8, 0, -1.4), 2.6, 0.0, Vector3(1.9, 0.6, 0.9))

	_barn()
	_cowshed()
	_church()


func _house(c: Vector3, width: float, depth: float, h: float, ridge: String, style: Dictionary, walls: Dictionary) -> Vector3:
	_indoors.append(Rect2(c.x - width * 0.5, c.z - depth * 0.5, width, depth))
	_y = w.terrain.height(c.x, c.z)
	var l := LowPoly.new()
	var plaster: Color = style["plaster"]
	var x0 := c.x - width * 0.5
	var x1 := c.x + width * 0.5
	var z0 := c.z - depth * 0.5
	var z1 := c.z + depth * 0.5
	l.box(Vector3(c.x, 0.04, c.z), Vector3(width, 0.08, depth), FLOOR)
	var beams: bool = style.get("beams", true)
	_wall(l, Vector2(x0, z0), Vector2(x1, z0), h, walls.get("n", []), plaster, beams)
	_wall(l, Vector2(x0, z1), Vector2(x1, z1), h, walls.get("s", []), plaster, beams)
	_wall(l, Vector2(x0, z0), Vector2(x0, z1), h, walls.get("w", []), plaster, beams)
	_wall(l, Vector2(x1, z0), Vector2(x1, z1), h, walls.get("e", []), plaster, beams)
	for corner: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		l.box(Vector3(corner.x, h * 0.5, corner.y), Vector3(0.4, h, 0.4), BEAM)
	_roof(l, c, width, depth, h, 2.1, ridge, style["roof"], plaster)
	_add(l)
	# A ceiling: flyers cannot reach you through it, and nothing can be shot through it.
	collider(Vector3(c.x, h + 0.1, c.z), Vector3(width, 0.2, depth))
	w.perches.append(c + Vector3(0, _y + h + 2.25, 0))
	_y = 0.0
	return c


## An axis-aligned wall split around its openings. Offsets are measured from its centre.
func _wall(l: LowPoly, a: Vector2, b: Vector2, h: float, openings: Array, col: Color, beams: bool) -> void:
	const T := 0.3
	var along_x := absf(a.x - b.x) > absf(a.y - b.y)
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	var sorted := openings.duplicate()
	sorted.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["at"] < q["at"])
	var cursor := -length * 0.5
	var seg := func(s0: float, s1: float, y0: float, y1: float) -> void:
		if s1 - s0 < 0.01 or y1 - y0 < 0.01:
			return
		var m := (s0 + s1) * 0.5
		var centre := Vector3(mid.x + (m if along_x else 0.0), (y0 + y1) * 0.5, mid.y + (0.0 if along_x else m))
		var size := Vector3(s1 - s0, y1 - y0, T) if along_x else Vector3(T, y1 - y0, s1 - s0)
		l.box(centre, size, col)
		solid(centre, size)
		if y0 <= 0.0 and y1 > 0.6:
			var band := Vector3(size.x + (0.0 if along_x else 0.06), 0.5, size.z + (0.06 if along_x else 0.0))
			l.box(Vector3(centre.x, 0.25, centre.z), band, STONE)
	for o: Dictionary in sorted:
		var left: float = o["at"] - o["width"] * 0.5
		var right: float = o["at"] + o["width"] * 0.5
		seg.call(cursor, left, 0.0, h)
		seg.call(left, right, 0.0, o["sill"])
		seg.call(left, right, o["top"], h)
		if not o.get("bare", false):
			_frame(l, mid, along_x, left, right, o["sill"], o["top"], T)
		cursor = right
	seg.call(cursor, length * 0.5, 0.0, h)
	if beams:
		var stud := 2.0
		while stud < length - 1.0:
			var at_s := -length * 0.5 + stud
			var clear := true
			for o: Dictionary in sorted:
				if absf(at_s - float(o["at"])) < float(o["width"]) * 0.5 + 0.25:
					clear = false
			if clear:
				var p := Vector3(mid.x + (at_s if along_x else 0.0), h * 0.5, mid.y + (0.0 if along_x else at_s))
				l.box(p, Vector3(0.14, h, T + 0.08) if along_x else Vector3(T + 0.08, h, 0.14), BEAM)
			stud += 2.0
		var rail := Vector3(length, 0.12, T + 0.06) if along_x else Vector3(T + 0.06, 0.12, length)
		if sorted.is_empty():
			l.box(Vector3(mid.x, h * 0.5, mid.y), rail, BEAM)
		var top := Vector3(length + 0.2, 0.22, T + 0.1) if along_x else Vector3(T + 0.1, 0.22, length + 0.2)
		l.box(Vector3(mid.x, h - 0.05, mid.y), top, BEAM)


func _frame(l: LowPoly, mid: Vector2, along_x: bool, s0: float, s1: float, y0: float, y1: float, t: float) -> void:
	var post := func(s: float) -> void:
		var centre := Vector3(mid.x + (s if along_x else 0.0), (y0 + y1) * 0.5, mid.y + (0.0 if along_x else s))
		var size := Vector3(0.14, y1 - y0, t + 0.08) if along_x else Vector3(t + 0.08, y1 - y0, 0.14)
		l.box(centre, size, BEAM)
	post.call(s0)
	post.call(s1)
	var m := (s0 + s1) * 0.5
	var bar := Vector3(s1 - s0 + 0.14, 0.14, t + 0.08) if along_x else Vector3(t + 0.08, 0.14, s1 - s0 + 0.14)
	l.box(Vector3(mid.x + (m if along_x else 0.0), y1, mid.y + (0.0 if along_x else m)), bar, BEAM)
	if y0 > 0.0:
		l.box(Vector3(mid.x + (m if along_x else 0.0), y0, mid.y + (0.0 if along_x else m)), bar, BEAM)


func _roof(l: LowPoly, c: Vector3, width: float, depth: float, h: float, rise: float, ridge: String, col: Color, gable_col: Color) -> void:
	const OVER := 0.6
	if ridge == "x":
		var half := depth * 0.5
		var slope := sqrt(half * half + rise * rise)
		var ang := rad_to_deg(atan2(rise, half))
		var y := h + rise * 0.5 + 0.1
		l.box(Vector3(c.x, y, c.z - half * 0.5), Vector3(width + OVER * 2, 0.2, slope + OVER), col, Vector3(-ang, 0, 0))
		l.box(Vector3(c.x, y, c.z + half * 0.5), Vector3(width + OVER * 2, 0.2, slope + OVER), col, Vector3(ang, 0, 0))
		l.box(Vector3(c.x, h + rise + 0.12, c.z), Vector3(width + OVER * 2, 0.16, 0.3), col.darkened(0.3))
		for x: float in [c.x - width * 0.5, c.x + width * 0.5]:
			l.gable(Vector3(x, h, c.z - half), Vector3(x, h, c.z + half), Vector3(x, h + rise, c.z), gable_col)
	else:
		var half := width * 0.5
		var slope := sqrt(half * half + rise * rise)
		var ang := rad_to_deg(atan2(rise, half))
		var y := h + rise * 0.5 + 0.1
		l.box(Vector3(c.x - half * 0.5, y, c.z), Vector3(slope + OVER, 0.2, depth + OVER * 2), col, Vector3(0, 0, ang))
		l.box(Vector3(c.x + half * 0.5, y, c.z), Vector3(slope + OVER, 0.2, depth + OVER * 2), col, Vector3(0, 0, -ang))
		l.box(Vector3(c.x, h + rise + 0.12, c.z), Vector3(0.3, 0.16, depth + OVER * 2), col.darkened(0.3))
		for z: float in [c.z - depth * 0.5, c.z + depth * 0.5]:
			l.gable(Vector3(c.x - half, h, z), Vector3(c.x + half, h, z), Vector3(c.x, h + rise, z), gable_col)


func _barn() -> void:
	var c := Vector3(-37, 0, -32)
	var plank := {"plaster": PLANK, "roof": SHINGLE}
	_house(c, 12, 18, 4.6, "z", plank, {"n": [door(0, 4.0, 3.6)], "s": [door(0, 4.0, 3.6)], "e": [window(-5), window(5)], "w": [window(-5), window(5)]})
	for s: Vector3 in [Vector3(-3.8, 0, -5), Vector3(-3.8, 0, -3), Vector3(3.8, 0, 4), Vector3(3.8, 0, 6), Vector3(-3.8, 0, 5)]:
		_hay_bale(c + s, Vector3(2.0, 1.0, 1.4))
	_hay_bale(c + Vector3(-3.8, 1.0, -4), Vector3(2.0, 1.0, 1.4))
	_hay_bale(c + Vector3(3.8, 1.0, 5), Vector3(2.0, 1.0, 1.4))
	_loot(c + Vector3(0, 0, -6))
	_loot(c + Vector3(3, 0, -2))
	_loot(c + Vector3(-3, 0, 1))
	w.pois.append(c)
	_prop_at("props/wheelbarrow", c + Vector3(3.8, 0, -6), 4.0, 0.9, Vector3(1.3, 0.8, 1.9))


func _cowshed() -> void:
	var c := Vector3(37, 0, -32)
	_indoors.append(Rect2(c.x - 8.0, c.z - 4.0, 16.0, 8.0))
	var l := LowPoly.new()
	var x0 := c.x - 8.0
	var x1 := c.x + 8.0
	var z0 := c.z - 4.0
	var z1 := c.z + 4.0
	var h := 2.9
	l.box(Vector3(c.x, 0.03, c.z), Vector3(16, 0.06, 8), FLOOR.darkened(0.2))
	_wall(l, Vector2(x0, z0), Vector2(x1, z0), h, [], PLANK, true)
	_wall(l, Vector2(x0, z0), Vector2(x0, z1), h, [window(0)], PLANK, true)
	_wall(l, Vector2(x1, z0), Vector2(x1, z1), h, [], PLANK, true)
	for x: float in [x0, c.x - 2.7, c.x + 2.7, x1]:
		l.box(Vector3(x, h * 0.5, z1), Vector3(0.3, h, 0.3), BEAM)
		w.add_solid(Vector3(x, h * 0.5, z1), Vector3(0.3, h, 0.3))
	l.box(Vector3(c.x, h, z1), Vector3(16.3, 0.24, 0.3), BEAM)
	_roof(l, c, 16, 8, h, 1.7, "x", THATCH.darkened(0.15), PLANK)
	w.add_collider(Vector3(c.x, h + 0.1, c.z), Vector3(16, 0.2, 8))
	for x: float in [c.x - 2.7, c.x + 2.7]:
		l.box(Vector3(x, 0.55, c.z - 1.0), Vector3(0.18, 1.1, 5.4), BEAM.lightened(0.15))
		w.add_solid(Vector3(x, 0.55, c.z - 1.0), Vector3(0.18, 1.1, 5.4))
	l.box(Vector3(c.x, 0.3, z0 + 0.7), Vector3(13, 0.6, 0.8), STONE.darkened(0.15))
	w.add_solid(Vector3(c.x, 0.3, z0 + 0.7), Vector3(13, 0.6, 0.8))
	_add(l)
	_cow(Vector3(c.x - 5.3, 0, c.z - 1.0), 0.0)
	_cow(Vector3(c.x + 5.3, 0, c.z - 0.8), PI)
	_loot(c + Vector3(0, 0, 0.5))
	_hay_bale(c + Vector3(-6.4, 0, 2.8), Vector3(2.0, 1.0, 1.4))
	w.pois.append(c + Vector3(0, 0, 5))


func _church() -> void:
	var c := Vector3(0, 0, -46)
	var wall := Color(0.46, 0.45, 0.47)
	_house(c, 10, 16, 5.0, "z", {"plaster": wall, "roof": SHINGLE, "beams": false}, {
		"s": [door(0, 2.8, 3.4)],
		"e": [{"at": -4.5, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 0.0, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 4.5, "width": 1.0, "sill": 1.6, "top": 3.8}],
		"w": [{"at": -4.5, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 0.0, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 4.5, "width": 1.0, "sill": 1.6, "top": 3.8}],
	})
	var l := LowPoly.new()
	# Stained glass, which you can see through but cannot climb.
	var glass := [Color(0.72, 0.16, 0.14), Color(0.16, 0.3, 0.72), Color(0.82, 0.62, 0.14)]
	for x: float in [c.x - 5.0, c.x + 5.0]:
		var i := 0
		for z: float in [-4.5, 0.0, 4.5]:
			l.box(Vector3(x, 2.7, c.z + z), Vector3(0.05, 2.2, 0.98), glass[i], Vector3.ZERO)
			i += 1
	# Pews either side of the aisle: low enough to jump.
	var z := c.z + 5.5
	while z > c.z - 3.5:
		for x: float in [-2.6, 2.6]:
			l.box(Vector3(x, 0.45, z), Vector3(3.1, 0.9, 0.2), BEAM.lightened(0.1))
			l.box(Vector3(x, 0.32, z - 0.28), Vector3(3.1, 0.1, 0.45), BEAM.lightened(0.2))
			w.add_solid(Vector3(x, 0.45, z - 0.1), Vector3(3.1, 0.9, 0.65))
		z -= 2.2
	# Altar.
	l.box(Vector3(0, 0.55, c.z - 6.2), Vector3(3.0, 1.1, 1.1), Color(0.6, 0.58, 0.55))
	l.box(Vector3(0, 1.11, c.z - 6.2), Vector3(3.2, 0.06, 1.3), Color(0.55, 0.12, 0.14))
	l.box(Vector3(0, 1.6, c.z - 6.2), Vector3(0.12, 1.0, 0.12), WeaponDefs.BRASS)
	l.box(Vector3(0, 1.75, c.z - 6.2), Vector3(0.55, 0.12, 0.12), WeaponDefs.BRASS)
	w.add_solid(Vector3(0, 0.55, c.z - 6.2), Vector3(3.0, 1.1, 1.1))
	_add(l)
	w.add_glow(Vector3(-1.2, 1.4, c.z - 6.2), Color(1.0, 0.7, 0.3), 0.9)
	w.add_glow(Vector3(1.2, 1.4, c.z - 6.2), Color(1.0, 0.7, 0.3), 0.9)
	_loot(c + Vector3(0, 0, -4.6))
	_loot(c + Vector3(0, 0, 2))
	w.pois.append(Vector3(0, 0, -36))
	# Bell tower at the north end.
	var t := Vector3(0, 0, -56.5)
	var tw := LowPoly.new()
	tw.box(t + Vector3(0, 4.25, 0), Vector3(5, 8.5, 5), wall.darkened(0.06))
	tw.box(t + Vector3(0, 8.6, 0), Vector3(5.5, 0.25, 5.5), wall.darkened(0.25))
	for sx: float in [-2.2, 2.2]:
		for sz: float in [-2.2, 2.2]:
			tw.box(t + Vector3(sx, 10.0, sz), Vector3(0.6, 2.8, 0.6), wall)
	tw.box(t + Vector3(0, 11.5, 0), Vector3(5.5, 0.3, 5.5), wall.darkened(0.25))
	tw.box(t + Vector3(0, 11.0, 0), Vector3(4.2, 0.18, 0.18), BEAM)
	var a := t + Vector3(0, 11.65, 0)
	tw.gable(a + Vector3(-2.8, 0, -2.8), a + Vector3(2.8, 0, -2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	tw.gable(a + Vector3(2.8, 0, -2.8), a + Vector3(2.8, 0, 2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	tw.gable(a + Vector3(2.8, 0, 2.8), a + Vector3(-2.8, 0, 2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	tw.gable(a + Vector3(-2.8, 0, 2.8), a + Vector3(-2.8, 0, -2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	# The tower ignores fog, so it stays a landmark you can navigate by.
	var tower := _add(tw)
	var clear := (LowPoly.material().duplicate() as StandardMaterial3D)
	clear.disable_fog = true
	tower.material_override = clear
	w.add_solid(t + Vector3(0, 4.25, 0), Vector3(5, 8.5, 5))
	w.add_glow(t + Vector3(0, 10.0, 2.4), Color(1.0, 0.72, 0.35), 3.0)
	var bell_mesh := LowPoly.new()
	bell_mesh.prism(Vector3(0, -0.2, 0), Vector3(0, -1.0, 0), 0.32, 0.72, 10, WeaponDefs.BRASS)
	bell_mesh.prism(Vector3(0, -0.02, 0), Vector3(0, -0.2, 0), 0.08, 0.32, 10, WeaponDefs.BRASS)
	bell_mesh.prism(Vector3(0, -1.0, 0), Vector3(0, -1.12, 0), 0.72, 0.76, 10, WeaponDefs.BRASS.lightened(0.15))
	var bell := MeshInstance3D.new()
	bell.mesh = bell_mesh.commit()
	bell.position = t + Vector3(0, 11.0, 0)
	w.add_child(bell)
	w.bell = bell
	w.perches.append(t + Vector3(0, 11.8, 2.8))


func _cow(at: Vector3, rot: float) -> void:
	var l := LowPoly.new()
	var white := Color(0.78, 0.76, 0.7)
	var dark := Color(0.16, 0.14, 0.13)
	l.box(Vector3(0, 0.95, 0), Vector3(0.75, 0.7, 1.7), white)
	l.box(Vector3(0.2, 1.05, 0.3), Vector3(0.4, 0.52, 0.7), dark)
	l.box(Vector3(0, 1.25, 1.05), Vector3(0.48, 0.48, 0.6), white)
	l.box(Vector3(0, 1.12, 1.38), Vector3(0.36, 0.22, 0.14), Color(0.75, 0.55, 0.5))
	for s: Vector2 in [Vector2(-0.25, 0.65), Vector2(0.25, 0.65), Vector2(-0.25, -0.65), Vector2(0.25, -0.65)]:
		l.box(Vector3(s.x, 0.32, s.y), Vector3(0.16, 0.64, 0.16), dark)
	var mi := _add(l)
	mi.position = at
	mi.rotation.y = rot
	w.add_solid(at + Vector3(0, 0.8, 0), Vector3(0.9, 1.6, 2.9) if is_zero_approx(rot) or is_equal_approx(rot, PI) else Vector3(2.9, 1.6, 0.9))


func _table(at: Vector3) -> void:
	at = on_ground(at)
	var l := _cell(at)
	l.box(at + Vector3(0, 0.78, 0), Vector3(1.8, 0.1, 1.0), BEAM.lightened(0.15))
	for s: Vector2 in [Vector2(-0.75, -0.38), Vector2(0.75, -0.38), Vector2(-0.75, 0.38), Vector2(0.75, 0.38)]:
		l.box(at + Vector3(s.x, 0.37, s.y), Vector3(0.1, 0.74, 0.1), BEAM)
	w.add_solid(at + Vector3(0, 0.42, 0), Vector3(1.8, 0.84, 1.0))


func _bed(at: Vector3) -> void:
	at = on_ground(at)
	var l := _cell(at)
	l.box(at + Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 2.0), BEAM)
	l.box(at + Vector3(0, 0.55, 0), Vector3(1.1, 0.16, 1.9), Color(0.55, 0.5, 0.42))
	l.box(at + Vector3(0, 0.66, -0.7), Vector3(0.9, 0.12, 0.4), Color(0.75, 0.72, 0.62))
	w.add_solid(at + Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 2.0))


func _hay_bale(at: Vector3, size: Vector3) -> void:
	at = on_ground(at)
	var l := _cell(at)
	l.box(at + Vector3(0, size.y * 0.5, 0), size, HAY)
	l.box(at + Vector3(0, size.y * 0.5, 0), Vector3(size.x * 0.12, size.y + 0.02, size.z + 0.02), HAY.darkened(0.35))
	w.add_solid(at + Vector3(0, size.y * 0.5, 0), size)


func _loot(at: Vector3) -> void:
	w.loot_spots.append(on_ground(at))


# --- Village square ----------------------------------------------------------

func _square() -> void:
	w.pois.append(Vector3(0, 0, 8))
	# Well.
	var l := LowPoly.new()
	l.prism(Vector3(0, 0, -1), Vector3(0, 0.95, -1), 1.05, 1.05, 8, STONE)
	l.prism(Vector3(0, 0.95, -1), Vector3(0, 1.0, -1), 0.75, 0.75, 8, Color(0.04, 0.06, 0.09))
	for x: float in [-0.95, 0.95]:
		l.box(Vector3(x, 1.5, -1), Vector3(0.16, 1.5, 0.16), BEAM)
	l.box(Vector3(0, 2.2, -1), Vector3(2.0, 0.12, 0.12), BEAM)
	l.box(Vector3(-0.0, 2.4, -1.45), Vector3(2.4, 0.1, 1.2), THATCH, Vector3(-28, 0, 0))
	l.box(Vector3(-0.0, 2.4, -0.55), Vector3(2.4, 0.1, 1.2), THATCH, Vector3(28, 0, 0))
	_add(l)
	w.add_solid(Vector3(0, 0.5, -1), Vector3(2.1, 1.0, 2.1))
	_bonfire(Vector3(9.5, 0, -6.5))
	_stall(Vector3(-5.5, 0, 6.5), Color(0.55, 0.14, 0.12))
	_stall(Vector3(6, 0, 5.5), Color(0.14, 0.26, 0.5))
	_prop_at("props/barrel", Vector3(-7.4, 0, 4.0), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	_prop_at("props/barrel", Vector3(-6.4, 0, 3.5), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	_prop_at("props/crate_long_A", Vector3(7.8, 0, 3.2), 3.6, 0.5, Vector3(1.5, 0.6, 1.5))
	_lantern(Vector3(-4.5, 0, -8.5))
	_lantern(Vector3(4.5, 0, -9))
	_lantern(Vector3(-4.5, 0, 9))
	_lantern(Vector3(5, 0, 9))
	_lantern(Vector3(3.2, 0, -35.5))
	if Game.quality > 0:
		_lantern(Vector3(-29, 0, -22))
		_lantern(Vector3(29, 0, -26))


## A fire to warm yourself at. Everything out there can see you by it.
func bonfire(at: Vector3) -> void:
	_bonfire(at)


func _bonfire(at: Vector3) -> void:
	at = on_ground(at)
	var l := _cell(at)
	for i in 8:
		var a := TAU * i / 8.0
		l.prism(at + Vector3(cos(a) * 1.0, 0.0, sin(a) * 1.0), at + Vector3(cos(a) * 1.0, 0.24, sin(a) * 1.0), 0.24, 0.17, 5, Color(0.34, 0.33, 0.33).lightened(0.05 * (i % 3)))
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		l.prism(at + Vector3(cos(a) * 0.72, 0.1, sin(a) * 0.72), at + Vector3(cos(a) * 0.08, 0.62, sin(a) * 0.08), 0.1, 0.07, 5, Color(0.17, 0.11, 0.07))
	w.add_solid(at + Vector3.UP * 0.5, Vector3(1.9, 1.0, 1.9))
	w.add_glow(at + Vector3.UP * 1.0, Color(1.0, 0.6, 0.22), 4.5, 95.0)
	_flame(at + Vector3.UP * 0.1, 1.0)
	var light: OmniLight3D = null
	if Game.quality > 0:
		light = OmniLight3D.new()
		light.position = at + Vector3.UP * 1.5
		light.light_color = Color(1.0, 0.62, 0.28)
		light.light_energy = 2.5
		light.omni_range = 8.0
		light.omni_attenuation = 1.3
		w.add_child(light)
	w.add_fire(at, WorldLight.BONFIRE_REACH, light, true)


## A burning torch on a pole. Only High quality gives a torch its own light.
func torch(at: Vector3) -> void:
	at = on_ground(at)
	var l := _cell(at)
	l.prism(at, at + Vector3.UP * 2.3, 0.07, 0.05, 5, Village.BEAM)
	l.prism(at + Vector3.UP * 2.22, at + Vector3.UP * 2.42, 0.1, 0.13, 6, Color(0.14, 0.11, 0.09))
	w.add_solid(at + Vector3.UP, Vector3(0.22, 2.0, 0.22))
	w.add_glow(at + Vector3.UP * 2.6, Color(1.0, 0.64, 0.26), 2.0, 85.0)
	_flame(at + Vector3.UP * 2.38, 0.38)
	var light: OmniLight3D = null
	if Game.quality == 2:
		light = OmniLight3D.new()
		light.position = at + Vector3.UP * 2.6
		light.light_color = Color(1.0, 0.66, 0.32)
		light.light_energy = 2.5
		light.omni_range = 5.0
		light.omni_attenuation = 1.4
		w.add_child(light)
	w.add_fire(at, WorldLight.TORCH_REACH, light)


func _flame(at: Vector3, size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = WorldLight.flame_mesh()
	mi.position = at
	mi.scale = Vector3.ONE * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 90.0
	w.add_child(mi)


func _stall(at: Vector3, cloth: Color) -> void:
	at = on_ground(at)
	var l := _cell(at)
	for s: Vector2 in [Vector2(-1.5, -0.9), Vector2(1.5, -0.9), Vector2(-1.5, 0.9), Vector2(1.5, 0.9)]:
		l.box(at + Vector3(s.x, 1.15, s.y), Vector3(0.12, 2.3, 0.12), BEAM)
	l.box(at + Vector3(0, 2.4, 0), Vector3(3.5, 0.08, 2.3), cloth, Vector3(10, 0, 0))
	l.box(at + Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 1.2), BEAM.lightened(0.2))
	w.add_solid(at + Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 1.2))
	_loot(at + Vector3(0, 0, 1.9))


func _lantern(at: Vector3) -> void:
	at = on_ground(at)
	var l := _cell(at)
	l.box(at + Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14), BEAM)
	l.box(at + Vector3(0.28, 2.7, 0), Vector3(0.65, 0.09, 0.09), BEAM)
	l.box(at + Vector3(0.52, 2.46, 0), Vector3(0.22, 0.32, 0.22), Color(1.0, 0.72, 0.28))
	w.add_solid(at + Vector3(0, 1.2, 0), Vector3(0.25, 2.4, 0.25))
	var flame_at := at + Vector3(0.52, 2.46, 0)
	w.add_glow(flame_at, Color(1.0, 0.68, 0.3), 2.2)
	if Game.quality == 0:
		w.add_fire(at, WorldLight.LANTERN_REACH)
	if Game.quality > 0:
		var light := OmniLight3D.new()
		light.position = flame_at
		light.light_color = Color(1.0, 0.7, 0.38)
		light.light_energy = 2.0
		light.omni_range = 6.5
		light.omni_attenuation = 1.4
		w.add_child(light)
		w.add_lantern_light(light)
		w.add_fire(at, WorldLight.LANTERN_REACH)


# --- Fields ------------------------------------------------------------------

func _fields() -> void:
	_field(Rect2(-50, 22, 30, 28), "wheat", {"n": [Vector2(-34, -30)], "e": [Vector2(34, 38)]})
	_field(Rect2(20, 26, 30, 24), "corn", {"n": [Vector2(30, 34)], "w": [Vector2(40, 44)]})
	_field(Rect2(-54, -10, 18, 20), "barley", {"e": [Vector2(-1, 1)], "s": [Vector2(-48, -44)]})
	_field(Rect2(22, -16, 28, 18), "garden", {"s": [Vector2(34, 38)], "w": [Vector2(-10, -6)]})
	_scarecrow(Vector3(-35, 0, 36))
	_scarecrow(Vector3(35, 0, 38))
	_scarecrow(Vector3(-45, 0, 0))
	_hay_bale(Vector3(-16, 0, 34), Vector3(2.0, 1.0, 1.4))
	_hay_bale(Vector3(14, 0, 30), Vector3(1.4, 1.0, 2.0))
	_hay_bale(Vector3(18, 0, 28), Vector3(2.0, 1.0, 1.4))
	_hay_bale(Vector3(-20, 0, 2.5), Vector3(2.0, 1.0, 1.4))


## gaps: wall name -> list of (from, to) along that wall, in world coordinates.
func field(r: Rect2, kind: String, gaps: Dictionary) -> void:
	_field(r, kind, gaps)


func _field(r: Rect2, kind: String, gaps: Dictionary) -> void:
	_y = w.terrain.height(r.get_center().x, r.get_center().y)
	var soil := LowPoly.new()
	soil.box(Vector3(r.get_center().x, 0.03, r.get_center().y), Vector3(r.size.x, 0.06, r.size.y), Color(0.22, 0.17, 0.1))
	_furrows(soil, r, 2.4 if kind == "garden" else 1.1)
	_add(soil).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var f := LowPoly.new()
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	_fence(f, Vector2(x0, z0), Vector2(x1, z0), gaps.get("n", []))
	_fence(f, Vector2(x0, z1), Vector2(x1, z1), gaps.get("s", []))
	_fence(f, Vector2(x0, z0), Vector2(x0, z1), gaps.get("w", []))
	_fence(f, Vector2(x1, z0), Vector2(x1, z1), gaps.get("e", []))
	_add(f)
	match kind:
		"wheat", "barley":
			_grain(r, kind == "barley")
		"corn":
			_corn(r)
		"garden":
			_garden(r)
	if kind != "garden":
		w.grid.mark_crops(x0 + 0.5, z0 + 0.5, x1 - 0.5, z1 - 0.5)
		for i in 3:
			w.crop_spots.append(on_ground(Vector3(_land.randf_range(x0 + 3, x1 - 3), 0, _land.randf_range(z0 + 3, z1 - 3))))
	_y = 0.0


## Ploughed ridges, so the soil reads as a field and not as a brown square.
func _furrows(l: LowPoly, r: Rect2, every: float) -> void:
	var z := r.position.y + 0.7
	while z < r.end.y - 0.3:
		l.box(Vector3(r.get_center().x, 0.09, z), Vector3(r.size.x - 0.6, 0.14, every * 0.42), Color(0.17, 0.125, 0.075))
		z += every


func _fence(l: LowPoly, a: Vector2, b: Vector2, gaps: Array) -> void:
	var along_x := absf(a.x - b.x) > absf(a.y - b.y)
	var from := a.x if along_x else a.y
	var to := b.x if along_x else b.y
	var other := a.y if along_x else a.x
	var spans: Array[Vector2] = []
	var cursor := from
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	for g: Vector2 in sorted:
		spans.append(Vector2(cursor, g.x))
		cursor = g.y
	spans.append(Vector2(cursor, to))
	for s: Vector2 in spans:
		var length := s.y - s.x
		if length < 0.2:
			continue
		var m := (s.x + s.y) * 0.5
		var centre := Vector3(m, 0, other) if along_x else Vector3(other, 0, m)
		for rail_y: float in [0.5, 0.88]:
			l.box(centre + Vector3.UP * rail_y, Vector3(length, 0.09, 0.05) if along_x else Vector3(0.05, 0.09, length), BEAM.lightened(0.28))
		var n := int(length / 2.0)
		for i in n + 1:
			var p := s.x + length * i / maxf(1.0, n)
			var post := Vector3(p, 0.5, other) if along_x else Vector3(other, 0.5, p)
			l.box(post, Vector3(0.12, 1.0, 0.12), BEAM.lightened(0.15))
		solid(centre + Vector3.UP * 0.5, Vector3(length, 1.0, 0.14) if along_x else Vector3(0.14, 1.0, length))


## Rows of different vegetables. They hide nothing, but they are a pleasure to walk through.
func _garden(r: Rect2) -> void:
	var kinds: Array[Mesh] = [Crops.cabbage(), Crops.turnip(), Crops.beans(), Crops.pumpkin()]
	var groups := {}
	var row := 0
	var z := r.position.y + 1.6
	while z < r.end.y - 1.0:
		var pick: int = [0, 1, 2, 0, 3, 1, 2, 3][row % 8]
		var x := r.position.x + 1.3
		while x < r.end.x - 1.0:
			var at := on_ground(Vector3(x + rng.randf_range(-0.12, 0.12), 0.13, z + rng.randf_range(-0.14, 0.14)))
			var key := Vector3i(pick, int(floor(at.x / 16.0)), int(floor(at.z / 16.0)))
			if not groups.has(key):
				groups[key] = [[], PackedColorArray()]
			var s := rng.randf_range(0.8, 1.2)
			(groups[key][0] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), at))
			groups[key][1] = (groups[key][1] as PackedColorArray) + PackedColorArray([Color(rng.randf_range(0.85, 1.1), rng.randf_range(0.9, 1.1), rng.randf_range(0.85, 1.0))])
			x += [1.1, 0.7, 1.0, 1.9][pick] * rng.randf_range(0.9, 1.15)
		z += 2.4
		row += 1
	for key: Vector3i in groups:
		var list: Array[Transform3D] = []
		list.assign(groups[key][0])
		var node := Crops.plant(kinds[key.x], list, groups[key][1], key.x != 2)
		node.visibility_range_end = 60.0
		w.add_child(node)


## Tall grain hides you. Barley is paler and greener. Chunks let the camera skip what it cannot see.
func _grain(r: Rect2, barley: bool) -> void:
	var spacing: float = [1.1, 0.82, 0.66][Game.quality]
	var colour := FastNoiseLite.new()
	colour.seed = int(r.position.x * 3.0 + r.position.y)
	colour.frequency = 0.09
	var ripe := Color(1.0, 0.98, 0.92)
	var green := Color(0.78, 0.92, 0.72)
	if barley:
		ripe = Color(0.92, 0.94, 0.76)
		green = Color(0.66, 0.86, 0.6)
	var chunks := {}
	var x := r.position.x + 0.6
	while x < r.end.x - 0.4:
		var z := r.position.y + 0.6
		while z < r.end.y - 0.4:
			var p := on_ground(Vector3(x + rng.randf_range(-0.25, 0.25), 0.06, z + rng.randf_range(-0.25, 0.25)))
			var k := Vector2i(int(floor(p.x / 10.0)), int(floor(p.z / 10.0)))
			if not chunks.has(k):
				chunks[k] = [[], PackedColorArray()]
			var s := rng.randf_range(0.85, 1.2) * (0.86 if barley else 1.0)
			var yaw := rng.randf() * TAU
			(chunks[k][0] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), p))
			var tone := ripe.lerp(green, clampf(colour.get_noise_2d(p.x, p.z) * 1.6 + 0.3, 0.0, 1.0)) * rng.randf_range(0.86, 1.08)
			chunks[k][1] = (chunks[k][1] as PackedColorArray) + PackedColorArray([tone])
			z += spacing
		x += spacing
	for k: Vector2i in chunks:
		var list: Array[Transform3D] = []
		list.assign(chunks[k][0])
		var node := Crops.plant(Crops.wheat(), list, chunks[k][1])
		node.visibility_range_end = 58.0
		w.add_child(node)


## Corn stands in rows, taller than you are.
func _corn(r: Rect2) -> void:
	var along: float = [1.2, 1.0, 0.8][Game.quality]
	var chunks := {}
	var x := r.position.x + 0.8
	while x < r.end.x - 0.5:
		var z := r.position.y + 0.7
		while z < r.end.y - 0.4:
			var p := on_ground(Vector3(x + rng.randf_range(-0.08, 0.08), 0.06, z + rng.randf_range(-0.2, 0.2)))
			var k := Vector2i(int(floor(p.x / 12.0)), int(floor(p.z / 12.0)))
			if not chunks.has(k):
				chunks[k] = [[], PackedColorArray()]
			var s := rng.randf_range(0.85, 1.15)
			(chunks[k][0] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.1), s)), p))
			var tone := Color(rng.randf_range(0.82, 1.1), rng.randf_range(0.9, 1.1), rng.randf_range(0.7, 1.0))
			chunks[k][1] = (chunks[k][1] as PackedColorArray) + PackedColorArray([tone])
			z += along
		x += 1.5
	for k: Vector2i in chunks:
		var list: Array[Transform3D] = []
		list.assign(chunks[k][0])
		var node := Crops.plant(Crops.corn(), list, chunks[k][1], true)
		node.visibility_range_end = 62.0
		w.add_child(node)


func _scarecrow(at: Vector3) -> void:
	at = on_ground(at)
	var l := _cell(at)
	l.box(at + Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), BEAM)
	l.box(at + Vector3(0, 1.45, 0), Vector3(1.5, 0.1, 0.1), BEAM)
	l.box(at + Vector3(0, 1.25, 0), Vector3(0.6, 0.65, 0.3), Color(0.32, 0.22, 0.25))
	l.box(at + Vector3(0, 1.8, 0), Vector3(0.34, 0.34, 0.34), HAY)
	l.prism(at + Vector3(0, 1.97, 0), at + Vector3(0, 2.35, 0), 0.38, 0.0, 6, Color(0.14, 0.1, 0.08))
	w.add_solid(at + Vector3(0, 0.9, 0), Vector3(0.2, 1.8, 0.2))


# --- Props and nature --------------------------------------------------------

func _prop_at(file: String, at: Vector3, scale: float, rot: float, solid_size: Vector3) -> void:
	at = on_ground(at)
	var path := "res://assets/%s.gltf" % file
	if not _props.has(path):
		_props[path] = []
	(_props[path] as Array).append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scale), at))
	if solid_size != Vector3.ZERO:
		w.add_solid(at + Vector3.UP * solid_size.y * 0.5, solid_size)


func _scatter_props() -> void:
	_prop_at("props/resource_lumber", Vector3(23, 0, 2.8), 3.0, 0.1, Vector3(2.2, 0.7, 1.1))
	_prop_at("props/resource_lumber", Vector3(-24, 0, -3), 3.0, 1.57, Vector3(1.1, 0.7, 2.2))
	_prop_at("props/crate_A_big", Vector3(-27, 0, -21), 4.0, 0.3, Vector3(0.9, 0.85, 0.9))
	_prop_at("props/crate_B_small", Vector3(-26, 0, -20), 4.0, 0.9, Vector3(0.6, 0.6, 0.6))
	_prop_at("props/barrel", Vector3(25, 0, -21), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	_prop_at("props/barrel", Vector3(26, 0, -21.5), 4.2, 0.0, Vector3(0.85, 0.9, 0.85))
	_prop_at("props/sack", Vector3(27, 0, -24), 5.0, 0.4, Vector3.ZERO)
	_prop_at("props/bucket_water", Vector3(1.8, 0, 1), 3.5, 0.0, Vector3.ZERO)
	_prop_at("props/wheelbarrow", Vector3(8, 0, 22), 4.0, 2.2, Vector3(1.3, 0.8, 1.3))
	_prop_at("props/target", Vector3(-12, 0, -44), 5.0, 0.0, Vector3(1.2, 1.5, 0.5))
	_prop_at("props/weaponrack", Vector3(-14.5, 0, -42), 5.0, 0.0, Vector3(1.0, 1.2, 0.7))
	_loot(Vector3(-13, 0, -40.5))
	_loot(Vector3(-14, 0, 34))
	_loot(Vector3(0, 0, 45))
	_loot(Vector3(46, 0, 14))
	_loot(Vector3(-39, 0, -46))
	w.pois.append(Vector3(0, 0, 34))
	w.pois.append(Vector3(-20, 0, -40))
	w.pois.append(Vector3(42, 0, 10))
	w.pois.append(Vector3(-30, 0, 16))


func _flush_props() -> void:
	for path: String in _props:
		var list: Array[Transform3D] = []
		list.assign(_props[path])
		w.add_child(Models.scatter(Models.merged(path), list))
	for key: String in _trees:
		var parts := key.split("|")
		var list: Array[Transform3D] = []
		list.assign(_trees[key])
		w.add_child(Models.scatter(Models.merged(parts[0]), list))


func _tree(at: Vector3, is_solid: bool) -> void:
	at = on_ground(at)
	var path := "res://assets/nature/tree_single_A.gltf" if rng.randf() < 0.72 else "res://assets/nature/tree_single_B.gltf"
	var key := "%s|%d|%d" % [path, int(floor(at.x / 40.0)), int(floor(at.z / 40.0))]
	if not _trees.has(key):
		_trees[key] = []
	var s := rng.randf_range(5.5, 8.5)
	(_trees[key] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), at))
	if is_solid:
		w.add_solid(at + Vector3.UP, Vector3(0.7, 2.0, 0.7))


func indoors() -> Array[Rect2]:
	return _indoors


func _is_indoors(p: Vector3) -> bool:
	for r in _indoors:
		if r.grow(1.0).has_point(Vector2(p.x, p.z)):
			return true
	return false


## Somewhere a tree or a rock can stand: clear ground, not on a road or a field.
func _clear_spot(p: Vector3) -> bool:
	var h := World.HALF_SIZE
	if absf(p.x) > h - 1.5 or absf(p.z) > h - 1.5 or _is_indoors(p) or w.grid.in_crops(p):
		return false
	var cell := w.grid.to_cell(p)
	if not (w.grid.is_free(cell) and w.grid.is_free(cell + Vector2i(1, 0)) and w.grid.is_free(cell + Vector2i(0, 1))):
		return false
	return not _near_road(p, 3.4)


func _near_road(p: Vector3, reach: float) -> bool:
	var at := Vector2(p.x, p.z)
	for road: Array in _roads_now:
		for i in road.size() - 1:
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			var t := clampf((at - a).dot(b - a) / maxf((b - a).length_squared(), 0.01), 0.0, 1.0)
			if at.distance_to(a.lerp(b, t)) < reach:
				return true
	return false


func _trees_and_rocks() -> void:
	var h := World.HALF_SIZE
	# Copses, on the land's own random numbers, because they are solid and every player must agree.
	var copses: Array = _copses if not _copses.is_empty() else [Vector3(-52, 0, -52), Vector3(-44, 0, 15), Vector3(50, 0, 13), Vector3(-5, 0, 50), Vector3(52, 0, -50), Vector3(-8, 0, -26), Vector3(-30, 0, 8), Vector3(22, 0, 20),
		Vector3(20, 0, -55), Vector3(5, 0, -72), Vector3(-25, 0, -82), Vector3(85, 0, -35), Vector3(95, 0, -55), Vector3(100, 0, -95), Vector3(70, 0, -95),
		Vector3(-100, 0, -20), Vector3(-85, 0, 40), Vector3(-65, 0, 40), Vector3(-95, 0, 85), Vector3(-75, 0, 100), Vector3(-30, 0, 72), Vector3(50, 0, 72),
		Vector3(70, 0, 66), Vector3(95, 0, 70), Vector3(45, 0, 105), Vector3(10, 0, 106), Vector3(-45, 0, 108), Vector3(100, 0, 30), Vector3(60, 0, 25)]
	for c: Vector3 in copses:
		for i in _land.randi_range(6, 10):
			var p: Vector3 = c + Vector3(_land.randf_range(-8, 8), 0, _land.randf_range(-8, 8))
			var keep := _land.randf() > 0.15
			if keep and _clear_spot(p) and absf(p.x) > 3.2 and absf(p.z) > 3.2 and w.terrain.slope(p.x, p.z) < 0.5:
				_tree(p, true)
	var rock_budget := 46
	for i in 400:
		if rock_budget <= 0:
			break
		var p := Vector3(_land.randf_range(-h + 3, h - 3), 0, _land.randf_range(-h + 3, h - 3))
		if w.fort and w.fort.inside(p * 0.86):
			continue
		var s := _land.randf_range(3.0, 7.0)
		var r := _land.randf() * TAU
		if not _clear_spot(p) or absf(p.x) < 6.0 or absf(p.z) < 6.0:
			continue
		rock_budget -= 1
		_prop_at("nature/rock_single_C", p, s, r, Vector3(1.2, 0.7, 1.2))
	# Forest wall outside the playable edge. It needs no collision, so it may depend on quality.
	var step: float = [7.5, 5.5, 4.2][Game.quality]
	var depth: int = [2, 2, 3][Game.quality]
	for row in depth:
		var off := h + 1.5 + row * 3.4
		var t := -off
		while t <= off:
			_tree(Vector3(t + rng.randf_range(-1, 1), 0, -off + rng.randf_range(-1, 1)), false)
			_tree(Vector3(t + rng.randf_range(-1, 1), 0, off + rng.randf_range(-1, 1)), false)
			_tree(Vector3(-off + rng.randf_range(-1, 1), 0, t + rng.randf_range(-1, 1)), false)
			_tree(Vector3(off + rng.randf_range(-1, 1), 0, t + rng.randf_range(-1, 1)), false)
			t += step
	# Grass tufts, in patches so the camera can skip those it cannot see.
	var patches := {}
	var tuft := _grass_tuft()
	for i in Game.grass_count() * 3:
		var p := Vector3(rng.randf_range(-h, h), 0, rng.randf_range(-h, h))
		if not w.grid.is_free(w.grid.to_cell(p)) or (absf(p.x) < 9.0 and absf(p.z) < 9.0) or _is_indoors(p):
			continue
		p = on_ground(p)
		var key := Vector2i(int(floor(p.x / 24.0)), int(floor(p.z / 24.0)))
		if not patches.has(key):
			patches[key] = [[], PackedColorArray()]
		var s := rng.randf_range(1.0, 1.9)
		(patches[key][0] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		patches[key][1] = (patches[key][1] as PackedColorArray) + PackedColorArray([Color.WHITE.darkened(rng.randf() * 0.2)])
	for key: Vector2i in patches:
		var list: Array[Transform3D] = []
		list.assign(patches[key][0])
		var node := Crops.plant(tuft, list, patches[key][1])
		node.visibility_range_end = 46.0
		w.add_child(node)


func _grass_tuft() -> Mesh:
	var l := LowPoly.new()
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var off := Vector3(cos(a), 0, sin(a)) * 0.08
		var side := Vector3(-sin(a), 0, cos(a)) * 0.055
		var tip := off * 3.0 + Vector3.UP * (0.36 + 0.09 * (i % 3))
		l.gable(off - side, off + side, tip, GRASS.lerp(GRASS_TIP, 0.45 * (i % 3)))
	return l.commit()
