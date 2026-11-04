extends Node
## Bots playing a match while the player stands safely aside, at high speed, to see how they do.
## godot --headless --path . res://tests/bot_watch.tscn -- coop 3 300
var m: Main


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var rule: int = {"coop": Net.Rules.COOP, "ffa": Net.Rules.FFA, "teams": Net.Rules.TEAMS, "fort": Net.Rules.FORT}[args[0]]
	var count := int(args[1])
	var seconds := float(args[2])
	Game.quality = 1
	m = load("res://scripts/main.gd").new()
	add_child(m)
	await get_tree().create_timer(0.5).timeout
	Net.host_game()
	Net.set_rules(rule)
	Net.set_bots(count)
	if args.size() > 3:
		for peer: int in Net.roster:
			if Net.is_bot(peer):
				Net.roster[peer]["class"] = args[3]
	Net.start_match()
	while not m._net_go:
		await get_tree().create_timer(0.2).timeout
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	Engine.max_fps = 0
	var w: World = m.world
	if args.size() > 4:
		w.director.elapsed = float(args[4])
	var t := 0.0
	while t < seconds and not m._run_over:
		await get_tree().create_timer(5.0).timeout
		t += 5.0
		w.player.guard_left = 99999.0
		if w.fog:
			w.player.global_position = w.fog.centre3() + Vector3.UP * 0.1
		var line := "t=%d zombies=%d" % [int(w.director.elapsed), w.zombies.size()]
		for b: BotPlayer in Net.bot_players():
			line += " | %s k%d d%d hp%d down%s g%.1f in%s at(%d,%d)" % [Net.roster[b.peer]["class"].substr(0, 3), int(Net.roster[b.peer]["score"]), int(Net.roster[b.peer]["deaths"]), int(b.hp), b.down, b._guard, (w.fog.contains(b.at) if w.fog else true), int(b.at.x), int(b.at.z)]
		if w.fog:
			line += " fog r=%d" % int(w.fog.radius)
		print(line)
	print("END over=%s winner=%s elapsed=%d" % [m._run_over, Net.last_winner, int(w.director.elapsed)])
	get_tree().quit()
