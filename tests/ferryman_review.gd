extends Node
## The Ferryman as players will see it: dressed and holding its Oar from the front and behind, the
## skiff of a Crossing gliding through a crowd, a Tollkeeper demanding the toll with its obols on the
## HUD, a Boatman's black water, and a Psychopomp's souls circling it and flying out.
##     godot --path . res://tests/ferryman_review.tscn -- OUT
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
		if n is TideWave or n is StormArc or n is Maelstrom or n is BlackWater or n is FerrySkiff or n is SoulBolt:
			n.queue_free()
	await get_tree().process_frame


## The player as a Ferryman of the given path (-1 for none), standing at `at` and facing -Z.
func ferryman(spec: int, final: bool, at: Vector3) -> void:
	p.class_id = "ferryman"
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
	p.obols = 0
	p.set_souls(0)


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "ferryman"
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
	var origin := ground(-4, 12)
	var bodies: Array[Avatar] = []
	for i in 4:
		var a := Avatar.new(w, 900 + i, {"name": "", "class": "ferryman", "team": 0})
		w.add_child(a)
		var at := origin + Vector3((i - 1.5) * 1.5, 0, 0)
		at.y = w.ground_at(at)
		a.apply_pose(at, [PI, PI, PI * 0.5, 0.0][i], 0.0, Vector3.ZERO, 1.0, 0, 0, "oar", 1.0)
		a.teleport(at)
		bodies.append(a)
	await shot("ferryman_models", origin + Vector3(0, 1.4, 5.2), origin + Vector3(0, 1.0, 0), 0.8)
	await shot("ferryman_model_close", bodies[0].global_position + Vector3(0.3, 1.6, 1.8), bodies[0].global_position + Vector3(0, 1.35, 0), 0.3)
	await shot("ferryman_model_back", bodies[3].global_position + Vector3(-0.4, 1.7, 1.8), bodies[3].global_position + Vector3(0, 1.2, 0), 0.3)
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
	# The Crossing, seen from beside: the skiff mid-glide through a knot of them.
	ferryman(-1, false, here)
	for i in 3:
		foe(ground(-0.8 + i * 0.8, 15 - i))
	var rower := Avatar.new(w, 960, {"name": "", "class": "ferryman", "team": 0})
	w.add_child(rower)
	var to := p.leap_landing(here, Vector3.FORWARD, FerrymanKit.CROSS_REACH)
	FerrySkiff.create(w, rower, here, to, 2.0)
	await get_tree().create_timer(0.85).timeout
	var mid := here.lerp(to, 0.42)
	rower.apply_pose(mid + Vector3.UP * 0.3, PI, 0.0, Vector3.ZERO, 1.0, 0, 0, "oar", 1.0)
	rower.teleport(mid + Vector3.UP * 0.3)
	await shot("ferryman_crossing", mid + Vector3(6.5, 2.2, 1.5), mid + Vector3(0, 0.8, -1), 0.05)
	rower.queue_free()
	# A Tollkeeper's toll, with obols held: first person, the HUD showing them.
	await clear()
	ferryman(0, true, here)
	p.obols = 3
	for i in 3:
		foe(ground(-1.5 + i * 1.5, 15))
	FerrymanKit.demand_the_toll(p)
	cam.current = false
	p.camera.current = true
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ferryman_toll_hud.png"))
	p.camera.current = false
	cam.current = true
	# A Boatman's wake of black water.
	await clear()
	ferryman(1, true, here)
	w.black_water(p.net_id(), here, to, 8.0)
	for i in 2:
		foe(ground(0.5 - i, 15 - i * 3))
	await shot("ferryman_black_water", here + Vector3(5, 3.5, 3), here.lerp(to, 0.5), 0.4)
	# A Psychopomp: souls circling it, then sent out at the enemies.
	await clear()
	ferryman(2, true, here)
	var guide := Avatar.new(w, 961, {"name": "", "class": "ferryman", "team": 0})
	w.add_child(guide)
	guide.apply_pose(here, PI, 0.0, Vector3.ZERO, 1.0, 0, 0, "oar", 1.0)
	guide.teleport(here)
	guide.set_souls(6)
	await shot("ferryman_souls", here + Vector3(2.6, 2.0, 2.8), here + Vector3(0, 1.2, 0), 0.6)
	for i in 3:
		foe(ground(-2 + i * 2, 12))
	p.set_souls(6)
	FerrymanKit.guide_the_souls(p)
	guide.set_souls(0)
	await shot("ferryman_souls_go", here + Vector3(5, 3, 2), here + Vector3(0, 1.4, -5), 0.32)
	guide.queue_free()
	await clear()
	hud.queue_free()
	await preload("res://tests/scene_cleanup.gd").finish(w)
