extends Node
var w: World
var camera: Camera3D
var out: String
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.night_map = "vael"
	Game.mode = Game.Mode.NIGHT
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate(): z.release()
	w.player.set_physics_process(false)
	w.player.camera.current = false
	camera = Camera3D.new()
	w.add_child(camera)
	camera.current = true
	w._apply_sky(0.0)
	for id: String in ["hollow_sovereign", "kraken_arm", "leviathan", "brine_hound", "angler", "siren"]:
		var at := Vector3(0, w.ground_at(Vector3(0,0,40)), 40)
		w.spawn_zombie(id, at)
		var z: Zombie = w.zombies.back()
		z.set_physics_process(false)
		z.position = at
		z.rotation.y = 0
		var tall := 6.0 if id == "leviathan" else 3.0 if id in ["hollow_sovereign", "kraken_arm"] else 1.0
		camera.position = at + Vector3(-tall*1.8, tall*1.2, tall*3.5)
		camera.look_at(at+Vector3.UP*tall)
		z._current_anim = ""
		if id == "angler": z._visual.set_meta("buried", false)
		for i in 30: z._animate_custom(1.0/60, 2)
		await snap(id+"_coastal_idle")
		z.mesenlla_warning = true
		z._current_anim = "Raise" if id == "hollow_sovereign" else "m_slam" if id in ["kraken_arm","leviathan"] else "m_song" if id == "siren" else "m_bite"
		for i in 40: z._animate_custom(1.0/60, 0)
		await snap(id+"_coastal_tell")
		z.release()
	await preload("res://tests/scene_cleanup.gd").finish(w)
func snap(label: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
