extends Node
## The creatures of Mesenlla side by side, from the front, the side and behind, and a few of them in
## the middle of a special move.
##     godot --path . res://tests/creature_shots.tscn -- OUT

const ROW := ["woods_child", "bear", "mist_bear", "shapeshifter", "eagle", "mist_eagle", "earth_elemental", "mist_elemental", "storm_elemental", "wyvern"]
const BIG := ["great_revenant_elemental", "war_wyvern", "mount"]


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var view := SubViewport.new()
	view.own_world_3d = true
	view.size = Vector2i(1900, 520)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.24, 0.27, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.86, 0.8)
	env.ambient_light_energy = 0.75
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-40, 35, 0)
	lamp.light_energy = 1.1
	view.add_child(lamp)
	var cam := Camera3D.new()
	view.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.6
	cam.position = Vector3(0, 1.9, 30)
	cam.current = true
	var bodies := _line(view, ROW, 1.95)
	for shot: Array in [["front", 0.0], ["side", PI * 0.5], ["back", PI]]:
		for b in bodies:
			b.rotation.y = shot[1]
		await _snap(view, "%s/creatures_%s.png" % [out, shot[0]])
	for b in bodies:
		b.queue_free()
	cam.size = 7.5
	cam.position = Vector3(0, 2.8, 30)
	bodies = _line(view, BIG, 6.0)
	for shot: Array in [["front", 0.0], ["side", PI * 0.5]]:
		for b in bodies:
			b.rotation.y = shot[1]
		await _snap(view, "%s/creatures_big_%s.png" % [out, shot[0]])
	get_tree().quit()


func _line(view: SubViewport, ids: Array, gap: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in ids.size():
		var id: String = ids[i]
		var body: Node3D
		if id == "woods_child":
			body = (load("res://assets/characters/normal_b.glb") as PackedScene).instantiate()
			var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
			var gear := MesenllaModels.child_gear()
			gear["head2"] = MesenllaModels.child_eyes()
			for key: String in gear:
				var a := BoneAttachment3D.new()
				a.bone_name = "head" if key == "head2" else key
				skeleton.add_child(a)
				var mi := MeshInstance3D.new()
				mi.mesh = gear[key]
				a.add_child(mi)
			body.scale = Vector3.ONE * 0.8 * 1.8 / 2.25
			var anim: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
			anim.play("Idle")
		elif id == "mount":
			body = Node3D.new()
			var bear := MesenllaModels.bear_mount()
			bear.rotation.y = PI
			body.add_child(bear)
		else:
			body = MesenllaModels.build(id)
		if id in ["eagle", "mist_eagle"]:
			body.position.y = 1.0
		view.add_child(body)
		body.position.x = (i - (ids.size() - 1) * 0.5) * gap
		out.append(body)
	return out


func _snap(view: SubViewport, path: String) -> void:
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(path)
