class_name SoulBolt
extends Node3D
## A soul let go by a Psychopomp: a pale wisp that leaves its circle round them and arcs to an enemy (or
## back into them, to mend). Every phone sees it fly. The Psychopomp's own phone does what it does.

const FLIGHT := 0.5
const COLOUR := Color(0.8, 1.0, 0.94)

var world: World
var _by: Node3D
var _to: Node3D
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _age := 0.0
var _heals := false
var _bend := Vector3.ZERO
var _orb: MeshInstance3D


static func create(w: World, by: Node3D, target: Node3D, index: int, heals: bool) -> SoulBolt:
	var b := SoulBolt.new()
	b.world = w
	b._by = by
	b._to = target
	b._heals = heals
	var a := TAU * index / 6.0
	b._start = by.global_position + Vector3(cos(a) * 0.9, 1.5, sin(a) * 0.9)
	b._bend = Vector3(cos(a), 1.2, sin(a)) * 1.6
	b._age = -0.05 * index # one after another
	w.add_child(b)
	return b


func _ready() -> void:
	top_level = true
	_orb = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.28
	s.radial_segments = 8
	s.rings = 4
	_orb.mesh = s
	_orb.material_override = MesenllaModels.glow_material()
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)
	global_position = _start


func _target_point() -> Vector3:
	if _to and is_instance_valid(_to):
		_end = (_to as Zombie).centre() if _to is Zombie else _to.global_position + Vector3.UP * 1.1
	return _end


func _physics_process(delta: float) -> void:
	_age += delta
	if _age < 0.0:
		return
	var f := clampf(_age / FLIGHT, 0.0, 1.0)
	var end := _target_point()
	var mid := (_start + end) * 0.5 + _bend
	global_position = _start.lerp(mid, f).lerp(mid.lerp(end, f), f)
	if randf() < 0.15:
		world.fx_rise(global_position, COLOUR)
	if f >= 1.0:
		# Only the Psychopomp's own phone (or the host, for a bot) does what a soul does: there the soul
		# left a Player; on everyone else's, it left their avatar.
		if is_instance_valid(_by) and _by is Player:
			FerrymanKit.soul_lands(_by as Player, _to if _to and is_instance_valid(_to) else null, _heals)
		queue_free()
