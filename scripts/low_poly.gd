@tool
class_name LowPoly
extends RefCounted
## Tiny flat-shaded mesh builder used for weapons that have no matching free model.
## Shapes are convex, so faces get their winding fixed automatically.

static var _material: StandardMaterial3D

var base := Transform3D.IDENTITY: # everything added goes through this, so a shape can be placed and turned
	set(value):
		base = value
		var determinant := value.basis.determinant()
		_normal_basis = value.basis.inverse().transposed() if absf(determinant) > 0.000001 else Basis.IDENTITY
		_mirrored = determinant < 0.0
var _normal_basis := Basis.IDENTITY
var _mirrored := false
var _st := SurfaceTool.new()


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0
	return _material


func commit() -> ArrayMesh:
	var m := _st.commit()
	if m.get_surface_count() > 0: # nothing drawn yet gives a mesh with no surface
		m.surface_set_material(0, material())
	return m


func _tri(a: Vector3, b: Vector3, c: Vector3, centre: Vector3, col: Color) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 0.0000001:
		return
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = (_normal_basis * n).normalized()
	if _mirrored:
		var t := b
		b = c
		c = t
	for v: Vector3 in [a, b, c]:
		_st.set_color(col)
		_st.set_normal(n)
		_st.add_vertex(base * v)


## A triangle whose corners each have their own colour, blended across it.
func _tri_shaded(a: Vector3, b: Vector3, c: Vector3, centre: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 0.0000001:
		return
	var swap := n.dot((a + b + c) / 3.0 - centre) < 0.0
	if swap:
		n = -n
	if _mirrored:
		swap = not swap
	n = (_normal_basis * n).normalized()
	var corners := [[a, ca], [c, cc], [b, cb]] if swap else [[a, ca], [b, cb], [c, cc]]
	for corner: Array in corners:
		_st.set_color(corner[1])
		_st.set_normal(n)
		_st.add_vertex(base * (corner[0] as Vector3))


## How much darker the foot of something this tall is than its top. Walls, towers and cliffs stand
## in their own shade near the ground, which gives big flat faces depth at no cost on the phone:
## the shade is in the colours of the mesh. Small things are left alone.
const FOOT_SHADE := 0.26
static func foot_shade(tall: float) -> float:
	return FOOT_SHADE * smoothstep(1.4, 5.0, tall)


func box(centre: Vector3, size: Vector3, col: Color, rot_deg := Vector3.ZERO) -> LowPoly:
	return turned_box(centre, size, col, Basis.from_euler(rot_deg * PI / 180.0))


## A box turned by any rotation, for shapes that are not lined up with the world.
func turned_box(centre: Vector3, size: Vector3, col: Color, turn: Basis) -> LowPoly:
	var h := size * 0.5
	var p: Array[Vector3] = []
	var shade := foot_shade(size.y * base.basis.get_scale().y) if absf((base.basis * turn).y.normalized().y) > 0.9 else 0.0
	var low := col.darkened(shade) if shade > 0.001 else col
	var tint: Array[Color] = []
	for x: float in [-h.x, h.x]:
		for y: float in [-h.y, h.y]:
			for z: float in [-h.z, h.z]:
				p.append(centre + turn * Vector3(x, y, z))
				tint.append(low if y < 0.0 else col)
	for f: Array in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		if shade > 0.001:
			_tri_shaded(p[f[0]], p[f[1]], p[f[2]], centre, tint[f[0]], tint[f[1]], tint[f[2]])
			_tri_shaded(p[f[0]], p[f[2]], p[f[3]], centre, tint[f[0]], tint[f[2]], tint[f[3]])
		else:
			_tri(p[f[0]], p[f[1]], p[f[2]], centre, col)
			_tri(p[f[0]], p[f[2]], p[f[3]], centre, col)
	return self


## A flat triangle visible from both sides (roof gables).
func gable(a: Vector3, b: Vector3, c: Vector3, col: Color) -> LowPoly:
	var n := (b - a).cross(c - a).normalized()
	var mid := (a + b + c) / 3.0
	_tri(a, b, c, mid - n, col)
	_tri(a, b, c, mid + n, col)
	return self


## One face for materials with culling disabled, such as foliage. Duplicating its back face
## would draw the same pixels twice and double vertex work for every plant instance.
func leaf(a: Vector3, b: Vector3, c: Vector3, col: Color) -> LowPoly:
	var n := (b - a).cross(c - a).normalized()
	_tri(a, b, c, (a + b + c) / 3.0 - n, col)
	return self


## An egg or a plump body: an ellipsoid with radii on its own axes (turned by `turn`), faceted into
## `lat` bands and `lon` sides, shading from `col` on top to `under` beneath.
func ovoid(centre: Vector3, radii: Vector3, col: Color, under: Color, lat := 5, lon := 10, turn := Basis.IDENTITY) -> LowPoly:
	var rows: Array[Array] = []
	for i in lat + 1:
		var th := PI * i / lat
		var row: Array[Vector3] = []
		for j in lon:
			var ph := TAU * j / lon + (PI / lon if i % 2 == 1 else 0.0)
			row.append(centre + turn * Vector3(sin(th) * cos(ph) * radii.x, cos(th) * radii.y, sin(th) * sin(ph) * radii.z))
		rows.append(row)
	for i in lat:
		var c0 := col.lerp(under, float(i) / lat)
		var c1 := col.lerp(under, float(i + 1) / lat)
		for j in lon:
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i][(j + 1) % lon]
			var c: Vector3 = rows[i + 1][j]
			var d: Vector3 = rows[i + 1][(j + 1) % lon]
			_tri_shaded(a, b, c, centre, c0, c0, c1)
			_tri_shaded(b, d, c, centre, c0, c1, c1)
	return self


## A tube or cone from a to b. Set rb to 0 for a point.
func prism(a: Vector3, b: Vector3, ra: float, rb: float, sides: int, col: Color) -> LowPoly:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(axis)
	var centre := (a + b) * 0.5
	for i in sides:
		var t0 := TAU * i / sides
		var t1 := TAU * (i + 1) / sides
		var d0 := side * cos(t0) + up * sin(t0)
		var d1 := side * cos(t1) + up * sin(t1)
		_tri(a + d0 * ra, a + d1 * ra, b + d0 * rb, centre, col)
		_tri(a + d1 * ra, b + d1 * rb, b + d0 * rb, centre, col)
		_tri(a, a + d0 * ra, a + d1 * ra, centre, col)
		if rb > 0.0:
			_tri(b, b + d0 * rb, b + d1 * rb, centre, col)
	return self
