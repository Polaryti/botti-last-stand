class_name MistTide
extends Node3D
## The Mist Tide of Port Vael: the grey-green water of the drowned harbour, which turns every TURN
## seconds of the night. The night begins at low tide. When the tide turns it takes RISE seconds to
## come in or go out.
##   Low tide: the seabed is bare. The wrecks' sea chests (salvage) can be opened, each once by each
##   player every time the water goes out.
##   High tide: the flats are flooded. Wading slows you, more the deeper it is, down to SLOW at
##   SLOW_DEPTH. Mist rolls in over the water: the fog thickens to BLIND_FOG and, with your eyes
##   at the water, the sea-mist half-blinds you. The Drowned (ZombieDefs "drowned") are quicker by
##   QUICKEN.
## Everything follows the night's clock (Director.elapsed), which the host sends to every phone, so
## the tide is the same everywhere. Salvage is opened on each phone for itself, like the Mists' caches.
## The Hollow Sovereign can call the tide in out of its turn (surge): the host sends when, and from then
## it stands high for as long as he said, then goes back to keeping its own time.
## (The Sirens' songs are VaelMind.sing, run by the world on every phone.)

const TURN := 90.0
const RISE := 12.0
const LOW_Y := -1.35
const HIGH_Y := 0.85
const SLOW := 0.6
const SLOW_DEPTH := 1.0
const QUICKEN := 1.25
const BLIND_FOG := 1.9 # how much thicker the fog is at high tide
const FLOODED := 0.25 # deeper than this, you are in the tide
const WARN := 10.0 # seconds before a turn that the bells give warning
const CELL := 2.0
const SALVAGE_REACH := 2.2
const SALVAGE_XP := 40
const SALVAGE_WEAPONS := ["cutlass", "boarding_hook", "harpoon", "flare_pistol", "anchor", "oar"]

var world: World
var level := LOW_Y
var always_high := false # the Lantern Road: the tide never goes out
var _mat: ShaderMaterial
var _water: MeshInstance3D
var _was_high := false
var _warned_turn := -1
var _salvage: Array[Dictionary] = []
var surge_from := -1.0 # the night's clock when the Hollow Sovereign called the tide in, or -1
var surge_until := -1.0

static var _chest_mesh: ArrayMesh
static var _lid_mesh: ArrayMesh


func _init(owner_world: World, high_always := false) -> void:
	world = owner_world
	always_high = high_always
	name = "MistTide"
	level = HIGH_Y if always_high else LOW_Y


func _ready() -> void:
	_build_water()


# --- The clock ----------------------------------------------------------------------------------

## How many turns there have been this far into the night.
static func turns(elapsed: float) -> int:
	return int(floor(maxf(elapsed, 0.0) / TURN))


## Whether the tide stands high (or is coming in) at this point of the night.
static func is_high_at(elapsed: float) -> bool:
	return turns(elapsed) % 2 == 1


## The water's height at this point of the night.
static func level_at(elapsed: float) -> float:
	var n := turns(elapsed)
	var into := maxf(elapsed, 0.0) - n * TURN
	var now_y := HIGH_Y if n % 2 == 1 else LOW_Y
	if n == 0:
		return now_y
	var was_y := LOW_Y if n % 2 == 1 else HIGH_Y
	return lerpf(was_y, now_y, smoothstep(0.0, RISE, into))


## Seconds until the tide turns next.
static func turns_in(elapsed: float) -> float:
	return TURN - fmod(maxf(elapsed, 0.0), TURN)


## Which low tide this is (0 for the first): salvage fills again each time the water goes out.
static func ebb(elapsed: float) -> int:
	return int((turns(elapsed) + 1) / 2)


func elapsed() -> float:
	return world.director.elapsed if world.director else 0.0


func high() -> bool:
	return always_high or is_high_at(elapsed()) or surging()


## Whether the tide stands in at the Sovereign's word right now.
func surging() -> bool:
	var e := elapsed()
	return surge_from >= 0.0 and e >= surge_from and e < surge_until


## Calls the tide in now, for `seconds` (the host; every phone is told).
func surge(seconds: float) -> void:
	var e := elapsed()
	set_surge(e, e + seconds)
	if Net.is_host():
		Net.tide_surge(e, e + seconds)


func set_surge(from: float, until: float) -> void:
	surge_from = from
	surge_until = until
	Sfx.play("tide_in", -2.0)


## The water's height now: the tide's own, or risen at the Sovereign's word (coming in over RISE
## seconds, and going back out over as long when the surge is over).
func level_now(e: float) -> float:
	var own := level_at(e)
	if surge_from < 0.0 or e < surge_from:
		return own
	var k := smoothstep(surge_from, surge_from + RISE, e) * (1.0 - smoothstep(surge_until, surge_until + RISE, e))
	return lerpf(own, HIGH_Y, k)


# --- What it does -------------------------------------------------------------------------------

## How deep the water is here: 0 on dry land.
## How deep the water is here: over the ground, or over what you stand on (the Lantern Barge's deck).
func depth_at(at: Vector3) -> float:
	return maxf(0.0, level - maxf(world.terrain.height(at.x, at.z), at.y - 0.1))


func flooded(at: Vector3) -> bool:
	return depth_at(at) > FLOODED


## What wading here does to your speed.
func slow_at(at: Vector3) -> float:
	var d := depth_at(at)
	if d <= FLOODED:
		return 1.0
	return lerpf(1.0, SLOW, clampf((d - FLOODED) / (SLOW_DEPTH - FLOODED), 0.0, 1.0))


## How quick one of the Drowned is now.
func quickens(z: Zombie) -> float:
	return QUICKEN if high() and z.def.get("drowned", false) else 1.0


## How much of the view the sea-mist takes: nothing out of the water, up to about half with the
## water to your chest at high tide.
func blind_for(at: Vector3) -> float:
	if not high() or (world.last_light and world.last_light.in_light(at)):
		return 0.0 # (on the Lantern Road the barge's light keeps the mist off the water round it)
	return clampf((depth_at(at) - FLOODED) / (SLOW_DEPTH - FLOODED), 0.0, 1.0) * 0.5


## How much thicker the fog is now: up to BLIND_FOG as the tide comes in.
func fog_scale() -> float:
	return lerpf(1.0, BLIND_FOG, clampf((level - LOW_Y) / (HIGH_Y - LOW_Y), 0.0, 1.0))


## What the HUD shows: the state of the tide and when it turns.
func status() -> Dictionary:
	if always_high:
		return {"high": true, "text": "High tide", "turns_in": -1.0}
	var e := elapsed()
	var h := is_high_at(e)
	var moving := e >= TURN and fmod(e, TURN) < RISE
	var text := ("The tide is coming in" if h else "The tide is going out") if moving else ("High tide" if h else "Low tide")
	return {"high": h, "text": text, "turns_in": turns_in(e)}


func _process(delta: float) -> void:
	var e := elapsed()
	var want := HIGH_Y if always_high else level_now(e)
	level = want if absf(want - level) > 1.0 else move_toward(level, want, delta * 2.0)
	if _mat:
		_mat.set_shader_parameter("level", level)
	world.set_tide_fog(fog_scale())
	if always_high:
		return
	var h := is_high_at(e) or surging()
	if h != _was_high:
		_was_high = h
		_turned(h)
	# The harbour bells give warning before it turns.
	var n := turns(e)
	if turns_in(e) <= WARN and _warned_turn != n and not surging():
		_warned_turn = n
		world.banner("The tide is about to come in..." if not h else "The tide will soon go out...", 3.0)
		Sfx.play("tide_bell", -4.0)
	_tick_salvage(e)


func _turned(h: bool) -> void:
	if h:
		world.banner("High tide: the Mist rolls in over the flats", 3.5)
		Sfx.play("tide_in", -2.0)
	else:
		world.banner("Low tide: the seabed is bare. Salvage the wrecks!", 3.5)
		Sfx.play("tide_out", -2.0)


## Sets the water's colour for the light of morning (0 night, 1 full day).
func set_dawn(k: float) -> void:
	if _mat:
		_mat.set_shader_parameter("dawn", k)


# --- The water ----------------------------------------------------------------------------------

## A sheet over every part of the map the tide can reach. Each vertex keeps the ground's height in
## UV2.x for the shader, and the shader lifts the sheet to the tide's level.
func _build_water() -> void:
	var t := world.terrain
	var half := float(t.half_extent)
	var side := int(half * 2.0 / CELL)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for j in side:
		for i in side:
			var x0 := -half + i * CELL
			var z0 := -half + j * CELL
			var corners := [Vector2(x0, z0), Vector2(x0 + CELL, z0), Vector2(x0 + CELL, z0 + CELL), Vector2(x0, z0 + CELL)]
			var lowest := INF
			for c: Vector2 in corners:
				lowest = minf(lowest, t.ground_height(c.x, c.y))
			if lowest > HIGH_Y + 0.05:
				continue
			any = true
			for k: int in [0, 1, 2, 0, 2, 3]:
				var c: Vector2 = corners[k]
				st.set_uv2(Vector2(t.ground_height(c.x, c.y), 0.0))
				st.set_uv(c * 0.1)
				st.add_vertex(Vector3(c.x, 0.0, c.y))
	if not any:
		return
	if not t.coast.is_empty() or not t.sea.is_empty():
		# The open sea, out past the edge of the land to the horizon: to the south off Port Vael, all
		# round the Lantern Road.
		var far := 900.0
		var quads: Array = [[Vector2(-far, half - 1.0), Vector2(far, half - 1.0), Vector2(far, half + far), Vector2(-far, half + far)]]
		if not t.sea.is_empty():
			quads.append([Vector2(-far, -half - far), Vector2(far, -half - far), Vector2(far, -half + 1.0), Vector2(-far, -half + 1.0)])
			quads.append([Vector2(-half - far, -half + 1.0), Vector2(-half + 1.0, -half + 1.0), Vector2(-half + 1.0, half - 1.0), Vector2(-half - far, half - 1.0)])
			quads.append([Vector2(half - 1.0, -half + 1.0), Vector2(half + far, -half + 1.0), Vector2(half + far, half - 1.0), Vector2(half - 1.0, half - 1.0)])
		for q: Array in quads:
			for k: int in [0, 1, 2, 0, 2, 3]:
				var c: Vector2 = q[k]
				st.set_uv2(Vector2(Terrain.SEA_Y - 6.0, 0.0))
				st.set_uv(c * 0.1)
				st.add_vertex(Vector3(c.x, 0.0, c.y))
	_water = MeshInstance3D.new()
	_water.name = "TideWater"
	_water.mesh = st.commit()
	# The mesh is flat at 0 and lifted in the shader, so its bounds must cover every height it reaches.
	_water.extra_cull_margin = 4.0
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/tide_sea.gdshader")
	_mat.set_shader_parameter("coastal", 1.0 if world.map_id == "vael" else 0.0)
	_mat.set_shader_parameter("level", level)
	_water.material_override = _mat
	add_child(_water)


# --- Salvage ------------------------------------------------------------------------------------

## A sea chest on a wreck: iron-bound, crusted with barnacles and hung with weed, and a little green
## lamp of light over it while it can be opened.
func add_salvage(at: Vector3, yaw: float) -> void:
	if _chest_mesh == null:
		_build_chest_meshes()
	var node := Node3D.new()
	node.name = "Salvage"
	add_child(node)
	node.position = at
	node.rotation.y = yaw
	var chest := MeshInstance3D.new()
	chest.mesh = _chest_mesh
	chest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(chest)
	var lid := MeshInstance3D.new()
	lid.mesh = _lid_mesh
	lid.position = Vector3(0, 0.6, -0.4)
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lid)
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	glow.mesh = quad
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.albedo_color = Color(0.55, 1.0, 0.82, 0.5)
	look.albedo_texture = (WyvernRig.puff_mesh().material as StandardMaterial3D).albedo_texture
	look.disable_fog = true
	glow.material_override = look
	glow.position.y = 1.3
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glow)
	_salvage.append({"at": at, "lid": lid, "glow": glow, "taken": -1})


func salvage() -> Array[Dictionary]:
	return _salvage


## Whether this chest is out of the water and not yet opened by you this low tide.
func salvage_open(c: Dictionary) -> bool:
	var at: Vector3 = c["at"]
	return level < at.y - 0.1 and int(c["taken"]) != ebb(elapsed())


func _tick_salvage(e: float) -> void:
	var p := world.player
	var n := ebb(e)
	for c: Dictionary in _salvage:
		var can_open := salvage_open(c)
		(c["glow"] as Node3D).visible = can_open
		var lid := c["lid"] as Node3D
		lid.rotation.x = move_toward(lid.rotation.x, 0.0 if int(c["taken"]) != n else -1.7, get_process_delta_time() * 3.0)
		if can_open and p and not p.dead and p.global_position.distance_to(c["at"]) < SALVAGE_REACH:
			_open(c, p, n)


func _open(c: Dictionary, p: Player, n: int) -> void:
	c["taken"] = n
	var coins := randi_range(8, 20)
	if Game.mode != Game.Mode.SANDBOX:
		Game.doubloons += coins
		Game.save_settings()
	p.add_xp(SALVAGE_XP)
	var got := "%d doubloons" % coins
	var roll := randf()
	var usable := SALVAGE_WEAPONS.filter(func(w: String) -> bool: return p.can_use(w))
	if roll < 0.5 and not usable.is_empty():
		var weapon: String = usable.pick_random()
		p.give_weapon(weapon)
		got += " and a %s" % WeaponDefs.ALL[weapon]["name"]
	elif roll < 0.75:
		p.heal(35.0)
		got += " and ship's biscuit"
	else:
		var power: String = PowerDefs.pick_potion(world.spawn_map())
		if power != "":
			p.activate_power(power)
			got += " and %s" % PowerDefs.ALL[power]["name"]
	world.banner("Salvage: %s" % got, 3.5)
	world.fx_ring(c["at"], 2.6, Color(0.55, 1.0, 0.82))
	Sfx.play("salvage", -2.0)


static func _build_chest_meshes() -> void:
	var wood := Color(0.36, 0.25, 0.16)
	var iron := Color(0.2, 0.21, 0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2391
	var l := LowPoly.new()
	l.box(Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 0.8), wood)
	for x: float in [-0.45, 0.0, 0.45]:
		l.box(Vector3(x, 0.3, 0), Vector3(0.08, 0.62, 0.84), iron)
	l.box(Vector3(0, 0.42, 0.41), Vector3(0.16, 0.2, 0.04), Color(0.7, 0.55, 0.25))
	VaelModels.barnacles(l, Vector3(0.45, 0.15, 0.4), Vector3(0.4, 0, 1), 5, 0.035, rng)
	VaelModels.barnacles(l, Vector3(-0.55, 0.2, -0.2), Vector3(-1, 0.2, 0), 4, 0.03, rng)
	VaelModels.kelp(l, Vector3(-0.5, 0.6, 0.38), 0.4, 2, rng)
	_chest_mesh = l.commit()
	var t := LowPoly.new()
	t.box(Vector3(0, 0.1, 0.4), Vector3(1.2, 0.2, 0.8), wood.lightened(0.05))
	for x: float in [-0.45, 0.0, 0.45]:
		t.box(Vector3(x, 0.1, 0.4), Vector3(0.08, 0.22, 0.84), iron)
	VaelModels.barnacles(t, Vector3(0.2, 0.2, 0.3), Vector3(0, 1, 0), 4, 0.03, rng)
	_lid_mesh = t.commit()
