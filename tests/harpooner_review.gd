extends Node
## The Harpooner as players will see it: dressed and armed from the front and behind, Haul's rope in
## flight and a creature hauled in, a Reaver's Blood in the Water with both buttons on the HUD, a
## Rigger's lines (and Cat's Cradle) tripping what crosses them, and a Great Harpoon through a line of foes.
##     godot --path . res://tests/harpooner_review.tscn -- OUT
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
	await get_tree().process_frame


## The player as a Harpooner of the given path (-1 for none), standing at `at` and facing -Z.
func harpooner(spec: int, final: bool, at: Vector3) -> void:
	p.class_id = "harpooner"
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
	p.path_art_cd_left = 0.0


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "harpooner"
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
	# Dressed and armed: Harpoon, Boarding Hook, from the front, the side and behind.
	var origin := ground(-4, 12)
	var bodies: Array[Avatar] = []
	for i in 4:
		var a := Avatar.new(w, 900 + i, {"name": "", "class": "harpooner", "team": 0})
		w.add_child(a)
		var at := origin + Vector3((i - 1.5) * 1.5, 0, 0)
		at.y = w.ground_at(at)
		a.apply_pose(at, [PI, PI, PI * 0.5, 0.0][i], 0.0, Vector3.ZERO, 1.0, 0, 0, ["harpoon", "boarding_hook", "harpoon", "harpoon"][i], 1.0)
		a.teleport(at)
		bodies.append(a)
	await shot("harpooner_models", origin + Vector3(0, 1.4, 5.2), origin + Vector3(0, 1.0, 0), 0.8)
	await shot("harpooner_model_close", bodies[0].global_position + Vector3(0.3, 1.6, 1.6), bodies[0].global_position + Vector3(0, 1.35, 0), 0.3)
	await shot("harpooner_model_back", bodies[3].global_position + Vector3(-0.4, 1.7, 1.7), bodies[3].global_position + Vector3(0, 1.2, 0), 0.3)
	for a: Avatar in bodies:
		a.queue_free()
	# The HUD, as a Reaver: Haul, and Blood in the Water on the second button.
	hud = Hud.new()
	hud.theme = UiTheme.make()
	hud.player = p
	hud.director = w.director
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var here := ground(0, 20)
	harpooner(0, false, here)
	cam.current = false
	p.camera.current = true
	var bait := foe(ground(0.6, 7))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("harpooner_hud_ready.png"))
	# Haul: the rope in flight, then the creature dragged in.
	HarpoonerKit.haul(p)
	await get_tree().create_timer(0.1).timeout
	p.camera.current = false
	cam.current = true
	await shot("harpooner_haul_rope", here + Vector3(4.5, 2.4, 2.5), here + Vector3(0, 1.0, -6.5), 0.0)
	await shot("harpooner_hauled", here + Vector3(4.5, 2.4, 2.5), here + Vector3(0, 1.0, -3.0), 0.5)
	# Hauled to something too big to move: the Harpooner flies along its own rope.
	await clear()
	harpooner(0, false, here)
	var brute := foe(ground(0, 6))
	brute._scale = 1.6
	p.set_physics_process(true)
	HarpoonerKit.haul(p)
	await shot("harpooner_haul_self", here + Vector3(5.5, 2.0, -6.0), here + Vector3(0, 1.0, -8.0), 0.12)
	p.set_physics_process(false)
	brute._scale = 1.0
	# Blood in the Water, in first person, with both buttons on the HUD.
	await clear()
	harpooner(0, true, here)
	HarpoonerKit.blood_in_the_water(p)
	var fresh := foe(ground(-1.0, 16))
	cam.current = false
	p.camera.current = true
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("harpooner_blood_hud.png"))
	p.camera.current = false
	cam.current = true
	# A Rigger's lines, Cat's Cradle tying them together, and something tripping on one.
	await clear()
	p._buffs.clear()
	hud.visible = false
	harpooner(1, true, here)
	HarpoonerKit.rig_a_line(p)
	p.global_position = here + Vector3(6, 0, 1)
	p.global_position.y = w.ground_at(p.global_position)
	p.yaw = 0.25
	p.rotation.y = 0.25
	HarpoonerKit.rig_a_line(p)
	var lines := w.rig_lines.filter(func(l: RigLine) -> bool: return not l.cradle)
	if not lines.is_empty():
		var first: RigLine = lines[0]
		var on := first.a.lerp(first.b, 0.55)
		var tripper := foe(Vector3(on.x, w.ground_at(on), on.z))
		await get_tree().create_timer(0.15).timeout
	await shot("harpooner_rig_lines", here + Vector3(-7, 5.5, 4), here + Vector3(3, 0.3, -8), 0.3)
	await shot("harpooner_rig_close", here + Vector3(-2.5, 1.2, -4.5), here + Vector3(0.5, 0.4, -9), 0.1)
	# Great Harpoon, through a line of three.
	await clear()
	harpooner(2, true, here)
	for i in 3:
		var z := foe(ground(0.3 * i, 10 + i * 4))
	HarpoonerKit.great_harpoon(p)
	await shot("harpooner_great_harpoon", here + Vector3(5, 2.2, -4), here + Vector3(0, 1.2, -9), 0.08)
	await shot("harpooner_great_marked", here + Vector3(4, 2.4, -6), here + Vector3(0, 1.0, -14), 0.6)
	hud.queue_free()
	await preload("res://tests/scene_cleanup.gd").finish(w)
