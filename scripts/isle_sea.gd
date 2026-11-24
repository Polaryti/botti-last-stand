class_name IsleSea
extends Node3D
## The sea round an island of the archipelago (Fontanova): clear and blue-green in the shallows,
## dark far out, lapping white on the beaches, and out to the horizon on every side.
## It does not come and go like Port Vael's tide. Wading slows you, down to SLOW chest-deep; out past
## Terrain.ISLE_DROWN deep the water closes over your head, and after GRACE seconds there you start
## to drown (DROWN health a second) until you get back to where you can stand (Player).

const SLOW := 0.55
const SLOW_DEPTH := 1.2
const GRACE := 2.5
const DROWN := 12.0
const CELL := 2.0

var world: World
var level := Terrain.ISLE_SEA_Y
var _mat: ShaderMaterial
var _water: MeshInstance3D


func _init(owner_world: World) -> void:
	world = owner_world
	name = "IsleSea"


func _ready() -> void:
	_build_water()


## How deep the sea is here (0 on dry land).
func depth_at(at: Vector3) -> float:
	return maxf(0.0, level - world.terrain.ground_height(at.x, at.z))


## Over your head: you cannot stand here, and the sea will drown you.
func too_deep(at: Vector3) -> bool:
	return depth_at(at) > Terrain.ISLE_DROWN


## How much the water slows you here: 1 on dry land, down to SLOW chest-deep.
func slow_at(at: Vector3) -> float:
	var d := depth_at(at)
	if d <= 0.1:
		return 1.0
	return lerpf(1.0, SLOW, clampf(d / SLOW_DEPTH, 0.0, 1.0))


## The sea brightens with the dawn.
func set_dawn(k: float) -> void:
	if _mat:
		_mat.set_shader_parameter("dawn", k)


func _build_water() -> void:
	var t := world.terrain
	var half := float(t.half_extent)
	var side := int(half * 2.0 / CELL)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in side:
		for i in side:
			var x0 := -half + i * CELL
			var z0 := -half + j * CELL
			var corners := [Vector2(x0, z0), Vector2(x0 + CELL, z0), Vector2(x0 + CELL, z0 + CELL), Vector2(x0, z0 + CELL)]
			var lowest := INF
			for c: Vector2 in corners:
				lowest = minf(lowest, t.ground_height(c.x, c.y))
			if lowest > level + 0.05:
				continue
			for k: int in [0, 1, 2, 0, 2, 3]:
				var c: Vector2 = corners[k]
				st.set_uv2(Vector2(t.ground_height(c.x, c.y), 0.0))
				st.set_uv(c * 0.1)
				st.add_vertex(Vector3(c.x, 0.0, c.y))
	# Out past the edge of the map, open sea to the horizon on every side.
	var far := 900.0
	var e := half - 1.0
	var quads: Array = [
		[Vector2(-far, -far), Vector2(far, -far), Vector2(far, -e), Vector2(-far, -e)],
		[Vector2(-far, e), Vector2(far, e), Vector2(far, far), Vector2(-far, far)],
		[Vector2(-far, -e), Vector2(-e, -e), Vector2(-e, e), Vector2(-far, e)],
		[Vector2(e, -e), Vector2(far, -e), Vector2(far, e), Vector2(e, e)]]
	for q: Array in quads:
		for k: int in [0, 1, 2, 0, 2, 3]:
			var c: Vector2 = q[k]
			st.set_uv2(Vector2(Terrain.ISLE_FLOOR - 4.0, 0.0))
			st.set_uv(c * 0.1)
			st.add_vertex(Vector3(c.x, 0.0, c.y))
	_water = MeshInstance3D.new()
	_water.name = "IsleWater"
	_water.mesh = st.commit()
	_water.extra_cull_margin = 4.0
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/tide_sea.gdshader")
	# The Mediterranean at night: deep blue far out, turquoise over the sand, little mist on it.
	_mat.set_shader_parameter("level", level)
	_mat.set_shader_parameter("deep", Vector3(0.02, 0.06, 0.13))
	_mat.set_shader_parameter("shallow", Vector3(0.1, 0.33, 0.36))
	_mat.set_shader_parameter("mist", Vector3(0.3, 0.42, 0.55))
	_mat.set_shader_parameter("foam", Vector3(0.85, 0.92, 0.95))
	_mat.set_shader_parameter("coastal", 1.0)
	_water.material_override = _mat
	add_child(_water)
