class_name PathGrid
extends RefCounted
## 1 m walkability grid. Every solid box marks the cells it touches, so the grid can
## never disagree with collision. Each zombie asks for its own path when it needs one.

var size: int
var half: float
var astar := AStarGrid2D.new()
var crops: PackedByteArray
var _far := AStarGrid2D.new() # 4 m cells, for planning long journeys cheaply

const FAR_CELL := 4
const LONG_TRIP := 44.0
const LEG := 32.0


func _init(world_size: int) -> void:
	size = world_size
	half = world_size * 0.5
	astar.region = Rect2i(0, 0, size, size)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.jumping_enabled = true
	astar.update()
	crops.resize(size * size)


func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x + half)), 0, size - 1), clampi(int(floor(p.z + half)), 0, size - 1))


func to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5 - half, 0.0, c.y + 0.5 - half)


func block_box(centre: Vector3, box: Vector3) -> void:
	var a := to_cell(centre - box * 0.5 + Vector3(0.02, 0, 0.02))
	var b := to_cell(centre + box * 0.5 - Vector3(0.02, 0, 0.02))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			astar.set_point_solid(Vector2i(x, y), true)


## A box that is not lined up with the grid. A cell closes if its middle is in the box or very near it.
func block_turned(t: Transform3D, box: Vector3) -> void:
	var half_x := box.x * 0.5 + 0.35
	var half_z := box.z * 0.5 + 0.35
	var reach := Vector2(half_x, half_z).length()
	var a := to_cell(t.origin - Vector3(reach, 0, reach))
	var b := to_cell(t.origin + Vector3(reach, 0, reach))
	var inv := t.basis.inverse()
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var local := inv * (to_world(Vector2i(x, y)) - Vector3(t.origin.x, 0.0, t.origin.z))
			if absf(local.x) < half_x and absf(local.z) < half_z:
				astar.set_point_solid(Vector2i(x, y), true)


## A gate opening or closing.
func set_box(centre: Vector3, box: Vector3, solid: bool) -> void:
	var a := to_cell(centre - box * 0.5 + Vector3(0.02, 0, 0.02))
	var b := to_cell(centre + box * 0.5 - Vector3(0.02, 0, 0.02))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			astar.set_point_solid(Vector2i(x, y), solid)


func mark_crops(x0: float, z0: float, x1: float, z1: float) -> void:
	var a := to_cell(Vector3(x0, 0, z0))
	var b := to_cell(Vector3(x1, 0, z1))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			crops[y * size + x] = 1


func mark_crops_turned(t: Transform3D, field: Vector2) -> void:
	var half := field * 0.5 - Vector2(0.5, 0.5)
	var reach := half.length() + 1.0
	var a := to_cell(t.origin - Vector3(reach, 0, reach))
	var b := to_cell(t.origin + Vector3(reach, 0, reach))
	var inv := t.basis.inverse()
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var local := inv * (to_world(Vector2i(x, y)) - Vector3(t.origin.x, 0.0, t.origin.z))
			if absf(local.x) < half.x and absf(local.z) < half.y:
				crops[y * size + x] = 1


func in_crops(p: Vector3) -> bool:
	var c := to_cell(p)
	return crops[c.y * size + c.x] == 1


func is_free(c: Vector2i) -> bool:
	return astar.is_in_boundsv(c) and not astar.is_point_solid(c)


## Can something walk this straight line? The two ends' own cells do not count: someone standing
## against a wall is in a cell the wall touches, and they can still be walked up to.
func line_is_open(from: Vector3, to: Vector3) -> bool:
	var a := to_cell(from)
	var b := to_cell(to)
	var steps := int(Vector2(to.x - from.x, to.z - from.z).length() / 0.4)
	for i in range(1, steps):
		var c := to_cell(from.lerp(to, float(i) / steps))
		if c != a and c != b and astar.is_point_solid(c):
			return false
	return true


func nearest_free(c: Vector2i) -> Vector2i:
	if is_free(c):
		return c
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if is_free(n):
					return n
	return c


## Called when the map is finished. A coarse cell is open unless most of it is blocked, so walls
## do not close it, and only what really divides the map does: the river, the cliffs, the forest.
func build_far_grid() -> void:
	var n := ceili(float(size) / FAR_CELL)
	_far.region = Rect2i(0, 0, n, n)
	_far.cell_size = Vector2.ONE
	_far.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_far.jumping_enabled = true
	_far.update()
	for y in n:
		for x in n:
			var open := 0
			for dy in FAR_CELL:
				for dx in FAR_CELL:
					if is_free(Vector2i(x * FAR_CELL + dx, y * FAR_CELL + dy)):
						open += 1
			var cells := mini(FAR_CELL, size - x * FAR_CELL) * mini(FAR_CELL, size - y * FAR_CELL)
			_far.set_point_solid(Vector2i(x, y), open * 16 < cells * 6)


## The way to somewhere. Far away, this only plans the next stretch: the walker asks again when it
## gets there. A full path across this map costs as much as the rest of the frame put together.
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if Vector2(from.x - to.x, from.z - to.z).length() <= LONG_TRIP:
		return path(from, to)
	var a := _far_nearest(from)
	var b := _far_nearest(to)
	var travelled := 0.0
	var last := Vector2(from.x, from.z)
	var stop := Vector3(to)
	for c: Vector2i in _far.get_id_path(a, b, true):
		var p := Vector2((c.x + 0.5) * FAR_CELL - half, (c.y + 0.5) * FAR_CELL - half)
		var step := last.distance_to(p)
		if travelled + step > LEG and travelled > 0.0:
			break
		travelled += step
		last = p
		stop = Vector3(p.x, 0.0, p.y)
		if travelled > LEG * 0.6:
			break
	return path(from, stop)


func _far_nearest(p: Vector3) -> Vector2i:
	var n := _far.region.size.x
	var c := Vector2i(clampi(int((p.x + half) / FAR_CELL), 0, n - 1), clampi(int((p.z + half) / FAR_CELL), 0, n - 1))
	if not _far.is_point_solid(c):
		return c
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if _far.is_in_boundsv(q) and not _far.is_point_solid(q):
					return q
	return c


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := nearest_free(to_cell(from))
	var b := nearest_free(to_cell(to))
	if a == b or not is_free(a) or not is_free(b):
		return out
	for c: Vector2i in astar.get_id_path(a, b, true):
		out.append(to_world(c))
	return out


## Cells reachable from one point. Used by tests and to reject sealed-off spawn spots.
func flood(from: Vector3) -> Dictionary:
	var seen := {}
	var start := nearest_free(to_cell(from))
	if not is_free(start):
		return seen
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if is_free(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen
