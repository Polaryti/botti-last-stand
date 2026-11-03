extends Node
## Pictures of Defend the Fort and of this version's other new things. Args: output folder.
var out := ""
var w: World
var pl: Player


func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
	print(n, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " tris=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func view(n: String, at: Vector3, yaw: float, pitch := 0.0, height := 0.0) -> void:
	pl.global_position = Vector3(at.x, w.ground_at(at) + height, at.z)
	pl.yaw = yaw
	pl.rotation.y = yaw
	pl.pitch = pitch
	pl.head.rotation.x = pitch
	await wait(0.15)
	await snap(n)


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	Game.player_class = "heavy"
	var m: Main = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(0.6)
	await snap("menu")
	m.show_together()
	await wait(0.1)
	await m.start_game(Game.Mode.FORT)
	w = m.world
	pl = w.player
	pl.set_physics_process(false)
	w.director.running = false
	w.director._stock_timer = 9999.0
	w.director._familiar_timer = 9999.0
	for z: Zombie in w.zombies.duplicate():
		z.release()
	await wait(0.3)
	await view("start", Vector3(3, 0, 11), 0.3)
	await view("gate_outside", Vector3(0, 0, -44), PI)
	await view("gate_inside", Vector3(0, 0, -14), 0.0)
	await view("stairs", Vector3(-24, 0, -20), -1.2)
	await view("wall_top", Vector3(-14, 0, -26), -PI * 0.5, -0.12, 6.5)
	await view("small_door", Vector3(-15, 0, -33), PI)
	await view("keep_door", Vector3(0, 0, 13), 0.0)
	await view("heart", Vector3(3, 0, 5), 0.5, -0.1)
	var g: Dictionary = w.fort.gates[0]
	g["hp"] = Fort.GATE_HP * 0.55
	w.fort._show_gate(g)
	pl.wood = 6
	await view("gate_hurt", Vector3(0, 0, -19), 0.0)
	w.fort.hit_gate(g, 99999.0, g["at"])
	await view("gate_broken", Vector3(0, 0, -17), 0.0)
	var wood := w.spawn_pickup_at(Vector3(-46, 0, 2), Pickup.Kind.WOOD, "wood")
	await view("wood", Vector3(-46, 0, 7), 0.0, 0.1)
	w.remove_pickup(wood)
	w._apply_sky(1.0)
	w._env.fog_enabled = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 80.0
	cam.far = 500.0
	add_child(cam)
	cam.global_position = Vector3(0, 200, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	w._sky_root.visible = false
	await wait(0.2)
	await snap("above")
	w._apply_sky(0.0)
	w._env.fog_enabled = true
	w._sky_root.visible = true
	cam.current = false
	cam.queue_free()
	pl.camera.current = true
	# The village: light and glows, the rider, the fog.
	await m.start_game(Game.Mode.NIGHT)
	w = m.world
	pl = w.player
	pl.camera.current = true
	pl.set_physics_process(false)
	w.director.running = false
	w.director._stock_timer = 9999.0
	w.director._familiar_timer = 9999.0
	for z: Zombie in w.zombies.duplicate():
		z.release()
	for it: Pickup in w.pickups.duplicate():
		w.remove_pickup(it)
	await wait(0.3)
	await view("light_bonfire", Vector3(4, 0, 1), -0.75)
	await view("light_bridge", Vector3(-6, 0, 47), PI)
	w.spawn_zombie("rider", Vector3(0, 0, 24))
	var r: Zombie = w.zombies[-1]
	r.set_physics_process(false)
	r.rotation.y = PI
	await view("rider", Vector3(0, 0, 18), PI)
	r.release()
	pl.global_position = Vector3(0, 0.05, 30)
	w.fx_mist(Vector3(0, 1, 26), 1.9)
	w.fx_mist(Vector3(2, 1, 24), 1.4)
	w.fx_mist(Vector3(-2, 0.8, 22), 1.0)
	await wait(0.25)
	pl.fog_flash = 0.5
	await view("fog", Vector3(0, 0, 30), 0.0)
	w.fx_dome(Vector3(0, 0.5, 24), 6.0, 3.0)
	await view("dome", Vector3(0, 0, 34), 0.0)
	get_tree().quit()
