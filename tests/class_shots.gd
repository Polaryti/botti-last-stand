extends Node
## Every class's body in a row, from the front, the side and behind.
##     godot --path . res://tests/class_shots.tscn -- OUT


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var view := SubViewport.new()
	view.own_world_3d = true
	view.size = Vector2i(1800, 420)
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
	cam.size = 3.6
	cam.position = Vector3(0, 1.3, 30)
	cam.current = true
	var ids: Array = ClassDefs.ALL.keys()
	var bodies: Array[Node3D] = []
	for i in ids.size():
		var id: String = ids[i]
		var body: Node3D = (load("res://assets/characters/%s.glb" % Avatar.MODELS.get(id, "clever")) as PackedScene).instantiate()
		view.add_child(body)
		ClassDefs.dress(body, id)
		body.scale = Vector3.ONE * 1.8 / float(Zombie.BODY_TOP.get(Avatar.MODELS.get(id, "clever"), 2.25))
		body.position.x = (i - (ids.size() - 1) * 0.5) * 1.3
		var anim: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
		anim.play("Idle")
		bodies.append(body)
	for shot: Array in [["front", 0.0], ["side", PI * 0.5], ["back", PI]]:
		for b in bodies:
			b.rotation.y = shot[1]
		for f in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
	get_tree().quit()
