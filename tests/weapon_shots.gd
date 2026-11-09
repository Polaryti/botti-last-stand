extends Node
## Reproducible first/third-person weapon captures: godot ... weapon_shots.tscn -- OUTPUT.
var out := ""
var w: World

func snap(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	seed(716)
	Game.player_class = "chivalry"
	Game.quality = 1
	Game.mode = Game.Mode.SANDBOX
	Game.force_weather = Weather.Kind.CLEAR
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.SANDBOX)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate():
		z.release()
	w._apply_sky(1.0)
	w._env.fog_enabled = false
	w._env.ambient_light_energy = 1.0
	var p := w.player
	p.dismount()
	p.global_position = Vector3(0, w.ground_at(Vector3.ZERO), 0)
	p.yaw = 0.0
	p.pitch = 0.0
	p.rotation.y = 0.0
	p.head.rotation.x = 0.0
	p.set_physics_process(false)
	p.set_process(false)
	for weapon: String in ["lance", "scythe", "flail", "bell_hammer", "bow", "longbow", "crossbow"]:
		p.class_id = "chivalry" if weapon == "lance" else "ranger"
		p.slots = [weapon, null]
		p.current = 0
		p.arrows = 30
		p._equip()
		p._switch_anim = 0.0
		p._reload = 1.0
		p._swing = 1.0
		p.pose_weapon(p.weapon_def(), p._swing)
		await get_tree().create_timer(0.15).timeout
		await snap(weapon + "_idle")
		p._cooldown = 0.0
		p.input_fire = true
		p._handle_fire()
		p.input_fire = false
		p._swing = 0.3
		p._reload = 0.05
		p.pose_weapon(p.weapon_def(), p._swing)
		await get_tree().create_timer(0.15).timeout
		await snap(weapon + "_strike")
	p._vm_root.visible = false
	var a := Avatar.new(w, 901, {"name": "", "class": "chivalry"})
	w.add_child(a)
	var at := Vector3(0, w.ground_at(Vector3(0, 0, -5)), -5)
	a.apply_pose(at, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 0, "lance", 1.0)
	a.teleport(at)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.global_position = at + Vector3(4, 2.2, -4)
	cam.look_at(at + Vector3(0, 1.0, -0.7))
	await snap("lance_remote_idle")
	a.apply_pose(at, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 1, "lance", 1.0)
	await get_tree().create_timer(0.22).timeout
	await snap("lance_remote_strike")
	a.show_statuses(128)
	a.apply_pose(at, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 2, "sword", 1.0)
	await get_tree().create_timer(0.2).timeout
	await snap("vanguard_banner")
	a.show_statuses(0)
	for id: String in ["bow", "longbow", "crossbow", "flail", "scythe"]:
		a._attack_seen = 0
		a.apply_pose(at, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 0, id, 1.0)
		a._hand.reload_left = 0.0
		a._attack_left = 0.0
		await get_tree().create_timer(0.1).timeout
		await snap(id + "_remote_idle")
		a.apply_pose(at, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 1, id, 1.0)
		await get_tree().create_timer(0.06).timeout
		await snap(id + "_remote_strike")
	a.visible = false
	w.spawn_zombie("hero_chivalry", at)
	var knight: Zombie = w.zombies.back()
	knight.set_physics_process(false)
	knight.rotation.y = PI
	await snap("fallen_knight_idle")
	knight._current_anim = ""
	knight._play(BodyAnim.attack_for("lance"), 1.2)
	await get_tree().create_timer(0.2).timeout
	await snap("fallen_knight_strike")
	knight.visible = false
	cam.current = false
	p.camera.current = true
	p.class_id = "commander"
	p.spec_id = "vanguard"
	p.slots = ["sword", null]
	p._equip()
	p._vm_root.visible = true
	p._refresh_banner()
	p._banner.rotation.z = 0.0
	await snap("vanguard_first_person")
	p._banner.rotation.z = 0.18
	await snap("vanguard_first_person_command")
	a.queue_free()
	w.queue_free()
	await get_tree().process_frame
	Sfx.stop_all()
	get_tree().quit()
