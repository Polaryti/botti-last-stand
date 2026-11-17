class_name HaulRope
extends Node3D
## A Harpooner's line, as everyone sees it: a hook flies from the thrower's hand to what it caught,
## then the rope stays taut between them while one is hauled to the other. Both ends follow what they
## are tied to (a player, another phone's avatar, a creature), or a fixed point if that is gone.

const FLY := 0.16 # seconds for the hook to reach what it was thrown at
const ROPE := Color(0.86, 0.76, 0.54) # pale hemp, to read against grass, sand and stone

var _from: Node3D
var _to: Node3D
var _from_at := Vector3.ZERO
var _to_at := Vector3.ZERO
var _life := 0.0
var _age := 0.0
var _line: MeshInstance3D
var _hook: MeshInstance3D
static var _line_mesh: Mesh
static var _hook_mesh: Mesh


## `from` and `to` are what the ends are tied to (either may be null, and then its point is used).
## `life`: how long the rope stays after the hook arrives.
static func create(world: Node3D, from: Node3D, from_at: Vector3, to: Node3D, to_at: Vector3, life: float) -> HaulRope:
	var r := HaulRope.new()
	r._from = from
	r._to = to
	r._from_at = from_at
	r._to_at = to_at
	r._life = FLY + clampf(life, 0.1, 2.0)
	world.add_child(r)
	return r


func _ready() -> void:
	top_level = true
	_line = MeshInstance3D.new()
	_line.mesh = line_mesh()
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_hook = MeshInstance3D.new()
	_hook.mesh = hook_mesh()
	_hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hook)
	_place()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_place()


## The hand of whoever threw it, or the middle of what it caught.
func _end(tied: Variant, fallback: Vector3, hand: bool) -> Vector3:
	if tied == null or not is_instance_valid(tied) or not (tied as Node3D).is_inside_tree():
		return fallback
	var node := tied as Node3D
	if node is Zombie and not (node as Zombie).is_alive():
		return fallback
	if node is Zombie:
		return (node as Zombie).centre()
	var at := node.global_position + Vector3.UP * (1.25 if hand else 1.0)
	if hand:
		var right := node.global_basis.x
		at += Vector3(right.x, 0, right.z).normalized() * 0.28
	return at


func _place() -> void:
	var a := _end(_from if is_instance_valid(_from) else null, _from_at, true)
	var b := _end(_to if is_instance_valid(_to) else null, _to_at, false)
	_from_at = a
	_to_at = b
	var tip := a.lerp(b, clampf(_age / FLY, 0.0, 1.0))
	var span := tip - a
	var length := span.length()
	if length < 0.05:
		_line.visible = false
		_hook.global_position = tip
		return
	_line.visible = true
	var basis := Basis.looking_at(span / length, Vector3.UP if absf(span.normalized().y) < 0.98 else Vector3.RIGHT)
	_line.global_transform = Transform3D(basis.scaled(Vector3(1, 1, length)), a)
	_hook.global_transform = Transform3D(basis, tip)


## A length of rope, one metre long along -Z from its start: scaled to fit between the ends.
static func line_mesh() -> Mesh:
	if _line_mesh == null:
		var l := LowPoly.new()
		l.prism(Vector3.ZERO, Vector3(0, 0, -1), 0.028, 0.028, 5, ROPE)
		_line_mesh = l.commit()
	return _line_mesh


## The iron hook at the end: a shank, a curve back each side, and barbed points.
static func hook_mesh() -> Mesh:
	if _hook_mesh == null:
		var l := LowPoly.new()
		var iron := Color(0.36, 0.38, 0.4)
		l.prism(Vector3(0, 0, 0.12), Vector3(0, 0, -0.1), 0.025, 0.02, 6, iron)
		l.prism(Vector3(0, 0, 0.12), Vector3(0, 0, 0.16), 0.04, 0.04, 6, iron.darkened(0.2))
		for side: float in [-1.0, 1.0]:
			l.prism(Vector3(0, 0, -0.1), Vector3(side * 0.1, 0, -0.04), 0.02, 0.018, 5, iron)
			l.prism(Vector3(side * 0.1, 0, -0.04), Vector3(side * 0.12, 0, 0.05), 0.018, 0.0, 4, iron.lightened(0.15))
		_hook_mesh = l.commit()
	return _hook_mesh
