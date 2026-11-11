# Focused terrain/shadow equivalence checks and CPU microbenchmarks; not a match simulation.
extends World
func _old_deck_place(b: Dictionary, x: float, z: float) -> Vector2:
	var a: Vector2 = b["a"]
	var e: Vector2 = b["b"]
	var along := (e - a).normalized()
	var at := Vector2(x,z) - a
	return Vector2(at.dot(along), absf(at.dot(along.orthogonal())))
func old_deck(x: float, z: float) -> bool:
	for b: Dictionary in terrain.bridges():
		var q := _old_deck_place(b, x, z)
		var length := (b["a"] as Vector2).distance_to(b["b"])
		if q.x > 0 and q.x < length and q.y < float(b["half"]) + 0.2: return true
	return false
func old_near_deck(x: float, z: float) -> bool:
	for b: Dictionary in terrain.bridges():
		var q := _old_deck_place(b, x, z)
		if q.x > -6.0 and q.x < Vector2(b["a"]).distance_to(b["b"]) + 6.0 and q.y < float(b["half"]) + 3.0: return true
	return false
func old_over_deck(x: float, z: float) -> bool:
	for b: Dictionary in terrain.bridges():
		var q := _old_deck_place(b, x, z)
		if q.x > 0 and q.x < Vector2(b["a"]).distance_to(b["b"]) and q.y < 3.0: return true
	return false
func old_walkable(x: float, z: float) -> bool:
	if old_deck(x, z): return true
	var dx := terrain.ground_height(x + 0.5, z) - terrain.ground_height(x - 0.5, z)
	var dz := terrain.ground_height(x, z + 0.5) - terrain.ground_height(x, z - 0.5)
	return terrain.ground_height(x, z) > 0.0 and Vector2(dx, dz).length() < Terrain.STEEP

func old_shadow(z: Zombie) -> void:
	var floor_y := ground_at(z.position)
	var gap := maxf(0, z.position.y - floor_y)
	z._shadow.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(z._scale, 1, z._scale) / (1 + gap * 0.08)), Vector3(z.position.x, floor_y + 0.035, z.position.z))
	z._shadow.visible = z.is_alive() and terrain.is_walkable(z.position.x, z.position.z) and gap < 12
	z._shadow.transparency = clampf(gap / 12, 0, 1)
func _ready() -> void:
	Game.night_map = "mists"
	Game.quality = 1
	setup(Game.Mode.NIGHT)
	director.running = false
	player.set_physics_process(false)
	var points: Array[Vector3] = []
	for i in 2000: points.append(Vector3(sin(i * 1.71) * 155, 20, cos(i * 2.13) * 155))
	for radius: float in [0, 6, 13, 30, 54, 57]:
		for angle: float in [0, .2, 1.57]: points.append(Vector3(cos(angle)*radius, 20, sin(angle)*radius))
	for b: Dictionary in terrain.bridges():
		var a: Vector2 = b["a"]
		var end: Vector2 = b["b"]
		var direction := (end - a).normalized()
		for run: float in [-6.001, -6, -5, 0, 0.001, a.distance_to(end), a.distance_to(end)+6]:
			for side: float in [-8.001, -5, 0, 5, 8.001]:
				var point := a + direction * run + direction.orthogonal() * side
				points.append(Vector3(point.x, 20, point.y))
	for at in points:
		assert(old_walkable(at.x, at.z) == terrain.is_walkable(at.x, at.z))
		assert(old_near_deck(at.x, at.z) == terrain.near_deck(at.x, at.z))
		assert(old_over_deck(at.x, at.z) == terrain.over_water_on_deck(at.x, at.z))
		assert(old_deck(at.x, at.z) == terrain.on_deck(at.x, at.z))
	var start := Time.get_ticks_usec()
	for repeat in 5:
		for at in points: old_deck(at.x, at.z)
	var before := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for repeat in 5:
		for at in points: terrain.on_deck(at.x, at.z)
	print("DECK baseline_us=", before, " optimized_us=", Time.get_ticks_usec()-start)
	start = Time.get_ticks_usec()
	for repeat in 5:
		for at in points: old_walkable(at.x, at.z)
	before = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for repeat in 5:
		for at in points: terrain.is_walkable(at.x, at.z)
	print("WALKABILITY baseline_us=",before," optimized_us=",Time.get_ticks_usec()-start)
	var crowd: Array[Zombie] = []
	for i in 60:
		var z := Zombie.new(self, "normal_a")
		add_child(z)
		zombies.append(z)
		z.spawn("normal", Vector3(sin(i)*40, 20, cos(i)*40))
		z.set_physics_process(false)
		crowd.append(z)
	for z in crowd:
		for shift in 4:
			z.position += Vector3(shift, shift*.4, 0)
			old_shadow(z)
			var pose := z._shadow.global_transform
			var visible_before := z._shadow.visible
			var opacity := z._shadow.transparency
			z._update_ground_shadow()
			assert(z._shadow.global_transform == pose and z._shadow.visible == visible_before and z._shadow.transparency == opacity)
	start = Time.get_ticks_usec()
	for repeat in 50:
		for z in crowd: old_shadow(z)
	before = Time.get_ticks_usec()-start
	start = Time.get_ticks_usec()
	for repeat in 50:
		for z in crowd: z._update_ground_shadow()
	print("STATIONARY SHADOWS baseline_us=",before," optimized_us=",Time.get_ticks_usec()-start," mobs=",crowd.size())
	terrain.bake_revision += 1
	for z in crowd:
		z._shadow_floor = -1234
		z._update_ground_shadow()
		assert(z._shadow_floor == ground_at(z.position))
	print("EQUIVALENCE: ",points.size()," terrain points and moving shadows passed")
	var tree := get_tree()
	queue_free()
	await tree.process_frame
	Sfx.stop_all()
	tree.quit()

