class_name MistAtmosphere
extends Node3D
## Local night atmosphere. Every profile has a fixed particle budget independent of map size.
enum Place { MISTS, VILLAGE, FORT, MESENLLA }
var place := Place.MISTS
var world: World
var _follow := 0.0
var _wisps: CPUParticles3D
var _motes: CPUParticles3D

func _ready() -> void:
	_wisps = CPUParticles3D.new()
	_wisps.name = "GroundWisps"
	_wisps.amount = (8 if Game.quality == 0 else 18) if place in [Place.MISTS, Place.MESENLLA] else (5 if Game.quality == 0 else 10)
	_wisps.lifetime = 7.0
	_wisps.preprocess = 1.0
	_wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_wisps.emission_box_extents = Vector3(20, 1.2, 20)
	_wisps.direction = Vector3(1, 0.02, 0.3)
	_wisps.spread = 15.0
	_wisps.initial_velocity_min = 0.35
	_wisps.initial_velocity_max = 0.7
	_wisps.gravity = Vector3.ZERO
	_wisps.local_coords = false
	_wisps.scale_amount_min = 0.8
	_wisps.scale_amount_max = 1.6
	_wisps.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 20, 80))
	var quad := QuadMesh.new()
	quad.size = Vector2(9, 2.2)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/mist_wisp.gdshader")
	if place == Place.MESENLLA:
		material.set_shader_parameter("tint", Vector3(0.62, 0.5, 0.78))
		material.set_shader_parameter("opacity", 0.16)
	elif place != Place.MISTS:
		material.set_shader_parameter("tint", Vector3(0.27, 0.29, 0.34) if place == Place.VILLAGE else Vector3(0.29, 0.25, 0.21))
		material.set_shader_parameter("opacity", 0.10)
	quad.material = material
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	_wisps.color_ramp = fade
	_wisps.mesh = quad
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisps.emitting = false
	add_child(_wisps)
	_motes = CPUParticles3D.new()
	_motes.amount = (10 if Game.quality == 0 else 22) if place == Place.MESENLLA else (6 if Game.quality == 0 else 12)
	_motes.color_ramp = fade
	_motes.lifetime = 5.0
	_motes.preprocess = 1.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(12, 1.7, 12)
	_motes.gravity = Vector3(0, 0.04, 0)
	_motes.initial_velocity_min = 0.05
	_motes.initial_velocity_max = 0.15
	_motes.local_coords = false
	var mote := SphereMesh.new()
	mote.radius = 0.025
	mote.height = 0.05
	mote.radial_segments = 4
	mote.rings = 2
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.3, 0.75, 0.8) if place == Place.MISTS else Color(0.8, 0.65, 0.25) if place == Place.VILLAGE else Color(0.65, 0.95, 0.92) if place == Place.MESENLLA else Color(0.85, 0.34, 0.1)
	mote.material = glow
	_motes.mesh = mote
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.emitting = false
	add_child(_motes)

func _process(delta: float) -> void:
	_follow -= delta
	if _follow <= 0.0 and (world.player or world.menu_camera):
		_follow = 0.25
		var at := world.player.global_position if world.player else world.menu_camera.global_position
		global_position = Vector3(at.x, world.ground_at(at) + 0.65, at.z)
		var outside := true
		for room: Rect2 in world.indoors:
			if room.has_point(Vector2(at.x, at.z)): outside = false
		var night := world.director == null or world.director.dawn_amount() < 0.8
		_wisps.emitting = outside and night
		_motes.emitting = outside and night
