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
var _next_shell := 0


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
	for i in (3 if kind == "warlock" else 1):
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
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		ball.radial_segments = 8
		ball.rings = 4
		for i in 3:
			var shell := MeshInstance3D.new()
			shell.mesh = ball
			shell.material_override = material
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shell.visible = false
			add_child(shell)
			_shell_meshes.append(shell)


func _physics_process(delta: float) -> void:
	elapsed += delta
	_tick_shells(delta)
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
		_rings[0].scale = Vector3.ONE * (1.0 + 0.015 * sin(elapsed * 8.0))
		if elapsed >= CommanderKit.BARRAGE_DELAY + CommanderKit.BARRAGE_TIME:
			queue_free()
			return
		if elapsed >= CommanderKit.BARRAGE_DELAY:
			_strike -= delta
			if _strike <= 0.0:
				_strike += 0.25
				var angle := _rng.randf() * TAU
				var at := global_position + Vector3(cos(angle), 0, sin(angle)) * sqrt(_rng.randf()) * (CommanderKit.BARRAGE_RADIUS - 3.0)
				at.y = world.ground_at(at)
				_drop_shell(at)


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
	if kind == "warlock":
		world.flash_bolt(at)
	else:
		world.sfx_at("blast", at, -4.0)
	world.fx_blast(at + Vector3.UP, radius, Color(0.75, 0.6, 1.0, 0.6) if kind == "warlock" else Color(1, 0.55, 0.2, 0.6))
	if Net.active():
		Net.blast_fx(at + Vector3.UP, radius, Color(0.8, 0.55, 0.3, 0.6))
	for z: Zombie in world.zombies_near(at, radius, 128):
		z.next_hitter = peer
		z.take_damage(damage, z.position - at, 2.0, z.centre())
	for target: Target in world.players:
		if enemy(target) and target.global_position.distance_to(at) <= radius:
			Net.hit_player(world.peer_of(target), damage, at, peer)


func _drop_shell(at: Vector3) -> void:
	var node := _shell_meshes[_next_shell]
	_next_shell = (_next_shell + 1) % _shell_meshes.size()
	node.global_position = at + Vector3.UP * 18.0
	node.visible = true
	_shells.append({"node": node, "at": at, "left": 0.2})


func _tick_shells(delta: float) -> void:
	for i in range(_shells.size() - 1, -1, -1):
		var shell: Dictionary = _shells[i]
		shell["left"] = float(shell["left"]) - delta
		var node: MeshInstance3D = shell["node"]
		if float(shell["left"]) <= 0.0:
			node.visible = false
			if not Net.active() or Net.is_host():
				_impact(shell["at"], 4.5, 45.0)
			_shells.remove_at(i)
		else:
			node.global_position = (shell["at"] as Vector3) + Vector3.UP * float(shell["left"]) * 90.0
