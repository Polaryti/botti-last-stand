class_name SoulRing
extends Node3D
## The souls a Psychopomp has gathered, circling them at shoulder height: on their own phone round the
## player, on everyone else's round their avatar. Only the count is shared.

const RADIUS := 0.9
var count := 0
var _wisps: Array[MeshInstance3D] = []
var _age := 0.0
static var _wisp_mesh: Mesh


func set_count(n: int) -> void:
	count = n
	while _wisps.size() < n:
		var w := MeshInstance3D.new()
		w.mesh = wisp_mesh()
		w.material_override = MesenllaModels.glow_material()
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(w)
		_wisps.append(w)
	for i in _wisps.size():
		_wisps[i].visible = i < n
	visible = n > 0


func _process(delta: float) -> void:
	if count <= 0:
		return
	_age += delta
	for i in count:
		var a := _age * 1.6 + TAU * i / maxf(count, 1)
		_wisps[i].position = Vector3(cos(a) * RADIUS, 1.35 + sin(_age * 3.0 + i) * 0.12, sin(a) * RADIUS)


static func wisp_mesh() -> Mesh:
	if _wisp_mesh == null:
		var s := SphereMesh.new()
		s.radius = 0.09
		s.height = 0.22
		s.radial_segments = 8
		s.rings = 4
		_wisp_mesh = s
	return _wisp_mesh
