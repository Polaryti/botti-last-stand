class_name VaelSkyMind
extends MesenllaMind
## Host-owned coastal ranged flyers. Pose and warning travel in the existing snapshot;
## MistSeal owns the dodgeable impact on each phone. Stun cancels an unreleased shot.
const KINDS := ["wreck_gull", "storm_ray", "bell_wraith"]
const TELLS := {"wreck_gull": 0.8, "storm_ray": 1.15, "bell_wraith": 1.4}
const EVERY := {"wreck_gull": 5.5, "storm_ray": 8.0, "bell_wraith": 10.0}
const REACH := 24.0
const RECOVERY := 1.8
const FLIGHT := 0.65
var orbit := 0.0

func _init(id: String) -> void:
	super(id)
	orbit = randf() * TAU

func interrupt(z: Zombie) -> void:
	phase = ""
	cooldown = maxf(cooldown, 2.0)
	_show(z, "")

func on_death(_z: Zombie) -> void:
	phase = ""

func tick(z: Zombie, target: Target, _to: Vector3, _dist: float, delta: float) -> bool:
	cooldown -= delta
	orbit += delta * (0.5 if kind == "storm_ray" else 0.8)
	var flat := target.global_position - z.position
	flat.y = 0.0
	var dist := flat.length()
	if phase == "tell":
		left -= delta
		z.velocity = z.velocity.move_toward(Vector3.ZERO, delta * 12.0)
		_move_air(z, z.velocity, delta)
		_face(z, aim, delta, 5.0)
		if not z._sees or dist > REACH + 5.0 or not _clear_shot(z, target):
			interrupt(z)
		elif left <= 0.0:
			_release(z)
			phase = "recover"
			left = RECOVERY
			_show(z, "m_throw")
		return true
	if phase == "recover":
		left -= delta
		# Low recovery within reach of a sword, outside the target's body.
		var away := -flat.normalized()
		if away.is_zero_approx(): away = Vector3.RIGHT
		var low := target.global_position + away * 2.6 + Vector3.UP * 0.65
		_steer(z, low, delta, 0.85)
		_face(z, target.global_position, delta, 4.0)
		if left <= 0.0:
			phase = ""
			_show(z, "")
		return true
	if cooldown <= 0.0 and z._sees and dist > 4.0 and dist < REACH and _clear_shot(z, target):
		phase = "tell"
		left = float(TELLS[kind])
		cooldown = float(EVERY[kind])
		# Lock the aim to a place; never drag a warning after the player.
		aim = _ground(z, target.global_position + target.velocity.limit_length(6.0) * 0.35)
		heading = (aim - z.position) * Vector3(1, 0, 1)
		heading = heading.normalized() if heading.length_squared() > 0.01 else Vector3.FORWARD
		_show(z, "m_cast", true)
		z.world.sfx_at(kind + "_call", z.position, 0.0)
		return true
	var centre := target.global_position if z._sees else z._home
	var radius := 7.0 if kind == "wreck_gull" else 9.0
	var desired := centre + Vector3(cos(orbit) * radius, float(z.def["fly_height"]) + sin(orbit * 1.4) * 0.45, sin(orbit) * radius)
	_steer(z, desired, delta)
	_face(z, target.global_position if z._sees else z.position + z.velocity, delta, 3.0)
	return true

func _clear_shot(z: Zombie, target: Target) -> bool:
	return z.world.has_line_of_sight(z.centre(), target.eye_position())

func _release(z: Zombie) -> void:
	match kind:
		"wreck_gull":
			MistSeal.cast(z, aim, 1.65, FLIGHT, z._damage, 0.0, MistSeal.Style.SALT)
		"storm_ray":
			for i in 3:
				var at := aim + heading * (i - 1) * 3.0
				MistSeal.cast(z, _ground(z, at), 1.65, FLIGHT + i * 0.22, z._damage, 0.0, MistSeal.Style.BRINE_BOLT)
		"bell_wraith":
			MistSeal.cast(z, aim, 4.2, 1.0, z._damage, 1.8, MistSeal.Style.KNELL)
	z.world.sfx_at(kind + "_release", z.position, 0.0)

func _steer(z: Zombie, at: Vector3, delta: float, factor := 1.0) -> void:
	var slow := 0.5 if z._slow > 0.0 else 1.0
	var haste := Zombie.HASTE if z.haste_left > 0.0 else 1.0
	var dir := at - z.position
	var want := dir.limit_length(1.0) * z._speed * factor * slow * haste
	z.velocity = z.velocity.move_toward(want, delta * 7.0)
	_move_air(z, z.velocity, delta)

func _move_air(z: Zombie, speed: Vector3, delta: float) -> void:
	var step := speed * delta
	var from := z.centre()
	# Probe ahead so quay faces and roofs remain solid.
	var probe := speed.normalized() * maxf(0.8, step.length())
	if not z.world.has_line_of_sight(from, from + probe):
		var side := Vector3(-speed.z, 0, speed.x).normalized() * speed.length()
		if not z.world.has_line_of_sight(from, from + side.normalized()): side = -side
		if z.world.has_line_of_sight(from, from + side.normalized()):
			step = side * delta
		elif z.world.has_line_of_sight(from, from + Vector3.UP * 1.2):
			step = Vector3.UP * minf(speed.length(), 3.0) * delta
		else:
			step = Vector3.ZERO
	var next := z.position + step
	next.x = clampf(next.x, -z.world.half_size + 2.0, z.world.half_size - 2.0)
	next.z = clampf(next.z, -z.world.half_size + 2.0, z.world.half_size - 2.0)
	var floor_y := z.world.ground_at(next) + 0.5
	# A high cliff is an obstacle, never a teleport to its plateau.
	if next.y >= floor_y:
		z.position = next
	elif floor_y - next.y < 0.4:
		next.y = floor_y
		z.position = next
	else:
		z.velocity = Vector3.ZERO
