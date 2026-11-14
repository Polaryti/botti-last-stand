class_name MistStorm
extends Node3D
## A Mist Storm: an island of the Mists, all the outer islands at the Regent's coming, or a place on
## another map (the Valleys' camp once it has been shelled). Inside it, after a warning, the mist
## burns. Several can rage at once, each its own node in World.mist_storms. Local players own their
## damage; the host owns mobs and summons.
const FIRST := 45.0 # the first storm of a night in the Mists
const GAP := 12.0 # after one storm ends, the next gathers this much later
const TWO_FROM := 300.0 # from here on, two storms can rage at once
const STAGGER := 18.0 # the second of two does not gather at the same moment as the first
const WARNING := 8.0
const DURATION := 20.0
const DPS := 6.0
const FINALE_WARNING := 20.0
var finale := false
var warning := WARNING
var duration := DURATION
var world: World
var island := 0
var zone_at := Vector3.INF # a storm over a place rather than an island: its middle,
var zone_radius := 0.0 # and how far it reaches
var zone_leave := "" # what the warning tells you to leave
var elapsed := 0.0
var hud_line := "" # what the HUD says while you stand in this storm; empty when you do not
var _sound := 0.0
var _exposure := 0.0
var _rings: Array[MeshInstance3D] = []


## A storm over an island of the Mists, or (final_storm) over all the outer islands at once.
static func create(w: World, index: int, final_storm := false) -> MistStorm:
	for other: MistStorm in w.mist_storms.duplicate():
		# The Regent's storms take every outer island; otherwise, one storm to an island.
		if final_storm or other.finale or other.island == index:
			other.end_now()
	var storm := MistStorm.new()
	storm.finale = final_storm
	if final_storm:
		storm.warning = FINALE_WARNING
		storm.duration = INF
	storm.world = w
	storm.island = index
	storm._join(w)
	if not Net.is_client():
		for link: Dictionary in w.portals.links:
			link["open"] = true
			link["closing"] = 0.0
			w.portals._show(link)
		w.portals._tell_others()
	var affected: Array[int] = []
	if final_storm:
		for n in range(1, MapIslands.ISLANDS.size()): affected.append(n)
	else: affected.append(index)
	for n: int in affected:
		var land := MapIslands.ISLANDS[n]
		storm._ring(Vector3(land.x, land.w, land.y), land.z, final_storm)
	if final_storm:
		w.director.show_banner("The Veil Regent awakens — return to the arena! Outer-island storms strike in 20 seconds", 8.0)
	else:
		w.director.show_banner("Mist Storm gathering on %s — evacuate in 8 seconds" % NAMES[index], 8.0)
	return storm


## A storm that settles over a place and never lifts. The caller tells everyone why.
static func create_zone(w: World, centre: Vector3, radius: float, leave: String, warn := WARNING) -> MistStorm:
	var storm := MistStorm.new()
	storm.world = w
	storm.island = -1
	storm.zone_at = centre
	storm.zone_radius = radius
	storm.zone_leave = leave
	storm.warning = warn
	storm.duration = INF
	storm._join(w)
	storm._ring(Vector3(centre.x, w.ground_at(centre), centre.z), radius, false)
	return storm


## Becomes one of the world's storms, with its line of words at the top of the screen.
func _join(w: World) -> void:
	w.add_child(self)
	w.mist_storms.append(self)
	tree_exiting.connect(func() -> void:
		w.mist_storms.erase(self)
		w.storm_air())


## The look of a storm over a round of land: rings of mist light, and clouds rolling through.
func _ring(at: Vector3, radius: float, quiet: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.5, 0.35, 0.85, 0.4)
	for i in 3:
		var node := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = radius - 0.25
		ring.outer_radius = radius
		ring.rings = 64
		ring.ring_segments = 4
		node.mesh = ring
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position.y = i * 2.0 + 0.3
		root.add_child(node)
		_rings.append(node)
	var cloud := CPUParticles3D.new()
	cloud.amount = (2 if Game.quality == 0 else 4) if quiet else (16 if Game.quality == 0 else 32)
	cloud.lifetime = 5.0
	cloud.preprocess = 2.0
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cloud.emission_box_extents = Vector3(radius * 0.7, 4, radius * 0.7)
	cloud.direction = Vector3(1, 0, 0.5)
	cloud.initial_velocity_min = 1.5
	cloud.initial_velocity_max = 3.0
	cloud.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(18, 8)
	var mist := ShaderMaterial.new()
	mist.shader = preload("res://assets/shaders/mist_wisp.gdshader")
	mist.set_shader_parameter("tint", Vector3(0.4, 0.25, 0.65))
	quad.material = mist
	cloud.mesh = quad
	cloud.position.y = 3.0
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cloud)


## The line of words at the top of the screen while you are inside.
const NAMES := MapIslands.ZONE_NAMES


func contains(at: Vector3) -> bool:
	if zone_radius > 0.0:
		return Vector2(at.x - zone_at.x, at.z - zone_at.z).length() <= zone_radius
	if finale: return Vector2(at.x, at.z).length() > MapIslands.ISLANDS[0].z
	var land := MapIslands.ISLANDS[island]
	return world.portals != null and world.portals.island_of(at) == island and Vector2(at.x - land.x, at.z - land.y).length() <= land.z + 1.0


## Whether the mist burns yet, or is still gathering.
func burning() -> bool:
	return elapsed >= warning


## Gone at once, without waiting for its time to run out.
func end_now() -> void:
	set_physics_process(false)
	world.mist_storms.erase(self)
	queue_free()


func _physics_process(delta: float) -> void:
	var previous := elapsed
	elapsed += delta
	var exposure := maxf(0.0, minf(elapsed, warning + duration) - maxf(previous, warning))
	for i in _rings.size():
		_rings[i].position.y = 0.4 + (i % 3) * 2.0 + sin(elapsed * 1.5 + i) * 0.3
	_exposure += exposure
	if _exposure >= 0.5 or (elapsed >= warning + duration and _exposure > 0.0):
		var amount := DPS * _exposure
		_exposure = 0.0
		for target: Target in world.players:
			if target is Player and not target.dead and contains(target.global_position):
				target.hurt(amount, global_position)
		if not Net.active() or Net.is_host():
			for ally: Ally in world.allies:
				if not ally.dead and contains(ally.global_position): ally.hurt(amount, global_position)
	if world.player:
		var inside := contains(world.player.global_position)
		if not inside or world.player.dead: hud_line = ""
		elif elapsed < warning: hud_line = ("Mist Storm in %d s: leave %s" % [ceili(warning - elapsed), zone_leave.capitalize()]) if zone_leave != "" else "Mist Storm in %d s: get out" % ceili(warning - elapsed)
		elif finale: hud_line = "Mist Storm, 6 HP/s: back to the arena"
		elif zone_leave != "": hud_line = "Mist Storm, 6 HP/s: leave %s" % zone_leave.capitalize()
		else: hud_line = "Mist Storm, 6 HP/s: %d s left" % maxi(0, ceili(warning + duration - elapsed))
	_sound -= delta
	if _sound <= 0.0:
		_sound = 3.5
		if world.player and contains(world.player.global_position): Sfx.play("mist_regent", -10.0)
	if elapsed >= warning + duration: end_now()


## The way out: through an open portal off the island, or straight out of a storm over a place.
func escape(from: Vector3) -> Vector3:
	if zone_radius > 0.0:
		var out := Vector3(from.x - zone_at.x, 0, from.z - zone_at.z)
		if out.length_squared() < 0.01:
			out = Vector3.BACK
		var to := zone_at + out.normalized() * (zone_radius + 4.0)
		return Vector3(to.x, world.ground_at(to), to.z)
	if finale: return world.portals.waypoint(from, Vector3(16, 10, 0))
	var best := Vector3.INF
	var distance := INF
	for link: Dictionary in world.portals.links:
		if not link["open"] or float(link["closing"]) > 0.0: continue
		for side: String in ["a", "b"]:
			var at: Vector3 = link[side]
			if contains(at) and from.distance_squared_to(at) < distance:
				best = at
				distance = from.distance_squared_to(at)
	return best
