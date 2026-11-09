extends Node
## Review both maps and the complete artillery timeline with the actual renderer.
var out := ""

func snap(name: String) -> void:
	# Keep sky geometry centred on the review camera, as World._process does in normal play.
	var camera := get_viewport().get_camera_3d()
	for node: Node in get_children():
		if node is World:
			(node as World)._sky_root.global_position = camera.global_position
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("CAPTURE ", name, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " tris=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.apply_quality()
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "commander"
	for map_id: String in ["village", "mists", "fort"]:
		Game.night_map = map_id
		var w := World.new()
		add_child(w)
		w.setup(Game.Mode.FORT if map_id == "fort" else Game.Mode.NIGHT)
		w.director.running = false
		w.director.set_process(false)
		w.set_process(false)
		w.player.set_physics_process(false)
		w.player.set_process(false)
		w.player._vm_root.visible = false
		for z: Zombie in w.zombies.duplicate():
			z.release()
		var cam := w.player.camera
		cam.far = 550
		cam.fov = 72
		for c: Dictionary in w.caches.caches:
			if c["title"] == "Mist cache":
				continue
			var at: Vector3 = c["at"]
			w._apply_sky(1.0)
			cam.global_position = at + (Vector3(-9, 5, 10) if "Millers" in c["title"] else Vector3(9, 5, 12))
			cam.look_at(at + Vector3.UP * 1.6)
			await snap(map_id + "_" + str(c["title"]).to_snake_case().replace("’", ""))
			w._apply_sky(0.0)
			await snap(map_id + "_night_" + str(c["title"]).to_snake_case().replace("’", ""))
		w._env.fog_enabled = false
		w._apply_sky(1.0)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 355 if map_id == "mists" else 240
		cam.global_position = Vector3(0, 260, 0)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		await snap(map_id + "_above")
		if map_id == "village":
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.global_position = Vector3(15, 16, 33)
			var at := Vector3(0, w.ground_at(Vector3(0, 0, 20)), 20)
			cam.look_at(at + Vector3.UP * 2)
			var field := CommandField.new()
			w.add_child(field)
			field.setup(w, 1, "gunner", at)
			field.set_physics_process(false)
			field._physics_process(2.0)
			await snap("artillery_warning")
			for i in 18:
				field._physics_process(0.25)
			await snap("artillery_impacts")
			for i in 12:
				field._physics_process(0.25)
			await snap("artillery_lingering_fire")
		w.queue_free()
		await get_tree().process_frame
	await load("res://tests/scene_cleanup.gd").finish(self)
