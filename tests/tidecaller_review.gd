extends Node
## The Tidecaller as players will see it: dressed and holding its Trident from the front and behind, the
## tide bar on the HUD, Call the Tide rolling into a crowd, a Tidewarden in its Tide Shell and the shell
## bursting, a Stormcaller's Stormspear leaping between soaked enemies and its Maelstrom, and a
## Deepcaller's sea serpent rising, swaying and biting.
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
		if n is TideWave or n is StormArc or n is Maelstrom:
			n.queue_free()
	for a: Ally in w.allies.duplicate():
		w.remove_ally(a)
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
	# A Tidewarden in its Tide Shell, seen by another player, and the shell bursting.
	await clear()
	tidecaller(0, true, here)
	var warden := Avatar.new(w, 950, {"name": "", "class": "tidecaller", "team": 0})
	w.add_child(warden)
	warden.apply_pose(here, PI, 0.0, Vector3.ZERO, 1.0, 0, 0, "trident", 1.0)
	warden.teleport(here)
	warden.set_tide_shell(true)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		foe(here + Vector3(cos(a) * 2.6, 0, sin(a) * 2.6))
	await shot("tidecaller_shell", here + Vector3(2.6, 1.9, 3.4), here + Vector3(0, 1.0, 0), 0.8)
	await shot("tidecaller_shell_close", here + Vector3(1.2, 1.5, 2.0), here + Vector3(0, 1.1, 0), 0.2)
	TidecallerKit.raise_shell(p)
	p.global_position = here
	TidecallerKit.burst(p)
	warden.set_tide_shell(false)
	await shot("tidecaller_shell_burst", here + Vector3(4.5, 3.2, 5.0), here + Vector3(0, 0.6, 0), 0.12)
	warden.queue_free()
	# A Stormcaller's Stormspear, leaping from soaked enemy to soaked enemy.
	await clear()
	tidecaller(1, true, here)
	var line: Array[Zombie] = [foe(ground(0, 11)), foe(ground(2.2, 8)), foe(ground(-1.6, 6)), foe(ground(1.5, 4)), foe(ground(-2.5, 3))]
	for z: Zombie in line.slice(1):
		z.soak(TidecallerKit.SOAK_TIME)
	var caster := Avatar.new(w, 951, {"name": "", "class": "tidecaller", "team": 0})
	w.add_child(caster)
	caster.apply_pose(here, PI, 0.0, Vector3.ZERO, 1.0, 0, 0, "trident", 1.0)
	caster.teleport(here)
	await shot("tidecaller_soaked", here + Vector3(5.5, 2.4, -4.0), here + Vector3(0, 1.0, -9), 0.5)
	p.spears_thrown = 0
	TidecallerKit.stormspear(p)
	await shot("tidecaller_stormspear", here + Vector3(7, 3.4, -3), here + Vector3(0, 1.0, -8), 0.2)
	caster.queue_free()
	# Its Maelstrom over a crowd.
	await clear()
	tidecaller(1, true, here)
	var eye := ground(0, 10)
	for i in 6:
		var a := TAU * i / 6.0
		foe(eye + Vector3(cos(a) * 3.5, 0, sin(a) * 3.5))
	w.maelstrom(p.net_id(), eye)
	await shot("tidecaller_maelstrom", here + Vector3(9, 4.5, 6), eye + Vector3(0, 2.5, 0), 1.6)
	# A Deepcaller's sea serpent rising beside it, then going for a crowd.
	await clear()
	tidecaller(2, true, here)
	var deep := Avatar.new(w, 952, {"name": "", "class": "tidecaller", "team": 0})
	w.add_child(deep)
	deep.apply_pose(here, PI, 0.0, Vector3.ZERO, 1.0, 0, 0, "trident", 1.0)
	deep.teleport(here)
	TidecallerKit.call_of_the_deep(p)
	var serpent := TidecallerKit.serpent_of(p)
	serpent.set_physics_process(false)
	serpent.global_position = here + Vector3(1.6, 0, -2.2)
	serpent.global_position.y = w.ground_at(serpent.global_position)
	serpent.rotation.y = PI
	await shot("tidecaller_serpent_rising", here + Vector3(3.5, 1.6, 3.5), serpent.global_position + Vector3(0, 1.4, 0), 0.3)
	await shot("tidecaller_serpent", here + Vector3(4.2, 2.2, 3.2), serpent.global_position + Vector3(0, 1.6, 0), 1.0)
	await shot("tidecaller_serpent_close", serpent.global_position + Vector3(2.4, 2.4, -2.6), serpent.global_position + Vector3(0, 2.0, 0), 0.4)
	serpent.set_physics_process(true)
	for i in 3:
		foe(serpent.global_position + Vector3(-1.0 + i, 0, -2.0))
	await shot("tidecaller_serpent_bite", serpent.global_position + Vector3(4.5, 2.4, 1.0), serpent.global_position + Vector3(0, 1.2, -1.2), 0.62)
	deep.queue_free()
	await clear()
	hud.queue_free()
	await preload("res://tests/scene_cleanup.gd").finish(w)
