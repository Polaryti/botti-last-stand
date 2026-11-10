class_name SnakeBody
extends Node3D
## A travelling body wave and a brief head strike, shared by local, remote and preview snakes.
static var shared_mesh: ArrayMesh
var moving := false
var biting := false
var phase := 0.0
var motion := 0.0
var bite := 0.0
var look: ShaderMaterial

func _init() -> void:
	if shared_mesh == null:
		var l := LowPoly.new()
		var green := Color(0.24, 0.42, 0.18)
		for i in 14:
			var z := 0.35 - i * 0.135
			var front := lerpf(0.085, 0.012, float(i) / 14)
			var back := lerpf(0.085, 0.012, float(i + 1) / 14)
			l.prism(Vector3(0, 0.1, z), Vector3(0, 0.1, z - 0.135), front, back, 6, green.lightened(0.06 if i % 2 else 0.0))
		l.box(Vector3(0, 0.1, 0.45), Vector3(0.2, 0.12, 0.28), green.darkened(0.12))
		for side: float in [-1, 1]:
			l.box(Vector3(side * 0.075, 0.16, 0.5), Vector3(0.035, 0.035, 0.045), Color(0.95, 0.78, 0.1))
			l.box(Vector3(side * 0.085, 0.165, 0.515), Vector3(0.012, 0.018, 0.012), Color(0.03, 0.04, 0.02))
		shared_mesh = l.commit()
	var body := MeshInstance3D.new()
	body.mesh = shared_mesh
	look = ShaderMaterial.new()
	look.shader = preload("res://assets/shaders/snake.gdshader")
	body.material_override = look
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.extra_cull_margin = 0.35
	add_child(body)

func reset_pose() -> void:
	moving = false
	biting = false
	phase = 0.0
	motion = 0.0
	bite = 0.0
	look.set_shader_parameter("phase", phase)
	look.set_shader_parameter("motion", motion)
	look.set_shader_parameter("bite", bite)

func _process(delta: float) -> void:
	motion = move_toward(motion, 1.0 if moving else 0.0, delta * 5.0)
	phase = fmod(phase + delta * lerpf(1.5, 10.0, motion), TAU * 20.0)
	bite = move_toward(bite, 1.0 if biting else 0.0, delta * (12.0 if biting else 6.0))
	look.set_shader_parameter("phase", phase)
	look.set_shader_parameter("motion", motion)
	look.set_shader_parameter("bite", bite)
