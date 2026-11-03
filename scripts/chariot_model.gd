class_name ChariotModel
extends Node3D
## The Mechanic's war chariot. The same model is what you see around you while driving and what
## other players see. The wheels turn with its speed.

static var _body: Mesh
static var _wheel: Mesh
static var _turret_mesh: Mesh
static var _blades: Mesh

var _wheels: Array[MeshInstance3D] = []
var _turret: MeshInstance3D
var _spikes: Array[MeshInstance3D] = []


func _init(layer := 1) -> void:
	_build_meshes()
	_part(_body, layer)
	for side: float in [-1.0, 1.0]:
		var w := _part(_wheel, layer)
		w.position = Vector3(side * 0.98, 0.72, 0.15)
		_wheels.append(w)
		var s := _part(_blades, layer)
		s.position = w.position
		s.scale.x = side
		s.visible = false
		_spikes.append(s)
	_turret = _part(_turret_mesh, layer)
	_turret.position = Vector3(0.62, 1.36, -0.95)
	_turret.visible = false


func _part(m: Mesh, layer: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.layers = layer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _build_meshes() -> void:
	if _body:
		return
	var wood := Color(0.36, 0.24, 0.14)
	var iron := Color(0.27, 0.29, 0.32)
	var brass := Color(0.72, 0.56, 0.22)
	var l := LowPoly.new()
	l.box(Vector3(0, 0.82, 0.1), Vector3(1.5, 0.14, 2.5), wood)
	l.box(Vector3(0, 0.74, 0.15), Vector3(2.0, 0.1, 0.14), iron)
	for x: float in [-0.74, 0.74]:
		l.box(Vector3(x, 1.12, 0.1), Vector3(0.08, 0.5, 2.4), wood.darkened(0.15))
		l.box(Vector3(x, 1.4, 0.1), Vector3(0.12, 0.08, 2.44), iron)
	# The shield at the front, low enough to see over, with a ram below it.
	l.box(Vector3(0, 1.08, -1.14), Vector3(1.56, 0.66, 0.12), iron)
	l.box(Vector3(0, 1.43, -1.14), Vector3(1.3, 0.08, 0.16), brass)
	for x: float in [-0.5, 0.0, 0.5]:
		l.box(Vector3(x, 1.08, -1.21), Vector3(0.14, 0.14, 0.04), brass)
	l.prism(Vector3(0, 0.8, -1.18), Vector3(0, 0.62, -2.1), 0.17, 0.0, 6, iron.darkened(0.2))
	_body = l.commit()
	var w := LowPoly.new()
	w.prism(Vector3(-0.08, 0, 0), Vector3(0.08, 0, 0), 0.72, 0.72, 12, wood.darkened(0.25))
	w.prism(Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0), 0.16, 0.16, 8, iron)
	for i in 4:
		var a := PI * i / 4.0
		w.box(Vector3(0.1, 0, 0), Vector3(0.05, 1.3, 0.08), wood.lightened(0.12), Vector3(rad_to_deg(a), 0, 0))
	_wheel = w.commit()
	var t := LowPoly.new()
	t.prism(Vector3(0, -0.2, 0), Vector3(0, 0, 0), 0.06, 0.06, 6, iron)
	t.box(Vector3(0, 0.05, 0.02), Vector3(0.13, 0.1, 0.26), iron.lightened(0.1))
	t.prism(Vector3(0, 0.06, -0.08), Vector3(0, 0.06, -0.62), 0.03, 0.022, 6, brass)
	t.box(Vector3(0, 0.06, -0.16), Vector3(0.56, 0.035, 0.035), wood)
	_turret_mesh = t.commit()
	var b := LowPoly.new()
	b.prism(Vector3(0.1, 0, 0), Vector3(0.75, 0, 0), 0.1, 0.0, 5, Color(0.72, 0.74, 0.78))
	_blades = b.commit()


func show_upgrades(has_turret: bool, has_spikes: bool) -> void:
	_turret.visible = has_turret
	for s in _spikes:
		s.visible = has_spikes


## Points the turret at something, given in the world.
func aim_turret(at: Vector3) -> void:
	if _turret.visible and _turret.is_inside_tree():
		var to := at - _turret.global_position
		if Vector2(to.x, to.z).length_squared() > 0.01:
			_turret.look_at(at, Vector3.UP)


func roll(metres: float) -> void:
	for i in _wheels.size():
		_wheels[i].rotation.x += metres / 0.72
		_spikes[i].rotation.x = _wheels[i].rotation.x
