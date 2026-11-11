extends Node
func _ready() -> void:
	Game.night_map = "mists"
	Game.mode = Game.Mode.NIGHT
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	var w := World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	w.player.set_physics_process(false)
	w.player.set_process(false)
	w.portals.set_process(false)
	for link: Dictionary in w.portals.links:
		link["open"] = true
		w.portals._show(link)
	var gate: Node3D = w.portals.links[0]["nodes"][0]
	var at := gate.global_position + Vector3.UP * 2.2
	w.player.position = at + gate.global_basis.z * 8.0
	var camera := w.player.camera
	camera.cull_mask = 5
	camera.global_position = w.player.position
	camera.look_at(at)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("mist_portal.png"))
	await preload("res://tests/scene_cleanup.gd").finish(w)
