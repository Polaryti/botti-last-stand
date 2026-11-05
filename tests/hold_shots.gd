extends Node3D
## Every weapon in a character's hand, from the side and the front, to check it is held the right way.
##     godot --path . res://tests/hold_shots.tscn -- OUT


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	Game.quality = 2
	Game.apply_quality()
	Game.force_weather = Weather.Kind.CLEAR
	Game.mode = Game.Mode.SANDBOX
	var w := World.new()
	add_child(w)
	w.setup(Game.Mode.SANDBOX)
	w.director.running = false
	w.player.set_physics_process(false)
	w._apply_sky(1.0)
	w._env.fog_enabled = false
	w._env.ambient_light_color = Color.WHITE
	w._env.ambient_light_energy = 1.0
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 46.0
	var ids: Array = WeaponDefs.ALL.keys()
	ids.erase("claws")
	var i := 0
	var bodies: Array[Avatar] = []
	var origin := Vector3(0, w.ground_at(Vector3(0, 0, 14)), 14)
	for id: String in ids:
		var a := Avatar.new(w, 900 + i, {"name": "", "class": "infantry", "team": 0})
		w.add_child(a)
		var at := origin + Vector3((i % 9 - 4) * 2.1, 0.0, (i / 9) * 3.2)
		a.apply_pose(at, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 0, id, 1.0)
		a.teleport(at)
		bodies.append(a)
		i += 1
	var attack := OS.get_cmdline_user_args().has("attack")
	if attack:
		await get_tree().create_timer(0.2).timeout
		for a: Avatar in bodies:
			a.apply_pose(a.global_position, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 1, a._weapon, 1.0)
	for shot: Array in [["side", Vector3(13, 2.0, 15.4), Vector3(0, 0.9, 15.4)], ["front", Vector3(0, 2.0, 2.0), Vector3(0, 0.9, 15.4)], ["close", Vector3(2.5, 1.6, 22.0), Vector3(-1.0, 0.9, 14.0)]]:
		cam.global_position = origin + (shot[1] as Vector3) - Vector3(0, 0, 14)
		cam.look_at(origin + (shot[2] as Vector3) - Vector3(0, 0, 14))
		for f in (2 if attack else 8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
	get_tree().quit()
