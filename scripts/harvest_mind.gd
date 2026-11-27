class_name HarvestMind
extends MesenllaMind
## The kitchen monsters telegraph on the host. Their poses and marks are visible on all phones.

const KINDS := ["pipburst", "ovenback", "pepperwing"]
const PIP_TELL := 1.05
const PIP_RADIUS := 3.5
const OVEN_TELL := 1.15
const PEPPER_TELL := 1.0

var _popped := false


func _init(id: String) -> void:
	super(id)
	cooldown = 1.0


func tick(z: Zombie, target: Target, to: Vector3, dist: float, delta: float) -> bool:
	cooldown -= delta
	if phase != "":
		left -= delta
		if phase == "recoil" and kind == "pepperwing":
			_fly(z, target, 1.25, delta)
		else:
			z.velocity = Vector3.ZERO
		if left <= 0.0:
			if phase == "burst":
				_popped = true
				z.next_hitter = -1
				z.take_damage(z.hp + 1.0, Vector3.ZERO, 0.0, z.centre())
				return true
			if phase != "recoil":
				phase = "recoil"
				left = 2.1 if kind == "pepperwing" else 0.6
				_show(z, z._current_anim)
			else:
				phase = ""
				_show(z, "")
		return true
	if not target or cooldown > 0.0 or not z._sees:
		if kind == "pepperwing":
			_fly(z, target, 4.7, delta)
			return true
		return false
	match kind:
		"pipburst":
			if dist > 3.0:
				return false
			_begin(z, target, "burst", "m_rear", PIP_TELL + 0.04, 6.0)
			MistSeal.cast(z, z.position, PIP_RADIUS, PIP_TELL, z._damage, 0.0, MistSeal.Style.PIPS)
		"ovenback":
			if dist > 12.0:
				return false
			_begin(z, target, "oven", "m_breath", OVEN_TELL + 0.3, 7.0)
			var forward := Vector3(to.x, 0, to.z).normalized()
			for i in 3:
				var at := z.position + forward * (3.0 + 3.2 * i)
				at.y = z.world.ground_at(at)
				if not z.world.has_line_of_sight(z.position + Vector3.UP * z.height * 0.74, at + Vector3.UP * 0.85):
					break
				MistSeal.cast(z, at, 1.76, OVEN_TELL + 0.14 * i, z._damage * 0.85, 0.0, MistSeal.Style.OVEN)
		"pepperwing":
			if dist > 19.0:
				_fly(z, target, 4.7, delta)
				return true
			_begin(z, target, "pepper", "m_cast", PEPPER_TELL + 0.06, 6.8)
			var landing := target.global_position + target.velocity * 0.37
			MistSeal.cast(z, landing, 2.75, PEPPER_TELL, z._damage, 0.0, MistSeal.Style.PEPPER)
	return true


func _begin(z: Zombie, target: Target, move: String, pose: String, seconds: float, again: float) -> void:
	phase = move
	left = seconds
	cooldown = again
	_face(z, target.global_position, 1.0)
	z.velocity = Vector3.ZERO
	_show(z, pose, true)
	z.world.sfx_at(kind + "_tell", z.position, -3.0)


func _fly(z: Zombie, target: Target, height: float, delta: float) -> void:
	_orbit += delta * 0.91
	var centre := target.global_position if target and (z._sees or z.position.distance_to(target.global_position) < 24.0) else z._home
	var aim_at := centre + Vector3(cos(_orbit), 0, sin(_orbit)) * 6.0
	aim_at.y = z.world.ground_at(aim_at) + height
	var drift := aim_at - z.position
	z.velocity = drift.limit_length(z._speed) if drift.length() > 0.25 else Vector3.ZERO
	# The moth climbs over walls instead of gliding through them, and can dip where there's room.
	if not z.world.has_line_of_sight(z.position, z.position + z.velocity * 0.37):
		z.velocity = Vector3.UP * z._speed
	z.position += z.velocity * delta
	z.position.y = maxf(z.world.ground_at(z.position) + 0.75, z.position.y)
	if target:
		_face(z, target.global_position, delta, 3.0)


func interrupt(z: Zombie) -> void:
	if phase != "" and phase != "recoil":
		MistSeal.break_from(z.world, z.net_id)
	super(z)


func on_death(z: Zombie) -> void:
	if not _popped:
		MistSeal.break_from(z.world, z.net_id)
