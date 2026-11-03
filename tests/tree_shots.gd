extends Node
## Pictures of the skill tree screen at each stage. Args: output folder.
var out := ""


func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.quality = 1
	Game.apply_quality()
	Game.player_class = "magician"
	var m: Main = load("res://scripts/main.gd").new()
	add_child(m)
	await wait(0.5)
	await m.start_game(Game.Mode.SANDBOX)
	await wait(0.6)
	var pl: Player = m.world.player
	pl.points = 1
	m.toggle_tree()
	await wait(0.2)
	await snap("a_first")
	pl.choose_ability(0, 0)
	pl.points = 0
	m.tree_panel.refresh(true)
	await wait(0.2)
	await snap("b_waiting")
	pl.points = 3
	pl.choose_ability(1, 1)
	pl.choose_ability(2, 0)
	m.tree_panel.refresh(true)
	await wait(0.2)
	await snap("c_spec")
	pl.choose_ability(3, 2)
	m.tree_panel.refresh(true)
	await wait(0.2)
	await snap("d_branch")
	pl.points = 2
	pl.choose_ability(4, 1)
	m.tree_panel.refresh(true)
	await wait(0.2)
	await snap("e_branch_later")
	m.tree_panel.read(m.tree_panel._map.nodes[m.tree_panel._map.nodes.size() - 1])
	await wait(0.2)
	await snap("f_reading")
	get_tree().quit()
