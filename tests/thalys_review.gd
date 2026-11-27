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
	check(fort.has_lanes() and fort.heart_name == "Cornucopia" and fort.heart_hp == Fort.HEART_HP, "lanes lead to a healthy Cornucopia")
	check(_world.count_type("cult_worshipper") >= 3, "opening attackers spawn without an exposed player")
	for i in fort.gates.size():
		var g := fort.gates[i]
		var way: Array[Vector3] = g["way"]
		var front := fort.gate_front(g, way[0])
		check(not _world.grid.route(way[0], front).is_empty(), "%s attackers can reach the gate" % g["name"])
		fort.hit_gate(g, Fort.GATE_HP, way[0])
		check(not g["closed"] and not _world.grid.route(front, Vector3(0, 4, 3.5)).is_empty(), "%s breach gives access to the heart" % g["name"])
		fort.repair(i, Fort.GATE_HP)
		check(g["closed"], "%s gate can be repaired" % g["name"])
	for z: Zombie in _world.zombies.duplicate():
		z.release()
	if DisplayServer.get_name() != "headless" and _out != "":
		_camera = Camera3D.new()
		_camera.far = 550.0
		add_child(_camera)
		_camera.make_current()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := _world.get_world_3d().direct_space_state
	for dock_point: Vector3 in [Vector3(0, 0, 70), Vector3(0, 0, 80), Vector3(0, 0, 84), Vector3(0, 0, 89), Vector3(3, 0, 90)]:
		var ray := PhysicsRayQueryParameters3D.create(dock_point + Vector3.UP * 5.0, dock_point - Vector3.UP * 2.0, 1)
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and (hit.get("position", Vector3.ZERO) as Vector3).y > 1.8, "walkable dock or ship at %s" % dock_point)
	await shot("island", Vector3(121, 112, 145), Vector3(-3, -7, 0), 51.0)
	await shot("quay", Vector3(15, 11, 64), Vector3(1, 6, 90), 65.0)
	await shot("court", Vector3(11, 7.6, 15), Vector3(0, 8.3, -1), 64.0)
	await shot("orchard", Vector3(-19, 9.5, -57), Vector3(-3, 9, -23), 65.0)
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
	player.position = Vector3(0, 4.05, 2.5)
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


func _finish() -> void:
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
