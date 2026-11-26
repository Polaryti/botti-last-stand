extends Node
## Visual review of Al'quimelea: coming down (m_rise), floating, each of its attacks as it gathers them,
## half gone (its second face open), and dying. Stepped frame by frame.
## godot --path . res://tests/god_review.tscn -- OUT_DIR
const STEP := 1.0 / 30.0
var w: World
var cam: Camera3D


func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	Game.mode = Game.Mode.NIGHT
	Game.night_map = "fontanova"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	w.director.set_process(false)
	for z: Zombie in w.zombies.duplicate(): z.release()
	for n in w.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false
	w.player.set_physics_process(false)
	w.player.camera.current = false
	cam = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.fov = 50
	w._apply_sky(1.0)
	var spot := Vector3(-8, 0, 52)
	spot.y = w.ground_at(spot)
	w.player.position = spot + Vector3(0, 0, 22)
	w.player.position.y = w.ground_at(w.player.position)
	w.spawn_zombie("alquimelea", spot)
	var god: Zombie = w.zombies.back()
	god.set_physics_process(false)
	god.position = spot
	god.rotation.y = 0.0
	god.reset_physics_interpolation()
	var frames: Array[Image] = []
	var plan := [["m_rise", 0.4], ["m_rise", 1.6], ["", 3.0], ["m_cast", 0.9], ["m_slam", 0.45], ["m_slam", 0.9], ["m_sweep", 1.2], ["m_ink", 0.8], ["m_roar", 0.9]]
	for step: Array in plan:
		god._current_anim = step[0]
		god.mesenlla_warning = step[0] != ""
		var t := 0.0
		while t < float(step[1]):
			god._animate_custom(STEP, 0.0)
			w.now += STEP
			t += STEP
		frames.append(await _shot(god, spot, 0.5))
	# Close: its face, crucible and arms.
	frames.append(await _shot(god, spot, 2.6, 13.0, 8.5))
	# Half gone: its second face open.
	god.hp = god.max_hp * 0.4
	god._current_anim = ""
	god.mesenlla_warning = false
	for k in 60:
		god._animate_custom(STEP, 0.0)
		w.now += STEP
	frames.append(await _shot(god, spot, -0.9, 14.0, 8.0))
	# Dying.
	god.take_damage(god.hp + 100000.0, Vector3.ZERO, 0.0, god.centre())
	var t := 0.0
	for at: float in [0.5, 1.8, 2.7, 3.8, 5.2]:
		while t < at:
			god._physics_process(STEP)
			t += STEP
		frames.append(await _shot(god, spot, 0.5))
	var cols := 5
	var rows := int(ceil(frames.size() / float(cols)))
	var sheet := Image.create(cols * 640, rows * 360, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var im := frames[i]
		im.convert(Image.FORMAT_RGB8)
		im.resize(640, 360)
		sheet.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i((i % cols) * 640, (i / cols) * 360))
	sheet.save_png(out.path_join("god_review.png"))
	get_tree().quit()


func _shot(god: Zombie, spot: Vector3, side: float, far := 24.0, high := 6.5) -> Image:
	god.reset_physics_interpolation()
	var c := spot + Vector3.UP * high
	cam.position = c + Vector3(sin(side), 0.05, cos(side)).normalized() * far
	cam.look_at(c)
	for p in w.find_children("*", "Pickup", true, false):
		(p as Node3D).visible = false
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
