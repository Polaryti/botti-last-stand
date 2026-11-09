extends Node
var out := ""
var w: World
var cam: Camera3D

func snap(label: String, at: Vector3, toward: Vector3) -> void:
	w.player.global_position = at - Vector3.UP * 1.5
	cam.global_position = at
	cam.look_at(toward)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "infantry"
	Game.night_map = "mists"
	Game.mode = Game.Mode.NIGHT
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	w.player.set_physics_process(false)
	w.player.set_process(false)
	w.player._vm_root.visible = false
	cam = w.player.camera
	cam.current = true
	for z: Zombie in w.zombies.duplicate():
		z.release()
	await snap("arena_night", Vector3(0, 12, 26), Vector3(0, 14, -20))
	await snap("bridge_night", Vector3(-56, 20, 4), Vector3(-100, 17, 8))
	await snap("rotunda_night", Vector3(18, 22, -55), Vector3(0, 45, -122))
	await snap("stones_night", Vector3(-48, 21, -46), Vector3(-68, 24, -66))
	for i in 3:
		w.spawn_zombie(MistModels.KINDS[i], Vector3((i - 1) * 5, 10, 16))
		var z: Zombie = w.zombies.back()
		z.set_physics_process(false)
		z.rotation.y = 0.0
		z._animate_custom(0.1, 0.0)
	await snap("mist_enemies", Vector3(8, 13, 31), Vector3(0, 12, 16))
	var seal := MistSeal.create(w, Vector3(0, 10, 16), 9.0, 3.0, 10.0, 20.0, -1)
	seal.elapsed = 5.0
	await snap("regent_crown_warning", Vector3(14, 22, 32), Vector3(0, 10, 16))
	w.queue_free()
	await get_tree().process_frame
	Sfx.stop_all()
	get_tree().quit()
