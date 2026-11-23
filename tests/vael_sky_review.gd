extends Node
## Visual review of the Port Vael flyers, their attack tells, recovery and impacts.
## godot --path . res://tests/vael_sky_review.tscn -- OUT
var w: World
var camera: Camera3D
var out := ""
var flyers: Array[Zombie] = []

func snap(label: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.mode = Game.Mode.NIGHT
	Game.night_map = "vael"
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
	camera.fov = 58
	w._apply_sky(0.0)
	var y := w.ground_at(Vector3(0, 0, 24))
	w.player.position = Vector3(0, y, 24)
	for i in VaelSkyMind.KINDS.size():
		w.spawn_zombie(VaelSkyMind.KINDS[i], Vector3((i - 1) * 5.0, y, 16))
		var z: Zombie = w.zombies.back()
		z.set_physics_process(false)
		z.position.y = y + 2.5
		z.rotation.y = 0.2
		flyers.append(z)
		var label := Label3D.new()
		label.text = str(z.def["name"])
		label.position = Vector3(0, 2.3, 0)
		label.font_size = 40
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		z.add_child(label)
	camera.position = Vector3(0, y + 6.4, 31)
	camera.look_at(Vector3(0, y + 3, 16))
	for z: Zombie in flyers: z._animate_custom(0.16, 3)
	await snap("vael_flyers_glide")
	for z: Zombie in flyers:
		z.mesenlla_warning = true
		z._current_anim = "m_cast"
		z._animate_custom(0.3, 0)
	await snap("vael_flyers_tell")
	for z: Zombie in flyers:
		camera.position = z.position + Vector3(-3, 1.8, 5.2)
		camera.look_at(z.position + Vector3.UP * 0.7)
		await snap(z.type_id + "_tell")
	camera.position = Vector3(0, y + 7.5, 31)
	camera.look_at(Vector3(0, y + 1.8, 18))
	for z: Zombie in flyers:
		z.position.y = y + 0.8
		z.mesenlla_warning = false
		z._current_anim = "m_throw"
		z._animate_custom(0.1, 0)
		var mind := z.mesenlla_mind as VaelSkyMind
		mind.aim = Vector3(z.position.x, y, 21)
		mind.heading = Vector3.FORWARD
		mind._release(z)
	for seal: MistSeal in w.mist_seals: seal.set_physics_process(false)
	await snap("vael_flyers_impacts")
	for seal: MistSeal in w.mist_seals: seal.strike()
	await snap("vael_flyers_strike")
	await preload("res://tests/scene_cleanup.gd").finish(w)
