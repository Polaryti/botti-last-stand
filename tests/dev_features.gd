extends Node
var checks := 0
var failures := 0
var w: World
var p: Player
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	seed(38142)
	Game.quality = 0
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "heavy"
	Game.night_map = "village"
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for z: Zombie in w.zombies.duplicate(): z.release()
	p = w.player
	p.set_physics_process(false)
	p.position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	p.guard_left = 0
	_prices()
	_store_upgrades()
	_heavy()
	await _snakes()
	await _wood_and_gates()
	await _traversal()
	Net.leave()
	w.queue_free()
	await frames(2)
	Sfx.stop_all()
	OS.delay_msec(120)
	await get_tree().create_timer(0.15).timeout
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
func _prices() -> void:
	check(ClassDefs.price("monk") == 920 and ClassDefs.price("artificer") == 598, "both original Store classes cost exactly 15% more")
	check(ClassDefs.price("adept") == 1150 and ClassDefs.for_sale().has("adept"), "Adept is sold for 25% above the updated most expensive class")
	Game.unlocked.erase("adept")
	Game.doubloons = 1149
	check(not Game.buy_class("adept") and Game.doubloons == 1149, "an unaffordable Adept purchase cannot alter the balance")
	Game.doubloons = 1150
	check(Game.buy_class("adept") and Game.doubloons == 0 and Game.owns_class("adept"), "buying Adept unlocks it at the exact price")
	check(CodexPanel.acquisition("adept").contains("1150"), "Codex shows Adept's current Store acquisition")
	check(MistStorm.EVERY == 70.0, "scheduled Mist Storms use the new seventy-second cadence")
func _heavy() -> void:
	Game.owned_items["oathkeeper"] = true
	p.spec_id = "guardian"
	p.mods["dodge"] = 0.0
	p.hp = p.max_hp()
	for i in 9: p.hurt(1.0, p.position + Vector3.FORWARD * 3)
	check(p.oath_reserve == 20, "Oathkeeper caps its reserve even under repeated blocked attacks")
	p.hp = p.max_hp() - 50
	w.spawn_ally("ghost", p.position + Vector3.RIGHT * 2, 20)
	var ally: Ally = w.allies.back()
	ally.set_physics_process(false)
	ally.hp = 50
	p.raise_dome()
	check(p.oath_reserve == 0 and is_equal_approx(p.hp, p.max_hp() - 30), "Dome spends its healing reserve exactly once")
	check(ally.hp == 70 and ally.guarded > 0, "Oathkeeper mends and protects a nearby summon")
	var old := p.hp
	p.raise_dome()
	check(p.hp == old, "an empty reserve does not repeat its healing")
	p.flags.clear()
	p.guard_left = 0
	p.dome_left = 0
	p.hp = p.max_hp() - 30
	var at := p.position + Vector3.FORWARD * 3
	w.spawn_zombie("normal", at + Vector3.RIGHT)
	var enemy: Zombie = w.zombies.back()
	enemy.set_physics_process(false)
	enemy.hp = 1000
	HeavyArts.last_rites(p, at)
	check(p.hp == p.max_hp() - 20 and enemy.burn_time > 0, "Last Rites mends nearby allies and ignites nearby enemies")
	p.position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	p.rotation.y = 0
	p.head.rotation.x = 0
	enemy.position = p.position + Vector3.FORWARD * 8
	enemy.hp = 1000
	var before := enemy.hp
	HeavyArts.faultline(p)
	check(enemy.hp < before and enemy._slow > 0, "Faultline reaches and slows enemies beyond melee range")
	w.spawn_zombie("normal", p.position + Vector3(4, 0, -7))
	var side: Zombie = w.zombies.back()
	side.set_physics_process(false)
	side.hp = 1000
	HeavyArts.faultline(p)
	check(side.hp == 1000, "Faultline does not damage enemies beside its corridor")
	var tree: Dictionary = AbilityData.tree("heavy")
	var quake: Dictionary = tree["specs"][2]["final"]["on"][0]
	check(quake["when"] == "melee_swing", "Earthbreaker counts connecting swings rather than each victim")
	w.remove_ally(ally)
	for z: Zombie in w.zombies.duplicate(): z.release()
func _snakes() -> void:
	w.spawn_ally("snake", p.position + Vector3.RIGHT * 3, 20)
	var snake: Ally = w.allies.back()
	snake.set_physics_process(false)
	check(snake._snake != null and snake._legs.is_empty(), "a legless snake has its own body animator")
	snake._move_wolf(0.1, true)
	snake._snake._process(0.2)
	check(snake._snake.motion > 0 and snake._snake.look.get_shader_parameter("phase") > 0, "movement drives a travelling snake body wave")
	snake._attack_left = 0.25
	snake._move_wolf(0.1, false)
	snake._snake._process(0.1)
	check(snake._snake.bite > 0, "snake bites animate their head strike")
	w.remove_ally(snake)
	w.spawn_ally("snake", p.position, 20)
	snake = w.allies.back()
	snake.set_physics_process(false)
	check(not snake.net_biting and snake._snake.bite == 0, "a reused snake does not inherit an old attack pose")
	w.remove_ally(snake)
	var b := PackedByteArray()
	b.resize(10)
	b.encode_u8(0, 77)
	b.encode_u8(1, Ally.KINDS.find("snake") | 128)
	b.encode_s16(2, 300)
	b.encode_s16(4, 0)
	b.encode_s16(6, 3600)
	w.net_remote_allies(91, b)
	var remote: Ally = w._remote_allies["91:77"]
	remote.set_physics_process(false)
	remote._physics_process(0.016)
	check(remote.kind == "snake" and remote.net_biting and remote._snake.biting, "remote snake packets preserve both the species and bite animation")
	w.forget_peer_allies(91)
	await frames(2)
func _wood_and_gates() -> void:
	var space := SubViewport.new()
	space.own_world_3d = true
	add_child(space)
	var fw := World.new()
	space.add_child(fw)
	fw.setup(Game.Mode.FORT)
	fw.director.running = false
	fw.player.set_physics_process(false)
	for z: Zombie in fw.zombies.duplicate(): z.release()
	for item: Pickup in fw.pickups.duplicate(): fw.remove_pickup(item)
	check(fw.forest_wood_spots.size() > 20, "Fort has many reachable woodland supply sites")
	var failures_before := failures
	for sample in 80:
		fw.stock_wood()
		check(fw.pickups.size() == 1, "one firewood bundle spawns per stock operation")
		for item: Pickup in fw.pickups.duplicate():
			for gate: Dictionary in fw.fort.gates:
				check(Vector2(item.position.x - gate["at"].x, item.position.z - gate["at"].z).length() >= World.WOOD_GATE_CLEARANCE, "firewood remains far from every gate")
			check(not fw.fort.inside(item.position) and fw.grid.is_free(fw.grid.to_cell(item.position)), "firewood stands on traversable ground outside the fort")
			fw.remove_pickup(item)
	check(failures == failures_before, "the woodland policy holds across repeated replenishment")
	var gate: Dictionary = fw.fort.gates[0]
	gate["hp"] = 770.0
	fw.fort._show_gate(gate)
	check((gate["requirement"] as Label3D).text == "3 FIREWOOD\nto repair" and (gate["inner_requirement"] as Label3D).visible, "both gate faces show the correct repair cost")
	gate["hp"] = Fort.GATE_HP
	fw.fort._show_gate(gate)
	check(not (gate["requirement"] as Label3D).visible, "a fully repaired gate hides its requirement")
	gate["hp"] = Fort.GATE_HP * 0.5
	fw.fort._set_closed(gate, false)
	fw.player.position = gate["at"]
	fw.fort.repair(0, 100)
	check(not gate["closed"], "a repaired gate cannot close on a player in its doorway")
	fw.player.position = Vector3.ZERO
	fw.fort._process(0)
	check(gate["closed"], "the gate closes once its doorway is clear")
	# Bots use player-sized side doors even though the shared enemy grid blocks them.
	var info := {"name": "Woodrunner", "class": "infantry", "team": 0}
	var body := Avatar.new(fw, Net.BOT_BASE + 90, info)
	fw.add_child(body)
	var bot := BotPlayer.new(fw, body, info)
	fw.add_child(bot)
	await frames(3)
	bot.set_physics_process(false)
	bot.pawn.set_physics_process(false)
	bot.pawn.position = Vector3(15, 0.05, -20)
	for goal: Vector3 in [Vector3(15, 0, -52), Vector3(15, 0, -20)]:
		bot._goal = goal
		bot._has_goal = true
		bot._repath = 0.0
		bot._fort_cross = Vector3.INF
		for tick in 700:
			if Vector2(bot.pawn.position.x - goal.x, bot.pawn.position.z - goal.z).length() < 1.2: break
			var dir := bot._walk_dir(0.016)
			bot.pawn.velocity = dir * 8 + Vector3.DOWN * 3
			bot.pawn.move_and_slide()
			await frames(1)
		check(Vector2(bot.pawn.position.x - goal.x, bot.pawn.position.z - goal.z).length() < 1.5, "a wood-gathering bot traverses the side door to %s (ended %s)" % [goal, bot.pawn.position])
	space.queue_free()
	await frames(2)

func _walk_surface(pawn: Player, from: Vector3, toward: Vector3, label: String) -> void:
	pawn.position = from + Vector3.UP * 0.25
	var direction := Vector3(toward.x - from.x, 0, toward.z - from.z).normalized()
	for tick in 900:
		if Vector2(pawn.position.x - toward.x, pawn.position.z - toward.z).length() < 0.8: break
		pawn.velocity = direction * 6 + Vector3.DOWN * 4
		pawn.move_and_slide()
		await frames(1)
	check(Vector2(pawn.position.x - toward.x, pawn.position.z - toward.z).length() < 1.0 and pawn.position.y > toward.y - 1.0, label + " ended " + str(pawn.position))

func _traversal() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	add_child(viewport)
	Game.night_map = "mists"
	var mist := World.new()
	viewport.add_child(mist)
	mist.setup(Game.Mode.NIGHT)
	mist.director.running = false
	for z: Zombie in mist.zombies.duplicate(): z.release()
	var pawn := mist.player
	pawn.set_physics_process(false)
	await frames(3)
	for ramp: Array in MapIslands.RAMPS:
		await _walk_surface(pawn, ramp[0], ramp[1], "ascending shelf ramp")
		await _walk_surface(pawn, ramp[1], ramp[0], "descending shelf ramp")
	for shrine: Array in MapIslands.ROTUNDAS:
		var centre: Vector2 = shrine[0]
		for n in 4:
			var dir := Vector2(cos(n * PI / 2), sin(n * PI / 2))
			var at := centre + dir * (float(shrine[1]) + 4)
			var from := Vector3(at.x, mist.ground_at(Vector3(at.x, 0, at.y)), at.y)
			await _walk_surface(pawn, from, Vector3(centre.x, float(shrine[3]) + MapIslands.ROTUNDA_RISE, centre.y), "open shrine approach")
	for pair: Array in MapIslands.JOINED:
		var from: Vector4 = MapIslands.ISLANDS[pair[0]]
		var to: Vector4 = MapIslands.ISLANDS[pair[1]]
		var start := mist.grid.to_world(mist.grid.nearest_free(mist.grid.to_cell(Vector3(from.x, 0, from.y))))
		var end := mist.grid.nearest_free(mist.grid.to_cell(Vector3(to.x, 0, to.y)))
		check(mist.grid.flood(start).has(end), "bots and mobs can traverse joined islands %s" % str(pair))
	check(mist.map_marks.size() >= MapIslands.ISLANDS.size(), "every Mists zone has a map label")
	viewport.queue_free()
	await frames(2)

func _store_upgrades() -> void:
	for id: String in ["oathkeeper", "last_rites", "faultline"]:
		check(ShopDefs.for_class("heavy").has(id), "Heavy upgrade is listed in the Store: " + id)
		Game.owned_items.erase(id)
		var price := int(ShopDefs.ITEMS[id]["price"])
		Game.doubloons = price - 1
		check(not Game.buy_item(id), "purchase rejects insufficient funds: " + id)
		Game.doubloons = price
		check(Game.buy_item(id) and Game.doubloons == 0, "purchase charges the exact upgrade price: " + id)
		Game.set_item_on(id, false)
		check(not Game.item_active(id), "Armory can disable " + id)
		Game.set_item_on(id, true)
		check(Game.item_active(id), "Armory can equip " + id)
