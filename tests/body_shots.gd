extends Node3D
## Each made animation at its moments, with a weapon that uses it, seen from the side and the front.
##     godot --path . res://tests/body_shots.tscn -- OUT


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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.3
	cam.far = 200.0
	var rows := [["Thrust", "spear"], ["Thrust", "dagger"], ["Overhead", "mace"], ["Sweep", "sword"], ["Throw", "javelins"], ["BoSpin", "bo"], ["Sweep", "bo"], ["Stomp", ""], ["Stance", "sword"], ["Vault", "bo"]]
	var origin := Vector3(0, w.ground_at(Vector3(0, 0, 14)), 14)
	var bodies: Array[Avatar] = []
	for i in rows.size():
		var a := Avatar.new(w, 900 + i, {"name": "", "class": "ranger", "team": 0})
		w.add_child(a)
		a.apply_pose(origin, 0.0, 0.0, Vector3.ZERO, 1.0, 0, 0, rows[i][1], 1.0)
		a.teleport(origin)
		a.set_process(false)
		bodies.append(a)
	for moment: int in [1, 2]:
		for i in rows.size():
			var a: Avatar = bodies[i]
			var name_of: String = rows[i][0]
			var list: Array = BodyAnim.POSES[name_of]
			a._anim.play(name_of, 0.0)
			a._anim.seek(float(list[mini(moment + 1, list.size() - 1)][0]), true)
			a._anim.pause()
		for group in 2:
			for view: int in [0, 1]:
				for i in rows.size():
					var slot: int = i - group * 5
					var along := Vector3(0, 0, (slot - 2) * 2.1) if view == 0 else Vector3((slot - 2) * 2.1, 0, 0)
					bodies[i].global_position = origin + along if slot >= 0 and slot < 5 else origin + Vector3(0, -40, 0)
				cam.global_position = origin + (Vector3(30, 1.1, 0) if view == 0 else Vector3(0, 1.1, -30))
				cam.look_at(origin + Vector3(0, 1.1, 0))
				for f in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_g%d_m%d.png" % [out, "side" if view == 0 else "front", group, moment])
	get_tree().quit()
