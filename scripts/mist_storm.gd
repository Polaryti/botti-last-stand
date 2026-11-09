class_name MistStorm
extends Node3D
## One scheduled island storm. Local players own their damage; the host owns mobs and summons.
const EVERY := 90.0
const WARNING := 8.0
const DURATION := 20.0
const DPS := 6.0
var world: World
var island := 0
var elapsed := 0.0
var _inside := false
var _status: Label
var _sound := 0.0
var _exposure := 0.0
var _rings: Array[MeshInstance3D] = []

static func create(w: World, index: int) -> MistStorm:
	var storm := MistStorm.new()
	storm.world = w
	storm.island = index
	w.add_child(storm)
	w.mist_storm = storm
	if not Net.is_client():
		for link: Dictionary in w.portals.links:
			link["open"] = true
			link["closing"] = 0.0
			w.portals._show(link)
		w.portals._tell_others()
	storm.tree_exiting.connect(func() -> void:
		w.set_fog_thickness(1.0)
		w._sky_value = -1.0
		w._apply_sky(w._last_dawn)
		if w.mist_storm == storm: w.mist_storm = null)
	var canvas := CanvasLayer.new()
	canvas.layer = 6
	storm.add_child(canvas)
	var panel := Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	storm._status = Label.new()
	storm._status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	storm._status.position.y = 80.0
	storm._status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storm._status.add_theme_color_override("font_color", Color(0.8, 0.65, 1.0))
	storm._status.add_theme_font_size_override("font_size", 22)
	storm._status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(storm._status)
	var land := MapIslands.ISLANDS[index]
	storm.position = Vector3(land.x, land.w, land.y)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.5, 0.35, 0.85, 0.4)
	for i in 3:
		var node := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = land.z - 0.25
		ring.outer_radius = land.z
		ring.rings = 64
		ring.ring_segments = 4
		node.mesh = ring
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position.y = i * 2.0 + 0.3
		storm.add_child(node)
		storm._rings.append(node)
	var cloud := CPUParticles3D.new()
	cloud.amount = 16 if Game.quality == 0 else 32
	cloud.lifetime = 5.0
	cloud.preprocess = 2.0
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cloud.emission_box_extents = Vector3(land.z * 0.7, 4, land.z * 0.7)
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
	storm.add_child(cloud)
	w.director.show_banner("Mist Storm gathering on %s — evacuate in 8 seconds" % NAMES[index], 8.0) if not Net.is_client() else w.director.show_banner("Mist Storm — evacuate %s" % NAMES[index], 8.0)
	return storm

const NAMES := ["the Arena", "the Rotunda", "the Battlements", "the Old Forest", "the Monument", "the Falls", "the Hollow", "the Terrace", "the Harbour", "the Northern Shelf", "the Eastern Shelf", "the Southern Shelf", "the Western Shelf"]

func contains(at: Vector3) -> bool:
	var land := MapIslands.ISLANDS[island]
	return world.portals != null and world.portals.island_of(at) == island and Vector2(at.x - land.x, at.z - land.y).length() <= land.z + 1.0

func _physics_process(delta: float) -> void:
	var previous := elapsed
	elapsed += delta
	var exposure := maxf(0.0, minf(elapsed, WARNING + DURATION) - maxf(previous, WARNING))
	for i in _rings.size():
		_rings[i].position.y = 0.4 + i * 2.0 + sin(elapsed * 1.5 + i) * 0.3
	_exposure += exposure
	if _exposure >= 0.5 or (elapsed >= WARNING + DURATION and _exposure > 0.0):
		var amount := DPS * _exposure
		_exposure = 0.0
		for target: Target in world.players:
			if target is Player and not target.dead and contains(target.global_position):
				target.hurt(amount, global_position)
		if not Net.active() or Net.is_host():
			for mob: Zombie in world.zombies.duplicate():
				if mob.is_alive() and contains(mob.position):
					var flinch := mob._hurt_stun
					var hitter := mob.last_hitter
					mob.next_hitter = -1
					mob.take_damage(amount, Vector3.ZERO, 0.0, mob.centre())
					mob._hurt_stun = flinch
					if mob.is_alive():
						mob.last_hitter = hitter
						mob.next_hitter = 0
			for ally: Ally in world.allies:
				if not ally.dead and contains(ally.global_position): ally.hurt(amount, global_position)
	if world.player:
		world.set_fog_thickness((1.5 if elapsed < WARNING else 4.0) if contains(world.player.global_position) else 1.0)
		var inside := contains(world.player.global_position)
		_status.visible = inside and not world.player.dead
		_status.text = "MIST STORM — EVACUATE • %ds" % ceili(WARNING - elapsed) if elapsed < WARNING else "MIST STORM • 6 HP/s • %ds" % maxi(0, ceili(WARNING + DURATION - elapsed))
		if inside: world._env.fog_light_color = Color(0.16, 0.1, 0.25)
		elif _inside:
			world._sky_value = -1.0
			world._apply_sky(world._last_dawn)
		_inside = inside
	_sound -= delta
	if _sound <= 0.0:
		_sound = 3.5
		if world.player and contains(world.player.global_position): Sfx.play("mist_regent", -10.0)
	if elapsed >= WARNING + DURATION: queue_free()

func escape(from: Vector3) -> Vector3:
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
