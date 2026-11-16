extends Node
var out: String
var w: World
func shot(label: String, at: Vector3, toward: Vector3) -> void:
	w.player.position = at - Vector3.UP * 1.5
	w.player.camera.global_position = at
	w.player.camera.look_at(toward)
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	for map_id: String in ["village", "mists"]:
		Game.night_map = map_id
		w = World.new()
		add_child(w)
		w.setup(Game.Mode.NIGHT)
		w.director.running = false
		w.player.set_physics_process(false)
		w.player.set_process(false)
		w.player.camera.cull_mask = 5
		for z: Zombie in w.zombies.duplicate(): z.release()
		if map_id == "village":
			await shot("river", Vector3(18, 5, 58), Vector3(28, 1.4, 70))
			var fire: Vector3 = w.fires[0]["at"]
			await shot("hearth", fire + Vector3(0, 2, 7), fire)
			# Register the farthest burners first: light priority must follow distance instead.
			w._burning.clear()
			var burners: Array[Zombie] = []
			for i in range(w._burn_lights.size() + 2, 0, -1):
				assert(w.spawn_zombie("normal", w.player.position + Vector3(3 * i, 0, 0)))
				var z: Zombie = w.zombies.back()
				z.set_physics_process(false)
				z.burn_time = 5
				burners.append(z)
				w.register_burning(z)
			w._tick_burn_lights()
			if OS.get_environment("LIGHTING_BASELINE") != "1":
				assert(w._lit_burning[0] == burners.back())
				assert(w._lit_burning.size() == w._burn_lights.size())
				burners.back().burn_time = 0
				w._tick_burn_lights()
				assert(not w._lit_burning.has(burners.back()))
		else:
			await shot("pool", Vector3(90, 51, -110), Vector3(90, 46, -122))
			await shot("mist_sea", Vector3(-56, 20, 4), Vector3(-100, 17, 8))
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Sfx.stop_all()
	await get_tree().create_timer(0.15).timeout
	print("Lighting review complete")
	get_tree().quit()
