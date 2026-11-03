extends Node
## Measures what a scene costs to draw, from typical viewpoints and with a crowd.
## Needs a display: xvfb-run godot --path . --rendering-driver opengl3 res://tests/perf.tscn -- 2

var w: World
var pl: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Game.quality = int(args[0]) if args.size() > 0 else 2
	Game.apply_quality()
	Engine.max_fps = 0
	Game.player_class = "infantry"
	var m: Node = load("res://scripts/main.gd").new()
	add_child(m)
	await get_tree().create_timer(0.5).timeout
	await m.start_game(Game.Mode.NIGHT)
	w = m.world
	pl = w.player
	w.director.set_process(false)
	for z: Zombie in w.zombies.duplicate():
		z.release()
	await _views("empty")
	# Everything the village is made of, by type.
	var groups := {}
	for c in w.get_children():
		var key := c.get_class()
		if c is MultiMeshInstance3D:
			key = "MultiMesh %s" % (c as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
		if not groups.has(key):
			groups[key] = []
		groups[key].append(c)
	for key: String in groups:
		print("  node type %s: %d" % [key, (groups[key] as Array).size()])
	_place(Vector3(0, 0, 14), 0.0)
	await _measure("square north, all")
	for key: String in groups:
		if not String(key).begins_with("MultiMesh") and key != "MeshInstance3D":
			continue
		for c: Node3D in groups[key]:
			c.visible = false
		await _measure("  without %s" % key)
		for c: Node3D in groups[key]:
			c.visible = true
	# What each kind of light costs.
	await _timing("all lights")
	for l: OmniLight3D in w._lanterns:
		l.visible = false
	await _measure("  without lanterns")
	await _timing("  without lanterns")
	for l: OmniLight3D in w._lanterns:
		l.visible = true
	w._moon.shadow_enabled = false
	await _measure("  without moon shadow")
	await _timing("  without moon shadow")
	w._moon.shadow_enabled = Game.quality == 2
	pl._light.visible = false
	await _measure("  without player light")
	await _timing("  without player light")
	pl._light.visible = true
	# A crowd in view.
	var at := pl.global_position - pl.global_basis.z * 9.0
	for i in 24:
		var a := float(i) * 0.7
		w.spawn_zombie(["normal", "clever", "magic", "leaper"][i % 4], at + Vector3(cos(a) * (2.0 + i * 0.25), 0, sin(a) * (2.0 + i * 0.25) - 3.0))
	for z: Zombie in w.zombies:
		z.set_physics_process(false)
		z.rotation.y = 0.0
	await _measure("crowd of %d in view" % w.zombies.size())
	await _timing("crowd of %d in view" % w.zombies.size())
	get_tree().quit()


func _place(at: Vector3, yaw: float) -> void:
	pl.global_position = at
	pl.yaw = yaw
	pl.rotation.y = yaw
	pl.pitch = 0.0
	pl.head.rotation.x = 0.0


func _views(prefix: String) -> void:
	for v: Array in [[Vector3(0, 0, 14), 0.0, "square north"], [Vector3(0, 0, -30), PI, "road south"], [Vector3(-35, 0, 15), PI * 1.2, "field"], [Vector3(55, 0, 55), PI * 0.25, "corner in"], [Vector3(30, 0, -32), 0.0, "cowshed"]]:
		_place(v[0], v[1])
		await _measure("%s, %s" % [prefix, v[2]])
		await _timing(v[2])


func _measure(label: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	print("%-36s draws=%4d  tris=%7d  objects=%4d" % [label, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])


func _timing(label: String) -> void:
	var t0 := Time.get_ticks_usec()
	for i in 12:
		await RenderingServer.frame_post_draw
	print("%-36s frame=%.1f ms (software renderer)" % [label, (Time.get_ticks_usec() - t0) / 12000.0])
