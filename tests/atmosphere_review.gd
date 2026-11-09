extends Node
## Capture the two grounded night profiles with their normal weather and lighting pipeline.
var out := ""

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.night_map = "village"
	Game.player_class = "infantry"
	for mode: int in [Game.Mode.NIGHT, Game.Mode.FORT]:
		Game.mode = mode
		var world := World.new()
		add_child(world)
		world.setup(mode)
		world.director.running = false
		for mob: Zombie in world.zombies.duplicate(): mob.release()
		world.player.set_physics_process(false)
		world.player._vm_root.visible = false
		var at := Vector3(12, 0, 20) if mode == Game.Mode.NIGHT else Vector3(0, 0, 21)
		at.y = world.ground_at(at)
		world.player.global_position = at
		var camera := world.player.camera
		camera.cull_mask = 5
		camera.global_position = at + Vector3.UP * 1.7
		camera.look_at(Vector3(0, world.ground_at(Vector3.ZERO) + 3, 0))
		await get_tree().create_timer(4.0).timeout
		await RenderingServer.frame_post_draw
		var name := "village_aura" if mode == Game.Mode.NIGHT else "fort_aura"
		get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		world.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Sfx.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
