extends Node
func frames(n: int) -> void:
	for i in n: await get_tree().process_frame
func _ready() -> void:
	var window := get_tree().root
	window.content_scale_size = Vector2i.ZERO
	var m := Main.new()
	add_child(m)
	var tested := 0
	var overflowing := 0
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		window.size = resolution
		await frames(3)
		m.show_store()
		for id: String in ClassDefs.ALL:
			var detail: VBoxContainer = m.panel.get_meta("detail")
			m._fill_class_detail(detail, id, -1, true)
			await frames(6)
			var scroll: DragScroll = detail.get_node("ClassDescriptionScroll")
			assert(scroll.size.y > 0)
			if scroll._longest() > 0:
				overflowing += 1
				var start := scroll.get_global_rect().get_center()
				scroll._press(start, 0)
				scroll._move(start - Vector2(0, 20))
				scroll._move(start - Vector2(0, 80))
				scroll._release()
				assert(scroll._pos > 0)
			scroll.scroll_to(scroll._longest())
			await frames(2)
			var last := scroll.get_child(0).get_child(-1) as Control
			assert(last.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1)
			var action := detail.get_child(-1) as Control
			assert(action.get_global_rect().end.y <= window.get_visible_rect().end.y)
			tested += 1
	assert(overflowing > 0)
	print("Store scrolling: ", tested, " class/resolution cases passed")
	if not OS.get_cmdline_user_args().is_empty():
		window.size = Vector2i(1280,720)
		m.show_store("monk")
		await frames(8)
		var detail: VBoxContainer = m.panel.get_meta("detail")
		var scroll: DragScroll = detail.get_node("ClassDescriptionScroll")
		scroll.scroll_to(scroll._longest())
		await frames(2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("store_description_bottom.png"))
	await preload("res://tests/scene_cleanup.gd").finish(m)
