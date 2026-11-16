class_name Pickup
extends Node3D
## Something lying on the map, with a soft coloured beacon so it can be found at night.

enum Kind { WEAPON, FOOD, ARROWS, POWER, WOOD }

const WEAPON_LIFE := 60.0
const ITEM_LIFE := 45.0
const FAMILIAR_LIFE := 80.0
const WOOD_LIFE := 150.0
const BLINK_TIME := 10.0
const SHUN_REACH := 3.2 # how far you walk from a weapon you put down before it can be picked up again

static var _beacon_mesh: CylinderMesh
static var _beacon_mats := {}
static var _wood: Mesh

var kind: int = Kind.WEAPON
var item_id := ""
var weapon_id := ""
var bonus_arrows := 0
var net_id := 0
var life := 45.0
var _spin: Node3D
var _beam: MeshInstance3D


static func _beacon_material(col: Color) -> StandardMaterial3D:
	if _beacon_mats.has(col):
		return _beacon_mats[col]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col, 0.15)
	_beacon_mats[col] = m
	return m


## For a weapon with its own ammunition, the throws it brings: a fresh one its full share, one that
## was put down what it had left (kept as throws + 1, so that 0 still means fresh).
func throws() -> int:
	if bonus_arrows <= 0:
		return WeaponDefs.own_ammo(weapon_id)
	return bonus_arrows - 1


func setup(k: int, id: String, bonus := 0) -> void:
	kind = k
	item_id = id
	bonus_arrows = bonus
	life = WEAPON_LIFE if k == Kind.WEAPON else ITEM_LIFE
	if k == Kind.POWER and PowerDefs.ALL[id]["familiar"]:
		life = FAMILIAR_LIFE
	if k == Kind.WOOD:
		life = WOOD_LIFE
	_spin = Node3D.new()
	_spin.position.y = 0.8
	add_child(_spin)
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var col := Color(1.0, 0.72, 0.2)
	match k:
		Kind.WEAPON:
			weapon_id = id
			mi.mesh = WeaponDefs.mesh(id)
			match id:
				"dagger": mi.scale = Vector3.ONE * 0.5
				"sword": mi.scale = Vector3.ONE * 0.5
				"crossbow": mi.scale = Vector3.ONE * 0.42
				"spear": mi.scale = Vector3.ONE * 0.5
				_: mi.scale = Vector3.ONE * 0.75
			if id == "dagger" or id == "sword" or id == "mace":
				mi.position.y = -0.3
		Kind.FOOD:
			mi.mesh = PowerDefs.mesh(id)
			mi.scale = Vector3.ONE * 1.1
			col = Color(0.5, 1.0, 0.5)
		Kind.ARROWS:
			mi.mesh = PowerDefs.mesh("arrows")
			mi.scale = Vector3.ONE * 1.0
			col = Color(0.92, 0.92, 0.92)
		Kind.POWER:
			mi.mesh = PowerDefs.mesh(id)
			mi.scale = Vector3.ONE * 1.5
			col = PowerDefs.ALL[id]["color"]
		Kind.WOOD:
			mi.mesh = _wood_mesh()
			col = Color(0.9, 0.62, 0.32)
	_spin.add_child(mi)
	if _beacon_mesh == null:
		_beacon_mesh = CylinderMesh.new()
		_beacon_mesh.top_radius = 0.05
		_beacon_mesh.bottom_radius = 0.28
		_beacon_mesh.height = 2.8
		_beacon_mesh.radial_segments = 6
		_beacon_mesh.rings = 1
		_beacon_mesh.cap_top = false
		_beacon_mesh.cap_bottom = false
	_beam = MeshInstance3D.new()
	_beam.mesh = _beacon_mesh
	_beam.material_override = _beacon_material(col)
	_beam.position.y = 1.4
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)


static func _wood_mesh() -> Mesh:
	if _wood == null:
		var l := LowPoly.new()
		var c := Color(0.5, 0.33, 0.18)
		for s: Vector3 in [Vector3(-0.15, 0, 0), Vector3(0.15, 0, 0), Vector3(0, 0.25, 0)]:
			l.prism(s + Vector3(0, 0, -0.5), s + Vector3(0, 0, 0.5), 0.14, 0.14, 6, c)
		l.box(Vector3(0, 0.05, 0), Vector3(0.5, 0.06, 0.1), Color(0.18, 0.14, 0.1))
		_wood = l.commit()
	return _wood


func display_name() -> String:
	match kind:
		Kind.WOOD: return "Wood"
		Kind.WEAPON: return WeaponDefs.ALL[weapon_id]["name"]
		Kind.FOOD: return PowerDefs.FOODS[item_id]["name"]
		Kind.ARROWS: return "Arrows"
	return PowerDefs.ALL[item_id]["name"]


func _process(delta: float) -> void:
	_spin.rotation.y += delta * 1.6
	life -= delta
	if life <= 0.0:
		var w := get_parent() as World
		if w:
			w.remove_pickup(self)
		return
	# Blinking warns that it is about to vanish, faster at the very end.
	if life < BLINK_TIME:
		var speed := 3.0 if life > 3.0 else 7.0
		_spin.visible = fmod(life * speed, 1.0) > 0.35
	# Hide the beacon up close, so the camera never ends up inside it.
	var cam := get_viewport().get_camera_3d()
	if cam:
		_beam.visible = global_position.distance_squared_to(cam.global_position) > 7.0
