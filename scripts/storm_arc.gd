class_name StormArc
extends Node3D
## A Stormspear's flight and the leaps of its lightning: a spear of white-blue light that streaks from
## the hand to what it strikes, then jagged bolts from each struck enemy to the next, crackling (redrawn
## every few hundredths of a second) and fading, with a flash where each lands. Only a picture: what
## was struck was worked out on the Stormcaller's phone.

const LIFE := 0.42
const SPEAR_TIME := 0.08 # the spear's flight, before the first leap
const LEAP_GAP := 0.06 # each leap after the one before
const CRACKLE := 0.045

var points := PackedVector3Array()
var bolts_only := false # a Maelstrom's bolt from the cloud: no spear, the bolt at once
var _age := 0.0
var _crackle := 0.0
var _mesh: ImmediateMesh
var _view: MeshInstance3D
var _lights: Array[OmniLight3D] = []
var _open := false # a surface is begun: only once there is something to draw
static var _mat: StandardMaterial3D


func _init(through: PackedVector3Array, from_the_sky := false) -> void:
	points = through
	bolts_only = from_the_sky
	name = "StormArc"


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.no_depth_test = false
	_mesh = ImmediateMesh.new()
	_view = MeshInstance3D.new()
	_view.mesh = _mesh
	_view.material_override = _mat
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_view)
	for i in range(1, points.size()):
		var light := OmniLight3D.new()
		light.light_color = TidecallerKit.STORM
		light.omni_range = 5.0
		light.light_energy = 0.0
		light.position = points[i]
		add_child(light)
		_lights.append(light)
	_draw()


## When the segment from point i to i+1 is struck: the spear first, then each leap in turn.
func _struck_at(i: int) -> float:
	if bolts_only:
		return LEAP_GAP * i
	return SPEAR_TIME + LEAP_GAP * i if i > 0 else 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE + _struck_at(points.size() - 2):
		queue_free()
		return
	for i in _lights.size():
		var since := _age - _struck_at(i) - (SPEAR_TIME if i == 0 and not bolts_only else 0.0)
		_lights[i].light_energy = 3.0 * clampf(1.0 - since / 0.25, 0.0, 1.0) if since >= 0.0 else 0.0
	_crackle -= delta
	if _crackle <= 0.0:
		_crackle = CRACKLE
		_draw()


func _draw() -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam else Vector3.UP * 100.0
	_open = false
	for i in points.size() - 1:
		var start := _struck_at(i)
		var since := _age - start
		if since < 0.0:
			continue
		var a := points[i]
		var b := points[i + 1]
		var fade := clampf(1.0 - (since - 0.08) / (LIFE - 0.08), 0.0, 1.0)
		if fade <= 0.0:
			continue
		if i == 0 and not bolts_only:
			# The spear: a straight shaft of light that has flown as far as the time allows.
			var f := clampf(since / SPEAR_TIME, 0.0, 1.0)
			var tip := a.lerp(b, f)
			var tail := a.lerp(b, maxf(0.0, f - 0.45))
			_ribbon(tail, tip, eye, 0.16, Color(0.55, 0.8, 1.0) * fade)
			_ribbon(tail, tip, eye, 0.05, Color(1, 1, 1) * fade)
			if f >= 1.0:
				_bolt(a, b, eye, 0.05, fade * 0.6)
			continue
		_bolt(a, b, eye, 0.07, fade)
	if _open:
		_mesh.surface_end()


## A jagged bolt: the line broken into pieces each pushed aside at random, with a fainter branch.
func _bolt(a: Vector3, b: Vector3, eye: Vector3, wide: float, fade: float) -> void:
	var length := a.distance_to(b)
	var pieces := clampi(int(length / 0.55), 3, 14)
	var side := (b - a).cross(Vector3.UP).normalized()
	if side == Vector3.ZERO:
		side = Vector3.RIGHT
	var up := side.cross((b - a).normalized())
	var prev := a
	for k in range(1, pieces + 1):
		var f := float(k) / pieces
		var at := a.lerp(b, f)
		if k < pieces:
			var sway := length * 0.08 * sin(f * PI)
			at += side * randf_range(-sway, sway) + up * randf_range(-sway, sway) * 0.7
		_ribbon(prev, at, eye, wide * 5.0, Color(0.2, 0.45, 0.9) * fade * 0.45)
		_ribbon(prev, at, eye, wide * 2.4, Color(0.45, 0.75, 1.0) * fade * 0.7)
		_ribbon(prev, at, eye, wide, Color(0.95, 0.98, 1.0) * fade)
		if k == pieces / 2 and randf() < 0.7:
			var fork := at + (side * randf_range(-1, 1) + up * randf_range(-0.4, 0.8)).normalized() * length * 0.18
			_ribbon(at, fork, eye, wide * 0.6, Color(0.6, 0.85, 1.0) * fade * 0.7)
		prev = at


## A flat strip from a to b, turned to face the eye.
func _ribbon(a: Vector3, b: Vector3, eye: Vector3, wide: float, col: Color) -> void:
	var along := b - a
	if along.length_squared() < 0.0001:
		return
	var face := (eye - (a + b) * 0.5).normalized()
	var side := along.cross(face).normalized() * wide * 0.5
	if not _open:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_open = true
	var quad := [a - side, a + side, b + side, b - side]
	for i: int in [0, 1, 2, 0, 2, 3]:
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(quad[i])
