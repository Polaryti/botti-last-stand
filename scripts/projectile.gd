class_name Projectile
extends MeshInstance3D
## Pooled moving shot: player arrows, enemy arrows and fireballs. Steps with a ray each tick.

enum Kind { ARROW, ENEMY_ARROW, FIREBALL, BOLT, AXE }

const HIT_PAD := 0.24 # how close to a body a shot has to pass to count as a hit

static var _graze_shape: SphereShape3D
static var _graze_query: PhysicsShapeQueryParameters3D

var world: World
var active := false
var kind: int = Kind.ARROW
var damage := 0.0
var knock := 0.0
var fire := false
var bounces := 0
var pierce := 0
var frost := false
var blast_radius := 0.0
var sharp := false
var from_player := false
var source := "" # who fired it, for the end screen
var visual := false # someone else's shot: it flies here too, but only their phone decides what it hits
var on_burst := Callable() # thrown things: what happens where it lands
var chaos_left := 0 # bomblets: how many more times it bounces off and goes on
var sparks := 0 # darts: how many others the spark jumps to
var poison := Vector2.ZERO # damage per second, and seconds
var stagger := 0.0
var owner_player: Player # who shot it: this phone's player, or one of the host's bots
var _returning := false
var _spin := 0.0
var _vel := Vector3.ZERO
var _gravity := 0.0
var _left := 0.0
var _speed := 0.0
var _exclude: Array[RID] = []
var _flame: Sprite3D


func _init(owner_world: World) -> void:
	world = owner_world
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	_flame = Sprite3D.new()
	_flame.texture = load("res://assets/sprites/burst.png")
	_flame.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_flame.shaded = false
	_flame.pixel_size = 0.0035
	_flame.modulate = Color(1.0, 0.6, 0.15)
	_flame.visible = false
	add_child(_flame)


func _ready() -> void:
	set_physics_process(active)


func launch(k: int, m: Mesh, pos: Vector3, vel: Vector3, grav: float, max_range: float, dmg: float, knock_force := 0.0, on_fire := false, bounce_count := 0) -> void:
	kind = k
	poison = Vector2.ZERO
	stagger = 0.0
	mesh = m
	position = pos
	_vel = vel
	_speed = vel.length()
	_gravity = grav
	_left = max_range
	damage = dmg
	knock = knock_force
	fire = on_fire
	bounces = bounce_count
	_exclude.clear()
	active = true
	visible = true
	pierce = 0
	frost = false
	blast_radius = 0.0
	sharp = false
	from_player = false
	visual = false
	on_burst = Callable()
	chaos_left = 0
	sparks = 0
	source = ""
	owner_player = null
	_returning = false
	_flame.visible = on_fire or k == Kind.FIREBALL
	_flame.modulate = Color(1.0, 0.6, 0.15)
	_orient()
	set_physics_process(true)


## A bot's shot never hits its own body, and can hit this phone's player if they are on the other side.
func set_owner_player(p: Player) -> void:
	owner_player = p
	if p and p.is_bot() and p.bot and is_instance_valid(p.bot.body):
		_exclude.append(p.bot.body.get_rid())


func _owner() -> Player:
	return owner_player if owner_player != null and is_instance_valid(owner_player) else world.player


func _orient() -> void:
	if _vel.length_squared() > 0.01:
		look_at(position + _vel, Vector3.UP if absf(_vel.normalized().y) < 0.98 else Vector3.RIGHT)


func stop() -> void:
	if kind == Kind.AXE and active and _owner():
		_owner().axe_returned()
	active = false
	visible = false
	set_physics_process(false)


func _is_friendly() -> bool:
	return kind == Kind.ARROW or kind == Kind.BOLT or kind == Kind.AXE


func _physics_process(delta: float) -> void:
	if _is_friendly() and not visual:
		var was := world.begin_act(_owner())
		_fly(delta)
		world.end_act(was)
	else:
		_fly(delta)


func _fly(delta: float) -> void:
	if kind == Kind.AXE and _returning:
		var thrower := _owner()
		if thrower == null or thrower.dead or position.distance_to(thrower.eye_position()) < 1.0:
			stop()
			return
		var home := thrower.eye_position()
		_vel = (home - position).normalized() * _speed
	_vel.y -= _gravity * delta
	var step := _vel * delta
	_left -= step.length()
	if _left <= 0.0:
		if kind == Kind.AXE and not _returning:
			_turn_back()
		elif kind == Kind.BOLT and blast_radius > 0.0:
			_explode(position)
		else:
			stop()
		return
	var next := position + step
	var mask := (Zombie.LAYER if _is_friendly() else Target.LAYER) | (0 if _returning else (1 | Terrain.LAYER))
	if visual:
		mask = 1 | Terrain.LAYER
	elif _is_friendly() and Net.pvp():
		mask |= Avatar.LAYER_AVATAR
		# A bot's shot can find this phone's own player.
		if _owner() != world.player:
			mask |= Target.LAYER
	elif not _is_friendly() and Net.is_host() and not Net.bot_players().is_empty():
		# The host's enemies shoot at its bots too. Nobody else's phone fires these.
		mask |= Avatar.LAYER_AVATAR
	var q := PhysicsRayQueryParameters3D.create(position, next, mask, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if _is_friendly() and not visual:
		var grazed := _grazed_body(position, step, hit)
		if not grazed.is_empty():
			hit = grazed
	if hit.is_empty():
		position = next
		_orient()
		if kind == Kind.AXE:
			_spin += delta * 18.0
			rotate_object_local(Vector3.RIGHT, _spin)
		return
	var c: Object = hit["collider"]
	var at: Vector3 = hit["position"]
	if _is_friendly() and c is Zombie:
		_hit_zombie(c as Zombie, at)
		return
	if c is Ally and _is_friendly():
		_exclude.append((c as Ally).get_rid())
		return
	if not _is_friendly() and c is Avatar:
		var victim := c as Avatar
		_exclude.append(victim.get_rid())
		if Net.is_bot(victim.peer):
			victim.hurt(damage, position)
			if kind == Kind.FIREBALL or fire:
				victim.ignite(ZombieDefs.BURN_SECONDS)
			stop()
		return
	if _is_friendly() and (c is Avatar or (c is Player and c != _owner())):
		var t := c as Target
		_exclude.append(t.get_rid())
		var shooter := _owner()
		var peer := world.peer_of(t)
		if shooter and shooter.is_foe_peer(peer):
			if on_burst.is_valid():
				_explode(at)
				return
			world.hit_rival(t, damage, position)
			world.fx_gore(at, Color(0.6, 0.1, 0.08))
			shooter.on_hit(false)
			shooter.on_shot_rival(peer, fire, frost)
			if poison.y > 0.0:
				world.status_rival(t, Net.Status.POISON, poison.y)
			if sparks > 0:
				world.status_rival(t, Net.Status.STUN, 0.5)
			if kind != Kind.AXE:
				stop()
		return
	if not _is_friendly() and c is Target:
		var t := c as Target
		if t is Player and source != "":
			(t as Player).hit_by = source
		t.hurt(damage, position)
		if kind == Kind.FIREBALL or fire:
			t.ignite(ZombieDefs.BURN_SECONDS)
		stop()
		return
	world.fx_impact(at)
	world.sfx_at("thunk", at, -6.0)
	if _is_friendly() and not visual:
		world.make_noise(at, 8.0)
	if kind == Kind.AXE:
		_turn_back()
	elif blast_radius > 0.0:
		_explode(at)
	else:
		stop()


## Bodies look wider than the capsules they collide with, so a shot that passes close enough to
## touch what you see still lands. Whatever the shot reaches first still stops it: a wall protects.
func _grazed_body(from: Vector3, step: Vector3, ray_hit: Dictionary) -> Dictionary:
	if _graze_shape == null:
		_graze_shape = SphereShape3D.new()
		_graze_shape.radius = HIT_PAD
		_graze_query = PhysicsShapeQueryParameters3D.new()
		_graze_query.shape = _graze_shape
	_graze_query.collision_mask = Zombie.LAYER | (Avatar.LAYER_AVATAR if Net.pvp() else 0) | (Target.LAYER if Net.pvp() and _owner() != world.player else 0)
	_graze_query.exclude = _exclude
	_graze_query.transform = Transform3D(Basis.IDENTITY, from)
	_graze_query.motion = step
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(_graze_query)
	if fractions[1] >= 1.0:
		return {}
	var at := from + step * fractions[1]
	if not ray_hit.is_empty() and from.distance_squared_to(ray_hit["position"]) <= from.distance_squared_to(at):
		return {}
	_graze_query.transform = Transform3D(Basis.IDENTITY, at)
	_graze_query.motion = Vector3.ZERO
	var touching := space.intersect_shape(_graze_query, 1)
	if touching.is_empty():
		return {}
	return {"collider": touching[0]["collider"], "position": at}


func _turn_back() -> void:
	_returning = true
	_gravity = 0.0
	_left = 60.0
	_exclude.clear()


func _explode(at: Vector3) -> void:
	var was := world.begin_act(_owner())
	_burst_here(at)
	world.end_act(was)


func _burst_here(at: Vector3) -> void:
	if on_burst.is_valid():
		var burst := on_burst
		if chaos_left > 0:
			chaos_left -= 1
			burst.call(at)
			# Off again, in any direction.
			var a := randf() * TAU
			position = at + Vector3.UP * 0.3
			_vel = Vector3(cos(a), randf_range(0.9, 1.5), sin(a)).normalized() * randf_range(6.0, 10.0)
			_left = 40.0
			_exclude.clear()
			return
		on_burst = Callable()
		stop()
		burst.call(at)
		return
	world.blast(at, blast_radius, WeaponDefs.DAMAGE * 2.0)
	stop()


func _hit_zombie(z: Zombie, at: Vector3) -> void:
	var head := z.headshot_at(at.y)
	var amount := damage * (2.0 if head and sharp else 1.0)
	var shooter := _owner()
	if from_player and shooter:
		amount = shooter.modify_damage(z, amount)
	if fire and z.phases:
		amount *= 1.5
	if amount > 0.0:
		world.damage_zombie(z, amount, _vel.normalized(), knock, at, head)
	if sparks > 0 and shooter:
		shooter.spark_from(z, sparks, amount)
	if from_player and shooter:
		shooter.on_shot_connect(z)
	if fire:
		z.ignite(ZombieDefs.BURN_SECONDS)
	if frost:
		z.slow(ZombieDefs.BURN_SECONDS)
	if poison.y > 0.0:
		z.add_dot(poison.x, poison.y)
		if from_player and shooter == world.player:
			Game.note_poison(poison.x * poison.y)
	if stagger > 0.0:
		z.stun(stagger)
	world.sfx_at("thunk", at, -3.0)
	_exclude.append(z.get_rid())
	if blast_radius > 0.0:
		_explode(at)
		return
	if kind == Kind.AXE:
		position = at
		return
	if pierce > 0:
		pierce -= 1
		position = at
		return
	if bounces > 0:
		var next := world.nearest_zombie_excluding(at, 12.0, _exclude)
		if next:
			bounces -= 1
			position = at
			_vel = (next.centre() - at).normalized() * _speed
			_gravity = 0.0
			_left = 14.0
			_orient()
			return
	stop()
