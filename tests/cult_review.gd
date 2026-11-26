extends Node
## Visual review of the cult of Al'quimelea: each of them standing, in its tell, and striking; the
## Ostrich Guardian riding, charging and, its bird brought down, on foot; and each of them dying.
## Framed on the body's bounds.
## godot --path . res://tests/cult_review.tscn -- OUT [one_id]
var w: World
var cam: Camera3D
const POSES := {"cult_worshipper": ["Idle", "Walking_A", "1H_Melee_Attack_Chop"], "cult_priest": ["Idle", "Throw", "Raise"],
	"cult_guardian": ["Idle", "WindUp", "Running_A"], "ostrich_rider": ["Ride", "RideCharge", "RideThrust"],
	"hierophant": ["Idle", "Throw", "Raise"], "polemarch": ["Idle", "WindUp", "1H_Melee_Attack_Chop"]}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var only := args[1] if args.size() > 1 else ""
	Game.mode = Game.Mode.NIGHT
	Game.night_map = "fontanova"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	w.director.set_process(false)
	for z: Zombie in w.zombies.duplicate(): z.release()
	w.player.set_physics_process(false)
	w.player.camera.current = false
	cam = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.fov = 38
	w._apply_sky(1.0)
	var spot := Vector3(-30, 0, 40)
	var y := w.ground_at(spot)
	w.player.position = spot + Vector3(0, 0, 30)
	w.player.position.y = w.ground_at(w.player.position)
	# A clear stage: the instanced grass and trees are hidden, so nothing stands in front of the camera.
	for n in w.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false
	var frames: Array[Image] = []
	for id: String in POSES:
		if only != "" and id != only:
			continue
		if not w.spawn_zombie(id, Vector3(spot.x, y, spot.z)):
			print("no spawn ", id)
			continue
		var z: Zombie = w.zombies.back()
		z.set_physics_process(false)
		z.position = Vector3(spot.x, y, spot.z)
		z.rotation.y = 0.5
		z.reset_physics_interpolation()
		var shots: Array = POSES[id]
		var sides := [0.9, 0.4, 1.4]
		for i in shots.size():
			z.mesenlla_warning = i == 1
			z._current_anim = ""
			z._play(shots[i], 1.0, 0.0)
			for k in 18:
				if z._mounted:
					z._tick_mount(1.0 / 30.0, 7.0 if i > 0 else 2.0)
				z._anim.advance(1.0 / 30.0)
				await get_tree().process_frame
			frames.append(await _shoot(z, sides[i]))
		if id == "ostrich_rider":
			# The bird brought down: the Guardian on foot, behind its shield.
			z.hp = z.max_hp * 0.3
			z._check_dismount()
			for k in 100:
				z._tick_mount_fall(1.0 / 30.0)
				await get_tree().process_frame
				if k == 30:
					frames.append(await _shoot(z, 0.6)) # the bird going down, a second in
			z._stun = 0.0
			z._play("WindUp", 1.0, 0.0)
			for k in 12:
				z._anim.advance(1.0 / 30.0)
				await get_tree().process_frame
			frames.append(await _shoot(z, 0.9))
		# And how it dies: struck down, the body falling (0.5 s) and lying still (1.4 s).
		var box := _bounds(z)
		z.take_damage(z.hp + 1000.0, Vector3.ZERO, 0.0, z.centre())
		var t := 0.0
		for at: float in [0.5, 1.4]:
			while t < at:
				z._physics_process(1.0 / 30.0)
				if z._anim:
					z._anim.advance(1.0 / 30.0)
				t += 1.0 / 30.0
			await get_tree().process_frame
			var c := box.get_center()
			cam.position = c + Vector3(sin(0.9 + z.rotation.y), 0.45, cos(0.9 + z.rotation.y)).normalized() * maxf(box.size.length() * 0.62, 1.2) * 2.2
			cam.look_at(c + Vector3.DOWN * box.size.y * 0.25)
			await RenderingServer.frame_post_draw
			frames.append(get_viewport().get_texture().get_image())
		if z.active:
			z.release()
	var cols := 5
	var rows := int(ceil(frames.size() / float(cols)))
	var sheet := Image.create(cols * 640, rows * 360, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var im := frames[i]
		im.convert(Image.FORMAT_RGB8)
		im.resize(640, 360)
		sheet.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i((i % cols) * 640, (i / cols) * 360))
	sheet.save_png(out.path_join("cult_review%s.png" % ("" if only == "" else "_" + only)))
	get_tree().quit()


func _shoot(z: Zombie, side: float) -> Image:
	var box := _bounds(z)
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.62, 1.2)
	cam.position = c + Vector3(sin(side + z.rotation.y), 0.25, cos(side + z.rotation.y)).normalized() * r * 2.2
	cam.look_at(c)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.get_aabb().size.length() > 30.0:
			continue
		var b := mi.global_transform * mi.get_aabb()
		if b.size.length() > 30.0:
			continue
		box = b if first else box.merge(b)
		first = false
	return box
