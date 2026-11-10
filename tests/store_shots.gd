extends Node
func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.07)
	backdrop.size = Vector2(1280, 720)
	add_child(backdrop)
	var ids: Array = ShopDefs.ITEMS.keys()
	ids.append("wolf")
	for i in ids.size():
		var id: String = ids[i]
		var cell := Control.new()
		cell.position = Vector2(i % 4 * 320, i / 4 * 230)
		add_child(cell)
		var model := ModelView.new(Vector2(310, 200))
		cell.add_child(model)
		if id == "wolf": model.show_pet(id)
		else: model.show_item(id)
		var label := Label.new()
		label.text = id.replace("_", " ").capitalize()
		label.position = Vector2(10, 205)
		cell.add_child(label)
	for phase in 3:
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("store_upgrade_%d.png" % phase))
	await preload("res://tests/scene_cleanup.gd").finish(self)
