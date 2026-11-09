class_name MistMind
extends RefCounted
## Separate, bounded AI for the three mist-born enemies. Zombies still handle damage, pooling and stun.
var cooldown := 2.5
var enraged := false
var casts := 0
var leap_left := 0.0
var leap_to := Vector3.ZERO

func tick(z: Zombie, target: Target, delta: float) -> void:
	cooldown -= delta
	var boss := z.type_id == "veil_regent"
	if leap_left > 0.0:
		leap_left -= delta
		if leap_left <= 0.0:
			z.world.fx_mist(z.centre(), 2.0)
			z.position = leap_to
			z.world.fx_mist(z.centre(), 2.0)
		return
	if boss and not enraged and z.hp <= z.max_hp * 0.5:
		enraged = true
		z.world.fx_blast(z.centre(), 8.0, Color(0.6, 0.3, 1.0, 0.7))
		if Net.is_host(): Net.blast_fx(z.centre(), 8.0, Color(0.6, 0.3, 1.0, 0.7))
		cooldown = maxf(cooldown, 1.5)
		z.world.director.show_banner("The Regent's crown breaks. The mist answers", 3.0)
		for side: float in [-1.0, 1.0]:
			var at := z.position + Vector3(side * 4, 0, 0)
			if z.world.terrain.is_walkable(at.x, at.z):
				at = z.world.grid.to_world(z.world.grid.nearest_free(z.world.grid.to_cell(at)))
				z.world.spawn_zombie("lantern_wisp", at)
	var visible := boss or (z._sees and not target.is_unseen())
	var destination := target.global_position if visible else z._goal if z._has_goal else z.position
	if z.world.mist_storm and z.world.mist_storm.contains(z.position) and not boss:
		visible = false
		destination = z.world.mist_storm.escape(z.position)
		var exit := z.world.portals.exit_from(z.position)
		if exit != Vector3.INF:
			z.position = exit
			z._clear_goal()
			z.state = Zombie.State.ROAM
			destination = exit
	var to := destination - z.position
	var flat := Vector3(to.x, 0, to.z)
	var distance := flat.length()
	var desired := 1.4 if z.type_id == "fallen_revenant" else 0.8 if not visible else 5.0 if boss else 9.0 if z.type_id == "lantern_wisp" else 12.0
	var speed := z._speed * (0.5 if z._slow > 0.0 else 1.0)
	z.velocity = flat.normalized() * speed if distance > desired else Vector3.ZERO
	z.position += z.velocity * delta
	# Cross the void at the destination's height; never sink down to the sea between islands.
	var floor_height := maxf(z.world.ground_at(z.position), destination.y)
	z.position.y = move_toward(z.position.y, floor_height, speed * delta)
	if distance > 0.01:
		z.rotation.y = lerp_angle(z.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 6.0))
	z._animate_custom(delta, z.velocity.length())
	if not visible:
		return
	z.state = Zombie.State.CHASE
	if distance < 1.8 and absf(to.y) < 3.0 and z._attack_cd <= 0.0:
		z._attack_cd = 1.4
		target.hurt(z._damage, z.position, z)
		if z.type_id == "fallen_revenant": z.hp = minf(z.max_hp, z.hp + 8.0)
	if cooldown > 0.0 or distance > (55.0 if boss else 30.0):
		return
	if not z.world.has_line_of_sight(z.centre(), target.eye_position()):
		cooldown = 0.5
		return
	if z.type_id == "fallen_revenant":
		cooldown = 9.0
		leap_left = 1.2
		leap_to = target.global_position + flat.normalized() * -2.5
		if not z.world.terrain.is_walkable(leap_to.x, leap_to.z): leap_to = target.global_position
		leap_to.y = z.world.ground_at(leap_to)
		MistSeal.cast(z, target.global_position, 3.5, 1.2, 18.0 * Game.enemy_damage())
		return
	casts += 1
	cooldown = (5.5 if enraged else 7.0) if boss else 8.0 if z.type_id == "mist_weaver" else 5.5
	if boss and (not enraged or casts % 2 == 0) and distance < 16.0:
		MistSeal.cast(z, z.position, 9.0, 1.8, 22.0 * Game.enemy_damage(), 3.0)
	else:
		var centre := target.global_position
		var count := 3 if z.type_id == "mist_weaver" or boss else 1
		var across := flat.normalized().cross(Vector3.UP)
		for i in count:
			var offset := across * ((i - 1) * 5.5) if count == 3 else Vector3.ZERO
			MistSeal.cast(z, centre + offset, 2.6 if not boss else 3.3, 1.5 if not boss else 1.8, (13.0 if not boss else 20.0) * Game.enemy_damage())
