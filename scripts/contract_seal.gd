class_name ContractSeal
extends Node3D
## A Mercenary's Contract (CrownUpgrades) over the creature it names: a gold coin stamped with a crossed
## dagger, turning slowly above its head, and a thin gold ring on the ground at its feet, so everyone in
## the dome can see which one is worth the price. Made on every phone; it goes when the dome does, or
## when the creature dies.

var _z: Zombie
var _left := 1.0
var _life := 1.0
var _coin: MeshInstance3D
var _ring: MeshInstance3D
static var _coin_mesh: Mesh
static var _ring_mesh: Mesh


func _init(z: Zombie, secs: float) -> void:
	_z = z
	_left = secs
	_life = maxf(secs, 0.1)
	top_level = true


func _ready() -> void:
	_coin = MeshInstance3D.new()
	_coin.mesh = coin_mesh()
	_coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coin)
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_shape()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(CrownUpgrades.COIN, 0.6)
	m.disable_fog = true
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_place(0.0)


## The coin: a thick gold disc with a raised rim, a dagger struck across its face on both sides, and a
## tab of red wax hanging under it. It stands on edge and turns about Y.
static func coin_mesh() -> Mesh:
	if _coin_mesh == null:
		var l := LowPoly.new()
		var gold := Color(1.0, 0.78, 0.3)
		var deep := Color(0.72, 0.5, 0.16)
		var face := Vector3(0, 0, 1)
		l.prism(-face * 0.04, face * 0.04, 0.3, 0.3, 14, gold)
		for side: float in [-1.0, 1.0]:
			l.prism(face * side * 0.035, face * side * 0.055, 0.3, 0.26, 14, deep)
			# The dagger: blade, guard and grip, raised off the face.
			l.box(face * side * 0.05 + Vector3(0.0, 0.05, 0), Vector3(0.05, 0.3, 0.025), Color(0.95, 0.9, 0.75))
			l.box(face * side * 0.05 + Vector3(0.0, -0.11, 0), Vector3(0.16, 0.035, 0.03), deep)
			l.box(face * side * 0.05 + Vector3(0.0, -0.17, 0), Vector3(0.04, 0.09, 0.03), Color(0.35, 0.2, 0.12))
		l.box(Vector3(0, -0.33, 0), Vector3(0.1, 0.1, 0.03), Color(0.7, 0.1, 0.1))
		l.box(Vector3(0, -0.39, 0), Vector3(0.06, 0.08, 0.02), Color(0.55, 0.06, 0.06), Vector3(0, 0, 18))
		_coin_mesh = l.commit()
	return _coin_mesh


static func _ring_shape() -> Mesh:
	if _ring_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		const PARTS := 32
		for i in PARTS:
			var a := TAU * i / PARTS
			var b := TAU * (i + 1) / PARTS
			var ia := Vector3(cos(a), 0, sin(a)) * 0.9
			var oa := Vector3(cos(a), 0, sin(a))
			var ib := Vector3(cos(b), 0, sin(b)) * 0.9
			var ob := Vector3(cos(b), 0, sin(b))
			for v: Vector3 in [ia, oa, ib, oa, ob, ib]:
				st.add_vertex(v)
		_ring_mesh = st.commit()
	return _ring_mesh


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(_z) or not _z.is_alive():
		queue_free()
		return
	_place(_life - _left)


func _place(now: float) -> void:
	var pop := clampf(now / 0.25, 0.0, 1.0) * clampf(_left / 0.3, 0.0, 1.0)
	var base := _z.global_position
	global_position = base
	_coin.position = Vector3.UP * (_z.height + 0.75 + 0.08 * sin(now * 3.0))
	_coin.rotation = Vector3(0, now * 2.2, 0)
	_coin.scale = Vector3.ONE * 1.5 * maxf(0.02, pop) * (1.0 + 0.4 * (1.0 - clampf(now / 0.25, 0.0, 1.0)))
	var r := maxf(0.6, _z.body_radius() * 1.3)
	_ring.position = Vector3.UP * 0.06
	_ring.scale = Vector3(r, 1.0, r) * (1.0 + 0.06 * sin(now * 4.0))
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.6 * pop
