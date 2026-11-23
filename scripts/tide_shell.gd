class_name TideShell
extends Node3D
## A Tide Shell round someone: a bubble of seawater with light running over it, a ring of foam where
## it meets the ground, and drops of water circling inside it. It thins as it is spent and flickers
## when it is nearly gone. On your own body (seen from the eyes) only the foam and the drops show, so
## it never stands between you and the fight.

const RADIUS := 1.05
const FADE := 0.3

var own_view := false
var _fill := 1.0
var _shown := 0.0
var _age := 0.0
var _bubble: MeshInstance3D
var _foam: MeshInstance3D
var _drops: Array[MeshInstance3D] = []
static var _shader: Shader
static var _bubble_mesh: SphereMesh
static var _foam_mesh: TorusMesh
static var _drop_mesh: SphereMesh
static var _drop_mat: StandardMaterial3D
static var _foam_mat: StandardMaterial3D


func _init(seen_from_inside := false) -> void:
	own_view = seen_from_inside
	name = "TideShell"


func _ready() -> void:
	_make_assets()
	_bubble = MeshInstance3D.new()
	_bubble.mesh = _bubble_mesh
	var m := ShaderMaterial.new()
	m.shader = _shader
	_bubble.material_override = m
	_bubble.position = Vector3.UP * 1.0
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.visible = not own_view
	add_child(_bubble)
	_foam = MeshInstance3D.new()
	_foam.mesh = _foam_mesh
	_foam.material_override = _foam_mat
	_foam.position = Vector3.UP * 0.06
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foam)
	for i in 5:
		var d := MeshInstance3D.new()
		d.mesh = _drop_mesh
		d.material_override = _drop_mat
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		_drops.append(d)
	scale = Vector3.ONE * 0.2


func set_fill(f: float) -> void:
	_fill = clampf(f, 0.0, 1.0)


func gone() -> bool:
	return _fill <= 0.0 and _shown <= 0.01


func _process(delta: float) -> void:
	_age += delta
	var parent := get_parent()
	if parent is Player and (parent as Player).dead:
		_fill = 0.0
	var want := 1.0 if _fill > 0.0 else 0.0
	_shown = move_toward(_shown, want, delta / (0.18 if want > 0.0 else FADE))
	# It swells into being with a little overshoot, and shrinks a touch as it is spent.
	var pop := 1.0 + sin(minf(_age * 9.0, PI)) * 0.12 * (1.0 if _age < 0.35 else 0.0)
	var size := (0.82 + 0.18 * _fill) * pop * maxf(0.05, _shown)
	scale = Vector3.ONE * size
	var low := _fill < 0.3
	var flicker := 0.55 + 0.45 * absf(sin(_age * 22.0)) if low else 1.0
	(_bubble.material_override as ShaderMaterial).set_shader_parameter("strength", _shown * (0.45 + 0.55 * _fill) * flicker)
	_foam.rotation.y = _age * 0.8
	_foam_mat.albedo_color.a = 0.75 * _shown
	for i in _drops.size():
		var a := _age * (1.6 + i * 0.13) + TAU * i / _drops.size()
		var r := RADIUS * (0.78 if own_view else 0.86)
		_drops[i].position = Vector3(cos(a) * r, 0.5 + 0.8 * (0.5 + 0.5 * sin(_age * 1.3 + i * 1.7)), sin(a) * r)
		_drops[i].visible = _shown > 0.2 and (not low or (i + int(_age * 6.0)) % 2 == 0)


static func _make_assets() -> void:
	if _shader != null:
		return
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform float strength = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float ripple = sin(w.y * 9.0 - t * 3.2 + sin(w.x * 4.0 + t) * 1.6) * 0.5 + 0.5;
	float caustic = pow(sin(w.x * 7.0 + t * 1.7) * sin(w.z * 7.0 - t * 1.3) * 0.5 + 0.5, 3.0);
	vec3 deep = vec3(0.06, 0.32, 0.36);
	vec3 bright = vec3(0.55, 1.0, 0.92);
	float glow = rim * 0.9 + ripple * 0.08 + caustic * 0.22;
	ALBEDO = mix(deep, bright, clamp(rim + caustic * 0.5, 0.0, 1.0)) * glow * strength;
}
"""
	_bubble_mesh = SphereMesh.new()
	_bubble_mesh.radius = RADIUS
	_bubble_mesh.height = RADIUS * 2.0
	_bubble_mesh.radial_segments = 24
	_bubble_mesh.rings = 12
	_foam_mesh = TorusMesh.new()
	_foam_mesh.inner_radius = RADIUS * 0.82
	_foam_mesh.outer_radius = RADIUS * 1.02
	_foam_mesh.rings = 24
	_foam_mesh.ring_segments = 6
	_foam_mat = StandardMaterial3D.new()
	_foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam_mat.albedo_color = Color(0.86, 1.0, 0.98, 0.75)
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.05
	_drop_mesh.height = 0.12
	_drop_mesh.radial_segments = 6
	_drop_mesh.rings = 3
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_mat.albedo_color = Color(0.62, 1.0, 0.95)
