extends Node3D
## Photographs a map from above in daylight, to check how things are laid out.
## Args after --: output folder, then which maps: village fort sandbox.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	Game.quality = 2
	Game.apply_quality()
	Game.player_class = "infantry"
	var modes := {"village": Game.Mode.NIGHT, "fort": Game.Mode.FORT, "sandbox": Game.Mode.SANDBOX}
	var names: Array = args.slice(1) if args.size() > 1 else ["village", "fort", "sandbox"]
	for map: String in names:
		Game.mode = modes[map]
		var w := World.new()
		add_child(w)
		var t0 := Time.get_ticks_msec()
		w.setup(modes[map])
		print(map, " built in ", Time.get_ticks_msec() - t0, " ms")
		w.director.running = false
		for z: Zombie in w.zombies.duplicate():
			z.release()
		w.player.set_physics_process(false)
		w._apply_sky(1.0)
		w._env.fog_enabled = false
		w._env.ambient_light_color = Color.WHITE
		w._env.ambient_light_energy = 0.9
		w._moon.shadow_enabled = false
		w._moon.light_color = Color.WHITE
		w._moon.light_energy = 0.5
		w._moon.rotation_degrees = Vector3(-70, 20, 0)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.far = 400.0
		add_child(cam)
		cam.current = true
		for shot: Array in _shots(map):
			cam.size = shot[1]
			var c: Vector2 = shot[0]
			cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(c.x, 150, c.y))
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, map, shot[2]])
		cam.free()
		w.free()
		await get_tree().process_frame
	get_tree().quit()


func _shots(map: String) -> Array:
	match map:
		"village": return [[Vector2.ZERO, 225.0, "all"], [Vector2(0, -6), 100.0, "centre"]]
		"fort": return [[Vector2.ZERO, 225.0, "all"], [Vector2.ZERO, 70.0, "centre"]]
	return [[Vector2.ZERO, 90.0, "all"]]
