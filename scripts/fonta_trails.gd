class_name FontaTrails
extends Node3D
## The trails the Mutant Snails of Fontanova leave behind them: glistening green poison, or embers
## still burning (FontaMind.trail_of). Each phone lays them itself from the snails it sees (they move
## the same everywhere) and hurts only its own player, and on the host its bots, who step in them:
## poison for TRAIL_POISON seconds, or set alight for TRAIL_BURN. A trail lasts TRAIL_LIFE seconds,
## a blob every TRAIL_STEP metres, and fades as it goes.

const TRAIL_STEP := 1.3
const TRAIL_LIFE := 8.0
const TRAIL_RADIUS := 0.95
const TRAIL_POISON := 2.0
const TRAIL_BURN := 1.5
const LIMIT := 90
const CHECK := 0.4

var world: World
var _blobs: Array[MeshInstance3D] = []
var _life: Array[float] = []
var _fire: Array[bool] = []
var _next := 0
var _check := 0.0
static var _meshes := {}


func _init(w: World) -> void:
	world = w
	name = "FontaTrails"


## Where a snail has got to: a new blob once it has gone far enough from its last.
func track(z: Zombie) -> void:
	if not z.is_alive():
		return
	var last: Vector3 = z.get_meta("trail_at", Vector3.INF)
	var at := Vector3(z.position.x, world.ground_at(z.position), z.position.z)
	if last != Vector3.INF and last.distance_to(at) < TRAIL_STEP:
		return
	z.set_meta("trail_at", at)
	if last == Vector3.INF:
		return
	_lay(at - z.global_basis.z * 0.9, FontaMind.trail_of(z) == "fire")


func _lay(at: Vector3, fire: bool) -> void:
	var blob: MeshInstance3D
	if _blobs.size() < LIMIT:
		blob = MeshInstance3D.new()
		blob.material_override = MesenllaModels.glow_material()
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blob)
		_blobs.append(blob)
		_life.append(0.0)
		_fire.append(false)
	else:
		blob = _blobs[_next]
	var i := _blobs.find(blob)
	_next = (i + 1) % LIMIT
	blob.mesh = _mesh(fire)
	blob.global_position = at + Vector3.UP * 0.04
	blob.rotation.y = randf() * TAU
	blob.scale = Vector3.ONE
	blob.visible = true
	_life[i] = TRAIL_LIFE
	_fire[i] = fire


static func _mesh(fire: bool) -> Mesh:
	var key := "fire" if fire else "poison"
	if _meshes.has(key):
		return _meshes[key]
	var l := LowPoly.new()
	var r := RandomNumberGenerator.new()
	r.seed = 301 if fire else 303
	var base := Color(1.0, 0.45, 0.12) if fire else Color(0.35, 0.85, 0.25)
	var bright := Color(1.0, 0.85, 0.4) if fire else Color(0.7, 1.0, 0.5)
	# A low, uneven puddle; little embers or bubbles on it.
	for k in 4:
		var a := r.randf() * TAU
		var d := r.randf_range(0.0, 0.35)
		l.prism(Vector3(cos(a) * d, 0, sin(a) * d), Vector3(cos(a) * d, 0.03, sin(a) * d), r.randf_range(0.35, 0.6), r.randf_range(0.3, 0.55), 7, base.darkened(0.1 * k))
	for k in 6:
		var a := r.randf() * TAU
		var d := r.randf_range(0.1, 0.5)
		if fire:
			l.prism(Vector3(cos(a) * d, 0.02, sin(a) * d), Vector3(cos(a) * d, r.randf_range(0.12, 0.3), sin(a) * d), 0.06, 0.0, 4, bright)
		else:
			l.prism(Vector3(cos(a) * d, 0.02, sin(a) * d), Vector3(cos(a) * d, 0.08, sin(a) * d), 0.06, 0.05, 6, bright)
	_meshes[key] = l.commit()
	return _meshes[key]


func _process(delta: float) -> void:
	var t := world.now
	for i in _blobs.size():
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		var blob := _blobs[i]
		if _life[i] <= 0.0:
			blob.visible = false
			continue
		var fade := clampf(_life[i] / 2.0, 0.0, 1.0)
		var flicker := (1.0 + sin(t * 9.0 + i) * 0.08) if _fire[i] else (1.0 + sin(t * 2.0 + i) * 0.03)
		blob.scale = Vector3(fade, 1.0 if _fire[i] else fade, fade) * flicker
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK
	for p: Player in world.local_players():
		if p.dead:
			continue
		var at := p.global_position
		for i in _blobs.size():
			if _life[i] <= 0.5:
				continue
			var b := _blobs[i].global_position
			if Vector2(at.x - b.x, at.z - b.z).length() < TRAIL_RADIUS and absf(at.y - b.y) < 1.5:
				if _fire[i]:
					p.ignite(TRAIL_BURN)
				else:
					p.poison_by_creature(TRAIL_POISON)
				break


## The world's trails, made the first time a snail needs one.
static func of(w: World) -> FontaTrails:
	if w.fonta_trails == null:
		w.fonta_trails = FontaTrails.new(w)
		w.add_child(w.fonta_trails)
	return w.fonta_trails
