extends Node
## The classes of the coast on the screens around a match: picked on the class picker, read in the
## Armory, and their skill trees opened in play, one profession after another.
##     godot --path . res://tests/sea_class_ui_shots.tscn -- OUT
const CLASSES := ["harpooner", "tidecaller", "ferryman"]
var out := ""
var m: Main


func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	seed(2311)
	Game.player_name = "Mara"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	for id: String in CLASSES:
		Game.unlocked[id] = true
	m = Main.new()
	add_child(m)
	await wait(0.4)
	for id: String in CLASSES:
		m.show_class_picker(Game.Mode.NIGHT)
		m._fill_class_detail(m.panel.get_meta("detail"), id, Game.Mode.NIGHT)
		await wait(0.3)
		await snap(id + "_picker")
		m.show_armory(id)
		m._fill_armory(m.panel.get_meta("detail"), id)
		await wait(0.3)
		await snap(id + "_armory")
		for spec in 3:
			Game.player_class = id
			await m.start_game(Game.Mode.NIGHT)
			m.world.director.running = false
			m.world.player.grant_all_points()
			for step in 9:
				m.world.player.choose_ability(step, spec if step == 3 else 0)
			m.toggle_tree()
			await wait(0.3)
			await snap("%s_tree_%d" % [id, spec])
			m.toggle_tree()
			await wait(0.2)
			await snap("%s_hud_%d" % [id, spec])
	await preload("res://tests/scene_cleanup.gd").finish(m)
