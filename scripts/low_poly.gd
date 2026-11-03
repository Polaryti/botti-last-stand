@tool
class_name LowPoly
extends RefCounted
## Tiny flat-shaded mesh builder used for weapons that have no matching free model.
## Shapes are convex, so faces get their winding fixed automatically.

static var _material: StandardMaterial3D

var base := Transform3D.IDENTITY # everything added goes through this, so a shape can be placed and turned
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
	n = (base.basis * n).normalized()
	for v: Vector3 in [a, b, c]:
		_st.set_color(col)
		_st.set_normal(n)
		_st.add_vertex(base * v)


func box(centre: Vector3, size: Vector3, col: Color, rot_deg := Vector3.ZERO) -> LowPoly:
	var b := Basis.from_euler(rot_deg * PI / 180.0)
	var h := size * 0.5
	var p: Array[Vector3] = []
	for x: float in [-h.x, h.x]:
		for y: float in [-h.y, h.y]:
			for z: float in [-h.z, h.z]:
				p.append(centre + b * Vector3(x, y, z))
	for f: Array in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		_tri(p[f[0]], p[f[1]], p[f[2]], centre, col)
		_tri(p[f[0]], p[f[2]], p[f[3]], centre, col)
	return self


## A box turned by any rotation, for shapes that are not lined up with the world.
func turned_box(centre: Vector3, size: Vector3, col: Color, turn: Basis) -> LowPoly:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for x: float in [-h.x, h.x]:
		for y: float in [-h.y, h.y]:
			for z: float in [-h.z, h.z]:
				p.append(centre + turn * Vector3(x, y, z))
	for f: Array in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
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
