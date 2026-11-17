class_name FerrySkiff
extends Node3D
## The Ferryman's skiff, as everyone sees it: a pale, half-there boat with a lantern on a pole at its
## stern, gliding over the ground from where the Crossing set off to where it grounds, a little mist
## curling off its keel, then fading. It carries no one itself: the Ferryman's own phone moves them.

const FADE := 0.35
const GHOST := Color(0.72, 0.9, 0.86)

var world: World
var from := Vector3.ZERO
var to := Vector3.ZERO
var time := 0.45
var _age := 0.0
var _boat: MeshInstance3D
var _light: OmniLight3D
var _mist := 0.0
static var _hull: Mesh
static var _mat: StandardMaterial3D


static func create(w: World, _by: Node3D, start: Vector3, end: Vector3, seconds: float) -> FerrySkiff:
	var s := FerrySkiff.new()
	s.world = w
	s.from = start
	s.to = end
	s.time = maxf(0.1, seconds)
	w.add_child(s)
	return s


func _ready() -> void:
	top_level = true
	_boat = MeshInstance3D.new()
	_boat.mesh = hull_mesh()
	_boat.material_override = ghost_material()
	_boat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_boat)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.85, 1.0, 0.92)
	_light.light_energy = 1.4
	_light.omni_range = 5.0
	_light.position = Vector3(0, 1.7, 1.2)
	add_child(_light)
	_place()


func _process(delta: float) -> void:
	_age += delta
	if _age >= time + FADE:
		queue_free()
		return
	_place()
	_mist -= delta
	if _mist <= 0.0 and _age < time:
		_mist = 0.06
		world.fx_mist(global_position + Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.6, 0.6)), 0.7)


func _place() -> void:
	var f := clampf(_age / time, 0.0, 1.0)
	var at := from.lerp(to, f)
	at.y = world.ground_at(at) + 0.05 + sin(f * PI) * 0.15
	var dir := Vector3(to.x - from.x, 0, to.z - from.z)
	var look := Basis.looking_at(dir.normalized(), Vector3.UP) if dir.length() > 0.05 else Basis.IDENTITY
	global_transform = Transform3D(look, at)
	var fade := 1.0 - clampf((_age - time) / FADE, 0.0, 1.0)
	_boat.transparency = 1.0 - fade * 0.75
	_light.light_energy = 1.4 * fade


## A narrow boat about 3 m long, pointed at both ends, -Z forward: a keel, planked sides that rise to
## the prow and stern, two thwarts, and the lantern pole at the stern with its lamp.
static func hull_mesh() -> Mesh:
	if _hull == null:
		var l := LowPoly.new()
		var wood := Color(0.75, 0.9, 0.86)
		var dark := Color(0.5, 0.66, 0.64)
		var steps := 8
		for i in steps:
			var z0 := -1.5 + 3.0 * i / steps
			var z1 := -1.5 + 3.0 * (i + 1) / steps
			var zm := (z0 + z1) * 0.5
			var beam := 0.55 * (1.0 - pow(absf(zm) / 1.5, 2.0))
			var rise := 0.38 + pow(absf(zm) / 1.5, 3.0) * 0.4
			l.box(Vector3(0, 0.08, zm), Vector3(beam * 1.6, 0.08, z1 - z0 + 0.01), dark)
			for side: float in [-1.0, 1.0]:
				l.box(Vector3(side * beam * 0.85, rise * 0.55, zm), Vector3(0.05, rise, z1 - z0 + 0.01), wood, Vector3(0, 0, -side * 14))
		for z: float in [-0.5, 0.45]:
			l.box(Vector3(0, 0.36, z), Vector3(0.9, 0.05, 0.16), wood)
		l.prism(Vector3(0, 0.1, 1.3), Vector3(0, 1.9, 1.35), 0.025, 0.02, 6, dark)
		l.prism(Vector3(0, 1.88, 1.35), Vector3(0, 1.88, 1.1), 0.015, 0.015, 4, dark)
		l.prism(Vector3(0, 1.62, 1.1), Vector3(0, 1.82, 1.1), 0.08, 0.06, 6, Color(0.95, 1.0, 0.9))
		_hull = l.commit()
	return _hull


static func ghost_material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(1, 1, 1, 0.7)
		_mat.emission_enabled = true
		_mat.emission = GHOST * 0.45
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat
