class_name ClosingFog
extends Node3D
## All vs All: a deadly fog closes in on one spot near the village, stage by stage, so everyone left
## ends up in the same place. Outside it you lose health quickly. The clock in a match counts down to
## the moment it has closed: after that it keeps going until only one player is standing.

const TOTAL := 360.0
const STAGES := [[0.0, 190.0], [40.0, 190.0], [130.0, 85.0], [170.0, 85.0], [240.0, 48.0], [275.0, 48.0], [360.0, 8.0], [415.0, 0.0]]
const DAMAGE := [[0.0, 5.0], [170.0, 8.0], [275.0, 12.0], [360.0, 20.0]]
const WALL_HEIGHT := 50.0

var world: World
var centre := Vector2.ZERO
var radius := 190.0
var _wall: MeshInstance3D
var _stage := 0
var _zombie_timer := 1.0
var _thick := 1.0


func _init(owner_world: World, at: Vector2) -> void:
	world = owner_world
	centre = at


func _ready() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = WALL_HEIGHT
	tube.radial_segments = 72
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/fog_wall.gdshader")
	_wall = MeshInstance3D.new()
	_wall.mesh = tube
	_wall.material_override = m
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.extra_cull_margin = 400.0
	add_child(_wall)


static func radius_at(t: float) -> float:
	for i in STAGES.size() - 1:
		var a: Array = STAGES[i]
		var b: Array = STAGES[i + 1]
		if t <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), inverse_lerp(float(a[0]), float(b[0]), t))
	return 0.0


static func damage_at(t: float) -> float:
	var out := 0.0
	for row: Array in DAMAGE:
		if t >= float(row[0]):
			out = float(row[1])
	return out


## Whether it is moving in right now.
static func is_closing(t: float) -> bool:
	return radius_at(t + 0.5) < radius_at(t) - 0.001


func contains(at: Vector3, margin := 0.0) -> bool:
	# Once it has closed there is nowhere left, not even the very middle.
	return radius > 0.0 and Vector2(at.x - centre.x, at.z - centre.y).length() <= radius + margin


func _process(delta: float) -> void:
	var t: float = world.director.elapsed
	radius = radius_at(t)
	_wall.global_position = Vector3(centre.x, world.ground_at(Vector3(centre.x, 0, centre.y)) + WALL_HEIGHT * 0.2, centre.y)
	_wall.scale = Vector3(maxf(radius, 0.1), 1.0, maxf(radius, 0.1))
	var p := world.player
	var outside := false
	if p and not p.dead:
		outside = not contains(p.global_position)
		if outside:
			p.fog_hurt(damage_at(t) * delta)
	# Out there you cannot see far either.
	_thick = move_toward(_thick, 3.2 if outside else 1.0, delta * 2.0)
	world.set_fog_thickness(_thick)
	_announce(t)
	if Net.is_client():
		return
	_zombie_timer -= delta
	if _zombie_timer <= 0.0:
		_zombie_timer = 1.0
		for z: Zombie in world.zombies.duplicate():
			if z.is_alive() and not contains(z.position, 3.0):
				z.release()


func _announce(t: float) -> void:
	var closing := 0
	for i in STAGES.size():
		if t >= float(STAGES[i][0]):
			closing = i
	if closing != _stage:
		_stage = closing
		if is_closing(t):
			if not Net.is_client():
				world.director.show_banner("The fog is closing in", 3.0)
			Sfx.play("thunder_far", -7.0, 0.8, 1.0)


func centre3() -> Vector3:
	return Vector3(centre.x, 0.0, centre.y)
