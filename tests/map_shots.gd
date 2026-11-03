extends Node
## Pictures of the map: one from above in daylight, then views from the ground at each place.
## Args after --: output folder, quality.

const VIEWS := [
	["square", Vector3(0, 0, 8), 0.0, 0.0],
	["square_back", Vector3(0, 0, -7), 3.14, 0.0],
	["north_road", Vector3(1, 0, -18), 0.0, 0.0],
	["east_road", Vector3(14, 0, 1), -1.57, 0.0],
	["west_road", Vector3(-14, 0, -1), 1.57, 0.0],
	["south_road", Vector3(-1, 0, 16), 3.14, 0.0],
	["castle_road", Vector3(-27, 0, -52), 1.2, 0.1],
	["castle_gate", Vector3(-44, 0, -70), 1.57, 0.05],
	["castle_yard", Vector3(-58, 0, -58), 2.2, 0.0],
	["keep", Vector3(-78, 0, -76), -0.8, 0.0],
	["castle_view", Vector3(-58, 0, -56), 1.0, -0.1],
	["graveyard", Vector3(44, 0, -66), 0.0, 0.0],
	["crypt", Vector3(55, 0, -84), 3.14, 0.0],
	["bridge_south", Vector3(0, 0, 46), 3.14, 0.0],
	["on_bridge", Vector3(0, 0, 64), 3.14, -0.05],
	["river", Vector3(18, 0, 57), -2.6, -0.1],
	["bridge_east", Vector3(58, 0, 0), -1.57, 0.0],
	["ford", Vector3(-52, 0, 52), 3.14, -0.05],
	["water_mill", Vector3(12, 0, 79), -1.9, 0.0],
	["windmill", Vector3(90, 0, 22), 3.3, 0.14],
	["farm", Vector3(2, 0, 84), 3.14, -0.02],
	["wheat", Vector3(-34, 0, 21), 3.14, 0.0],
	["in_wheat", Vector3(-35, 0, 30), 3.14, 0.0],
	["corn", Vector3(34, 0, 25), 3.14, 0.0],
	["garden", Vector3(36, 0, -19), 3.14, -0.2],
	["orchard", Vector3(-72, 0, 8), 1.4, 0.0],
	["hills", Vector3(-34, 0, 2), 1.57, 0.06],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	Game.quality = int(args[1]) if args.size() > 1 else 2
	Game.apply_quality()
	Game.mode = Game.Mode.NIGHT
	Game.player_class = "infantry"
	var t0 := Time.get_ticks_msec()
	var w := World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	print("map build ms=", Time.get_ticks_msec() - t0)
	w.director.running = false
	w.director.set_process(false)
	for z: Zombie in w.zombies.duplicate():
		z.release()
	var p := w.player
	p.set_physics_process(false)
	for pu: Pickup in w.pickups.duplicate():
		w.remove_pickup(pu)
	w._apply_sky(0.0)
	for v: Array in VIEWS:
		var at: Vector3 = v[1]
		p.global_position = Vector3(at.x, w.ground_at(at), at.z)
		p.yaw = v[2]
		p.rotation.y = v[2]
		p.pitch = v[3]
		p.head.rotation.x = v[3]
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
		print(v[0], " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " tris=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	# From above, in daylight, without fog.
	w._apply_sky(1.0)
	w._env.fog_enabled = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 240.0
	cam.far = 500.0
	add_child(cam)
	cam.global_position = Vector3(0, 200, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	w._sky_root.visible = false
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/above.png" % out)
	get_tree().quit()
