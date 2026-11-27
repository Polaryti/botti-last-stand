extends Node
## Visual review of the mutants of Fontanova: each one moving, its tell, and its attacks (a spider
## clinging to a real trunk, as World.spawn_spider places it), framed on the model's own bounds.
## godot --path . res://tests/fonta_mutants_review.tscn -- OUT [one_id]
var w: World
var cam: Camera3D
const ACTS := {"mutant_bee": ["m_dive"], "mutant_wasp": ["m_throw", "m_dive"], "ember_moth": ["m_throw"], "beehive": [],
	"mutant_snail": [], "wasp_hive_snail": ["m_cast"], "mutant_spider": ["m_sink", "m_lunge"], "battle_ostrich": ["m_charge"], "thornback": ["m_bite"]}
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
	for z: Zombie in w.zombies.duplicate(): z.release()
	w.player.set_physics_process(false)
	w.player.camera.current = false
	cam = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.fov = 40
	w._apply_sky(1.0)
	var spot := Vector3(-30, 0, 40)
	var y := w.ground_at(spot)
	w.player.position = spot + Vector3(0, 0, 30)
	w.player.position.y = w.ground_at(w.player.position)
	for id: String in FontaModels.KINDS:
		if only != "" and id != only:
			continue
		if not w.spawn_zombie(id, Vector3(spot.x, y, spot.z)):
			print("no spawn ", id)
			continue
		var z: Zombie = w.zombies.back()
		z.set_physics_process(false)
		z.position = Vector3(spot.x, y, spot.z)
		var frames: Array[Image] = []
		var box := _bounds(z._visual)
		var shoot := func(side: float, rise := 0.32) -> void:
			var c := box.get_center()
			var r := maxf(box.size.length() * 0.62, 1.2)
			var dir := Vector3(sin(side), rise, cos(side)).normalized()
			cam.position = c + dir * r * 2.3
			cam.look_at(c)
		z.rotation.y = 0.0
		# Moving.
		z.velocity = Vector3(0, 0, 1.5)
		z._current_anim = "move"
		for k in 20: z._animate_custom(1.0 / 30.0, 1.5)
		box = _bounds(z._visual)
		shoot.call(1.1)
		await RenderingServer.frame_post_draw
		frames.append(get_viewport().get_texture().get_image())
		z.velocity = Vector3.ZERO
		# The tell.
		z.mesenlla_warning = true
		z._current_anim = "m_cast"
		for k in 18: z._animate_custom(1.0 / 30.0, 0.0)
		shoot.call(1.4)
		await RenderingServer.frame_post_draw
		frames.append(get_viewport().get_texture().get_image())
		z.mesenlla_warning = false
		for act: String in ACTS[id]:
			z._current_anim = act
			z.position.y = y + (3.2 if act == "m_sink" else 0.0)
			var keep := z.position
			if act == "m_sink":
				# On the nearest real trunk, as World.spawn_spider places it.
				var perch: Dictionary = w.spider_trunks[0]
				for t: Dictionary in w.spider_trunks:
					if (t["at"] as Vector3).distance_to(keep) < (perch["at"] as Vector3).distance_to(keep):
						perch = t
				var side := Vector3(1, 0, 0.3).normalized()
				z.position = FontaMind.perch_at(perch, side, w.ground_at(perch["at"]))
				z.rotation.y = atan2(side.x, side.z)
			for k in 8: z._animate_custom(1.0 / 30.0, 0.0)
			box = _bounds(z._visual)
			z.reset_physics_interpolation()
			for k in 3: await get_tree().physics_frame
			shoot.call(1.7, -0.35 if act == "m_sink" else 0.32)
			await RenderingServer.frame_post_draw
			frames.append(get_viewport().get_texture().get_image())
			z.position = keep
			z.position.y = y
			z.rotation.y = 0.0
		var cols := 3
		var rows := int(ceil(frames.size() / float(cols)))
		var sheet := Image.create(cols * 640, rows * 360, false, Image.FORMAT_RGB8)
		for i in frames.size():
			var im := frames[i]
			im.convert(Image.FORMAT_RGB8)
			im.resize(640, 360)
			sheet.blit_rect(im, Rect2i(0, 0, 640, 360), Vector2i((i % cols) * 640, (i / cols) * 360))
		sheet.save_png(out.path_join("fonta_" + id + ".png"))
		z.release()
	get_tree().quit()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		if b.size.length() > 40.0:
			continue
		box = b if first else box.merge(b)
		first = false
	return box
