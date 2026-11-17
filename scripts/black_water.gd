class_name BlackWater
extends Node3D
## A Boatman's wake: a strip of still black water left along the skiff's path for a while. Enemies in
## it are slowed. Every phone shows it; the Boatman's own phone (or the host, for a bot) slows them.

const WIDTH := 2.4
const TICK := 0.25

var world: World
var owner_peer := 0
var a := Vector3.ZERO
var b := Vector3.ZERO
var left := 4.0
var _tick := 0.0
var _sheet: MeshInstance3D
static var _mat: StandardMaterial3D


func _init(w: World, peer: int, from: Vector3, to: Vector3, seconds: float) -> void:
	world = w
	owner_peer = peer
	a = from
	b = to
	left = seconds


func _ready() -> void:
	top_level = true
	_sheet = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WIDTH, 1.0)
	_sheet.mesh = plane
	_sheet.material_override = water_material()
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheet)
	var span := Vector3(b.x - a.x, 0, b.z - a.z)
	var mid := (a + b) * 0.5
	mid.y = world.ground_at(mid) + 0.06
	var look := Basis.looking_at(span.normalized(), Vector3.UP) if span.length() > 0.05 else Basis.IDENTITY
	_sheet.global_transform = Transform3D(look.scaled(Vector3(1, 1, span.length() + 1.0)), mid)


func owner_is_here() -> bool:
	if not Net.active():
		return true
	return owner_peer == Net.my_id() or (Net.is_host() and Net.is_bot(owner_peer))


func _physics_process(delta: float) -> void:
	left -= delta
	_sheet.transparency = 1.0 - clampf(left / 0.6, 0.0, 1.0)
	if left <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0 or not owner_is_here():
		return
	_tick = TICK
	var mid := (a + b) * 0.5
	for z: Zombie in world.zombies_near(mid, a.distance_to(b) * 0.5 + WIDTH, 30):
		if z.is_alive() and _in(z.position):
			z.slow(TICK * 2.0)


func _in(at: Vector3) -> bool:
	var p := Vector2(at.x, at.z)
	var s := Vector2(a.x, a.z)
	var seg := Vector2(b.x, b.z) - s
	var t := 0.0 if seg.length_squared() < 0.001 else clampf((p - s).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return p.distance_to(s + seg * t) <= WIDTH * 0.5


static func water_material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(0.04, 0.08, 0.1, 0.55)
		_mat.roughness = 0.05
		_mat.metallic_specular = 1.0
		_mat.emission_enabled = true
		_mat.emission = Color(0.06, 0.16, 0.16)
	return _mat
