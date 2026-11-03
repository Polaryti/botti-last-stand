extends Node
## Renders reference screenshots and scene cost numbers.
## Args after --: output folder, quality (0-2).

var out := "user://"


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print(name, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" tris=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func place(pl: Player, at: Vector3, yaw: float, pitch := 0.0) -> void:
	pl.global_position = at
	pl.yaw = yaw
	pl.rotation.y = yaw
	pl.pitch = pitch
	pl.head.rotation.x = pitch


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	Game.quality = int(args[1]) if args.size() > 1 else 2
	Game.apply_quality()
	Game.player_class = "magician"
	var m: Node = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(1.0)
	await snap("menu")
	m.show_settings()
	await wait(0.2)
	await snap("settings")
	m.show_codex()
	await wait(0.2)
	await snap("codex_enemies")
	(m.panel as CodexPanel).show_tab(1)
	await wait(0.2)
	await snap("codex_enemies2")
	(m.panel as CodexPanel).show_tab(4)
	await wait(0.2)
	await snap("codex_weapons")
	m.show_changelog()
	await wait(0.2)
	await snap("changelog")
	Game.doubloons = 372
	m.show_store()
	await wait(0.2)
	await snap("store")
	m.show_class_picker(Game.Mode.NIGHT)
	await wait(0.2)
	await snap("classes")
	var t0 := Time.get_ticks_msec()
	await m.start_game(Game.Mode.NIGHT)
	print("game build ms=", Time.get_ticks_msec() - t0)
	var w: World = m.world
	var pl: Player = w.player
	w.director.running = false
	w.director._stock_timer = 99999.0
	w.director._familiar_timer = 99999.0
	for z: Zombie in w.zombies.duplicate():
		z.release()
	await wait(0.5)
	await snap("hud_start")
	pl.points = 12
	m.toggle_tree()
	await wait(0.3)
	await snap("tree_start")
	for i in 6:
		pl.choose_ability(i, 0 if i != Player.CORE_STEPS else 2)
	m.tree_panel.refresh(true)
	await wait(0.3)
	await snap("tree_branch")
	m.toggle_tree()
	# A moment of a fight: hit markers, health bars, the hurt arc and a level-up.
	place(pl, Vector3(0, 0, 14), 0.0)
	var a1 := w.zombies.size()
	w.spawn_zombie("hero_heavy", Vector3(-2, 0, 8))
	w.spawn_zombie("normal", Vector3(2, 0, 8))
	for z: Zombie in w.zombies:
		z.set_physics_process(false)
		z.rotation.y = 0.0
	w.zombies[a1 + 1].take_damage(30.0, Vector3.ZERO, 0.0, Vector3(2, 1, 8))
	w.zombies[a1].take_damage(60.0, Vector3.ZERO, 0.0, Vector3(-2, 1, 8))
	w.zombies[a1].state = Zombie.State.CHASE
	await wait(0.15)
	pl.hurt(5.0, pl.global_position + Vector3(6, 0, 2))
	pl.level_flash = 0.7
	pl.level = 8
	var nearby := w.spawn_pickup_at(Vector3(3, 0, 10.5), Pickup.Kind.WEAPON, "scythe")
	await wait(0.2)
	await snap("fight")
	w.remove_pickup(nearby)
	pl.level_flash = 0.0
	pl.hurt_dir_time = 0.0
	for z: Zombie in w.zombies.duplicate():
		z.set_physics_process(true)
		z.release()
	var line := {"normal": Vector3(-6, 0, 8), "clever": Vector3(-4.3, 0, 8), "leaper": Vector3(-2.6, 0, 8), "hero_heavy": Vector3(-0.9, 0, 8), "hero_chivalry": Vector3(0.9, 0, 8),
		"wraith": Vector3(2.6, 0, 8), "banshee": Vector3(4.3, 0, 8), "scarecrow": Vector3(6, 0, 8)}
	for id: String in line:
		w.spawn_zombie(id, line[id])
	for z: Zombie in w.zombies:
		z.set_physics_process(false)
		z.rotation.y = 0.0
	await wait(0.3)
	await snap("enemies_a")
	for z: Zombie in w.zombies.duplicate():
		z.set_physics_process(true)
		z.release()
	var line2 := {"crow": Vector3(-4, 3.2, 8), "gargoyle": Vector3(-1, 0.1, 8), "mimic": Vector3(3, 0, 9)}
	for id: String in line2:
		w.spawn_zombie(id, line2[id])
	for z: Zombie in w.zombies:
		z.dormant = false
		if z._lure:
			z._lure.visible = false
			z._beam.visible = false
			z._visual.visible = true
			(z._visual.get_meta("lid") as Node3D).rotation.x = -0.7
		z.set_physics_process(false)
		z.position = line2[z.type_id]
		z.rotation.y = 0.0
	await wait(0.3)
	await snap("enemies_b")
	for z: Zombie in w.zombies.duplicate():
		z.set_physics_process(true)
		z.release()
	w.spawn_ally("wolf", Vector3(-2.5, 0, 9), 99.0)
	w.spawn_ally("decoy", Vector3(0, 0, 9), 99.0)
	w.spawn_ally("mirror", Vector3(2.5, 0, 9), 99.0)
	w.place_trap(pl, Vector3(0.5, 0, 11.5))
	for id: String in ["speed", "sensor", "angel", "raven", "ghost", "rat"]:
		pl.activate_power(id)
	await wait(0.4)
	await snap("allies_powers")
	pl.powers.clear()
	for k: String in pl._familiars.keys():
		pl._familiars[k].queue_free()
	pl._familiars.clear()
	for a: Ally in w.allies.duplicate():
		a.life = 0.01
		w.remove_ally(a)
	# Sunrise, looking toward the sun.
	w.director.running = true
	for d: float in [0.0, 0.35, 0.65, 1.0]:
		w.director.elapsed = Game.NIGHT_LENGTH - Director.DAWN_GLOW * (1.0 - d) - 0.01
		place(pl, Vector3(-3, 0, 24), deg_to_rad(30.0), 0.1)
		w._apply_sky(d)
		w.director.running = false
		w._apply_sky(d)
		await wait(0.2)
		await snap("sun_%d" % int(d * 100))
		place(pl, Vector3(8, 0, 2), deg_to_rad(170.0), 0.02)
		await wait(0.15)
		if d >= 0.6:
			await snap("sun_back_%d" % int(d * 100))
	get_tree().quit()
