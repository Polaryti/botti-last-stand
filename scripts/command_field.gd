class_name CommandField
extends Node3D
## Bounded work: storm queries at 2 Hz, lightning at 1 Hz, barrage at 4 Hz.
## Only the host applies damage. Every peer draws the same warning and duration.

var world: World
var peer := 0
var kind := ""
var elapsed := 0.0
var _pulse := 0.0
var _strike := 0.0
var _rings: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
var _shells: Array[Dictionary] = []
var _shell_meshes: Array[MeshInstance3D] = []
var _spawned := 0
var _fires: Array[Dictionary] = []
var _fire_tick := 0.0
var _warning: MeshInstance3D
var _countdown: Label3D


func setup(w: World, owner_peer: int, effect: String, at: Vector3) -> void:
	world = w
	peer = owner_peer
	kind = effect
	position = at
	_rng.seed = 9713 + peer
	var radius := CommanderKit.STORM_RADIUS if kind == "warlock" else CommanderKit.BARRAGE_RADIUS
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.6, 0.4, 0.95) if kind == "warlock" else Color(1.0, 0.5, 0.15)
	for i in (3 if kind == "warlock" else 0):
		var ring := MeshInstance3D.new()
		var mesh_ring := TorusMesh.new()
		mesh_ring.inner_radius = radius - 0.1
		mesh_ring.outer_radius = radius
		mesh_ring.rings = 32
		mesh_ring.ring_segments = 4
		ring.mesh = mesh_ring
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = 0.12 + i * 1.1
		add_child(ring)
		_rings.append(ring)

	if kind == "gunner":
		_build_warning()
		var ball := SphereMesh.new()
		ball.radius = 0.26
		ball.height = 0.8
		ball.radial_segments = 8
		ball.rings = 4
		for i in int(CommanderKit.BARRAGE_TIME / CommanderKit.BARRAGE_INTERVAL):
			var shell := MeshInstance3D.new()
			shell.mesh = ball
			shell.material_override = material
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shell.visible = false
			add_child(shell)
			_shell_meshes.append(shell)
		_sound("artillery_warning", at, -4.0)


func _physics_process(delta: float) -> void:
	elapsed += delta
	var authority := not Net.active() or Net.is_host()
	if kind == "warlock":
		var source := source_target()
		if source == null or source.dead or elapsed >= 8.0:
			queue_free()
			return
		global_position = source.global_position
		for i in _rings.size():
			_rings[i].rotation = Vector3(0.1 * sin(elapsed * 2 + i), elapsed * (i + 1), 0.1 * cos(elapsed * 2 + i))
		if authority:
			_pulse -= delta
			_strike -= delta
			if _pulse <= 0.0:
				_pulse += 0.5
				_slow_enemies()
			if _strike <= 0.0:
				_strike += 1.0
				_lightning()
	else:
		var warning := elapsed < CommanderKit.BARRAGE_DELAY
		_warning.visible = warning
		_countdown.visible = warning
		_countdown.text = "ARTILLERY • %d" % maxi(1, ceili(CommanderKit.BARRAGE_DELAY - elapsed))
		_warning.transparency = 0.15 + 0.35 * (0.5 + 0.5 * sin(elapsed * 12.0))
		while _spawned < _shell_meshes.size() and elapsed >= CommanderKit.BARRAGE_DELAY - CommanderKit.SHELL_FALL + _spawned * CommanderKit.BARRAGE_INTERVAL:
			# Stratified coverage instead of random clumps; identical index/seed on every peer.
			var angle := _spawned * 2.399963 + _rng.randf_range(-0.2, 0.2)
			var distance := sqrt((float(_spawned) + 0.5) / _shell_meshes.size()) * (CommanderKit.BARRAGE_RADIUS - CommanderKit.FIRE_RADIUS)
			var at := global_position + Vector3(cos(angle), 0, sin(angle)) * distance
			at.y = world.terrain.height(at.x, at.z)
			_drop_shell(at)
		_tick_shells()
		_tick_fire(delta, authority)
		if elapsed >= CommanderKit.BARRAGE_DELAY + CommanderKit.BARRAGE_TIME and _shells.is_empty() and _fires.is_empty():
			queue_free()


func source_target() -> Target:
	for target: Target in world.players:
		if world.peer_of(target) == peer:
			return target
	return world.player if not Net.active() else null


func enemy(target: Target) -> bool:
	return not target.dead and Net.active() and Net.bots_foes(peer, world.peer_of(target))


func _slow_enemies() -> void:
	for z: Zombie in world.zombies_near(global_position, CommanderKit.STORM_RADIUS, 128):
		z.slow(0.8)
	for target: Target in world.players:
		if enemy(target) and target.global_position.distance_to(global_position) <= CommanderKit.STORM_RADIUS:
			Net.status_peer(world.peer_of(target), Net.Status.SLOW, 0.8, peer)


func _lightning() -> void:
	var spots: Array[Vector3] = []
	for z: Zombie in world.zombies_near(global_position, CommanderKit.STORM_RADIUS, 128):
		spots.append(z.position)
	for target: Target in world.players:
		if enemy(target) and target.global_position.distance_to(global_position) <= CommanderKit.STORM_RADIUS:
			spots.append(target.global_position)
	if not spots.is_empty():
		var at := spots[_rng.randi_range(0, spots.size() - 1)]
		_impact(at, 3.5, 35.0)


func _impact(at: Vector3, radius: float, damage: float) -> void:
	visual_impact(world, at, radius, kind == "warlock")
	if Net.active():
		Net.command_impact_visual(at, radius, kind == "warlock")
	for z: Zombie in world.zombies_near(at, radius, 128):
		z.next_hitter = peer
		z.take_damage(damage, z.position - at, 2.0, z.centre())
	for target: Target in world.players:
		if enemy(target) and target.global_position.distance_to(at) <= radius:
			Net.hit_player(world.peer_of(target), damage, at, peer)


func _drop_shell(at: Vector3) -> void:
	var node := _shell_meshes[_spawned]
	var impact_time := CommanderKit.BARRAGE_DELAY + _spawned * CommanderKit.BARRAGE_INTERVAL
	_spawned += 1
	node.visible = true
	_shells.append({"node": node, "at": at, "impact": impact_time})
	_sound("artillery_fall", at, -11.0)


func _tick_shells() -> void:
	for i in range(_shells.size() - 1, -1, -1):
		var shell: Dictionary = _shells[i]
		var node: MeshInstance3D = shell["node"]
		var left := float(shell["impact"]) - elapsed
		if left <= 0.0:
			node.visible = false
			if (not Net.active() or Net.is_host()) and (shell["at"] as Vector3).y > World.FALL_DEATH:
				_impact(shell["at"], 4.5, 45.0)
			_add_fire(shell["at"], float(shell["impact"]))
			_shells.remove_at(i)
		else:
			node.global_position = (shell["at"] as Vector3) + Vector3(6, 26, -4) * left / CommanderKit.SHELL_FALL


func _sound(sound: String, at: Vector3, volume: float) -> void:
	if world.player:
		Sfx.play_at(sound, at, world.player.global_position, volume)


## Segmented ground markings follow hills and bridge decks rather than floating as a flat torus.
func _build_warning() -> void:
	var l := LowPoly.new()
	var r := CommanderKit.BARRAGE_RADIUS
	var has_ground := false
	for i in 64:
		var angle := TAU * i / 64.0
		var next := TAU * (i + 0.7) / 64.0
		var a := global_position + Vector3(cos(angle), 0, sin(angle)) * r
		var b := global_position + Vector3(cos(next), 0, sin(next)) * r
		a.y = world.terrain.height(a.x, a.z) + 0.12
		b.y = world.terrain.height(b.x, b.z) + 0.12
		if minf(a.y, b.y) <= World.FALL_DEATH:
			continue
		has_ground = true
		l.prism(a - global_position, b - global_position, 0.09, 0.09, 4, Color(1, 0.35, 0.08))
	_warning = MeshInstance3D.new()
	_warning.mesh = l.commit() if has_ground else null
	var mat := LowPoly.material().duplicate() as StandardMaterial3D
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning.material_override = mat
	_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_warning)
	_countdown = Label3D.new()
	_countdown.position.y = 4.5
	_countdown.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_countdown.font_size = 64
	_countdown.pixel_size = 0.025
	_countdown.modulate = Color(1, 0.55, 0.16)
	add_child(_countdown)


## Batched animated flames, a terrain-following scorch and one seven-puff smoke burst.
## No dynamic lights, shadow casters, transparent smoke layers or permanent crater collision.
func _add_fire(at: Vector3, born: float) -> void:
	if at.y <= World.FALL_DEATH or world.terrain.in_water(at.x, at.z) or world.terrain.in_pool(at.x, at.z):
		return
	var transforms: Array[Transform3D] = []
	for i in 7:
		var angle := TAU * i / 7.0
		var point := at + Vector3(cos(angle), 0, sin(angle)) * (0.0 if i == 0 else 2.1)
		point.y = world.terrain.height(point.x, point.z) + 0.05
		if point.y <= World.FALL_DEATH or world.terrain.in_water(point.x, point.z) or world.terrain.in_pool(point.x, point.z):
			continue
		transforms.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * (1.15 if i == 0 else 0.75)), point - global_position))
	var flames := Models.scatter(WorldLight.flame_mesh(), transforms)
	flames.extra_cull_margin = 0.8
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flames)
	var scorch := MeshInstance3D.new()
	var l := LowPoly.new()
	var has_scorch := false
	# Triangles conform to all sides of the terrain, including hills and bridge decks.
	for i in 12:
		var a := at + Vector3(cos(TAU * i / 12), 0, sin(TAU * i / 12)) * CommanderKit.FIRE_RADIUS
		var b := at + Vector3(cos(TAU * (i + 1) / 12), 0, sin(TAU * (i + 1) / 12)) * CommanderKit.FIRE_RADIUS
		a.y = world.terrain.height(a.x, a.z) + 0.045
		b.y = world.terrain.height(b.x, b.z) + 0.045
		if minf(a.y, b.y) <= World.FALL_DEATH or world.terrain.in_water(a.x, a.z) or world.terrain.in_water(b.x, b.z):
			continue
		has_scorch = true
		l.gable(at + Vector3.UP * 0.045 - global_position, a - global_position, b - global_position, Color(0.16, 0.1, 0.065))
	if has_scorch:
		scorch.mesh = l.commit()
		scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.add_child(scorch)
	else:
		scorch.free()
	var smoke := CPUParticles3D.new()
	smoke.position = at - global_position + Vector3.UP
	smoke.amount = 7
	smoke.lifetime = 1.6
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.direction = Vector3.UP
	smoke.spread = 55.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 4.0
	smoke.gravity = Vector3.UP * 0.6
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.5
	var puff := SphereMesh.new()
	puff.radius = 0.65
	puff.height = 1.3
	puff.radial_segments = 6
	puff.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.24, 0.23)
	puff.material = mat
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.add_child(smoke)
	smoke.emitting = true
	if _spawned % 4 == 0:
		_sound("burn", at, -14.0)
	_fires.append({"at": at, "born": born, "flames": flames})


func _tick_fire(delta: float, authority: bool) -> void:
	for i in range(_fires.size() - 1, -1, -1):
		var zone: Dictionary = _fires[i]
		var age := elapsed - float(zone["born"])
		if age >= CommanderKit.FIRE_TIME:
			(zone["flames"] as Node).queue_free()
			_fires.remove_at(i)
			continue
		(zone["flames"] as GeometryInstance3D).transparency = clampf(age - CommanderKit.FIRE_TIME + 1.0, 0.0, 1.0)
	_fire_tick -= delta
	if not authority or _fire_tick > 0.0:
		return
	_fire_tick = 0.5
	var hit := {} # Overlapping fires never multiply damage.
	for zone: Dictionary in _fires:
		var at: Vector3 = zone["at"]
		for z: Zombie in world.zombies_near(at, CommanderKit.FIRE_RADIUS, 128):
			if not hit.has(z):
				hit[z] = true
				z.next_hitter = peer
				z.take_damage(CommanderKit.FIRE_DPS * 0.5, Vector3.ZERO, 0.0, z.centre())
		for target: Target in world.players:
			if not hit.has(target) and enemy(target) and target.global_position.distance_to(at) <= CommanderKit.FIRE_RADIUS:
				hit[target] = true
				Net.hit_player(world.peer_of(target), CommanderKit.FIRE_DPS * 0.5, at, peer)


static func visual_impact(w: World, at: Vector3, radius: float, storm: bool) -> void:
	if storm:
		w.flash_bolt(at)
		if w.player:
			Sfx.play_at("thunder", at, w.player.global_position, -8.0)
	else:
		if w.player:
			Sfx.play_at("artillery_impact", at, w.player.global_position, -3.0)
			var proximity := clampf(1.0 - w.player.global_position.distance_to(at) / 32.0, 0.0, 1.0)
			w.player.shake(proximity * 0.45)
		w.fx_ring(at + Vector3.UP * 0.1, radius * 1.4, Color(1, 0.55, 0.16))
	w.fx_blast(at + Vector3.UP, radius, Color(0.75, 0.6, 1.0, 0.6) if storm else Color(1, 0.55, 0.2, 0.6))
