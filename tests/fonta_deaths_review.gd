extends Node
## Visual review of how the mutants of Fontanova die: each one killed (the flyers in the air), six
## moments of its death in a strip (0.1 s, 0.4, 0.8, 1.2, 1.8 and 2.5 s), stepped frame by frame so
## the timing is exact however slowly the picture is drawn.
## godot --path . res://tests/fonta_deaths_review.tscn -- OUT_DIR [one_id]
const MOMENTS := [0.1, 0.4, 0.8, 1.2, 1.8, 2.5]
const STEP := 1.0 / 30.0
var w: World
var cam: Camera3D


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
	cam.fov = 42
	w._apply_sky(1.0)
	var spot := Vector3(-30, 0, 40)
	var y := w.ground_at(spot)
	w.player.position = spot + Vector3(0, 0, 30)
	w.player.position.y = w.ground_at(w.player.position)
	# A clear stage: the instanced grass and trees round the spot are hidden, so nothing stands
	# between the camera and the body.
	for n in w.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false
	for id: String in FontaModels.KINDS:
		if only != "" and id != only:
			continue
		if not w.spawn_zombie(id, Vector3(spot.x, y, spot.z)):
			print("no spawn ", id)
			continue
		var z: Zombie = w.zombies.back()
		z.set_physics_process(false)
		z.position = Vector3(spot.x, y + (2.2 if id in FontaModels.FLYERS else 0.0), spot.z)
		z.rotation.y = 0.6
		z.reset_physics_interpolation()
		for k in 6: z._animate_custom(STEP, 0.0)
		var size := _bounds(z._visual).size.length()
		var centre := Vector3(spot.x, y + maxf(0.6, size * 0.3), spot.z)
		var r := maxf(size, 1.2) * 1.45 + (1.2 if id in FontaModels.FLYERS else 0.0)
		cam.position = centre + Vector3(sin(1.9), 0.3, cos(1.9)).normalized() * r
		cam.look_at(centre)
		z.take_damage(z.hp + 1000.0, Vector3.ZERO, 0.0, z.centre())
		var frames: Array[Image] = []
		var t := 0.0
		for moment: float in MOMENTS:
			while t < moment:
				z._physics_process(STEP)
				t += STEP
			z.reset_physics_interpolation()
			for p in w.find_children("*", "Pickup", true, false):
				(p as Node3D).visible = false
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(640, 360)
			frames.append(img)
		var sheet := Image.create(1920, 720, false, frames[0].get_format())
		for n in frames.size():
			sheet.blit_rect(frames[n], Rect2i(0, 0, 640, 360), Vector2i((n % 3) * 640, (n / 3) * 360))
		sheet.save_png(out.path_join(id + "_death.png"))
		if z.active:
			z.release()
	get_tree().quit()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
