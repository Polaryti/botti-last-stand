extends Node
func _ready() -> void:
	var m := Main.new()
	add_child(m)
	await get_tree().process_frame
	var checks := 0
	for id: String in ClassDefs.ALL:
		assert(ClassPresentation.COPY.has(id))
		assert(ClassPresentation.description(id).count(".") == 2)
		m.show_armory(id)
		m._fill_armory(m.panel.get_meta("detail"), id)
		await get_tree().process_frame
		var labels := m.panel.find_children("*", "Label", true, false)
		for spec: Dictionary in AbilityData.tree(id)["specs"]:
			assert(ClassPresentation.profession(spec).ends_with("."))
			assert(labels.any(func(l: Label) -> bool: return l.text == spec["name"]))
			assert(not labels.any(func(l: Label) -> bool: return l.text.begins_with(spec["final"]["name"] + " —")))
			for item: String in ShopDefs.for_class(id):
				if not ShopDefs.ITEMS[item].get("pet", false):
					assert(labels.any(func(l: Label) -> bool: return l.text == ShopDefs.ITEMS[item]["desc"]))
			checks += 3
		checks += 2
	print("ARMORY ESSENTIALS: ", checks, " checks passed")
	if not OS.get_cmdline_user_args().is_empty():
		m.show_armory()
		m._fill_armory(m.panel.get_meta("detail"), "commander")
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("armory_commander.png"))
	await preload("res://tests/scene_cleanup.gd").finish(m)
