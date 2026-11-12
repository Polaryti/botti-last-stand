@tool
class_name MapBuilder
extends RefCounted
## Turns a map scene into a world: meshes, collision and pathing. Each piece on the map calls one of
## the builders below while xf says where that piece stands, and shapes are given relative to it.
## The same code draws the preview in the Godot editor, so what you see there is what you get.

const THATCH := Color(0.52, 0.42, 0.22)
const SHINGLE := Color(0.27, 0.2, 0.2)
const PLASTER := Color(0.68, 0.62, 0.5)
const PLASTER_B := Color(0.6, 0.55, 0.47)
const PLANK := Color(0.42, 0.2, 0.13)
const BEAM := Color(0.2, 0.13, 0.08)
const STONE := Color(0.4, 0.4, 0.42)
const CASTLE_STONE := Color(0.43, 0.43, 0.45)
const CASTLE_DARK := Color(0.32, 0.32, 0.35)
const FLOOR := Color(0.3, 0.22, 0.15)
const HAY := Color(0.72, 0.6, 0.26)
const DIRT := Color(0.27, 0.2, 0.13)
const ROAD_PIXELS_PER_METRE := 2
const ROAD_REACH := 3.0 # metres either side of a road's edge that the ground's road mask can tell apart
const GRASS := Color(0.27, 0.44, 0.19)
const GRASS_TIP := Color(0.42, 0.56, 0.24)
const BRASS := Color(0.78, 0.6, 0.24)
const FORT_PLANK := Color(0.42, 0.28, 0.16)

var look := "village" # which lands: "mesenlla" has rock on its steep slopes
var w # the World in the game, a MapPreview in the editor
var terrain: Terrain
var quality := 1 # 0 low, 1 medium, 2 high
var grass_tufts := 350 # how much grass the whole map gets
var is_preview := false
var _ground_patches: Array[MeshInstance3D] = []
var _ground_material: ShaderMaterial
var _road_lines: Array[Dictionary] = []
var _dirt_patches: Array[Dictionary] = []
var skip_beyond := false # the menu only needs the village
var xf := Transform3D.IDENTITY # where the piece being built stands
var piece_scale := 1.0
var rng := RandomNumberGenerator.new() # for looks only: phones may disagree about these
var _props := {}
var _trees := {}
var _indoors: Array[Rect2] = []
var _plant_clearings: Array[Vector3] = []
var _plant_rooms: Array[Dictionary] = []
var _cells := {} # small things, merged by map area into one mesh each
static var _cow_mesh: Mesh


func _init(world: Variant, p_terrain: Terrain) -> void:
	w = world
	terrain = p_terrain
	rng.seed = 1337


## The whole map, for the game.
func build(root: MapRoot) -> void:
	look = root.look
	_reserve_plants(root, Transform3D.IDENTITY)
	ground()
	w.play_half = root.play_half
	boundary(root.play_half)
	_walk(root, Transform3D.IDENTITY)
	if root.forest_wall:
		forest_wall(root.play_half)
	grass(root.play_half)
	_paint_roads()
	_warm_ground()
	flush()
	w.indoors = _indoors


func _walk(node: Node, parent: Transform3D) -> void:
	for c: Node in node.get_children():
		if not c is Node3D or (skip_beyond and c.name == &"Beyond"):
			continue
		var at := parent * (c as Node3D).transform
		if c is MapPiece and (c as MapPiece).on_ground:
			at.origin.y = terrain.height(at.origin.x, at.origin.z) + (c as MapPiece).lift
		if c.has_method("build"):
			stand_at(at)
			c.call("build", self)
		_walk(c, at)


func stand_at(at: Transform3D) -> void:
	piece_scale = at.basis.get_scale().x
	xf = Transform3D(at.basis.orthonormalized(), at.origin)


## A generator that gives the same numbers for the same place, on every phone, whatever the map's order.
func seeded() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(xf.origin.x * 73.0) ^ int(xf.origin.z * 179.0) ^ 4242
	return r


func world_point(local: Vector3) -> Vector3:
	return xf * local


## A point on the land, under a spot given relative to this piece.
func on_ground(local: Vector3) -> Vector3:
	var p := xf * local
	p.y = terrain.height(p.x, p.z) + local.y
	return p


func solid(at: Vector3, size: Vector3) -> void:
	w.add_solid_xf(xf.translated_local(at), size)


func collider(at: Vector3, size: Vector3) -> void:
	w.add_collider_xf(xf.translated_local(at), size)


## A window's opening: stops bodies and blades, not sight or shots.
func window_gap(at: Vector3, size: Vector3) -> void:
	w.add_window_xf(xf.translated_local(at), size)


func mesh() -> LowPoly:
	var l := LowPoly.new()
	l.base = xf
	return l


func add(l: LowPoly) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	w.add_child(mi)
	return mi


## Small things share one mesh per 24 m square, which saves a draw call for each of them.
func cell() -> LowPoly:
	var key := Vector2i(int(floor(xf.origin.x / 24.0)), int(floor(xf.origin.z / 24.0)))
	if not _cells.has(key):
		_cells[key] = LowPoly.new()
	var l: LowPoly = _cells[key]
	l.base = xf
	return l


func flush() -> void:
	for path: String in _props:
		var list: Array[Transform3D] = []
		list.assign(_props[path])
		w.add_child(Models.scatter(Models.merged(path), list))
	_props.clear()
	for key: String in _trees:
		var list: Array[Transform3D] = []
		list.assign(_trees[key])
		w.add_child(Models.scatter(Models.merged(key.get_slice("|", 0)), list))
	_trees.clear()
	for key: Vector2i in _cells:
		(_cells[key] as LowPoly).base = Transform3D.IDENTITY
		add(_cells[key])
	_cells.clear()


func no_fog() -> StandardMaterial3D:
	var clear := LowPoly.material().duplicate() as StandardMaterial3D
	clear.disable_fog = true
	return clear


# --- The land ------------------------------------------------------------------

## Patches instead of one big plane: a light only costs shading time on objects it touches, so
## a lantern costs the few patches around it rather than all the ground on screen.
func ground() -> void:
	const CELLS := 12
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground.gdshader")
	mat.set_shader_parameter("tile", load("res://assets/sprites/ground_tile.png"))
	mat.set_shader_parameter("dirt", Vector3(DIRT.r, DIRT.g, DIRT.b))
	mat.set_shader_parameter("map_half", float(terrain.half_extent))
	mat.set_shader_parameter("mask_reach", ROAD_REACH)
	mat.set_shader_parameter("cliffs", 1.0 if terrain.has_islands() or look in SpawnRules.MESENLLA else 0.0)
	if look in SpawnRules.MESENLLA:
		# Mountain meadow in the twilight: cooler grass, and dark heather-coloured earth.
		mat.set_shader_parameter("tint", Vector3(0.9, 1.0, 1.06))
		mat.set_shader_parameter("dirt", Vector3(0.24, 0.19, 0.17))
	_ground_material = mat
	var j := 0
	while j < terrain.vertices_per_side - 1:
		var i := 0
		while i < terrain.vertices_per_side - 1:
			_ground_mesh(terrain.patch_mesh(i, j, CELLS), mat)
			i += CELLS
		j += CELLS
	if not terrain.has_islands():
		for sector in 4:
			_ground_mesh(terrain.skirt_mesh(sector), mat)


func _ground_mesh(m: Mesh, mat: Material) -> void:
	var g := MeshInstance3D.new()
	g.mesh = m
	g.material_override = mat
	if not is_preview: g.layers = 4
	_ground_patches.append(g)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(g)


func boundary(h: float) -> void:
	var t := 2.0
	w.add_collider(Vector3(0, 15, -h - t * 0.5), Vector3(h * 2 + 4, 70, t))
	w.add_collider(Vector3(0, 15, h + t * 0.5), Vector3(h * 2 + 4, 70, t))
	w.add_collider(Vector3(-h - t * 0.5, 15, 0), Vector3(t, 70, h * 2 + 4))
	w.add_collider(Vector3(h + t * 0.5, 15, 0), Vector3(t, 70, h * 2 + 4))
	# Cliffs and deep water.
	for r in terrain.blocked_rects():
		var c := Vector2(r.position) + Vector2(r.size) * 0.5 - Vector2.ONE * terrain.half_extent
		var y := terrain.height(c.x, c.y)
		if terrain.has_islands():
			# You can walk off the edge. Mobs know better.
			w.add_enemy_block(Vector3(c.x, 0.0, c.y), Vector3(r.size.x, 120.0, r.size.y))
		else:
			if terrain.height(c.x, c.y) < Terrain.WATER_Y - Terrain.WADE:
				w.add_barrier(Vector3(c.x, y, c.y), Vector3(r.size.x, 60.0, r.size.y))
			else:
				w.add_enemy_block(Vector3(c.x, y, c.y), Vector3(r.size.x, 60.0, r.size.y))
	# Everything outside a smaller map is closed to pathing too.
	if h < terrain.half_extent - 0.5:
		var far := float(terrain.half_extent)
		var band := far - h
		for box: Array in [[Vector3(0, 0, -(h + band * 0.5)), Vector3(far * 2, 4, band)], [Vector3(0, 0, h + band * 0.5), Vector3(far * 2, 4, band)],
				[Vector3(-(h + band * 0.5), 0, 0), Vector3(band, 4, far * 2)], [Vector3(h + band * 0.5, 0, 0), Vector3(band, 4, far * 2)]]:
			w.grid.block_box(box[0], box[1])


## In a game a road is painted on the ground itself, so it cannot float over the land or swallow feet.
func road(points: Array[Vector2], width: float) -> void:
	if is_preview:
		_road_strip(points, width)
	else:
		_road_lines.append({"points": points, "half": width * 0.5})


## The ground's shader reads how far each spot is from the nearest road's edge. With that, even a
## coarse picture gives a clean edge, and a 220 m map needs only half a metre per pixel.
func _paint_roads() -> void:
	if _road_lines.is_empty() and _dirt_patches.is_empty():
		return
	var side := terrain.half_extent * ROAD_PIXELS_PER_METRE * 2
	var far := 255
	var mask := PackedByteArray()
	mask.resize(side * side)
	mask.fill(far)
	for line: Dictionary in _road_lines:
		var points: Array[Vector2] = line["points"]
		var half: float = line["half"]
		var reach: float = half + ROAD_REACH
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var ab := b - a
			var ab_len2 := maxf(ab.length_squared(), 0.001)
			var x0 := clampi(int((minf(a.x, b.x) - reach + terrain.half_extent) * ROAD_PIXELS_PER_METRE), 1, side - 2)
			var x1 := clampi(int((maxf(a.x, b.x) + reach + terrain.half_extent) * ROAD_PIXELS_PER_METRE) + 1, 1, side - 2)
			var z0 := clampi(int((minf(a.y, b.y) - reach + terrain.half_extent) * ROAD_PIXELS_PER_METRE), 1, side - 2)
			var z1 := clampi(int((maxf(a.y, b.y) + reach + terrain.half_extent) * ROAD_PIXELS_PER_METRE) + 1, 1, side - 2)
			for z in range(z0, z1 + 1):
				var wz := (z + 0.5) / ROAD_PIXELS_PER_METRE - terrain.half_extent
				for x in range(x0, x1 + 1):
					var wx := (x + 0.5) / ROAD_PIXELS_PER_METRE - terrain.half_extent
					var t := clampf(((wx - a.x) * ab.x + (wz - a.y) * ab.y) / ab_len2, 0.0, 1.0)
					var edge := Vector2(wx - a.x - ab.x * t, wz - a.y - ab.y * t).length() - half
					if edge >= ROAD_REACH:
						continue
					var value := int((edge / ROAD_REACH * 0.5 + 0.5) * 255.0)
					if value < mask[z * side + x] and not terrain.over_water_on_deck(wx, wz):
						mask[z * side + x] = value
	# Bare patches, like the village square: boxes with rounded corners, so they melt into the paths.
	for patch_of_dirt: Dictionary in _dirt_patches:
		var at: Transform3D = patch_of_dirt["at"]
		var half_size: Vector2 = patch_of_dirt["half"]
		var inverse := at.affine_inverse()
		var round_off := minf(3.0, minf(half_size.x, half_size.y))
		var far_corner := half_size.length() + ROAD_REACH
		var mid := Vector2(at.origin.x, at.origin.z)
		var x0 := clampi(int((mid.x - far_corner + terrain.half_extent) * ROAD_PIXELS_PER_METRE), 1, side - 2)
		var x1 := clampi(int((mid.x + far_corner + terrain.half_extent) * ROAD_PIXELS_PER_METRE) + 1, 1, side - 2)
		var z0 := clampi(int((mid.y - far_corner + terrain.half_extent) * ROAD_PIXELS_PER_METRE), 1, side - 2)
		var z1 := clampi(int((mid.y + far_corner + terrain.half_extent) * ROAD_PIXELS_PER_METRE) + 1, 1, side - 2)
		for z in range(z0, z1 + 1):
			var wz := (z + 0.5) / ROAD_PIXELS_PER_METRE - terrain.half_extent
			for x in range(x0, x1 + 1):
				var wx := (x + 0.5) / ROAD_PIXELS_PER_METRE - terrain.half_extent
				var local := inverse * Vector3(wx, at.origin.y, wz)
				var q := Vector2(absf(local.x), absf(local.z)) - half_size + Vector2.ONE * round_off
				var edge := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - round_off
				if edge >= ROAD_REACH:
					continue
				var value := clampi(int((edge / ROAD_REACH * 0.5 + 0.5) * 255.0), 0, 255)
				if value < mask[z * side + x]:
					mask[z * side + x] = value
	var image := Image.create_from_data(side, side, false, Image.FORMAT_L8, mask)
	_ground_material.set_shader_parameter("roads", ImageTexture.create_from_image(image))


## A strip that follows the land, for the map editor. It is cut every 24 m or so, for the same reason as the ground patches.
func _road_strip(points: Array[Vector2], width: float) -> void:
	const STEP := 1.6
	const ACROSS := 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row: Array[Vector3] = []
	var since := 0.0
	var used := false
	var t := terrain
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
	var m := st.commit()
	m.surface_set_material(0, LowPoly.material())
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)


func river() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = terrain.water_mesh()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/water.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	w.set_water(m)
	_reeds()


## A stone bridge with a parapet, or a timber one on trestles. Nothing else crosses the water.
## Runs along the piece's own Z axis.
func bridge(length: float, stone_built: bool) -> void:
	var a := xf * Vector3(0, 0, -length * 0.5)
	var e := xf * Vector3(0, 0, length * 0.5)
	var deck_col := Color(0.42, 0.41, 0.4) if stone_built else Color(0.4, 0.28, 0.17)
	var rail_col := Color(0.36, 0.36, 0.37) if stone_built else BEAM.lightened(0.1)
	const STEP := 1.2
	var l := LowPoly.new()
	var yaw := atan2(e.x - a.x, e.z - a.z)
	var s := 0.0
	var i := 0
	var t := terrain
	var along := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	var from := Vector3(a.x, 0, a.z)
	while s < length:
		var s1 := minf(s + STEP, length)
		var p0 := from + along * s
		var p1 := from + along * s1
		var y0 := t.height(p0.x, p0.z)
		var y1 := t.height(p1.x, p1.z)
		var mid := (p0 + p1) * 0.5
		var pitch := rad_to_deg(atan2(y1 - y0, s1 - s))
		var turn := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -deg_to_rad(pitch))
		var tone := deck_col.lightened(0.05 * (i % 3))
		l.turned_box(Vector3(mid.x, (y0 + y1) * 0.5 - 0.14, mid.z), Vector3(5.8, 0.4, s1 - s + 0.1), tone, turn)
		for f: float in [-2.75, 2.75]:
			var edge := mid + side * f
			if stone_built:
				l.turned_box(Vector3(edge.x, (y0 + y1) * 0.5 + 0.48, edge.z), Vector3(0.35, 1.0, s1 - s + 0.06), rail_col.lightened(0.04 * (i % 2)), turn)
			elif i % 2 == 0:
				l.turned_box(Vector3(edge.x, (y0 + y1) * 0.5 + 0.55, edge.z), Vector3(0.18, 1.2, 0.18), BEAM, turn)
			if not stone_built:
				l.turned_box(Vector3(edge.x, (y0 + y1) * 0.5 + 1.05, edge.z), Vector3(0.1, 0.1, s1 - s + 0.06), rail_col, turn)
		s = s1
		i += 1
	# What holds it up.
	var flat := Basis(Vector3.UP, yaw)
	for f: float in [0.34, 0.5, 0.66]:
		var p := from + along * length * f
		var top := t.height(p.x, p.z) - 0.3
		if stone_built:
			if absf(f - 0.5) > 0.01:
				l.turned_box(Vector3(p.x, (top + Terrain.BED_Y) * 0.5, p.z), Vector3(6.0, top - Terrain.BED_Y, 1.6), deck_col.darkened(0.15), flat)
		else:
			for g: float in [-2.2, 2.2]:
				var q := p + side * g
				l.turned_box(Vector3(q.x, (top + Terrain.BED_Y) * 0.5, q.z), Vector3(0.3, top - Terrain.BED_Y, 0.3), BEAM, flat)
	var mi := MeshInstance3D.new()
	mi.mesh = l.commit()
	w.add_child(mi)
	# Nothing walks off the side.
	var centre := (from + from + along * length) * 0.5
	var y := t.height(centre.x, centre.z)
	for f: float in [-4.5, 4.5]:
		var c := centre + side * f
		w.add_barrier_xf(Transform3D(flat, Vector3(c.x, y, c.z)), Vector3(3.2, 60.0, length))


## Stepping stones in the shallows.
func ford(size: Vector2) -> void:
	var l := mesh()
	var r := seeded()
	var z := -size.y * 0.5
	while z < size.y * 0.5:
		for k in 2:
			var x := r.randf_range(-size.x * 0.5 + 0.5, size.x * 0.5 - 0.5)
			var p := xf * Vector3(x, 0, z)
			var y := terrain.ground_height(p.x, p.z) - xf.origin.y
			if y + xf.origin.y < 0.0:
				var s := r.randf_range(0.5, 1.1)
				l.prism(Vector3(x, y - 0.1, z), Vector3(x, y + 0.22, z), s, s * 0.6, 6, Color(0.44, 0.43, 0.42).lightened(r.randf() * 0.1))
		z += 1.7
	add(l).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Reeds on the banks, where the land meets the water.
func _reeds() -> void:
	var l := LowPoly.new()
	for i in 5:
		var a := TAU * i / 5.0
		var off := Vector3(cos(a), 0, sin(a)) * 0.1
		var side := Vector3(-sin(a), 0, cos(a)) * 0.04
		l.gable(off - side, off + side, off * 2.2 + Vector3.UP * (0.95 + 0.2 * (i % 2)), Color(0.3, 0.38, 0.17))
	var reed := l.commit()
	var chunks := {}
	var t := terrain
	var line := t.river
	for i in grass_tufts:
		var seg := rng.randi_range(0, line.size() - 2)
		var p := line[seg].lerp(line[seg + 1], rng.randf())
		var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(t.river_width + 0.2, t.river_width + 1.8)
		p += off
		if absf(p.x) > terrain.half_extent or absf(p.y) > terrain.half_extent or t.on_deck(p.x, p.y):
			continue
		var y := t.ground_height(p.x, p.y)
		if y < Terrain.WATER_Y - 0.3 or y > 0.5:
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
		var node := Crops.plant(reed, list, chunks[key][1])
		node.visibility_range_end = 50.0
		w.add_child(node)


# --- Buildings -----------------------------------------------------------------

func door(at: float, width := 2.2, top := 2.5) -> Dictionary:
	return {"at": at, "width": width, "sill": 0.0, "top": top}


func window(at: float) -> Dictionary:
	return {"at": at, "width": 1.1, "sill": 1.15, "top": 2.0}


## A building with four walls and a roof, centred on the piece.
func house(width: float, depth: float, h: float, ridge: String, style: Dictionary, walls: Dictionary, rise := 2.1) -> void:
	_indoors.append(_flat_rect(width, depth))
	var l := mesh()
	var plaster: Color = style["plaster"]
	var x0 := -width * 0.5
	var x1 := width * 0.5
	var z0 := -depth * 0.5
	var z1 := depth * 0.5
	l.box(Vector3(0, 0.04, 0), Vector3(width, 0.08, depth), FLOOR)
	var beams: bool = style.get("beams", true)
	wall(l, Vector2(x0, z0), Vector2(x1, z0), h, walls.get("n", []), plaster, beams)
	wall(l, Vector2(x0, z1), Vector2(x1, z1), h, walls.get("s", []), plaster, beams)
	wall(l, Vector2(x0, z0), Vector2(x0, z1), h, walls.get("w", []), plaster, beams)
	wall(l, Vector2(x1, z0), Vector2(x1, z1), h, walls.get("e", []), plaster, beams)
	for corner: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		l.box(Vector3(corner.x, h * 0.5, corner.y), Vector3(0.4, h, 0.4), BEAM)
	_roof(l, width, depth, h, rise, ridge, style["roof"], plaster)
	_dress(l, width, depth, h, walls, plaster.is_equal_approx(PLASTER) or plaster.is_equal_approx(PLASTER_B))
	add(l)
	# A ceiling: flyers cannot reach you through it, and nothing can be shot through it.
	collider(Vector3(0, h + 0.1, 0), Vector3(width, 0.2, depth))
	w.perches.append(xf * Vector3(0, h + 2.25, 0))


const RUGS := [Color(0.42, 0.14, 0.12), Color(0.18, 0.24, 0.4), Color(0.48, 0.36, 0.14), Color(0.22, 0.3, 0.18)]
const CROCKERY := [Color(0.62, 0.36, 0.22), Color(0.72, 0.68, 0.58), Color(0.32, 0.36, 0.42), Color(0.5, 0.42, 0.3)]


## Rooms that look lived in: shelves of crockery against bare stretches of wall, and in homes a
## woven rug and tie beams overhead with herbs drying on them. Nothing collides: the rug is flat,
## the shelves stand 28 cm from the wall and the beams hang above head height, so the furniture
## placed in the room and the way through it stay exactly as they were.
func _dress(l: LowPoly, width: float, depth: float, h: float, walls: Dictionary, home: bool) -> void:
	if width < 4.0 or depth < 4.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(xf.origin.x * 10.0), roundi(xf.origin.z * 10.0), roundi(width * 10.0 + depth)))
	_shelves(l, width, depth, h, walls, rng)
	# Barns, sheds and stone halls keep their bare floors; homes get a rug and drying herbs.
	if not home:
		return
	# A rug, with a border, just above the floor.
	var rug: Color = RUGS[rng.randi() % RUGS.size()]
	var rug_size := Vector2(minf(width * 0.45, 3.6), minf(depth * 0.4, 2.6))
	l.box(Vector3(0, 0.086, 0), Vector3(rug_size.x, 0.012, rug_size.y), rug)
	l.box(Vector3(0, 0.094, 0), Vector3(rug_size.x - 0.36, 0.012, rug_size.y - 0.36), rug.lightened(0.18))
	l.box(Vector3(0, 0.1, 0), Vector3(rug_size.x - 0.9, 0.012, rug_size.y - 0.9), rug)
	# Tie beams across the room, with bundles of herbs hanging from them.
	if h >= 2.8:
		var across_x := width <= depth
		var span_len := width if across_x else depth
		var run := depth if across_x else width
		var count := maxi(1, int(run / 3.2))
		for i in count:
			var at := -run * 0.5 + run * (i + 1) / (count + 1)
			var beam_at := Vector3(0, h - 0.32, at) if across_x else Vector3(at, h - 0.32, 0)
			l.box(beam_at, Vector3(span_len, 0.18, 0.18) if across_x else Vector3(0.18, 0.18, span_len), BEAM)
			for j in 3:
				if rng.randf() < 0.5:
					continue
				var off := rng.randf_range(-span_len * 0.35, span_len * 0.35)
				var hang := beam_at + (Vector3(off, -0.09, 0) if across_x else Vector3(0, -0.09, off))
				var green := Color(0.3, 0.38, 0.18).lerp(Color(0.5, 0.42, 0.22), rng.randf())
				l.prism(hang, hang + Vector3.DOWN * rng.randf_range(0.3, 0.45), 0.02, 0.09, 5, green)


## Shelves of crockery on the two longest bare stretches of wall, from shoulder height up.
func _shelves(l: LowPoly, width: float, depth: float, h: float, walls: Dictionary, rng: RandomNumberGenerator) -> void:
	# Shelves on the two longest bare stretches of wall.
	var spans: Array = []
	for side: String in ["n", "s", "w", "e"]:
		var along_x := side == "n" or side == "s"
		var length := width if along_x else depth
		var span := _longest_gap(length, walls.get(side, []))
		if span.y - span.x >= 1.6:
			spans.append([side, span])
	spans.sort_custom(func(p: Array, q: Array) -> bool: return (p[1] as Vector2).y - (p[1] as Vector2).x > (q[1] as Vector2).y - (q[1] as Vector2).x)
	for k in mini(2, spans.size()):
		var side: String = spans[k][0]
		var span: Vector2 = spans[k][1]
		var length := minf(span.y - span.x - 0.3, 2.2)
		var centre := (span.x + span.y) * 0.5
		var inward := 0.15 + 0.14
		var pos := Vector3.ZERO
		var along := Vector3.ZERO
		match side:
			"n": pos = Vector3(centre, 0, -depth * 0.5 + inward); along = Vector3.RIGHT
			"s": pos = Vector3(centre, 0, depth * 0.5 - inward); along = Vector3.RIGHT
			"w": pos = Vector3(-width * 0.5 + inward, 0, centre); along = Vector3.BACK
			"e": pos = Vector3(width * 0.5 - inward, 0, centre); along = Vector3.BACK
		var deep := Vector3(0.28, 0.05, 0.28) - along * 0.28 + along * length
		for shelf_y: float in ([1.62, 2.12] if h >= 2.9 else [1.62]):
			l.box(pos + Vector3.UP * shelf_y, deep, BEAM.lightened(0.12))
			for end: float in [-0.5, 0.5]:
				l.box(pos + along * (end * (length - 0.2)) + Vector3.UP * (shelf_y - 0.12), Vector3(0.05, 0.2, 0.05) + (Vector3(0.0, 0.0, 0.18) if along == Vector3.RIGHT else Vector3(0.18, 0.0, 0.0)), BEAM)
			# Jars, jugs and bowls along it.
			var x := -length * 0.5 + 0.2
			while x < length * 0.5 - 0.15:
				var col: Color = CROCKERY[rng.randi() % CROCKERY.size()]
				var tall := rng.randf_range(0.12, 0.3)
				var wide := rng.randf_range(0.06, 0.11)
				var base := pos + along * x + Vector3.UP * (shelf_y + 0.025)
				l.prism(base, base + Vector3.UP * tall, wide, wide * rng.randf_range(0.55, 0.95), 6, col)
				x += wide * 2.0 + rng.randf_range(0.12, 0.32)


## The longest stretch of a wall with no door or window in it, measured from its centre, kept a
## little clear of the corners and of every opening.
static func _longest_gap(length: float, openings: Array) -> Vector2:
	var cuts: Array = []
	for o: Dictionary in openings:
		cuts.append(Vector2(float(o["at"]) - float(o["width"]) * 0.5 - 0.35, float(o["at"]) + float(o["width"]) * 0.5 + 0.35))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var best := Vector2.ZERO
	var cursor := -length * 0.5 + 0.55
	for c: Vector2 in cuts:
		if c.x - cursor > best.y - best.x:
			best = Vector2(cursor, c.x)
		cursor = maxf(cursor, c.y)
	if length * 0.5 - 0.55 - cursor > best.y - best.x:
		best = Vector2(cursor, length * 0.5 - 0.55)
	return best


## The space a building takes on the map, for the map screen and for keeping grass out.
func _flat_rect(width: float, depth: float) -> Rect2:
	var corners := [Vector3(-width, 0, -depth), Vector3(width, 0, -depth), Vector3(-width, 0, depth), Vector3(width, 0, depth)]
	var r := Rect2(Vector2(xf.origin.x, xf.origin.z), Vector2.ZERO)
	for c: Vector3 in corners:
		var p := xf * (c * 0.5)
		r = r.expand(Vector2(p.x, p.z))
	return r


## An axis-aligned wall split around its openings. Offsets are measured from its centre.
func wall(l: LowPoly, a: Vector2, b: Vector2, h: float, openings: Array, col: Color, beams: bool, t := 0.3) -> void:
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
		var size := Vector3(s1 - s0, y1 - y0, t) if along_x else Vector3(t, y1 - y0, s1 - s0)
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
		if float(o["sill"]) > 0.0 and not o.get("bare", false):
			# A window is looked and shot through, never climbed through or jumped at. (A bare gap
			# in a ruined wall stays open.)
			var m := (left + right) * 0.5
			var gap := Vector3(mid.x + (m if along_x else 0.0), (float(o["sill"]) + float(o["top"])) * 0.5, mid.y + (0.0 if along_x else m))
			window_gap(gap, Vector3(right - left, float(o["top"]) - float(o["sill"]), t) if along_x else Vector3(t, float(o["top"]) - float(o["sill"]), right - left))
		if not o.get("bare", false):
			_frame(l, mid, along_x, left, right, o["sill"], o["top"], t)
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
				l.box(p, Vector3(0.14, h, t + 0.08) if along_x else Vector3(t + 0.08, h, 0.14), BEAM)
			stud += 2.0
		var rail := Vector3(length, 0.12, t + 0.06) if along_x else Vector3(t + 0.06, 0.12, length)
		if sorted.is_empty():
			l.box(Vector3(mid.x, h * 0.5, mid.y), rail, BEAM)
		var top := Vector3(length + 0.2, 0.22, t + 0.1) if along_x else Vector3(t + 0.1, 0.22, length + 0.2)
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


func _roof(l: LowPoly, width: float, depth: float, h: float, rise: float, ridge: String, col: Color, gable_col: Color) -> void:
	const OVER := 0.6
	if ridge == "x":
		var half := depth * 0.5
		var slope := sqrt(half * half + rise * rise)
		var ang := rad_to_deg(atan2(rise, half))
		var y := h + rise * 0.5 + 0.1
		l.box(Vector3(0, y, -half * 0.5), Vector3(width + OVER * 2, 0.2, slope + OVER), col, Vector3(-ang, 0, 0))
		l.box(Vector3(0, y, half * 0.5), Vector3(width + OVER * 2, 0.2, slope + OVER), col, Vector3(ang, 0, 0))
		l.box(Vector3(0, h + rise + 0.12, 0), Vector3(width + OVER * 2, 0.16, 0.3), col.darkened(0.3))
		for x: float in [-width * 0.5, width * 0.5]:
			l.gable(Vector3(x, h, -half), Vector3(x, h, half), Vector3(x, h + rise, 0), gable_col)
	else:
		var half := width * 0.5
		var slope := sqrt(half * half + rise * rise)
		var ang := rad_to_deg(atan2(rise, half))
		var y := h + rise * 0.5 + 0.1
		l.box(Vector3(-half * 0.5, y, 0), Vector3(slope + OVER, 0.2, depth + OVER * 2), col, Vector3(0, 0, ang))
		l.box(Vector3(half * 0.5, y, 0), Vector3(slope + OVER, 0.2, depth + OVER * 2), col, Vector3(0, 0, -ang))
		l.box(Vector3(0, h + rise + 0.12, 0), Vector3(0.3, 0.16, depth + OVER * 2), col.darkened(0.3))
		for z: float in [-depth * 0.5, depth * 0.5]:
			l.gable(Vector3(-half, h, z), Vector3(half, h, z), Vector3(0, h + rise, z), gable_col)


## A cattle shed, open along its south side.
func cowshed() -> void:
	_indoors.append(_flat_rect(16.0, 8.0))
	var l := mesh()
	var x0 := -8.0
	var x1 := 8.0
	var z0 := -4.0
	var z1 := 4.0
	var h := 2.9
	l.box(Vector3(0, 0.03, 0), Vector3(16, 0.06, 8), FLOOR.darkened(0.2))
	wall(l, Vector2(x0, z0), Vector2(x1, z0), h, [], PLANK, true)
	wall(l, Vector2(x0, z0), Vector2(x0, z1), h, [window(0)], PLANK, true)
	wall(l, Vector2(x1, z0), Vector2(x1, z1), h, [], PLANK, true)
	for x: float in [x0, -2.7, 2.7, x1]:
		l.box(Vector3(x, h * 0.5, z1), Vector3(0.3, h, 0.3), BEAM)
		solid(Vector3(x, h * 0.5, z1), Vector3(0.3, h, 0.3))
	l.box(Vector3(0, h, z1), Vector3(16.3, 0.24, 0.3), BEAM)
	_roof(l, 16, 8, h, 1.7, "x", THATCH.darkened(0.15), PLANK)
	collider(Vector3(0, h + 0.1, 0), Vector3(16, 0.2, 8))
	for x: float in [-2.7, 2.7]:
		l.box(Vector3(x, 0.55, -1.0), Vector3(0.18, 1.1, 5.4), BEAM.lightened(0.15))
		solid(Vector3(x, 0.55, -1.0), Vector3(0.18, 1.1, 5.4))
	l.box(Vector3(0, 0.3, z0 + 0.7), Vector3(13, 0.6, 0.8), STONE.darkened(0.15))
	solid(Vector3(0, 0.3, z0 + 0.7), Vector3(13, 0.6, 0.8))
	add(l)
	var here := xf
	stand_at(here.translated_local(Vector3(-5.3, 0, -1.0)))
	cow()
	stand_at(here * Transform3D(Basis(Vector3.UP, PI), Vector3(5.3, 0, -0.8)))
	cow()
	stand_at(here)
	w.pois.append(xf * Vector3(0, 0, 5))


## The church and its tower, with the bell. The door faces the piece's +Z.
func church() -> void:
	var wall_col := Color(0.46, 0.45, 0.47)
	house(10, 16, 5.0, "z", {"plaster": wall_col, "roof": SHINGLE, "beams": false}, {
		"s": [door(0, 2.8, 3.4)],
		"e": [{"at": -4.5, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 0.0, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 4.5, "width": 1.0, "sill": 1.6, "top": 3.8}],
		"w": [{"at": -4.5, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 0.0, "width": 1.0, "sill": 1.6, "top": 3.8}, {"at": 4.5, "width": 1.0, "sill": 1.6, "top": 3.8}],
	})
	var l := mesh()
	# Stained glass, which you can see through but cannot climb.
	var glass := [Color(0.72, 0.16, 0.14), Color(0.16, 0.3, 0.72), Color(0.82, 0.62, 0.14)]
	for x: float in [-5.0, 5.0]:
		var i := 0
		for z: float in [-4.5, 0.0, 4.5]:
			l.box(Vector3(x, 2.7, z), Vector3(0.05, 2.2, 0.98), glass[i], Vector3.ZERO)
			i += 1
	# Pews either side of the aisle: low enough to jump.
	var z := 5.5
	while z > -3.5:
		for x: float in [-2.6, 2.6]:
			l.box(Vector3(x, 0.45, z), Vector3(3.1, 0.9, 0.2), BEAM.lightened(0.1))
			l.box(Vector3(x, 0.32, z - 0.28), Vector3(3.1, 0.1, 0.45), BEAM.lightened(0.2))
			solid(Vector3(x, 0.45, z - 0.1), Vector3(3.1, 0.9, 0.65))
		z -= 2.2
	# Altar.
	l.box(Vector3(0, 0.55, -6.2), Vector3(3.0, 1.1, 1.1), Color(0.6, 0.58, 0.55))
	l.box(Vector3(0, 1.11, -6.2), Vector3(3.2, 0.06, 1.3), Color(0.55, 0.12, 0.14))
	l.box(Vector3(0, 1.6, -6.2), Vector3(0.12, 1.0, 0.12), BRASS)
	l.box(Vector3(0, 1.75, -6.2), Vector3(0.55, 0.12, 0.12), BRASS)
	solid(Vector3(0, 0.55, -6.2), Vector3(3.0, 1.1, 1.1))
	add(l)
	w.add_glow(xf * Vector3(-1.2, 1.4, -6.2), Color(1.0, 0.7, 0.3), 0.9)
	w.add_glow(xf * Vector3(1.2, 1.4, -6.2), Color(1.0, 0.7, 0.3), 0.9)
	w.church_door = xf * Vector3(0, 0, 10)
	w.pois.append(w.church_door)
	# Bell tower at the far end.
	var t := Vector3(0, 0, -10.5)
	var tw := mesh()
	tw.box(t + Vector3(0, 4.25, 0), Vector3(5, 8.5, 5), wall_col.darkened(0.06))
	tw.box(t + Vector3(0, 8.6, 0), Vector3(5.5, 0.25, 5.5), wall_col.darkened(0.25))
	for sx: float in [-2.2, 2.2]:
		for sz: float in [-2.2, 2.2]:
			tw.box(t + Vector3(sx, 10.0, sz), Vector3(0.6, 2.8, 0.6), wall_col)
	tw.box(t + Vector3(0, 11.5, 0), Vector3(5.5, 0.3, 5.5), wall_col.darkened(0.25))
	tw.box(t + Vector3(0, 11.0, 0), Vector3(4.2, 0.18, 0.18), BEAM)
	var a := t + Vector3(0, 11.65, 0)
	tw.gable(a + Vector3(-2.8, 0, -2.8), a + Vector3(2.8, 0, -2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	tw.gable(a + Vector3(2.8, 0, -2.8), a + Vector3(2.8, 0, 2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	tw.gable(a + Vector3(2.8, 0, 2.8), a + Vector3(-2.8, 0, 2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	tw.gable(a + Vector3(-2.8, 0, 2.8), a + Vector3(-2.8, 0, -2.8), a + Vector3(0, 4.2, 0), SHINGLE)
	# The tower ignores fog, so it stays a landmark you can navigate by.
	add(tw).material_override = no_fog()
	solid(t + Vector3(0, 4.25, 0), Vector3(5, 8.5, 5))
	w.add_glow(xf * (t + Vector3(0, 10.0, 2.4)), Color(1.0, 0.72, 0.35), 3.0)
	var bell_mesh := LowPoly.new()
	bell_mesh.prism(Vector3(0, -0.2, 0), Vector3(0, -1.0, 0), 0.32, 0.72, 10, BRASS)
	bell_mesh.prism(Vector3(0, -0.02, 0), Vector3(0, -0.2, 0), 0.08, 0.32, 10, BRASS)
	bell_mesh.prism(Vector3(0, -1.0, 0), Vector3(0, -1.12, 0), 0.72, 0.76, 10, BRASS.lightened(0.15))
	var bell := MeshInstance3D.new()
	bell.mesh = bell_mesh.commit()
	bell.transform = xf.translated_local(t + Vector3(0, 11.0, 0))
	w.add_child(bell)
	w.bell = bell
	w.perches.append(xf * (t + Vector3(0, 11.8, 2.8)))


## A round tower with a crown of merlons.
func tower(radius: float, h: float, block: bool) -> void:
	var l := mesh()
	l.prism(Vector3.ZERO, Vector3.UP * h, radius, radius * 0.92, 8, CASTLE_STONE.darkened(0.04))
	l.prism(Vector3.UP * h, Vector3.UP * (h + 0.5), radius * 1.14, radius * 1.14, 8, CASTLE_DARK)
	for i in 8:
		var a := TAU * i / 8.0
		l.box(Vector3(cos(a) * radius, h + 0.85, sin(a) * radius), Vector3(0.72, 0.7, 0.72), CASTLE_DARK.lightened(0.04))
	# Stands clear of the fog: you can find it from anywhere.
	add(l).material_override = no_fog()
	if block:
		solid(Vector3.UP * h * 0.5, Vector3(radius * 1.6, h, radius * 1.6))
		w.perches.append(xf * (Vector3.UP * (h + 0.6)))


## A long stone or plank wall with holes in it, running along the piece's X axis.
func long_wall(length: float, h: float, col: Color, openings: Array, merlons: bool, beams: bool, thick: float) -> void:
	var l := mesh()
	wall(l, Vector2(-length * 0.5, 0), Vector2(length * 0.5, 0), h, openings, col, beams, thick)
	if merlons:
		var s := -length * 0.5 + 1.0
		while s < length * 0.5:
			var clear := true
			for g: Dictionary in openings:
				if float(g.get("sill", 0.0)) + float(g["top"]) >= h - 0.01 and absf(s - float(g["at"])) < float(g["width"]) * 0.5 + 0.5:
					clear = false
			if clear:
				l.box(Vector3(s, h + 0.34, 0), Vector3(1.0, 0.68, 0.42), CASTLE_DARK.lightened(0.05))
			s += 2.0
	add(l).material_override = no_fog()


func windmill() -> void:
	var l := mesh()
	l.prism(Vector3.ZERO, Vector3.UP * 8.5, 3.5, 2.2, 10, Color(0.56, 0.52, 0.44))
	l.prism(Vector3.UP * 8.5, Vector3.UP * 10.8, 2.5, 0.2, 10, Color(0.26, 0.2, 0.17))
	l.box(Vector3(0, 1.2, 3.4), Vector3(1.4, 2.4, 0.3), Color(0.2, 0.13, 0.08))
	l.box(Vector3(0, 4.5, 2.95), Vector3(0.7, 1.0, 0.2), Color(1.0, 0.76, 0.34))
	add(l).material_override = no_fog()
	var hull := LowPoly.new()
	hull.prism(Vector3.ZERO, Vector3.UP * 8.5, 3.5, 2.2, 10, Color.WHITE)
	var body := StaticBody3D.new()
	body.transform = xf
	var shape := CollisionShape3D.new()
	shape.shape = hull.commit().create_convex_shape()
	body.add_child(shape)
	w.add_child(body)
	w.grid.block_box(xf.origin, Vector3(6.5, 8.5, 6.5))
	var sails := LowPoly.new()
	sails.prism(Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), 0.2, 0.2, 6, Color(0.2, 0.14, 0.1))
	for i in 4:
		var turn := Basis(Vector3.BACK, TAU * i / 4.0)
		sails.box(turn * Vector3(0, 3.1, 0.3), Vector3(0.16, 6.2, 0.1), Color(0.3, 0.21, 0.13), Vector3(0, 0, -rad_to_deg(TAU * i / 4.0)))
		sails.box(turn * Vector3(0.48, 3.6, 0.3), Vector3(0.8, 4.8, 0.04), Color(0.72, 0.68, 0.58), Vector3(0, 0, -rad_to_deg(TAU * i / 4.0)))
	var node := MeshInstance3D.new()
	node.mesh = sails.commit()
	node.material_override = no_fog()
	node.transform = xf.translated_local(Vector3(0, 8.0, 3.2))
	w.add_child(node)
	w.add_spinner(node, Vector3.BACK, 0.55)


## The wheel, its frame and the race. Stand it where the mill meets the water, with +Z toward the mill.
func mill_wheel() -> void:
	var hub := xf * Vector3(0, 0, -1.0)
	hub.y = Terrain.WATER_Y + 2.1
	var frame := LowPoly.new()
	for side: float in [-1.0, 1.0]:
		var foot := hub + xf.basis.x * side * 2.75 + xf.basis.z * 0.8
		foot.y = terrain.height(foot.x, foot.z) - 0.2
		var top := Vector3(foot.x, hub.y + 0.5, foot.z)
		frame.prism(foot, top, 0.14, 0.14, 4, BEAM)
	frame.prism(hub - xf.basis.x * 2.9 + xf.basis.z * 0.8, hub + xf.basis.x * 2.9 + xf.basis.z * 0.8, 0.14, 0.14, 4, BEAM)
	frame.prism(hub - xf.basis.z * 0.7, hub + xf.basis.z * 8.4, 0.17, 0.17, 8, BEAM)
	add(frame)
	var wheel := LowPoly.new()
	for i in 12:
		var angle := TAU * i / 12.0
		var next := TAU * (i + 1) / 12.0
		var rim := Vector3(cos(angle), sin(angle), 0) * 2.25
		var rim_next := Vector3(cos(next), sin(next), 0) * 2.25
		wheel.prism(Vector3.ZERO, rim, 0.07, 0.07, 4, BEAM)
		for side: float in [-0.5, 0.5]: wheel.prism(rim + Vector3(0, 0, side), rim_next + Vector3(0, 0, side), 0.09, 0.09, 4, BEAM)
		wheel.box(rim, Vector3(0.75, 0.14, 1.1), PLANK.lightened(0.1), Vector3(0, 0, rad_to_deg(angle)))
	var node := MeshInstance3D.new()
	node.name = "WaterMillWheel"
	node.mesh = wheel.commit()
	node.transform = Transform3D(xf.basis, hub)
	w.add_child(node)
	w.add_spinner(node, Vector3.BACK, 0.7)


# --- Small things --------------------------------------------------------------

## A cow grazes, wanders a few steps and flicks its tail, all in its shader. It has its own mesh for that.
func cow() -> void:
	if _cow_mesh == null:
		var l := LowPoly.new()
		var white := Color(0.78, 0.76, 0.7)
		var dark := Color(0.16, 0.14, 0.13)
		l.box(Vector3(0, 0.95, 0), Vector3(0.75, 0.7, 1.7), white)
		l.box(Vector3(0.2, 1.05, 0.3), Vector3(0.4, 0.52, 0.7), dark)
		l.box(Vector3(0, 1.25, 1.05), Vector3(0.48, 0.48, 0.6), white)
		l.box(Vector3(0, 1.12, 1.38), Vector3(0.36, 0.22, 0.14), Color(0.75, 0.55, 0.5))
		l.box(Vector3(0.3, 1.46, 0.92), Vector3(0.2, 0.08, 0.1), dark)
		l.box(Vector3(-0.3, 1.46, 0.92), Vector3(0.2, 0.08, 0.1), dark)
		l.box(Vector3(0, 1.05, -0.93), Vector3(0.07, 0.62, 0.07), dark)
		for s: Vector2 in [Vector2(-0.25, 0.65), Vector2(0.25, 0.65), Vector2(-0.25, -0.65), Vector2(0.25, -0.65)]:
			l.box(Vector3(s.x, 0.32, s.y), Vector3(0.16, 0.64, 0.16), dark)
		_cow_mesh = l.commit()
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/cow.gdshader")
		_cow_mesh.surface_set_material(0, m)
	var cow_node := MeshInstance3D.new()
	cow_node.mesh = _cow_mesh
	cow_node.transform = xf
	cow_node.extra_cull_margin = 1.5
	w.add_child(cow_node)
	solid(Vector3(0, 0.8, 0), Vector3(0.9, 1.6, 2.9))


func table() -> void:
	var l := cell()
	l.box(Vector3(0, 0.78, 0), Vector3(1.8, 0.1, 1.0), BEAM.lightened(0.15))
	for s: Vector2 in [Vector2(-0.75, -0.38), Vector2(0.75, -0.38), Vector2(-0.75, 0.38), Vector2(0.75, 0.38)]:
		l.box(Vector3(s.x, 0.37, s.y), Vector3(0.1, 0.74, 0.1), BEAM)
	solid(Vector3(0, 0.42, 0), Vector3(1.8, 0.84, 1.0))


func bed() -> void:
	var l := cell()
	l.box(Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 2.0), BEAM)
	l.box(Vector3(0, 0.55, 0), Vector3(1.1, 0.16, 1.9), Color(0.55, 0.5, 0.42))
	l.box(Vector3(0, 0.66, -0.7), Vector3(0.9, 0.12, 0.4), Color(0.75, 0.72, 0.62))
	solid(Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 2.0))


func hay_bale() -> void:
	var size := Vector3(2.0, 1.0, 1.4)
	var l := cell()
	l.box(Vector3(0, size.y * 0.5, 0), size, HAY)
	l.box(Vector3(0, size.y * 0.5, 0), Vector3(size.x * 0.12, size.y + 0.02, size.z + 0.02), HAY.darkened(0.35))
	solid(Vector3(0, size.y * 0.5, 0), size)


## A fire to warm yourself at. Everything out there can see you by it.
func bonfire() -> void:
	var l := cell()
	for i in 8:
		var a := TAU * i / 8.0
		l.prism(Vector3(cos(a) * 1.0, 0.0, sin(a) * 1.0), Vector3(cos(a) * 1.0, 0.24, sin(a) * 1.0), 0.24, 0.17, 5, Color(0.34, 0.33, 0.33).lightened(0.05 * (i % 3)))
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		l.prism(Vector3(cos(a) * 0.72, 0.1, sin(a) * 0.72), Vector3(cos(a) * 0.08, 0.62, sin(a) * 0.08), 0.1, 0.07, 5, Color(0.17, 0.11, 0.07))
	var at := xf.origin
	w.add_solid(at + Vector3.UP * 0.5, Vector3(1.9, 1.0, 1.9))
	w.add_glow(at + Vector3.UP * 1.0, Color(1.0, 0.6, 0.22), 4.5, 95.0)
	_flame(at + Vector3.UP * 0.1, 1.0)
	var light: OmniLight3D = null
	if quality > 0:
		light = OmniLight3D.new()
		light.light_cull_mask = 3
		light.position = at + Vector3.UP * 1.5
		light.light_color = Color(1.0, 0.62, 0.28)
		light.light_energy = 2.5
		light.omni_range = 8.0
		light.omni_attenuation = 1.3
		w.add_child(light)
	w.add_fire(at, WorldLight.BONFIRE_REACH, light, true)


## A burning torch on a pole. Only High quality gives a torch its own light.
func torch() -> void:
	var l := cell()
	l.prism(Vector3.ZERO, Vector3.UP * 2.3, 0.07, 0.05, 5, BEAM)
	l.prism(Vector3.UP * 2.22, Vector3.UP * 2.42, 0.1, 0.13, 6, Color(0.14, 0.11, 0.09))
	var at := xf.origin
	w.add_solid(at + Vector3.UP, Vector3(0.22, 2.0, 0.22))
	w.add_glow(at + Vector3.UP * 2.6, Color(1.0, 0.64, 0.26), 2.0, 85.0)
	_flame(at + Vector3.UP * 2.38, 0.38)
	var light: OmniLight3D = null
	if quality == 2:
		light = OmniLight3D.new()
		light.light_cull_mask = 3
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


func stall(cloth: Color) -> void:
	var l := cell()
	for s: Vector2 in [Vector2(-1.5, -0.9), Vector2(1.5, -0.9), Vector2(-1.5, 0.9), Vector2(1.5, 0.9)]:
		l.box(Vector3(s.x, 1.15, s.y), Vector3(0.12, 2.3, 0.12), BEAM)
	l.box(Vector3(0, 2.4, 0), Vector3(3.5, 0.08, 2.3), cloth, Vector3(10, 0, 0))
	l.box(Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 1.2), BEAM.lightened(0.2))
	solid(Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 1.2))
	w.loot_spots.append(on_ground(Vector3(0, 0, 1.9)))


func lantern() -> void:
	var l := cell()
	l.box(Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14), BEAM)
	l.box(Vector3(0.28, 2.7, 0), Vector3(0.65, 0.09, 0.09), BEAM)
	l.box(Vector3(0.52, 2.46, 0), Vector3(0.22, 0.32, 0.22), Color(1.0, 0.72, 0.28))
	solid(Vector3(0, 1.2, 0), Vector3(0.25, 2.4, 0.25))
	var flame_at := xf * Vector3(0.52, 2.46, 0)
	w.add_glow(flame_at, Color(1.0, 0.68, 0.3), 2.2)
	w.add_fire(xf.origin, WorldLight.LANTERN_REACH)
	if quality > 0:
		var light := OmniLight3D.new()
		light.position = flame_at
		light.light_color = Color(1.0, 0.7, 0.38)
		light.light_energy = 2.0
		light.omni_range = 6.5
		light.omni_attenuation = 1.4
		w.add_child(light)
		w.add_lantern_light(light)


## The village well, roofed and wide.
func well() -> void:
	var l := mesh()
	l.prism(Vector3.ZERO, Vector3(0, 0.95, 0), 1.05, 1.05, 8, STONE)
	l.prism(Vector3(0, 0.95, 0), Vector3(0, 1.0, 0), 0.75, 0.75, 8, Color(0.04, 0.06, 0.09))
	for x: float in [-0.95, 0.95]:
		l.box(Vector3(x, 1.5, 0), Vector3(0.16, 1.5, 0.16), BEAM)
	l.box(Vector3(0, 2.2, 0), Vector3(2.0, 0.12, 0.12), BEAM)
	l.box(Vector3(0, 2.4, -0.45), Vector3(2.4, 0.1, 1.2), THATCH, Vector3(-28, 0, 0))
	l.box(Vector3(0, 2.4, 0.45), Vector3(2.4, 0.1, 1.2), THATCH, Vector3(28, 0, 0))
	add(l)
	solid(Vector3(0, 0.5, 0), Vector3(2.1, 1.0, 2.1))


func small_well() -> void:
	var l := cell()
	l.prism(Vector3.ZERO, Vector3.UP * 0.9, 0.9, 0.9, 8, CASTLE_STONE)
	l.prism(Vector3.UP * 0.9, Vector3.UP * 0.95, 0.62, 0.62, 8, Color(0.04, 0.06, 0.09))
	solid(Vector3.UP * 0.5, Vector3(1.8, 1.0, 1.8))


func scarecrow() -> void:
	var l := cell()
	l.box(Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), BEAM)
	l.box(Vector3(0, 1.45, 0), Vector3(1.5, 0.1, 0.1), BEAM)
	l.box(Vector3(0, 1.25, 0), Vector3(0.6, 0.65, 0.3), Color(0.32, 0.22, 0.25))
	l.box(Vector3(0, 1.8, 0), Vector3(0.34, 0.34, 0.34), HAY)
	l.prism(Vector3(0, 1.97, 0), Vector3(0, 2.35, 0), 0.38, 0.0, 6, Color(0.14, 0.1, 0.08))
	solid(Vector3(0, 0.9, 0), Vector3(0.2, 1.8, 0.2))


func cart() -> void:
	var l := cell()
	var wood := Color(0.42, 0.28, 0.16)
	l.box(Vector3(0, 0.85, 0), Vector3(1.5, 0.12, 2.8), wood)
	for dx: float in [-0.72, 0.72]:
		l.box(Vector3(dx, 1.12, 0), Vector3(0.08, 0.5, 2.8), wood.darkened(0.1))
		l.prism(Vector3(dx * 1.1, 0.5, 0.8), Vector3(dx * 1.22, 0.5, 0.8), 0.5, 0.5, 8, BEAM)
		l.prism(Vector3(dx * 1.1, 0.5, -0.8), Vector3(dx * 1.22, 0.5, -0.8), 0.5, 0.5, 8, BEAM)
	l.box(Vector3(0, 1.1, 0.2), Vector3(1.2, 0.5, 1.6), HAY)
	solid(Vector3(0, 0.6, 0), Vector3(1.7, 1.2, 3.1))


func grave(kind: int) -> void:
	var r := seeded()
	var tilt := r.randf_range(-16.0, 16.0)
	var l := cell()
	var col := Color(0.47, 0.47, 0.48).lightened(r.randf() * 0.1)
	match kind:
		0:
			l.box(Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.16), col, Vector3(tilt * 0.6, 0, tilt * 0.25))
			l.box(Vector3(0, 1.0, 0), Vector3(0.5, 0.14, 0.14), col)
		1:
			l.box(Vector3(0, 0.65, 0), Vector3(0.15, 1.3, 0.15), col, Vector3(tilt * 0.5, 0, tilt))
			l.box(Vector3(0, 0.95, 0), Vector3(0.72, 0.15, 0.15), col, Vector3(tilt * 0.5, 0, tilt))
		_:
			l.box(Vector3(0, 0.42, 0), Vector3(0.9, 0.85, 0.2), col.darkened(0.1), Vector3(tilt, 0, 0))
	l.box(Vector3(0, 0.08, 1.15), Vector3(0.95, 0.16, 1.9), Color(0.2, 0.15, 0.1))
	solid(Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.3))


## A stone tomb.
func tomb() -> void:
	cell().box(Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 2.4), CASTLE_STONE.lightened(0.08))
	solid(Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 2.4))


func log_pile() -> void:
	var l := cell()
	for row in 3:
		for i in 3 - row:
			var off := Vector3(0, 0.27 + row * 0.46, (i - (2 - row) * 0.5) * 0.52)
			l.prism(off + Vector3(-1.9, 0, 0), off + Vector3(1.9, 0, 0), 0.25, 0.25, 6, Color(0.36, 0.25, 0.15).lightened(0.05 * i))
	solid(Vector3.UP * 0.7, Vector3(3.8, 1.4, 1.6))


func stump() -> void:
	var l := cell()
	l.prism(Vector3.ZERO, Vector3.UP * 0.55, 0.42, 0.36, 7, Color(0.3, 0.21, 0.13))
	l.prism(Vector3.UP * 0.55, Vector3.UP * 0.58, 0.36, 0.36, 7, Color(0.58, 0.44, 0.27))
	solid(Vector3.UP * 0.3, Vector3(0.7, 0.6, 0.7))


## Fallen stones. They hide nothing, but they look the part.
func rubble() -> void:
	var r := seeded()
	var l := cell()
	for i in 4:
		var s := r.randf_range(0.4, 1.0)
		l.box(Vector3(r.randf_range(-1.6, 1.6), s * 0.3, r.randf_range(-1.6, 1.6)), Vector3(s, s * 0.7, s * 0.9), CASTLE_DARK.lightened(r.randf() * 0.15), Vector3(0, r.randf() * 90.0, r.randf() * 18.0))


## A portcullis half raised, across the piece's Z axis.
func portcullis() -> void:
	var l := cell()
	for i in 6:
		l.box(Vector3(0, 3.6, -2.0 + i * 0.8), Vector3(0.1, 1.1, 0.1), Color(0.14, 0.14, 0.16))
	l.box(Vector3(0, 3.1, 0), Vector3(0.12, 0.1, 4.8), Color(0.14, 0.14, 0.16))


## A log lying in the wood. Spare wood turns up beside these.
func fallen_log() -> void:
	var inv := xf.affine_inverse()
	cell().prism(inv * on_ground(Vector3(-1.6, 0.25, 0)), inv * on_ground(Vector3(1.6, 0.25, 0.4)), 0.24, 0.22, 6, Color(0.32, 0.22, 0.14))
	w.wood_spots.append(on_ground(Vector3(0, 0, 1.4)))


## Bare earth or paving.
func dirt(size: Vector2) -> void:
	if not is_preview:
		_dirt_patches.append({"at": xf, "half": size * 0.5})
		return
	var l := mesh()
	l.box(Vector3(0, 0.02, 0), Vector3(size.x, 0.04, size.y), DIRT.lightened(0.05))
	add(l).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func glow(col: Color, size: float, height: float) -> void:
	w.add_glow(xf * (Vector3.UP * height), col, size)


## Something from the free model packs, like a barrel or a rock.
func prop(path: String, scale: float, solid_size: Vector3) -> void:
	var file := "res://assets/%s.gltf" % path
	if not _props.has(file):
		_props[file] = []
	(_props[file] as Array).append(Transform3D(xf.basis.scaled_local(Vector3.ONE * scale), xf.origin))
	if solid_size != Vector3.ZERO:
		solid(Vector3.UP * solid_size.y * 0.5, solid_size)


func tree(path: String, scale: float, tall: float, is_solid: bool) -> void:
	if not _plant_allowed(xf.origin, maxf(0.5, scale * 0.18)): return
	var at := xf.origin
	if not is_preview: w.tree_spots.append(at)
	var key := "%s|%d|%d" % [path, int(floor(at.x / 40.0)), int(floor(at.z / 40.0))]
	if not _trees.has(key):
		_trees[key] = []
	(_trees[key] as Array).append(Transform3D(xf.basis.scaled_local(Vector3(scale, scale * tall, scale)), at))
	if is_solid:
		w.add_solid(at + Vector3.UP, Vector3(0.7, 2.0, 0.7))


func dead_tree() -> void:
	if not _plant_allowed(xf.origin, 0.7): return
	var l := mesh()
	var bark := Color(0.14, 0.12, 0.11)
	l.prism(Vector3.ZERO, Vector3(0.2, 3.0, 0.1), 0.26, 0.1, 5, bark)
	for b: Array in [[Vector3(0.2, 2.0, 0.1), Vector3(1.4, 3.2, 0.3)], [Vector3(0.2, 2.5, 0.1), Vector3(-0.9, 3.7, -0.5)], [Vector3(0.2, 3.0, 0.1), Vector3(0.7, 4.3, 0.8)], [Vector3(0.1, 1.6, 0.0), Vector3(-1.1, 2.2, 0.8)]]:
		l.prism(b[0], b[1], 0.08, 0.02, 4, bark)
	add(l)
	w.add_solid(xf.origin + Vector3.UP, Vector3(0.6, 2.0, 0.6))


## Stairs up a wall, climbing toward the piece's -Z. The steps are drawn over a solid wedge, so you
## walk on top of them and cannot wander underneath.
func stairs(length: float, h: float, width: float) -> void:
	var l := mesh()
	var steps := maxi(1, int(h / 0.42))
	var run := length / steps
	for i in steps:
		var f := (float(i) + 0.5) / steps
		var tall := h * f
		var z := -length * f
		# Each tread sits level with the middle of the slope your feet follow, and goes down into the ground.
		l.box(Vector3(0, (tall - 1.0) * 0.5, z), Vector3(width, tall + 1.0, run + 0.02), CASTLE_STONE.lightened(0.05 * (i % 2)))
	add(l)
	var hw := width * 0.5
	var wedge := PackedVector3Array([Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(-hw, h, -length), Vector3(hw, h, -length), Vector3(-hw, -0.5, 0), Vector3(hw, -0.5, 0), Vector3(-hw, -0.5, -length), Vector3(hw, -0.5, -length)])
	w.add_wedge(xf, wedge)
	w.grid_block_turned(xf.translated_local(Vector3(0, 1.0, -length * 0.5)), Vector3(width, 2.5, length))


# --- Fields ----------------------------------------------------------------------

## size is the whole plot. gaps: wall name -> list of (from, to) along that wall, from its centre.
func field(size: Vector2, kind: String, gaps: Dictionary) -> void:
	var x0 := -size.x * 0.5
	var x1 := size.x * 0.5
	var z0 := -size.y * 0.5
	var z1 := size.y * 0.5
	if kind in ["wheat", "barley", "corn", "garden"]:
		var soil := mesh()
		soil.box(Vector3(0, 0.03, 0), Vector3(size.x, 0.06, size.y), Color(0.22, 0.17, 0.1))
		_furrows(soil, size, 2.4 if kind == "garden" else 1.1)
		add(soil).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind in ["wheat", "barley", "corn", "garden", "graveyard"]:
		var f := mesh()
		fence(f, Vector2(x0, z0), Vector2(x1, z0), gaps.get("n", []))
		fence(f, Vector2(x0, z1), Vector2(x1, z1), gaps.get("s", []))
		fence(f, Vector2(x0, z0), Vector2(x0, z1), gaps.get("w", []))
		fence(f, Vector2(x1, z0), Vector2(x1, z1), gaps.get("e", []))
		add(f)
	match kind:
		"wheat", "barley": _grain(size, kind == "barley")
		"corn": _corn(size)
		"garden": _garden(size)
		"orchard": _orchard(size)
		"vines": _vines(size)
	if kind in ["wheat", "barley", "corn"]:
		w.grid_mark_crops(xf, size)
		var r := seeded()
		for i in 3:
			w.crop_spots.append(on_ground(Vector3(r.randf_range(x0 + 3, x1 - 3), 0, r.randf_range(z0 + 3, z1 - 3))))


## Ploughed ridges, so the soil reads as a field and not as a brown square.
func _furrows(l: LowPoly, size: Vector2, every: float) -> void:
	var z := -size.y * 0.5 + 0.7
	while z < size.y * 0.5 - 0.3:
		l.box(Vector3(0, 0.09, z), Vector3(size.x - 0.6, 0.14, every * 0.42), Color(0.17, 0.125, 0.075))
		z += every


func fence(l: LowPoly, a: Vector2, b: Vector2, gaps: Array) -> void:
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
		var inv := xf.affine_inverse()
		var segments := maxi(1, ceili(length / 1.6))
		for i in segments:
			var first := lerpf(s.x, s.y, float(i) / segments)
			var last := lerpf(s.x, s.y, float(i + 1) / segments)
			var left := inv * on_ground(Vector3(first, 0, other) if along_x else Vector3(other, 0, first))
			var right := inv * on_ground(Vector3(last, 0, other) if along_x else Vector3(other, 0, last))
			for rail_y: float in [0.5, 0.88]:
				l.prism(left + Vector3.UP * rail_y, right + Vector3.UP * rail_y, 0.045, 0.045, 4, BEAM.lightened(0.28))
			var mid := (left + right) * 0.5 + Vector3.UP * 0.5
			var thick := 1.0 + absf(left.y - right.y)
			solid(mid, Vector3(last - first, thick, 0.14) if along_x else Vector3(0.14, thick, last - first))
		for i in segments + 1:
			var at := lerpf(s.x, s.y, float(i) / segments)
			var foot := inv * on_ground(Vector3(at, 0, other) if along_x else Vector3(other, 0, at))
			l.box(foot + Vector3.UP * 0.5, Vector3(0.12, 1.0, 0.12), BEAM.lightened(0.15))


## Rows of different vegetables. They hide nothing, but they are a pleasure to walk through.
func _garden(size: Vector2) -> void:
	var kinds: Array[Mesh] = [Crops.cabbage(), Crops.turnip(), Crops.beans(), Crops.pumpkin()]
	var groups := {}
	var row := 0
	var z := -size.y * 0.5 + 1.6
	while z < size.y * 0.5 - 1.0:
		var pick: int = [0, 1, 2, 0, 3, 1, 2, 3][row % 8]
		var x := -size.x * 0.5 + 1.3
		while x < size.x * 0.5 - 1.0:
			var at := on_ground(Vector3(x + rng.randf_range(-0.12, 0.12), 0.13, z + rng.randf_range(-0.14, 0.14)))
			if not _plant_allowed(at):
				x += 1.0
				continue
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
func _grain(size: Vector2, barley: bool) -> void:
	var spacing: float = [1.1, 0.82, 0.66][quality]
	var colour := FastNoiseLite.new()
	colour.seed = int(xf.origin.x * 3.0 + xf.origin.z)
	colour.frequency = 0.09
	var ripe := Color(1.0, 0.98, 0.92)
	var green := Color(0.78, 0.92, 0.72)
	if barley:
		ripe = Color(0.92, 0.94, 0.76)
		green = Color(0.66, 0.86, 0.6)
	var chunks := {}
	var x := -size.x * 0.5 + 0.6
	while x < size.x * 0.5 - 0.4:
		var z := -size.y * 0.5 + 0.6
		while z < size.y * 0.5 - 0.4:
			var p := on_ground(Vector3(x + rng.randf_range(-0.25, 0.25), 0.06, z + rng.randf_range(-0.25, 0.25)))
			if not _plant_allowed(p):
				z += spacing
				continue
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
func _corn(size: Vector2) -> void:
	var along: float = [1.2, 1.0, 0.8][quality]
	var chunks := {}
	var x := -size.x * 0.5 + 0.8
	while x < size.x * 0.5 - 0.5:
		var z := -size.y * 0.5 + 0.7
		while z < size.y * 0.5 - 0.4:
			var p := on_ground(Vector3(x + rng.randf_range(-0.08, 0.08), 0.06, z + rng.randf_range(-0.2, 0.2)))
			if not _plant_allowed(p):
				z += along
				continue
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


## Rows of apple trees, with windfalls under them.
func _orchard(size: Vector2) -> void:
	var r := seeded()
	var trees: Array[Transform3D] = []
	var tints := PackedColorArray()
	var fallen := LowPoly.new()
	var x := -size.x * 0.5 + 2.5
	while x < size.x * 0.5 - 1.0:
		var z := -size.y * 0.5 + 2.5
		while z < size.y * 0.5 - 1.0:
			var at := on_ground(Vector3(x + r.randf_range(-0.4, 0.4), 0, z + r.randf_range(-0.4, 0.4)))
			if not _plant_allowed(at, 2.0):
				z += 5.0
				continue
			var s := r.randf_range(0.9, 1.2)
			trees.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s, s)), at))
			tints.append(Color(r.randf_range(0.9, 1.08), r.randf_range(0.9, 1.08), r.randf_range(0.9, 1.0)))
			w.add_solid(at + Vector3.UP, Vector3(0.5, 2.0, 0.5))
			for i in 3:
				var a := r.randf() * TAU
				var p := at + Vector3(cos(a) * r.randf_range(0.5, 1.6), 0.06, sin(a) * r.randf_range(0.5, 1.6))
				fallen.box(p, Vector3.ONE * 0.11, Color(0.72, 0.14, 0.1))
			z += 5.0
		x += 5.0
	var node := Crops.plant(Crops.apple_tree(), trees, tints, true)
	node.visibility_range_end = 90.0
	w.add_child(node)
	var apples := MeshInstance3D.new()
	apples.mesh = fallen.commit()
	apples.visibility_range_end = 40.0
	apples.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(apples)


func _vines(size: Vector2) -> void:
	var r := seeded()
	var vines: Array[Transform3D] = []
	var tints := PackedColorArray()
	var x := -size.x * 0.5
	while x < size.x * 0.5:
		var z := -size.y * 0.5
		while z < size.y * 0.5:
			var at := on_ground(Vector3(x, 0, z))
			if not _plant_allowed(at, 0.4):
				z += 2.0
				continue
			vines.append(Transform3D(xf.basis, at))
			tints.append(Color(1, 1, 1) * r.randf_range(0.85, 1.1))
			z += 2.0
		x += 2.6
	var node := Crops.plant(Crops.vine(), vines, tints, true)
	node.visibility_range_end = 60.0
	w.add_child(node)


# --- The fort --------------------------------------------------------------------

## The walls, towers and gates of the fort. The rules of the game know where these are, so they stay
## together in the middle of the map.
func fort_walls() -> void:
	w.start_fort()
	var h := Fort.HALF
	var l := LowPoly.new()
	# Each side: from a corner to the gate, over the gate, on to the other corner, with one small door.
	for side in 4:
		_fort_side(l, side, Fort.DOORS[side])
	for c: Vector2 in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		_fort_tower(l, Vector3(c.x, 0, c.y))
	var walls := MeshInstance3D.new()
	walls.mesh = l.commit()
	walls.material_override = no_fog()
	w.add_child(walls)
	for i in 4:
		_fort_gate(i)


func _point(side: int, along: float, out: float) -> Vector3:
	var dir := Fort.DIRS[side]
	var across := Vector3(dir.z, 0, -dir.x)
	return dir * out + across * along


func _box_size(side: int, along: float, y: float, out: float) -> Vector3:
	return Vector3(along, y, out) if absf(Fort.DIRS[side].z) > 0.5 else Vector3(out, y, along)


func _fort_side(l: LowPoly, side: int, door_at: float) -> void:
	var h := Fort.HALF
	var t := Fort.WALL_T
	var top := Fort.WALL_H
	var gaps: Array[Vector2] = [Vector2(-Fort.GATE_W * 0.5, Fort.GATE_W * 0.5), Vector2(door_at - 0.95, door_at + 0.95)]
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor := -h
	var spans: Array[Vector2] = []
	for g in gaps:
		spans.append(Vector2(cursor, g.x))
		cursor = g.y
	spans.append(Vector2(cursor, h))
	for s in spans:
		var size := _box_size(side, s.y - s.x, top, t)
		var at := _point(side, (s.x + s.y) * 0.5, h) + Vector3.UP * top * 0.5
		l.box(at, size, CASTLE_STONE)
		w.add_solid(at, size)
	# The walk stays whole over the openings.
	var over_gate := _box_size(side, Fort.GATE_W, top - Fort.GATE_H, t)
	var over_at := _point(side, 0.0, h) + Vector3.UP * (Fort.GATE_H + (top - Fort.GATE_H) * 0.5)
	l.box(over_at, over_gate, CASTLE_DARK)
	w.add_collider(over_at, over_gate)
	var over_door := _box_size(side, 1.9, top - 2.5, t)
	var door_point := _point(side, door_at, h)
	w.fort.add_door(door_point, Fort.DIRS[side])
	l.box(door_point + Vector3.UP * (2.5 + (top - 2.5) * 0.5), over_door, CASTLE_DARK)
	w.add_collider(door_point + Vector3.UP * (2.5 + (top - 2.5) * 0.5), over_door)
	# Only players fit through the small door.
	var plug := _box_size(side, 1.9, 2.5, t)
	w.add_enemy_block(door_point + Vector3.UP * 1.25, plug)
	var dark := Color(0.05, 0.04, 0.04)
	for f: float in [-1.0, 1.0]:
		l.box(_point(side, door_at + f * 1.02, h + t * 0.52) + Vector3.UP * 1.25, _box_size(side, 0.18, 2.5, 0.12), FORT_PLANK)
	l.box(_point(side, door_at, h + t * 0.52) + Vector3.UP * 2.56, _box_size(side, 2.2, 0.16, 0.12), FORT_PLANK)
	l.box(door_point + Vector3.DOWN * 0.02, _box_size(side, 1.9, 0.05, t), dark)
	# Battlements on the outer edge. You can step between them and drop.
	var a := -h + 3.0
	while a < h - 2.5:
		var p := _point(side, a, h + t * 0.5 - 0.2)
		l.box(p + Vector3.UP * (top + 0.42), _box_size(side, 1.1, 0.84, 0.4), CASTLE_DARK.lightened(0.06))
		w.add_collider(p + Vector3.UP * (top + 0.42), _box_size(side, 1.1, 0.84, 0.4))
		a += 2.3


func _fort_tower(l: LowPoly, at: Vector3) -> void:
	var high := Fort.WALL_H + 3.2
	l.prism(at, at + Vector3.UP * high, 3.4, 3.1, 8, CASTLE_STONE.darkened(0.05))
	l.prism(at + Vector3.UP * high, at + Vector3.UP * (high + 0.5), 3.7, 3.7, 8, CASTLE_DARK)
	for i in 8:
		var a := TAU * i / 8.0
		l.box(at + Vector3(cos(a) * 3.3, high + 0.85, sin(a) * 3.3), Vector3(0.8, 0.7, 0.8), CASTLE_DARK.lightened(0.05))
	w.add_solid(at + Vector3.UP * high * 0.5, Vector3(5.6, high, 5.6))
	w.perches.append(at + Vector3.UP * (high + 0.6))


func _fort_gate(i: int) -> void:
	var dir := Fort.DIRS[i]
	var node := Node3D.new()
	node.position = dir * Fort.HALF
	node.rotation.y = 0.0 if absf(dir.z) > 0.5 else PI * 0.5
	w.add_child(node)
	# Rows of planks, each its own mesh, so a damaged gate can lose them one by one.
	var rows: Array[Node3D] = []
	const ROWS := 5
	for r in ROWS:
		var row := LowPoly.new()
		var y := (r + 0.5) * Fort.GATE_H / ROWS
		var x := -Fort.GATE_W * 0.5 + 0.34
		var k := 0
		while x < Fort.GATE_W * 0.5:
			row.box(Vector3(x, y, 0), Vector3(0.62, Fort.GATE_H / ROWS + 0.02, 0.36), FORT_PLANK.lightened(0.04 * (k % 3)).darkened(0.03 * (r % 2)))
			x += 0.68
			k += 1
		if r % 2 == 0:
			row.box(Vector3(0, y, 0.2), Vector3(Fort.GATE_W, 0.18, 0.1), Color(0.14, 0.13, 0.14))
			row.box(Vector3(0, y, -0.2), Vector3(Fort.GATE_W, 0.18, 0.1), Color(0.14, 0.13, 0.14))
		var mi := MeshInstance3D.new()
		mi.mesh = row.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		rows.append(mi)
	w.fort.add_gate(i, node, rows)


## The keep, and in it the heart that has to last until morning.
func fort_keep() -> void:
	var stone := {"plaster": CASTLE_STONE.lightened(0.04), "roof": Color(0.22, 0.2, 0.24), "beams": false}
	house(15, 15, 5.0, "x", stone, {"n": [door(0, 3.0, 3.4)], "e": [door(0, 3.0, 3.4)], "s": [door(0, 3.0, 3.4)], "w": [door(0, 3.0, 3.4)]})
	var l := mesh()
	l.prism(Vector3.ZERO, Vector3.UP * 0.5, 1.3, 1.1, 8, CASTLE_DARK)
	l.prism(Vector3.UP * 0.5, Vector3.UP * 0.9, 0.7, 0.45, 8, CASTLE_STONE)
	add(l)
	solid(Vector3.UP * 0.5, Vector3(2.2, 1.0, 2.2))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.05
	ring.outer_radius = 1.35
	var mi := MeshInstance3D.new()
	mi.name = "MistsPortalObjective"
	mi.mesh = ring
	mi.rotation.x = PI * 0.5
	mi.position = xf.origin + Vector3.UP * 2.0
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.22, 0.26, 0.3)
	stone_material.emission_enabled = true
	stone_material.emission = Color(0.1, 0.45, 0.5)
	mi.material_override = stone_material
	w.add_child(mi)
	var veil := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 1.05
	disc.height = 2.1
	veil.mesh = disc
	veil.scale = Vector3(1, 0.08, 1)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(0.2, 0.85, 0.85, 0.65)
	veil.material_override = glow
	mi.add_child(veil)
	w.add_glow(mi.position, Color(0.3, 0.9, 0.9), 4.0)
	w.fort.set_heart(xf.origin, mi)


# --- Round the edges -------------------------------------------------------------

## A forest wall outside the playable edge. It needs no collision, so it may depend on quality.
func forest_wall(h: float) -> void:
	var apron := LowPoly.new()
	for side in 4:
		var outward := Vector3(sin(side * PI * 0.5), 0, cos(side * PI * 0.5))
		var tangent := outward.cross(Vector3.UP)
		for n in range(-int(h), int(h), 4):
			var a := outward * h + tangent * n
			var z := outward * h + tangent * minf(n + 4, h)
			a.y = terrain.height(a.x, a.z) - 0.03
			z.y = terrain.height(z.x, z.z) - 0.03
			apron._tri(a, z, z + outward * 24, a - Vector3.UP, DIRT.darkened(0.3))
			apron._tri(a, z + outward * 24, a + outward * 24, a - Vector3.UP, DIRT.darkened(0.3))
	add(apron)
	var step: float = [7.5, 5.5, 4.2][quality]
	var depth: int = [2, 2, 3][quality]
	for row in depth:
		var off := h + 1.5 + row * 3.4
		var t := -off
		while t <= off:
			for at: Vector3 in [Vector3(t, 0, -off), Vector3(t, 0, off), Vector3(-off, 0, t), Vector3(off, 0, t)]:
				var p := at + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
				p.y = terrain.height(p.x, p.z)
				stand_at(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
				var file := "res://assets/nature/tree_single_A.gltf" if rng.randf() < 0.72 else "res://assets/nature/tree_single_B.gltf"
				tree(file, rng.randf_range(5.5, 8.5), rng.randf_range(0.9, 1.15), false)
			t += step


## Grass tufts, in patches so the camera can skip those it cannot see.
func grass(h: float) -> void:
	var patches := {}
	var tuft := _grass_tuft()
	# The same thickness of grass on any size of map.
	var area := pow(h / terrain.half_extent, 2.0)
	for i in int(grass_tufts * 3 * area):
		var p := Vector3(rng.randf_range(-h, h), 0, rng.randf_range(-h, h))
		if terrain.has_islands() and Vector2(p.x, p.z).length() < 57.1: continue
		if not _plant_allowed(p) or not w.grid.is_free(w.grid.to_cell(p)) or _is_indoors(p):
			continue
		if terrain.on_deck(p.x, p.z) or terrain.in_pool(p.x, p.z): continue
		if terrain.has_islands():
			if MapIslands.on_masonry(Vector2(p.x, p.z)): continue
			if not is_preview and MapIslands._near_gate(w, p, 4.0): continue
		p.y = terrain.height(p.x, p.z)
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


func _is_indoors(p: Vector3) -> bool:
	for r in _indoors:
		if r.grow(1.0).has_point(Vector2(p.x, p.z)):
			return true
	return false


func _grass_tuft() -> Mesh:
	var l := LowPoly.new()
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var off := Vector3(cos(a), 0, sin(a)) * 0.08
		var side := Vector3(-sin(a), 0, cos(a)) * 0.055
		var tip := off * 3.0 + Vector3.UP * (0.36 + 0.09 * (i % 3))
		l.gable(off - side, off + side, tip, GRASS.lerp(GRASS_TIP, 0.45 * (i % 3)))
	return l.commit()


func _reserve_plants(node: Node, parent: Transform3D) -> void:
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var at := parent * (child as Node3D).transform
		if child is MapThing and (child as MapThing).kind == "bonfire":
			_plant_clearings.append(Vector3(at.origin.x, at.origin.z, 2.6))
		if child is MapHouse:
			_plant_rooms.append({"inverse": at.affine_inverse(), "half": Vector2((child as MapHouse).width, (child as MapHouse).depth) * 0.5 + Vector2.ONE})
		_reserve_plants(child, at)

func _plant_allowed(at: Vector3, margin := 0.0) -> bool:
	for clearing: Vector3 in _plant_clearings:
		if Vector2(at.x - clearing.x, at.z - clearing.y).length() < clearing.z + margin: return false
	for room: Dictionary in _plant_rooms:
		var local: Vector3 = (room["inverse"] as Transform3D) * at
		var half: Vector2 = room["half"]
		if absf(local.x) < half.x + margin and absf(local.z) < half.y + margin: return false
	return true


## GLES limits point lights per mesh. Consistent ground warmth avoids square light seams between patches.
func _warm_ground() -> void:
	if is_preview: return
	for patch: MeshInstance3D in _ground_patches:
		var centre := patch.get_aabb().get_center()
		var nearby: Array = w.fires.duplicate()
		nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return centre.distance_squared_to(a["at"]) < centre.distance_squared_to(b["at"]))
		var hearths := PackedVector4Array()
		hearths.resize(8)
		for i in mini(8, nearby.size()):
			var fire: Dictionary = nearby[i]
			var at: Vector3 = fire["at"]
			var radius := 8.0 if fire["heals"] else 5.0
			hearths[i] = Vector4(at.x, at.y + 1.2, at.z, 1.0 / (radius * radius))
		var material := _ground_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("hearths", hearths)
		patch.material_override = material


## Rest boulders on the actual slope rather than floating their downhill edge above it.
func terrain_rock(grow: float) -> void:
	if not _plant_allowed(xf.origin, 0.65 * grow): return
	var saved := xf
	var at := xf.origin
	var step := maxf(0.5, grow * 0.6)
	var dx := (terrain.height(at.x + step, at.z) - terrain.height(at.x - step, at.z)) / (step * 2.0)
	var dz := (terrain.height(at.x, at.z + step) - terrain.height(at.x, at.z - step)) / (step * 2.0)
	var normal := Vector3(-dx, 1.0, -dz).normalized()
	var right := (xf.basis.x - normal * xf.basis.x.dot(normal)).normalized()
	at.y -= 0.1 * grow
	xf = Transform3D(Basis(right, normal, right.cross(normal)), at)
	prop("nature/rock_single_C", 5.0 * grow, Vector3(1.2, 0.7, 1.2) * grow)
	xf = saved
