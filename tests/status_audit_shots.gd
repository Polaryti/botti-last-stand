extends Node
var out := ""
func snap(id: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(id + ".png"))
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	var menu := Main.new()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	menu.show_codex()
	(menu.panel as CodexPanel).show_tab(5)
	await snap("codex_status_effects")
	(menu.panel as CodexPanel).show_tab(6)
	await snap("codex_maps")
	(menu.panel as CodexPanel).show_tab(4)
	await snap("codex_enemy_families")
	(menu.panel as CodexPanel)._scroll.scroll_to(100000)
	await snap("codex_map_exclusive_badge")
	menu.show_store()
	await snap("safe_store")
	Game.player_class = "adept"
	await menu.start_game(Game.Mode.FORT)
	menu.world.director.running = false
	menu.world.player.invis_left = 20
	menu.world.player.poison_left = 10
	menu.world.player.flurry_left = 8
	await snap("adept_fort_statuses")
	var camera := menu.world.player.camera
	menu.world.player.set_physics_process(false)
	camera.global_position = Vector3(4, 2.8, 6)
	camera.look_at(Vector3(0, 2, 0))
	await snap("fort_portal")
	await preload("res://tests/scene_cleanup.gd").finish(menu)
