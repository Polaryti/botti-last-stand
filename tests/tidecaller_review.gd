extends Node
## The Tidecaller as players will see it: dressed and holding its Trident from the front and behind, the
## tide bar on the HUD, Call the Tide rolling into a crowd, a Wavebreaker's Tsunami, a Deepsinger's
## Deep Song drawing enemies in, and a Fogbinder's fog bound round them.
##     godot --path . res://tests/tidecaller_review.tscn -- OUT
var out := ""
var w: World
var cam: Camera3D
var p: Player
var hud: Hud


func shot(label: String, from: Vector3, toward: Vector3, wait := 0.3) -> void:
	cam.global_position = from
	cam.look_at(toward)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func ground(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, w.ground_at(Vector3(x, 0, z)) + up, z)


func foe(at: Vector3) -> Zombie:
	w.spawn_zombie("normal", at)
	var z: Zombie = w.zombies.back()
	z.position = at
	z.hp = 5000.0
	z.max_hp = 5000.0
	z.look_at(Vector3(p.global_position.x, at.y, p.global_position.z), Vector3.UP, true)
	z.stun(30.0) # it stands and takes it, so the picture is of what is done to it
	return z


func clear() -> void:
	for z: Zombie in w.zombies.duplicate(): z.release()
	for l: RigLine in w.rig_lines.duplicate(): w.remove_rig_line(l)
	for n: Node in w.get_children():
		if n is DeepSong or n is FogBank or n is TideWave:
			n.queue_free()
	await get_tree().process_frame


## The player as a Tidecaller of the given path (-1 for none), standing at `at` and facing -Z, full of tide.
func tidecaller(spec: int, final: bool, at: Vector3) -> void:
	p.class_id = "tidecaller"
	p.points = 9
	p.level = 10 if final else 5
	p.chosen.clear()
	p.flags.clear()
	p.mods = Player.BASE_MODS.duplicate()
	p.spec_id = ""
	if spec >= 0:
		for step in (9 if final else 4):
			p.choose_ability(step, spec if step == 3 else 0)
	p.global_position = at
	p.yaw = 0.0
	p.rotation.y = 0.0
	p.pitch = 0.0
	p.camera.rotation = Vector3.ZERO
	p.art_cd_left = 0.0
	p.mana = p.max_mana()


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "tidecaller"
	Game.mode = Game.Mode.SANDBOX
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.SANDBOX)
	w.director.running = false
	w._apply_sky(1.0)
	await clear()
	p = w.player
	p.set_physics_process(false)
	p.set_process(false)
	p.camera.current = false
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 50.0
	# Dressed and holding the Trident: from the front, the side and behind.
	var origin := ground(-4, 12)
	var bodies: Array[Avatar] = []
	for i in 4:
		var a := Avatar.new(w, 900 + i, {"name": "", "class": "tidecaller", "team": 0})
		w.add_child(a)
		var at := origin + Vector3((i - 1.5) * 1.5, 0, 0)
		at.y = w.ground_at(at)
		a.apply_pose(at, [PI, PI, PI * 0.5, 0.0][i], 0.0, Vector3.ZERO, 1.0, 0, 0, "trident", 1.0)
		a.teleport(at)
		bodies.append(a)
	await shot("tidecaller_models", origin + Vector3(0, 1.4, 5.2), origin + Vector3(0, 1.0, 0), 0.8)
	await shot("tidecaller_model_close", bodies[0].global_position + Vector3(0.3, 1.6, 1.6), bodies[0].global_position + Vector3(0, 1.35, 0), 0.3)
	await shot("tidecaller_model_back", bodies[3].global_position + Vector3(-0.4, 1.7, 1.7), bodies[3].global_position + Vector3(0, 1.2, 0), 0.3)
	for a: Avatar in bodies:
		a.queue_free()
	hud = Hud.new()
	hud.theme = UiTheme.make()
	hud.player = p
	hud.director = w.director
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var here := ground(0, 20)
	# Call the Tide into a crowd, seen from beside it, and the HUD with its tide.
	tidecaller(-1, false, here)
	for i in 4:
		foe(ground(-1.5 + i, 12 - (i % 2) * 1.5))
	cam.current = false
	p.camera.current = true
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("tidecaller_hud.png"))
	p.camera.current = false
	cam.current = true
	TidecallerKit.call_the_tide(p)
	await shot("tidecaller_wave", here + Vector3(6, 2.6, -2), here + Vector3(0, 0.6, -6), 0.32)
	await shot("tidecaller_wave_struck", here + Vector3(6, 2.6, -2), here + Vector3(0, 0.6, -9), 0.35)
	# A Wavebreaker's Tsunami.
	await clear()
	tidecaller(0, true, here)
	p.waves_called = TidecallerKit.TSUNAMI_EVERY - 1
	for i in 5:
		foe(ground(-3 + i * 1.5, 10))
	TidecallerKit.call_the_tide(p)
	await shot("tidecaller_tsunami", here + Vector3(9, 3.5, 1), here + Vector3(0, 0.8, -7), 0.4)
	# A Deepsinger's song, drawing them in.
	await clear()
	tidecaller(1, true, here)
	for i in 5:
		var a := TAU * i / 5.0
		foe(here + Vector3(cos(a) * 7.0, 0, sin(a) * 7.0))
	TidecallerKit.deep_song(p)
	var singer := Avatar.new(w, 950, {"name": "", "class": "tidecaller", "team": 0})
	w.add_child(singer)
	singer.apply_pose(here, PI, 0.0, Vector3.ZERO, 1.0, 0, 0, "trident", 1.0)
	singer.teleport(here)
	await shot("tidecaller_song", here + Vector3(0, 9, 11), here, 1.1)
	singer.queue_free()
	# A Fogbinder's fog, bound round a knot of them.
	await clear()
	tidecaller(2, true, here)
	var at := TidecallerKit.fog_point(p)
	for i in 4:
		foe(at + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))
	TidecallerKit.bind_the_fog(p)
	await shot("tidecaller_fog", here + Vector3(7, 4, 2), at, 0.6)
	await clear()
	hud.queue_free()
	await preload("res://tests/scene_cleanup.gd").finish(w)
