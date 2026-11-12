extends Node
func _ready() -> void:
	var checks := 0
	for map_id: String in ["village", "fort", "mists"]:
		for i in 500:
			assert(SpawnRules.allows(WeaponDefs.ALL[WeaponDefs.pick_random(map_id)], map_id))
			assert(SpawnRules.allows(PowerDefs.ALL[PowerDefs.pick_familiar(map_id)], map_id))
			assert(SpawnRules.allows(ZombieDefs.ALL[ZombieDefs.pick_roamer(600, map_id)], map_id))
			checks += 3
	assert(ClassDefs.ALL.plague_doctor.hp == 100 and ClassDefs.ALL.plague_doctor.speed == 1.0)
	assert(ClassDefs.ALL.commander.speed == 1.05 and ClassDefs.ALL.artificer.hp == 100)
	assert(ClassDefs.ALL.heavy.weapon == "flail" and ClassDefs.ALL.artificer.weapon == "torch")
	Game.player_class = "monk"
	Game.quality = 0
	var m := Main.new()
	add_child(m)
	await get_tree().process_frame
	await m.start_game(Game.Mode.SANDBOX)
	m.world.director.running = false
	var p: Player = m.world.player
	p.set_physics_process(false)
	assert(p._vm_mesh.mesh != null and p._vm_left.mesh != null and p._vm_left.visible)
	p._cooldown = 0
	p.input_fire = true
	p._handle_fire()
	assert(p._swing < 1.0 and p.attack_count > 0)
	p.pose_weapon(p.weapon_def(), 0)
	var before := p._vm_root.transform
	p.pose_weapon(p.weapon_def(), 0.45)
	assert(before != p._vm_root.transform or not p._swing_side)
	Game.owned_items["rain_of_arrows"] = true
	m.show_armory("ranger")
	await get_tree().process_frame
	var panel := m.panel
	var detail: VBoxContainer = panel.get_meta("detail")
	var scroll: DragScroll = detail.find_children("*", "ScrollContainer", true, false)[0]
	scroll.scroll_to(120)
	var offset := scroll._pos
	var toggles := panel.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text in ["Equipped", "Not equipped"])
	assert(not toggles.is_empty())
	var toggle: Button = toggles[0]
	var old_text := toggle.text
	toggle.pressed.emit()
	await get_tree().process_frame
	assert(m.panel == panel and scroll._pos == offset and toggle.text != old_text)
	checks += 7
	print("MINOR UPDATE ESSENTIALS: ", checks, " checks passed")
	if not OS.get_cmdline_user_args().is_empty():
		# Capture the actual two-hand punch without playing a full match.
		m.panel.hide()
		p.pose_weapon(p.weapon_def(), 0.45)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("monk_punch_fixed.png"))
		m.show_codex()
		(m.panel as CodexPanel).show_tab(3)
		await get_tree().create_timer(0.2).timeout
		(m.panel as CodexPanel)._scroll.scroll_to(100000)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("map_exclusive_familiars.png"))
	await preload("res://tests/scene_cleanup.gd").finish(m)
