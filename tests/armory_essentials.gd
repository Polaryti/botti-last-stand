extends Node
func _ready() -> void:
	var m := Main.new()
	add_child(m)
	await get_tree().process_frame
	var checks := 0
	# A class you don't own is locked in the Armory, with only how to unlock it.
	var saved_unlocked := Game.unlocked.duplicate()
	Game.unlocked.erase("monk")
	m.show_armory("monk")
	await get_tree().process_frame
	assert(m.panel.find_child("LockedClass", true, false) != null and m.panel.find_child("WeaponTags", true, false) == null)
	checks += 1
	# Each class's page, as its owner sees it.
	for id: String in ClassDefs.ALL:
		Game.unlocked[id] = true
	for id: String in ClassDefs.ALL:
		assert(ClassPresentation.COPY.has(id))
		assert(ClassPresentation.description(id).count(".") == 2)
		m.show_armory(id)
		m._fill_armory(m.panel.get_meta("detail"), id)
		await get_tree().process_frame
		var labels := m.panel.find_children("*", "Label", true, false)
		# The weapon tags sit in a row, each word on one line.
		var tags := m.panel.find_child("WeaponTags", true, false) as HFlowContainer
		assert(tags != null and tags.get_children().all(func(t: Control) -> bool: return (t.get_child(0) as Label).autowrap_mode == TextServer.AUTOWRAP_OFF))
		for spec: Dictionary in AbilityData.tree(id)["specs"]:
			assert(ClassPresentation.profession(spec).ends_with("."))
			assert(labels.any(func(l: Label) -> bool: return l.text == spec["name"]))
			assert(not labels.any(func(l: Label) -> bool: return l.text.begins_with(spec["final"]["name"] + " —")))
			for item: String in ShopDefs.for_class(id):
				# The Paths tab lists Class Upgrades; looks are on the Appearance tab, pets as a row of choices.
				if ShopDefs.ITEMS[item]["section"] == "upgrades" and not ShopDefs.ITEMS[item].get("pet", false):
					assert(labels.any(func(l: Label) -> bool: return l.text == ShopDefs.ITEMS[item]["desc"]))
			checks += 3
		checks += 2
	Game.unlocked = saved_unlocked
	print("ARMORY ESSENTIALS: ", checks, " checks passed")
	if not OS.get_cmdline_user_args().is_empty():
		m.show_armory()
		m._fill_armory(m.panel.get_meta("detail"), "commander")
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("armory_commander.png"))
	await preload("res://tests/scene_cleanup.gd").finish(m)
