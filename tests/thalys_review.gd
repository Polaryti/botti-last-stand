extends Node
## Plays the core of the Thalys siege, jumping the clock between encounters. Non-headless
## runs also render the original island, dock, cornucopia and boss.

var _checks := 0
var _failures := 0
var _out := ""
var _world: World
var _camera: Camera3D


func check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", label)


func shot(label: String, at: Vector3, focus: Vector3, fov := 58.0) -> void:
	if _camera == null:
		return
	_camera.position = at
	_camera.look_at(focus)
	_camera.fov = fov
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var filename := _out.path_join("thalys_%s.png" % label)
	check(get_viewport().get_texture().get_image().save_png(filename) == OK, "saved " + filename)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else ""
	Game.quality = 1
	Game.mode = Game.Mode.FORT
	Game.fort_map = "thalys"
	Game.player_class = "infantry"
	Game.earned_specs.erase("adorer_pelagros")
	check("thalys" in Game.FORT_MAPS and not Game.MAPS.has("thalys"), "Thalys appears only in the fort mode")
	check(WorldAtlas.view_of("thalys") == WorldAtlas.ARCHIPELAGO, "Thalys lives on the sea chart")
	check(not Game.owns_spec({"earned": "adorer_pelagros"}), "profession starts locked")
	_world = World.new()
	add_child(_world)
	_world.setup(Game.Mode.FORT)
	check(_world.map_id == "thalys" and _world.isle_sea != null, "normal map loading builds the island")
	var fort := _world.fort
	if fort == null or fort.gates.size() != 3:
		check(false, "island built three gates")
		_finish()
		return
	var director := _world.director
	director.set_process(false)
	var player := _world.player
	player.set_physics_process(false)
	check(fort.region.size() == 3 and fort.doors.size() == 3, "the pyramid has three faces and three gate complexes")
	check(fort.has_lanes() and fort.heart_name == "Cornucopia" and fort.heart_hp == Fort.HEART_HP, "lanes lead to a healthy Cornucopia")
	check(_world.count_type("cult_worshipper") >= 3, "opening attackers spawn without an exposed player")
	for i in fort.gates.size():
		var g := fort.gates[i]
		var way: Array[Vector3] = g["way"]
		var front := fort.gate_front(g, way[0])
		check(not _world.grid.route(way[0], front).is_empty(), "%s attackers can reach the gate" % g["name"])
		fort.hit_gate(g, Fort.GATE_HP, way[0])
		check(not g["closed"] and not _world.grid.route(front, Vector3(5.5, 4, 0)).is_empty(), "%s breach gives access to the heart" % g["name"])
		fort.repair(i, Fort.GATE_HP)
		check(g["closed"], "%s gate can be repaired" % g["name"])
	for z: Zombie in _world.zombies.duplicate():
		z.release()
	var vine := fort.gates[1]
	var vine_out: Vector3 = vine["dir"]
	var vine_front := fort.gate_front(vine, (vine["at"] as Vector3) + vine_out * 12.0)
	check(_world.spawn_zombie("cult_worshipper", vine_front + vine_out * 2.2), "a Worshipper joins the Vine lane")
	var marcher: Zombie = _world.zombies.back()
	marcher._set_goal(vine_front + vine_out * 1.4)
	await get_tree().create_timer(2.4).timeout
	check(float(vine["hp"]) < Fort.GATE_HP, "an attacker replaces the old lane waypoint and hits the Vine gate")
	marcher.release()
	fort.repair(1, Fort.GATE_HP)
	if DisplayServer.get_name() != "headless" and _out != "":
		_camera = Camera3D.new()
		_camera.far = 550.0
		add_child(_camera)
		_camera.make_current()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := _world.get_world_3d().direct_space_state
	for sample: Array in [[Vector3(-5, 6, -1.8), Vector3(5, 6, -1.8)], [Vector3(0, 5.55, 7), Vector3(0, 5.55, -5)], [Vector3(-5, 8.4, -3.6), Vector3(5, 8.4, -3.6)]]:
		var ray := PhysicsRayQueryParameters3D.create(sample[0], sample[1], 1)
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty(), "the cornucopia blocks bodies above the pedestal at %s" % str(sample))
	# The two diagonal gates close real collision, and opening one removes it while the lintel stays.
	var passage := (vine["at"] as Vector3) + Vector3.UP * 1.6
	var across := PhysicsRayQueryParameters3D.create(passage + vine_out * 2.5, passage - vine_out * 7.0, 1)
	check(not space.intersect_ray(across).is_empty(), "closed diagonal gate is solid")
	fort.hit_gate(vine, Fort.GATE_HP, passage)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(space.intersect_ray(across).is_empty(), "diagonal gateway is physically open after breaking")
	fort.repair(1, Fort.GATE_HP)
	for dock_point: Vector3 in [Vector3(0, 0, 70), Vector3(0, 0, 80), Vector3(0, 0, 84), Vector3(0, 0, 89), Vector3(3, 0, 90)]:
		var ray := PhysicsRayQueryParameters3D.create(dock_point + Vector3.UP * 5.0, dock_point - Vector3.UP * 2.0, 1)
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and (hit.get("position", Vector3.ZERO) as Vector3).y > 1.8, "walkable dock or ship at %s" % dock_point)
	await shot("island", Vector3(121, 112, 145), Vector3(-3, -7, 0), 51.0)
	await shot("quay", Vector3(15, 11, 64), Vector3(1, 6, 90), 65.0)
	await shot("court", Vector3(3.5, 7.6, 13.5), Vector3(0, 8.3, -1), 65.0)
	await shot("orchard", Vector3(-19, 9.5, -57), Vector3(-3, 9, -23), 65.0)
	await shot("pyramid", Vector3(58, 37, 59), Vector3(0, 9, 0), 66.0)
	await _harvest_review(player)
	for z: Zombie in _world.zombies.duplicate():
		z.release()
	for seal: MistSeal in _world.mist_seals.duplicate():
		seal.queue_free()
	await get_tree().process_frame
	director.elapsed = FeastMind.ARRIVAL - 0.1
	director._tick_thalys()
	check(_world.count_type(FeastMind.ID) == 0, "Pelagros does not arrive early")
	director.elapsed = FeastMind.ARRIVAL
	director._tick_thalys()
	check(_world.count_type(FeastMind.ID) == 1, "Pelagros appears at 7:30")
	if _world.count_type(FeastMind.ID) != 1:
		_finish()
		return
	var boss: Zombie = _world.zombies.back()
	boss.set_physics_process(false)
	var mind := boss.mesenlla_mind as FeastMind
	check(Director.BOSS_CARDS[FeastMind.ID]["bells"] == "boss_bells_pelagros" and Sfx._entrance.stream.get_length() > 5.0, "Pelagros plays his dedicated entrance melody")
	player.position = Vector3(0, 4.05, 6.45)
	mind.tick(boss, player, Vector3.ZERO, 15.0, 1.9)
	mind._offering = 0.01
	mind.tick(boss, player, Vector3.ZERO, 15.0, 0.03)
	check(boss.is_warning() and mind.phase == "tribute" and _world.mist_seals.size() == 1, "the offering has a replicated tell")
	for i in 12:
		boss._animate_custom(0.06, 0.0)
	await shot("pelagros", Vector3(-8, 8.3, -0.5), Vector3(0, 8.7, -12), 62.0)
	var health := fort.heart_hp
	boss.take_damage(FeastMind.BREAK_DAMAGE + 1.0, Vector3.BACK, 0.0, boss.centre())
	mind.tick(boss, player, Vector3.ZERO, 15.0, 0.05)
	check(mind.phase == "recover" and fort.heart_hp == health and not boss.is_warning(), "damage interrupts the offering")
	check(_world.mist_seals.all(func(seal: MistSeal) -> bool: return seal.struck), "interrupted offering cannot hit players")
	mind._offering = 0.01
	mind.tick(boss, player, Vector3.ZERO, 15.0, 0.68)
	mind.tick(boss, player, Vector3.ZERO, 15.0, FeastMind.CHEST_TELL + 0.01)
	check(fort.heart_hp == health - FeastMind.TRIBUTE_DAMAGE, "unanswered offering damages the Cornucopia once")
	director.elapsed = director.match_length()
	director._process(0.01)
	check(not director._won, "surviving the clock with a living god does not win")
	boss.take_damage(boss.hp + 10.0, Vector3.BACK, 0.0, boss.centre())
	check(Game.owns_spec({"earned": "adorer_pelagros"}) and director._mist_boss_defeated, "defeating the god unlocks Adorer of Pelagros")
	director._process(0.01)
	check(director._won, "defeating Pelagros and keeping the horn wins the siege")

	# Use the profession's actual cast entry point on a living player and an enemy.
	_world.spawn_zombie("cult_worshipper", player.global_position + Vector3(3, 0, 0))
	var foe: Zombie = _world.zombies.back()
	var before := foe.hp
	player.class_id = "ascendant"
	player.spec_id = "adorer_pelagros"
	player.hp = 20.0
	check(AscendantKit.art(player)["name"] == "Feast of Embers", "Adorer of Pelagros takes the new cast")
	AscendantKit.cast(player)
	check(player.hp == 20.0 + AscendantKit.FEAST_HEAL and foe.hp < before, "Feast heals the caster and damages a nearby enemy")
	_finish()


func _harvest_review(player: Player) -> void:
	var director := _world.director
	for id: String in HarvestMind.KINDS:
		director.elapsed = float(ZombieDefs.ALL[id]["from"])
		director._tick_thalys()
		check(_world.count_type(id) > 0 and Icons.exists(id), "%s arrives in its own siege wave with a Codex icon" % id)
	for enemy: Zombie in _world.zombies.duplicate():
		enemy.release()
	var spots := [Vector3(-4, 4, 12), Vector3(0, 4, 12), Vector3(4, 7.2, 12)]
	var mobs: Array[Zombie] = []
	for i in HarvestMind.KINDS.size():
		check(_world.spawn_zombie(HarvestMind.KINDS[i], spots[i]), "pools supply a living food monster")
		var z: Zombie = _world.zombies.back()
		mobs.append(z)
		z.set_physics_process(false)
		z.rotation.y = 0.0
		z._sees = true
	player.position = Vector3(0, 4.05, 14.45)
	var pip := mobs[0]
	var oven := mobs[1]
	var pepper := mobs[2]
	var pip_mind := pip.mesenlla_mind as HarvestMind
	var oven_mind := oven.mesenlla_mind as HarvestMind
	var pepper_mind := pepper.mesenlla_mind as HarvestMind
	pip_mind.tick(pip, player, Vector3.BACK, 2.65, 1.04)
	oven_mind.tick(oven, player, Vector3.BACK, 8.0, 1.04)
	pepper_mind.tick(pepper, player, Vector3.BACK, 8.0, 1.04)
	for k in 9:
		for z: Zombie in mobs:
			z._animate_custom(0.08, 0.0)
	check(pip.is_warning() and oven.is_warning() and pepper.is_warning(), "each enemy uses an individual attack windup")
	check(_world.mist_seals.filter(func(seal: MistSeal) -> bool: return seal.style == MistSeal.Style.OVEN).size() == 3, "Ovenback lays three bursts in a line")
	check(_world.mist_seals.any(func(seal: MistSeal) -> bool: return seal.style == MistSeal.Style.PEPPER and seal._boulder != null), "Pepperwing drops a modeled hot seed")
	var pips: MistSeal
	for seal: MistSeal in _world.mist_seals:
		seal.set_physics_process(false)
		if seal.style == MistSeal.Style.PIPS:
			pips = seal
	await shot("harvest_monsters", Vector3(1.0, 7.1, 23), Vector3(0, 6.4, 12), 66.0)
	pip.take_damage(pip.hp + 2.0, Vector3.ZERO, 0.0, pip.centre())
	check(is_instance_valid(pips) and pips.struck and not _world.mist_seals.has(pips), "killing Pipburst interrupts its pips")
	pepper_mind.tick(pepper, player, Vector3.BACK, 6.0, HarvestMind.PEPPER_TELL + 0.2)
	check(pepper_mind.phase == "recoil" and not pepper.is_warning(), "Pepperwing releases the seed and enters recovery")
	for seal: MistSeal in _world.mist_seals.duplicate():
		seal.queue_free()
	await get_tree().process_frame
	var pepper_y := pepper.position.y
	var pepper_floor := _world.floor_contact(pepper.position).y
	check(pepper_y > pepper_floor + 1.0, "Pepperwing starts well above its landing surface")
	for z: Zombie in [oven, pepper]:
		z.take_damage(z.hp + 2.0, Vector3.ZERO, 0.0, z.centre())
	for i in 27:
		for z: Zombie in mobs:
			z._physics_process(1.0 / 60.0)
	var spill := pip._visual.get_node("Rig/Spill") as Node3D
	var loaf := oven._visual.get_node("Rig/Loaf") as Node3D
	check(spill.scale.x > 0.99 and (spill.get_child(2) as Node3D).position.y > 0.75, "Pipburst launches pieces from its split shell")
	check(pepper.position.y < pepper_y and pepper.position.y > pepper_floor + 0.25, "Pepperwing loses altitude over multiple frames")
	await shot("harvest_death_start", Vector3(1, 7.1, 23), Vector3(0, 6.4, 12), 66.0)
	for i in 44:
		for z: Zombie in mobs:
			z._physics_process(1.0 / 60.0)
	check(absf(loaf.rotation.z) > 1.0 and oven._visual.has_meta("did_oven_impact"), "Ovenback buckles and strikes the floor on its side")
	check(is_equal_approx(pepper.position.y, pepper_floor) and pepper._visual.has_meta("did_pepper_impact"), "Pepperwing hits the surface it fell towards")
	await shot("harvest_death_impact", Vector3(1, 6.9, 22), Vector3(0, 5.2, 12), 66.0)
	for i in 104:
		for z: Zombie in mobs:
			if z.active:
				z._physics_process(1.0 / 60.0)
	for z: Zombie in mobs:
		check(not z.active, "%s corpse is returned to its pool" % z.type_id)
		check(_world.spawn_zombie(z.type_id, spots[mobs.find(z)]), "pool can spawn %s again after its death" % z.type_id)
		var replacement: Zombie = _world.zombies.back()
		check(not replacement._visual.has_meta("fall_pose"), "%s respawns with its living rig" % z.type_id)
	check(spill.scale.x < 0.01, "pooled Pipburst hides the empty shell fragments")


func _finish() -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Sfx.stop_all()
	await get_tree().create_timer(0.12).timeout
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
