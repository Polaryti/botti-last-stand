extends Node3D
## Opens the saved map previews the way the editor would, and photographs them.
func _ready() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	for file: String in ["village", "fort"]:
		var p: PackedScene = load("res://map_previews/%s.scn" % file)
		var root: Node3D = p.instantiate()
		add_child(root)
		var c := Camera3D.new()
		add_child(c)
		c.far = 900.0
		c.position = Vector3(0, 90, 80) if file == "fort" else Vector3(0, 190, 170)
		c.look_at(Vector3.ZERO)
		c.current = true
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/prev_%s.png" % [dir, file])
		print(file, " children=", root.get_child_count())
		root.free()
		c.free()
	get_tree().quit()
