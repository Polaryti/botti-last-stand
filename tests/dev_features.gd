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
	await _ui_initialization()
	_codex_and_concealment()
	_prices()
	_store_upgrades()
	_heavy()
	await _snakes()
	await _wood_and_gates()
	await _traversal()
	_music_and_polish()
	await _after_0212()
	await _beyond_weapons()
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
	# Adept is switched off: not sold, not offered, not bought, and its code waits.
	var had_adept := Game.unlocked.has("adept")
	Game.unlocked.erase("adept")
	check(ClassDefs.disabled("adept") and not ClassDefs.for_sale().has("adept"), "Adept is not in the Store")
	Game.doubloons = 5000
	check(not Game.buy_class("adept") and Game.doubloons == 5000 and not Game.owns_class("adept"), "and cannot be bought")
	check(CodexPanel.acquisition("adept") == "Not available at this time.", "the Codex says it is not available")
	Game.unlocked["adept"] = true
	check(not ClassDefs.available().has("adept"), "a phone that owns it cannot pick it")
	Game.player_class = "adept"
	Game.save_settings()
	Game.load_settings()
	check(Game.player_class == "infantry" and Game.unlocked.has("adept"), "a saved Adept choice becomes Infantry, and ownership is kept")
	check(not Net.class_slot_available("adept", 1), "nobody can take it in a game together")
	if not had_adept:
		Game.unlocked.erase("adept")
		Game.save_settings()
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
				check(Vector2(item.position.x - gate["at"].x, item.position.z - gate["at"].z).length() >= World.WOOD_NEAR_GATE_CLEARANCE, "firewood stays out of every gateway")
			check(not fw.fort.inside(item.position) and fw.grid.is_free(fw.grid.to_cell(item.position)), "firewood stands on traversable ground outside the fort")
			fw.remove_pickup(item)
	check(failures == failures_before, "the wood policy holds across repeated replenishment")
	check(fw.near_wood_spots.size() > 40 and fw.field_wood_spots.size() > 40, "there is room for wood by the walls (%d) and out in the field (%d)" % [fw.near_wood_spots.size(), fw.field_wood_spots.size()])
	# The labels lie flat on the wall above each gateway, reading outwards and inwards.
	for g: Dictionary in fw.fort.gates:
		var outer: Label3D = g["requirement"]
		var inner: Label3D = g["inner_requirement"]
		var dir: Vector3 = g["dir"]
		check(outer.billboard == BaseMaterial3D.BILLBOARD_DISABLED and outer.global_basis.z.dot(dir) > 0.99 and inner.global_basis.z.dot(-dir) > 0.99, "gate %d's wood labels face out and in" % g["i"])
		var off: float = (outer.global_position - (g["at"] as Vector3)).dot(dir)
		check(off > Fort.WALL_T * 0.5 and off < Fort.WALL_T * 0.5 + 0.2 and outer.global_position.y > Fort.GATE_H and outer.global_position.y < Fort.WALL_H, "gate %d's label sits on the wall face above the gateway" % g["i"])
	# Zombies are sent evenly against the four gates, and rise on their gate's side.
	fw.director.running = false
	var per_gate := [0, 0, 0, 0]
	var on_side := 0
	var risen := 0
	for k in 40:
		if not fw.spawn_zombie("normal"):
			continue
		var z: Zombie = fw.zombies.back()
		risen += 1
		per_gate[z.fort_gate] += 1
		var d: Vector3 = Fort.DIRS[z.fort_gate]
		if Vector2(z.position.x, z.position.z).normalized().dot(Vector2(d.x, d.z)) > 0.6:
			on_side += 1
	check(risen >= 8 and per_gate.max() - per_gate.min() <= 1, "zombies are split evenly across the gates: %s" % str(per_gate))
	check(on_side >= risen - 1, "and rise on their own gate's side (%d of %d)" % [on_side, risen])
	# A breach at one gate draws only the zombies sent there, and about a quarter of the rest.
	var west: Dictionary = fw.fort.gates[3]
	west["hp"] = 0.0
	fw.fort._set_closed(west, false)
	var diverted := 0
	var others := 0
	for z: Zombie in fw.zombies:
		if z.fort_gate == 3:
			continue
		others += 1
		if fw.fort.gate_for(z)["i"] == 3:
			diverted += 1
	check(diverted <= others * 0.5, "an open gate does not pull the whole horde (%d of %d)" % [diverted, others])
	for z: Zombie in fw.zombies.duplicate(): z.release()
	west["hp"] = Fort.GATE_HP
	fw.fort._set_closed(west, true)
	var gate: Dictionary = fw.fort.gates[0]
	gate["hp"] = 770.0
	fw.fort._show_gate(gate)
	check((gate["requirement"] as Label3D).text == "3 WOOD\nto repair" and (gate["inner_requirement"] as Label3D).visible, "both gate faces show the correct repair cost")
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


## Each place has its own music, the menu its own theme, and homes are dressed without changing the way through.
func _music_and_polish() -> void:
	for set_name: String in Sfx.MUSIC_SETS:
		for stem: String in Sfx.MUSIC_SETS[set_name]:
			check(stem == "" or ResourceLoader.exists("res://assets/music/%s.ogg" % stem), "the %s music has its %s stem" % [set_name, stem])
	var was := Sfx.music_set
	Sfx.ambient(true)
	Sfx.use_music("fort")
	check(Sfx.music_set == "fort" and Sfx.music_is_playing() and (Sfx._music[0].stream as AudioStreamOggVorbis).resource_path.ends_with("fort_night.ogg"), "the Fort plays its own three stems")
	check(Sfx._music.all(func(p: AudioStreamPlayer) -> bool: return p.stream and (p.stream as AudioStreamOggVorbis).loop), "and all of them loop")
	Sfx.use_music("menu")
	check(Sfx._music[0].stream != null and Sfx._music[1].stream == null and Sfx._music[2].stream == null and Sfx.music_is_playing(), "the menu has one theme of its own")
	Sfx.use_music("nowhere")
	check(Sfx.music_set == "menu", "an unknown place keeps what is playing")
	var lengths: Array = []
	for stem: String in ["mists_night", "mists_hunted", "mists_dawn"]:
		lengths.append(snappedf((load("res://assets/music/%s.ogg" % stem) as AudioStream).get_length(), 0.01))
	check(lengths[0] == lengths[1] and lengths[1] == lengths[2], "the Mists stems are the same length, so they stay in step: %s" % str(lengths))
	Sfx.use_music(was)
	# Shelves keep clear of doors and windows, and of the corners.
	var gap := MapBuilder._longest_gap(8.0, [{"at": -1.0, "width": 2.2}, {"at": 2.6, "width": 1.1}])
	check(is_equal_approx(gap.x, 0.45) and is_equal_approx(gap.y, 1.7), "the longest bare stretch of an 8 m wall with a door and a window: %s" % str(gap))
	check(MapBuilder._longest_gap(6.0, []).is_equal_approx(Vector2(-2.45, 2.45)), "a bare wall keeps 55 cm from each corner")
	# A level gained shows a ring and motes, and an ability its class's colour.
	var rings_before := w._rings.filter(func(r: Dictionary) -> bool: return float(r["left"]) > 0.0).size()
	p.add_xp(p.xp_needed())
	check(w._rise != null and w._rise.emitting and w._rings.filter(func(r: Dictionary) -> bool: return float(r["left"]) > 0.0).size() > rings_before, "a level gained sends a ring and rising motes")



func _after_0212() -> void:
	# Late packets are dropped, not queued: each stream counts, and only newer counts are used.
	Net.leave()
	check(Net.fresh(["pose", 7], 10) and not Net.fresh(["pose", 7], 9) and not Net.fresh(["pose", 7], 10), "an older or repeated pose is ignored")
	check(Net.fresh(["pose", 7], 11) and Net.fresh(["pose", 8], 0), "a newer one, or another sender's, is used")
	check(Net.fresh(["snapshot"], 65535) and Net.fresh(["snapshot"], 65535, true) and Net.fresh(["snapshot"], 2), "parts of one snapshot all count, and counts wrap past 65535")
	check(not Net.fresh(["snapshot"], 65000, true), "a snapshot from before the wrap is still old")
	check(Net.next_seq("clock") == 0 and Net.next_seq("clock") == 1, "each stream counts on its own")
	Net.leave()
	check(Net.next_seq("clock") == 0, "and starts again with a new game")
	check(Net.SNAPSHOT_CHUNK * 12 + 64 < 1170, "a snapshot part fits one Epic packet with room for its header")
	# The drop button: up top, away from the fighting thumb, and it needs a held press.
	var hud := Hud.new()
	add_child(hud)
	hud.player = p
	hud.size = Vector2(1280, 720)
	hud._layout()
	var drop: Vector2 = hud._buttons["drop"]["pos"]
	check(drop.y < 100.0 and drop.distance_to(hud._buttons["fire"]["pos"]) > 300.0 and drop.distance_to(hud._buttons["switch"]["pos"]) > 250.0, "the drop button sits in the top row, far from Attack and Switch")
	p.set_physics_process(false)
	p.slots = ["mace", "sword"]
	p.current = 1
	p._equip()
	var can_drop := p.can_drop_weapon()
	hud._touch_down(5, drop)
	hud._process(0.2)
	check(p.slots[1] == "sword", "a short press does not drop the weapon")
	hud._process(0.4)
	check(not can_drop or p.slots[1] == null, "holding it half a second does")
	hud._touch_up(5)
	hud.queue_free()
	for item: Pickup in w.pickups.duplicate(): w.remove_pickup(item)
	# Each player's health and countdown, for the list in a game together.
	var state := Net.player_state(Net.my_id())
	check(state.has("hp") and state.has("down") and state.has("back_in"), "the player list knows your health and state")
	var info := {"name": "Ally", "class": "ranger", "team": 0}
	var other := Avatar.new(w, 4242, info)
	w.add_child(other)
	Net._avatars[4242] = other
	other.hp_fraction = 0.4
	check(is_equal_approx(float(Net.player_state(4242)["hp"]), 0.4) and not Net.player_state(4242)["down"], "and another player's health")
	other.set_fallen(true)
	other.down_since = w.now - 5.0
	var back: float = Net.player_state(4242)["back_in"]
	check(Net.player_state(4242)["down"] and back > 14.0 and back <= 15.0, "and when they are down, how long until they are back (%.1f)" % back)
	Net._avatars.erase(4242)
	other.queue_free()
	await frames(1)

func _ui_initialization() -> void:
	for item: Pickup in w.pickups.duplicate():
		if item.kind == Pickup.Kind.WEAPON: w.remove_pickup(item)
	w.spawn_pickup_at(p.position + Vector3.RIGHT, Pickup.Kind.WEAPON, "sword")
	var loose_weapon: Pickup = w.pickups.back()
	check(w.nearest_weapon_pickup(p.position, 100.0) == loose_weapon, "Clever search finds a nearby reachable weapon on maps without portals")
	w.remove_pickup(loose_weapon)
	var insets := UiTheme.safe_insets(Vector2i(1920, 1080), Rect2i(160, 20, 1680, 1020), Vector2(1280, 720), 24, 16)
	check(insets[0] >= 127 and insets[1] >= 74 and insets[2] >= 30 and insets[3] >= 43, "safe-area conversion protects all four edges in viewport units")
	var flipped := UiTheme.safe_insets(Vector2i(1920, 1080), Rect2i(80, 20, 1680, 1020), Vector2(1280, 720), 24, 16)
	check(flipped[1] > flipped[0], "rotating the notch to the opposite side swaps the protected horizontal inset")
	var margin := MarginContainer.new()
	UiTheme.fit_safe_area(margin, 32, 18)
	add_child(margin)
	await frames(2)
	check(margin.get_theme_constant("margin_left") >= 32 and margin.get_theme_constant("margin_top") >= 18, "safe-area margins bind after entering the tree")
	margin.queue_free()
	var avatar := Avatar.new(w, 7654, {"class": "infantry", "name": "Test"})
	w.add_child(avatar)
	avatar.apply_pose(p.position, 0, 0, Vector3.ZERO, 1, 0, 17, "sword", 1)
	check(avatar._attack_left <= 0, "first pose seeds the attack counter without playing a phantom swing")
	avatar.apply_pose(p.position, 0, 0, Vector3.ZERO, 1, 0, 18, "sword", 1)
	check(avatar._attack_left > 0, "subsequent attack counter changes still animate")
	avatar._flash = 0.1
	avatar._set_flash(true)
	avatar._ice_left = 1.0
	avatar._show_ice(true)
	avatar._flash = 0.0
	avatar._set_flash(false)
	var ice_preserved := true
	for part: MeshInstance3D in avatar._visual.find_children("*", "MeshInstance3D", true, false):
		if part.material_override != Avatar._ice_look(): ice_preserved = false
	check(ice_preserved, "ending a hit flash preserves a still-active freeze visual")
	avatar.set_fallen(true)
	avatar.set_fallen(false)
	var restored := true
	for part: MeshInstance3D in avatar._visual.find_children("*", "MeshInstance3D", true, false):
		if part.has_meta("status_base") and part.material_override != part.get_meta("status_base"): restored = false
	check(restored, "death and respawn restore base materials after overlapping status visuals")
	avatar.queue_free()
	for entry: Dictionary in StatusCatalog.TIMED:
		for glyph: String in entry["icon"].split("+"): check(Icons.exists(glyph), "status glyph exists: " + glyph)
		p.set(entry["field"], 2.5)
		var found := false
		for effect: Dictionary in p.status_effects():
			if is_equal_approx(float(effect["left"]), 2.5): found = true
		check(found, "temporary status exposes a duration: " + entry["name"])
		p.set(entry["field"], 0.0)
	w._warmed_quality = -1
	await w.warm_up()
	var clear := true
	for puddle: MeshInstance3D in w._puddles:
		if puddle.visible: clear = false
	for gore: CPUParticles3D in w._gore:
		if gore.visible or gore.emitting: clear = false
	check(clear, "warm-up leaves no visible puddles or phantom blood")

func _codex_and_concealment() -> void:
	var was := p.class_id
	p.class_id = "magician"
	for id: String in WeaponDefs.ALL:
		check(p.can_use(id) == (id == "staff"), "Magician only accepts the wand: " + id)
	p.class_id = was
	p.invis_left = 4.0
	p.input_fire = false
	p._handle_fire()
	check(p.invis_left == 4.0, "not attacking preserves invisibility")
	p._cooldown = 0.0
	p.input_fire = true
	p._handle_fire()
	check(p.invis_left == 0.0, "an actual attack breaks invisibility")
	p.input_fire = false
	check(CodexPanel.enemy_group("normal") < CodexPanel.enemy_group("hero_infantry") and CodexPanel.enemy_group("hero_infantry") < CodexPanel.enemy_group("veil_regent"), "Codex separates common enemies, fallen heroes and bosses")
	check(not "doubloons" in CodexPanel.acquisition("monk"), "Codex acquisition omits store prices")
	var shot := Projectile.new(w)
	w.add_child(shot)
	shot.launch(Projectile.Kind.ARROW, w._arrow_mesh, Vector3(0, 5, 0), Vector3.FORWARD, 0, 20, 1, 0, true)
	check(not shot._flame.visible and shot._arrow_aura.visible, "fire arrows use a narrow 3D tip, never the fireball sprite")
	shot.launch(Projectile.Kind.FIREBALL, w._fireball_mesh, Vector3(0, 5, 0), Vector3.FORWARD, 0, 20, 1)
	check(shot._flame.visible and not shot._arrow_aura.visible, "pooled fireballs reset the arrow effect")
	shot.queue_free()


## 0.22 step 1: Two-Handed weapons, the Greatsword, the Mesenlla weapons, tags and the 3 s reveal.
func _beyond_weapons() -> void:
	for id: String in ["bell_hammer", "pitchfork", "scythe", "greatsword", "battleaxe"]:
		check(WeaponDefs.category(id) == "two_handed", "%s is a Two-Handed weapon" % id)
	check(WeaponDefs.category("sword") == "melee" and WeaponDefs.category("chakram") == "ranged" and WeaponDefs.category("lance") == "exclusive" and WeaponDefs.category("bo") == "exclusive", "the other groups")
	var expect := {"infantry": ["melee", "two_handed", "ranged"], "ranger": ["melee", "ranged"], "heavy": ["melee"], "chivalry": ["melee", "two_handed", "exclusive"],
		"magician": ["exclusive"], "revenant": ["exclusive"], "monk": ["melee", "two_handed", "ranged", "exclusive"], "adept": ["melee", "two_handed"],
		"plague_doctor": ["melee", "ranged", "exclusive"], "artificer": ["melee", "two_handed", "ranged"], "commander": ["melee", "two_handed", "ranged", "exclusive"]}
	for id: String in expect:
		check(ClassDefs.weapon_categories(id) == Array(expect[id], TYPE_STRING, "", null), "%s wields %s (got %s)" % [id, str(expect[id]), str(ClassDefs.weapon_categories(id))])
	var cls := p.class_id
	for id: String in ["infantry", "chivalry", "monk", "adept", "artificer", "commander"]:
		p.setup_class(id)
		check(p.can_use("greatsword") and p.can_use("scythe"), "%s can wield Two-Handed weapons" % id)
	for id: String in ["ranger", "heavy", "plague_doctor"]:
		p.setup_class(id)
		check(not p.can_use("greatsword") and not p.can_use("bell_hammer") and p.can_use("sword"), "%s cannot, and keeps its one-handed melee" % id)
	p.setup_class("ranger")
	check(p.can_use("chakram") and p.can_use("bow"), "ranged rules are unchanged")
	p.setup_class("magician")
	check(not p.can_use("greatsword") and p.can_use("staff"), "the Magician still holds only its Staff")
	# Where they are found.
	check(SpawnRules.allows(WeaponDefs.ALL["greatsword"], "village") and SpawnRules.allows(WeaponDefs.ALL["greatsword"], "mists") and SpawnRules.allows(WeaponDefs.ALL["greatsword"], "mesenlla"), "the Greatsword lies on every map")
	for id: String in ["battleaxe", "chakram"]:
		check(not SpawnRules.allows(WeaponDefs.ALL[id], "village") and SpawnRules.allows(WeaponDefs.ALL[id], "mesenlla") and SpawnRules.allows(WeaponDefs.ALL[id], "bastion"), "%s only beyond the Mists" % id)
		check(SpawnRules.names(WeaponDefs.ALL[id]) == "Mesenlla", "%s's badge says Mesenlla" % id)
	for id: String in ["greatsword", "battleaxe", "chakram"]:
		check(WeaponDefs.mesh(id) != null and ResourceLoader.exists("res://assets/icons/%s.png" % Icons.weapon(id)) and Icons.weapon(id) == id, "%s has its own model and icon" % id)
	for sound: String in ["heavy_swing", "cleave", "chakram_throw", "chakram_hit"]:
		check(ResourceLoader.exists("res://assets/sounds/%s.ogg" % sound) and Sfx.NAMES.has(sound), "%s sound" % sound)
	# The Battleaxe: every third blow in a row cleaves for double.
	p.setup_class("infantry")
	p.slots = ["battleaxe", null]
	p.current = 0
	p._equip()
	p.global_position = Vector3(0, w.ground_at(Vector3(0, 0, 36)), 36)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	w.spawn_zombie("normal", p.global_position + Vector3(0, 0, -1.6))
	var z: Zombie = w.zombies.back()
	z.set_physics_process(false)
	var losses: Array[float] = []
	for i in 3:
		z.hp = 5000.0
		z.max_hp = 5000.0
		z.position = p.global_position + Vector3(0, 0, -1.6)
		p._do_melee_hit()
		losses.append(5000.0 - z.hp)
	check(losses[0] > 0.0 and is_equal_approx(losses[0], losses[1]) and absf(losses[2] - losses[0] * 2.0) < 1.0, "blows 1 and 2 are equal, the third does double (%s)" % str(losses))
	z.release()
	# The Rift Chakram ricochets.
	p.slots = ["chakram", null]
	p._equip()
	var row: Array[Zombie] = []
	for i in 4:
		w.spawn_zombie("normal", p.global_position + Vector3(i * 3.0 * (1 if i % 2 else -1) * 0.5, 0, -9.0 - i * 2.0))
		var zz: Zombie = w.zombies.back()
		zz.set_physics_process(false)
		zz.hp = 500.0
		row.append(zz)
	p._fire_arrow(p.weapon_def())
	var shot: Projectile = w._projectiles.filter(func(q: Projectile) -> bool: return q.active and q.spins).back()
	check(shot != null and shot.bounces >= 3, "a thrown chakram carries three ricochets")
	for i in 120:
		await get_tree().physics_frame
	var struck := row.filter(func(zz: Zombie) -> bool: return zz.hp < 500.0).size()
	check(struck >= 3, "and strikes several enemies in turn (%d)" % struck)
	for zz in row: zz.release()
	# Invisibility, then three seconds before the next.
	p.invis_left = 2.0
	check(p.invis_left > 0.0 and p.can_vanish(), "invisible")
	p.invis_left = 4.0
	check(is_equal_approx(p.invis_left, 4.0), "a running invisibility can be lengthened")
	p.invis_left = 0.0
	check(is_equal_approx(p.invis_lockout, Player.INVIS_LOCKOUT) and not p.can_vanish(), "coming out of it starts the 3 s reveal")
	p._act({"do": "invis", "secs": 5.0}, {})
	check(p.invis_left == 0.0, "nothing hides you during it")
	check(p.status_effects().any(func(e: Dictionary) -> bool: return e["icon"] == "eye+clock"), "the reveal shows on the effects row")
	p._tick_ability_timers(1.6)
	p._tick_ability_timers(1.5)
	p._act({"do": "invis", "secs": 5.0}, {})
	check(p.invis_left > 4.0, "after 3 s it works again")
	p.invis_left = 0.0
	p.invis_lockout = 0.0
	p.setup_class(cls)
	# Weapon groups read the same on the class screen, the Armory and the Codex.
	var m := Main.new()
	add_child(m)
	await frames(2)
	for id: String in ["infantry", "magician"]:
		var want := ClassDefs.weapon_categories(id).map(func(c: String) -> String: return WeaponDefs.CATEGORY_NAMES[c])
		m.show_class_picker(Game.Mode.NIGHT)
		m._fill_class_detail(m.panel.get_meta("detail"), id, Game.Mode.NIGHT)
		check(_tag_texts(m.panel) == want, "class screen tags for %s: %s" % [id, str(_tag_texts(m.panel))])
		check(m.panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == ClassPresentation.stats_line(id)), "class screen stat line for %s" % id)
		m.show_armory(id)
		m._fill_armory(m.panel.get_meta("detail"), id)
		check(_tag_texts(m.panel) == want, "Armory tags for %s" % id)
		check(m.panel.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.begins_with(ClassPresentation.stats_line(id))), "Armory stat line for %s" % id)
	var codex := CodexPanel.new()
	add_child(codex)
	codex._list = VBoxContainer.new()
	codex.add_child(codex._list)
	codex._classes()
	var codex_tags := codex._list.find_children("WeaponTags", "HFlowContainer", true, false)
	check(codex_tags.size() == ClassDefs.ALL.size(), "every class in the Codex has weapon tags")
	codex._list.queue_free()
	codex._list = VBoxContainer.new()
	codex.add_child(codex._list)
	codex._weapons()
	var texts := codex._list.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(texts.has("Two-Handed") and texts.has("Map Exclusive · Mesenlla") and texts.has("Greatsword"), "the Codex weapons show their group and the Mesenlla badge")
	codex.queue_free()
	m.queue_free()
	await frames(2)


func _tag_texts(root: Node) -> Array:
	var rows := root.find_children("WeaponTags", "HFlowContainer", true, false)
	if rows.is_empty():
		return []
	return (rows[0] as Node).find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
