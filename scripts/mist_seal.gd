class_name MistSeal
extends Node3D
## A ground-following, one-hit warning. Each phone hurts only its locally owned targets.
## The style says what lands when it closes: mist that slows (the Mists), a quake that stuns, a bolt
## of lightning, a gout of fire, a blast of frost that freezes and then slows (an Ice wyvern), or a boulder
## thrown from whoever cast it (Mesenlla), or a Lantern Jelly's sting (Port Vael), which stuns.
## The drowned court of Port Vael (VaelMind) adds: a Press Gang's weighted net (it holds you where you
## stand), a wave that throws you back and slows you, the Harbourmaster's hook (it drags you to him), a
## burning oil lamp, a Kraken's Arm slamming down, the Lighthouse Keeper's great lamp (it dazzles whoever
## is looking at him as it blazes) and the Sunken Crown's judgement.
## The mutants of Fontanova (FontaMind) add: a bee's sting and a wasp's bite where they dive, a spider's
## web where it lands (it holds you and poisons you), an ostrich's kick (it throws you back) and a
## moth's burning dust (it dazzles you and sets you alight).
const LIMIT := 16
const STING_STUN := 0.8 # how long a Lantern Jelly's sting stuns you (ZombieDefs "sting_stun")
## How hard a closing circle hits a stronghold's portal it lands on, for each point it does to a player.
const PORTAL_SHARE := 1.5
enum Style { MIST, QUAKE, STORM, FIRE, BOULDER, FROST, STING, NET, WAVE, HOOK, LAMP, SLAM, FLASH, CROWN, SALT, BRINE_BOLT, KNELL, INK, STINGER, BITE, WEB, KICK, DUST, ELIXIR, BASH, SWEEP, CHANGE, NOVA, SHARD } # new ones go at the end
const FROST_FREEZE := 0.6
const FROST_SLOW := 2.0
const LOOKS := {
	Style.SALT: [Color(0.4, 0.85, 0.75), Color(0.9, 1, 0.86)],
	Style.BRINE_BOLT: [Color(0.35, 0.7, 1), Color(0.85, 0.95, 1)],
	Style.KNELL: [Color(0.95, 0.72, 0.25), Color(0.4, 1, 0.78)],
	Style.MIST: [Color(0.2, 0.8, 1.0), Color(0.85, 0.4, 1.0)],
	Style.QUAKE: [Color(0.95, 0.86, 0.32), Color(1.0, 0.6, 0.12)],
	Style.STORM: [Color(0.75, 0.85, 1.0), Color(1.0, 1.0, 0.75)],
	Style.FIRE: [Color(1.0, 0.42, 0.1), Color(0.9, 0.08, 0.04)],
	Style.BOULDER: [Color(0.78, 0.76, 0.72), Color(0.66, 0.36, 0.22)],
	Style.FROST: [Color(0.55, 0.9, 1.0), Color(0.9, 0.98, 1.0)],
	Style.STING: [Color(0.55, 1.0, 0.85), Color(0.8, 0.95, 1.0)],
	Style.NET: [Color(0.85, 0.74, 0.5), Color(0.62, 0.5, 0.32)],
	Style.WAVE: [Color(0.35, 0.8, 0.85), Color(0.75, 0.98, 1.0)],
	Style.HOOK: [Color(0.7, 0.72, 0.76), Color(0.95, 0.55, 0.2)],
	Style.LAMP: [Color(1.0, 0.7, 0.25), Color(1.0, 0.36, 0.08)],
	Style.SLAM: [Color(0.5, 0.85, 0.75), Color(0.85, 0.4, 0.55)],
	Style.FLASH: [Color(1.0, 0.95, 0.7), Color(1.0, 1.0, 0.92)],
	Style.CROWN: [Color(0.95, 0.78, 0.3), Color(0.45, 1.0, 0.82)],
	Style.INK: [Color(0.42, 0.16, 0.5), Color(0.12, 0.04, 0.16)],
	Style.STINGER: [Color(0.95, 0.8, 0.2), Color(0.55, 1.0, 0.35)],
	Style.BITE: [Color(0.95, 0.35, 0.2), Color(1.0, 0.75, 0.3)],
	Style.WEB: [Color(0.8, 0.78, 0.9), Color(0.72, 0.4, 1.0)],
	Style.KICK: [Color(0.95, 0.6, 0.3), Color(0.85, 0.2, 0.15)],
	Style.DUST: [Color(1.0, 0.6, 0.25), Color(0.72, 0.4, 1.0)],
	Style.ELIXIR: [Color(0.55, 1.0, 0.45), Color(0.72, 0.4, 1.0)],
	Style.BASH: [Color(0.9, 0.7, 0.32), Color(0.85, 0.3, 0.18)],
	Style.SWEEP: [Color(1.0, 0.82, 0.4), Color(0.75, 0.14, 0.1)],
	Style.CHANGE: [Color(0.82, 0.5, 1.0), Color(0.45, 1.0, 0.5)],
	Style.NOVA: [Color(0.7, 1.0, 0.55), Color(1.0, 0.95, 0.7)],
	Style.SHARD: [Color(0.75, 0.55, 1.0), Color(0.95, 0.85, 1.0)],
}
## What each sounds like as its circle appears, and as it closes.
const WARN_SOUNDS := {Style.MIST: "mist_warning", Style.QUAKE: "quake_warning", Style.STORM: "storm_call", Style.FIRE: "fire_warning",
	Style.BOULDER: "boulder_throw", Style.FROST: "frost_warning", Style.STING: "jelly_hum", Style.NET: "", Style.WAVE: "wave_rise",
	Style.HOOK: "", Style.LAMP: "", Style.SLAM: "", Style.FLASH: "lamp_flare", Style.CROWN: "crown_toll", Style.SALT: "", Style.BRINE_BOLT: "", Style.KNELL: "", Style.INK: "",
	Style.STINGER: "", Style.BITE: "", Style.WEB: "", Style.KICK: "", Style.DUST: "moth_flutter", Style.ELIXIR: "", Style.BASH: "", Style.SWEEP: "", Style.CHANGE: "transmute_rite", Style.NOVA: "alq_gather", Style.SHARD: ""}
const STRIKE_SOUNDS := {Style.MIST: "mist_burst", Style.QUAKE: "earth_slam", Style.STORM: "thunder", Style.FIRE: "fire_breath",
	Style.BOULDER: "boulder_impact", Style.FROST: "frost_burst", Style.STING: "jelly_sting", Style.NET: "net_land", Style.WAVE: "wave_crash",
	Style.HOOK: "hook_catch", Style.LAMP: "lamp_smash", Style.SLAM: "kraken_slam", Style.FLASH: "lamp_blaze", Style.CROWN: "crown_fall", Style.SALT: "salt_splash", Style.BRINE_BOLT: "brine_crack", Style.KNELL: "knell_strike", Style.INK: "kraken_ink",
	Style.STINGER: "bee_sting", Style.BITE: "wasp_bite", Style.WEB: "spider_bite", Style.KICK: "ostrich_kick", Style.DUST: "moth_dust", Style.ELIXIR: "elixir_shatter", Style.BASH: "shield_bash", Style.SWEEP: "spear_sweep", Style.CHANGE: "alq_change", Style.NOVA: "alq_nova", Style.SHARD: "alq_shard"}
## Thrown things (a net, a hook, a lamp) leave the thrower's hand for the last part of the tell.
const THROWN := [Style.NET, Style.HOOK, Style.LAMP, Style.SALT, Style.INK, Style.ELIXIR]
const THROW_FLIGHT := 0.55
## What each of the drowned court's circles does to you (VaelMind has the numbers).
const NET_HOLD := VaelMind.NET_HOLD
const WAVE_SLOW := VaelMind.WAVE_SLOW
const WAVE_KNOCK := VaelMind.WAVE_KNOCK
const HOOK_STUN := VaelMind.HOOK_STUN
const HOOK_STOP := VaelMind.HOOK_STOP
const LAMP_BURN := VaelMind.LAMP_BURN
const SLAM_STUN := VaelMind.KRAKEN_STUN
const FLASH_STUN := VaelMind.FLASH_STUN
const JUDGEMENT_STUN := VaelMind.JUDGEMENT_STUN
const INK_BLIND := VaelMind.KRAKEN_INK_BLIND
const INK_SLOW := VaelMind.KRAKEN_INK_SLOW
const STING_POISON := FontaMind.STING_POISON
const WEB_ROOT := FontaMind.WEB_ROOT
const WEB_POISON := FontaMind.WEB_POISON
const KICK_KNOCK := FontaMind.KICK_KNOCK
const DUST_BLIND := FontaMind.DUST_BLIND
const DUST_BURN := FontaMind.DUST_BURN
const ELIXIR_POISON := CultMind.ELIXIR_POISON
const ELIXIR_SLOW := CultMind.ELIXIR_SLOW
const BASH_STUN := CultMind.BASH_STUN
const BASH_KNOCK := CultMind.BASH_KNOCK
const SPEAR_STUN := CultMind.SPEAR_STUN
const SPEAR_KNOCK := CultMind.SPEAR_KNOCK
const CHANGE_POISON := GodMind.CHANGE_POISON
const CHANGE_ROOT := GodMind.CHANGE_ROOT
const NOVA_KNOCK := GodMind.NOVA_KNOCK
const NOVA_BURN := GodMind.NOVA_BURN
const SHARD_SLOW := GodMind.SHARD_SLOW
var style := 0
var _boulder: MeshInstance3D
var _chain: MeshInstance3D
var _from := Vector3.ZERO
static var _boulder_mesh: Mesh
static var _thrown_meshes := {}
var world: World
var radius := 3.0
var inner := 0.0
var warning := 1.5
var damage := 12.0
var source_id := -1
var elapsed := 0.0
var struck := false
var _material: ShaderMaterial

static func cast(z: Zombie, at: Vector3, reach: float, delay: float, amount: float, eye := 0.0, kind := 0) -> void:
	if z.world.mist_seals.size() >= LIMIT or not z.world.terrain.is_walkable(at.x, at.z):
		return
	# Aim at the surface below a jumping target, never at an invisible plane in mid-air.
	var ground := z.world.ground_at(at)
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.35, Vector3(at.x, ground - 0.5, at.z), 1)
	var hit := z.world.get_world_3d().direct_space_state.intersect_ray(query)
	at.y = (hit["position"] as Vector3).y if not hit.is_empty() else ground
	if Net.active():
		if Net.is_host():
			Net.mist_seal(at, reach, eye, delay, amount, z.net_id, kind)
	else:
		create(z.world, at, reach, eye, delay, amount, z.net_id, kind)

## A caster's attack broken: each of its rings that has not landed fades without striking, on every phone.
static func break_from(w: World, source: int, told := false) -> int:
	var gone := 0
	for seal: MistSeal in w.mist_seals.duplicate():
		if seal.source_id == source and not seal.struck:
			seal.fizzle()
			gone += 1
	if not told and Net.active() and Net.is_host():
		Net.seals_broken(source)
	return gone


## Gone without landing: a flicker of light where it was.
func fizzle() -> void:
	struck = true
	world.show_ring(position, radius * 0.6, Color(1.0, 0.95, 0.8))
	world.fx_blast(position + Vector3.UP * 0.3, radius * 0.4, Color(1.0, 0.95, 0.8, 0.35))
	world.mist_seals.erase(self)
	queue_free()


static func create(w: World, at: Vector3, reach: float, eye: float, delay: float, amount: float, source: int, kind := 0) -> MistSeal:
	var seal := MistSeal.new()
	w.add_child(seal)
	seal.world = w
	seal.position = at
	seal.radius = reach
	seal.inner = eye
	seal.warning = delay
	seal.damage = amount
	seal.source_id = source
	seal.style = kind if LOOKS.has(kind) else 0
	w.mist_seals.append(seal)
	seal.tree_exiting.connect(func() -> void: w.mist_seals.erase(seal))
	seal._build()
	var warn: String = WARN_SOUNDS.get(seal.style, "")
	if warn != "":
		w.sfx_at(warn, at, 0.0)
	if seal.style == Style.BOULDER or seal.style in THROWN:
		seal._throw()
	return seal

func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEPS := 8
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	var space := world.get_world_3d().direct_space_state
	for row in STEPS + 1:
		for col in STEPS + 1:
			var p := Vector3((float(col) / STEPS * 2.0 - 1.0) * radius, 0, (float(row) / STEPS * 2.0 - 1.0) * radius)
			var at := position + p
			var ground := world.ground_at(at)
			query.from = Vector3(at.x, maxf(position.y, ground) + 0.35, at.z)
			query.to = Vector3(at.x, ground - 0.5, at.z)
			var hit := space.intersect_ray(query)
			p.y = float((hit["position"] as Vector3).y) - position.y + 0.12 if not hit.is_empty() else ground - position.y + 0.12
			vertices.append(p)
			colours.append(Color(1, 1, 1, 1 if world.terrain.is_walkable(at.x, at.z) else 0))
	for row in STEPS:
		for col in STEPS:
			var a := row * (STEPS + 1) + col
			for i: int in [a, a + STEPS + 1, a + 1, a + 1, a + STEPS + 1, a + STEPS + 2]:
				st.set_color(colours[i])
				st.set_uv(Vector2(vertices[i].x, vertices[i].z) / (radius * 2.0) + Vector2.ONE * 0.5)
				st.set_normal(Vector3.UP)
				st.add_vertex(vertices[i])
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/mist_seal.gdshader")
	_material.set_shader_parameter("eye", inner / radius)
	_material.set_shader_parameter("col_a", LOOKS[style][0])
	_material.set_shader_parameter("col_b", LOOKS[style][1])
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	mesh_node.material_override = _material
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_node)

## A boulder flies from its thrower to where the seal will close, landing just as it does.
func _throw() -> void:
	var source := world.zombie_by_id(source_id)
	_from = source.centre() + Vector3.UP * (1.2 if style == Style.BOULDER else 0.6) if source and source.active else position + Vector3(0, 14.0, 0)
	if _boulder_mesh == null:
		var l := LowPoly.new()
		l.prism(Vector3(0, -0.55, 0), Vector3(0, 0.55, 0), 0.6, 0.48, 6, Color(0.46, 0.43, 0.4))
		l.prism(Vector3(0.2, 0.2, 0.3), Vector3(0.1, 0.5, 0.5), 0.2, 0.0, 4, Color(0.3, 0.55, 0.3))
		l.box(Vector3(-0.3, 0.1, 0.42), Vector3(0.2, 0.08, 0.1), Color(0.55, 0.95, 0.92))
		_boulder_mesh = l.commit()
	_boulder = MeshInstance3D.new()
	_boulder.mesh = _boulder_mesh if style == Style.BOULDER else thrown_mesh(style)
	if style == Style.HOOK:
		# The chain, paid out behind the hook from his hand.
		_chain = MeshInstance3D.new()
		var links := BoxMesh.new()
		links.size = Vector3(0.07, 0.07, 1.0)
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.32, 0.31, 0.3)
		iron.metallic = 0.6
		iron.roughness = 0.5
		links.material = iron
		_chain.mesh = links
		_chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chain.top_level = true
		_chain.visible = false
		add_child(_chain)
	_boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boulder.top_level = true
	_boulder.visible = style == Style.BOULDER
	add_child(_boulder)
	_boulder.global_position = _from


## A net, a hook or an oil lamp, as it flies (low-poly, made once).
static func thrown_mesh(kind: int) -> Mesh:
	if _thrown_meshes.has(kind):
		return _thrown_meshes[kind]
	var l := LowPoly.new()
	match kind:
		Style.ELIXIR:
			# A priest's flask: a round glass belly of green elixir, a long neck, a wax seal, a violet glint.
			l.prism(Vector3(0, -0.16, 0), Vector3(0, 0.1, 0), 0.15, 0.16, 8, Color(0.45, 0.95, 0.4))
			l.prism(Vector3(0, 0.1, 0), Vector3(0, 0.18, 0), 0.16, 0.05, 8, Color(0.4, 0.85, 0.36))
			l.prism(Vector3(0, 0.18, 0), Vector3(0, 0.34, 0), 0.045, 0.04, 6, Color(0.82, 0.9, 0.86))
			l.prism(Vector3(0, 0.34, 0), Vector3(0, 0.4, 0), 0.06, 0.05, 6, Color(0.62, 0.2, 0.16))
			l.box(Vector3(0.1, 0.0, 0.1), Vector3(0.05, 0.12, 0.02), Color(0.85, 0.6, 1.0))
		Style.INK:
			# A gout of ink, ragged at the edges, trailing a tail.
			var ink := Color(0.08, 0.03, 0.1)
			l.prism(Vector3(0, -0.3, 0), Vector3(0, 0.3, 0), 0.38, 0.3, 7, ink)
			for i in 6:
				var a := TAU * i / 6.0
				l.prism(Vector3(cos(a) * 0.25, 0, sin(a) * 0.25), Vector3(cos(a) * 0.55, 0.12, sin(a) * 0.55), 0.14, 0.0, 4, ink.lightened(0.08))
			l.prism(Vector3(0, 0.25, 0), Vector3(0, 0.9, -0.2), 0.18, 0.0, 5, ink)
		Style.SALT:
			l.prism(Vector3(0, -0.17, 0), Vector3(0, 0.18, 0), 0.16, 0.12, 7, Color(0.65, 0.95, 0.8))
			for i in 5:
				var a := TAU * i / 5.0
				l.prism(Vector3(cos(a) * 0.12, 0, sin(a) * 0.12), Vector3(cos(a) * 0.3, 0.1, sin(a) * 0.3), 0.06, 0.0, 4, Color(0.9, 1, 0.88))
		Style.NET:
			# A net spread as it falls: a ring of cork floats and lead weights, the mesh between them.
			var rope := Color(0.62, 0.52, 0.36)
			for i in 10:
				var a := TAU * i / 10.0
				var b := TAU * (i + 1) / 10.0
				l.prism(Vector3(cos(a) * 1.4, 0, sin(a) * 1.4), Vector3(cos(b) * 1.4, 0, sin(b) * 1.4), 0.03, 0.03, 3, rope)
				l.prism(Vector3(cos(a) * 1.4, 0, sin(a) * 1.4), Vector3(0, 0.25, 0), 0.02, 0.02, 3, rope.darkened(0.15))
				l.box(Vector3(cos(a) * 1.4, -0.04, sin(a) * 1.4), Vector3(0.12, 0.1, 0.12), Color(0.3, 0.31, 0.33) if i % 2 == 0 else Color(0.72, 0.55, 0.3))
			for r in [0.5, 0.95]:
				for i in 10:
					var a := TAU * i / 10.0
					var b := TAU * (i + 1) / 10.0
					l.prism(Vector3(cos(a) * r, 0.25 * (1.0 - r / 1.4), sin(a) * r), Vector3(cos(b) * r, 0.25 * (1.0 - r / 1.4), sin(b) * r), 0.018, 0.018, 3, rope)
		Style.HOOK:
			# A great iron hook, its eye and a few links of chain.
			var iron := Color(0.3, 0.29, 0.28)
			l.prism(Vector3(0, 0.6, 0), Vector3(0, -0.2, 0), 0.07, 0.07, 6, iron)
			l.prism(Vector3(0, -0.2, 0), Vector3(0.22, -0.42, 0), 0.07, 0.06, 6, iron)
			l.prism(Vector3(0.22, -0.42, 0), Vector3(0.42, -0.25, 0), 0.06, 0.05, 6, iron)
			l.prism(Vector3(0.42, -0.25, 0), Vector3(0.44, 0.02, 0), 0.05, 0.0, 6, Color(0.55, 0.52, 0.48))
			l.prism(Vector3(0, 0.62, -0.08), Vector3(0, 0.62, 0.08), 0.12, 0.12, 8, iron)
		Style.LAMP:
			# A ship's oil lamp: a brass base and cap, glass, a burning wick, oil sloshing out.
			var brass := Color(0.72, 0.52, 0.22)
			l.prism(Vector3(0, -0.2, 0), Vector3(0, -0.1, 0), 0.16, 0.18, 8, brass)
			l.prism(Vector3(0, -0.1, 0), Vector3(0, 0.18, 0), 0.13, 0.13, 8, Color(1.0, 0.8, 0.4))
			l.prism(Vector3(0, 0.18, 0), Vector3(0, 0.28, 0), 0.16, 0.06, 8, brass)
			l.prism(Vector3(0, 0.28, 0), Vector3(0, 0.38, 0), 0.04, 0.04, 6, brass)
			l.prism(Vector3(0, -0.05, 0), Vector3(0, 0.14, 0), 0.05, 0.0, 5, Color(1.0, 0.95, 0.7))
	_thrown_meshes[kind] = l.commit()
	return _thrown_meshes[kind]


func _physics_process(delta: float) -> void:
	elapsed += delta
	_material.set_shader_parameter("progress", minf(elapsed / warning, 1.0))
	if _boulder and not struck:
		var t := minf(elapsed / warning, 1.0)
		if style in THROWN:
			# Thrown at the end of the wind-up: in the air for the last moments only.
			var flight := minf(THROW_FLIGHT, warning)
			t = clampf((elapsed - (warning - flight)) / flight, 0.0, 1.0)
			_boulder.visible = elapsed >= warning - flight
		var at := _from.lerp(position + Vector3.UP * (0.15 if style == Style.NET else 0.6), t)
		at.y += sin(t * PI) * maxf(1.5 if style in THROWN else 4.0, _from.distance_to(position) * (0.2 if style in THROWN else 0.35))
		_boulder.global_position = at
		if style == Style.NET:
			# It opens as it flies.
			_boulder.scale = Vector3.ONE * lerpf(0.3, radius / 1.4, t)
			_boulder.rotation = Vector3(0, t * 2.0, 0)
		elif style == Style.HOOK:
			_boulder.rotation = Vector3(t * 9.0, 0, 0)
		else:
			_boulder.rotation = Vector3(t * 7.0, t * 4.0, 0)
	if _chain:
		var source := world.zombie_by_id(source_id)
		var hand := source.centre() + Vector3.UP * 0.5 if source and source.active else _from
		_chain.visible = _boulder != null and _boulder.visible and elapsed < warning + 0.3
		if _chain.visible:
			var end := _boulder.global_position
			var span := hand.distance_to(end)
			if span > 0.1:
				_chain.global_transform = Transform3D(Basis.looking_at(end - hand, Vector3.UP if absf((end - hand).normalized().y) < 0.95 else Vector3.RIGHT).scaled(Vector3(1, 1, span)), (hand + end) * 0.5)
	if not struck and elapsed >= warning:
		struck = true
		strike()
	if elapsed >= warning + 0.45:
		queue_free()

func strike() -> void:
	var col: Color = LOOKS[style][1]
	world.show_ring(position, radius, col)
	if style != Style.KNELL:
		world.fx_blast(position + Vector3.UP * 0.5, radius, Color(col, 0.65))
	match style:
		Style.SALT:
			world.fx_water(position, radius * 0.8, Color(0.65, 0.95, 0.8))
			if _boulder: _boulder.visible = false
		Style.BRINE_BOLT:
			var caster := world.zombie_by_id(source_id)
			world.fx_spark(caster.centre() if caster and caster.active else position + Vector3.UP * 6, position + Vector3.UP * 0.2)
			world.fx_water(position, radius * 0.6, Color(0.5, 0.8, 1))
		Style.KNELL:
			world.show_ring(position + Vector3.UP * 0.4, inner, Color(0.4, 1, 0.78))
			world.fx_mist(position + Vector3.UP, radius * 0.25)
		Style.MIST:
			world.fx_mist(position + Vector3.UP, radius * 0.5)
		Style.STORM:
			world.flash_bolt(position)
		Style.STING:
			world.fx_spark(position + Vector3(-radius * 0.6, 1.2, 0), position + Vector3(radius * 0.6, 0.3, 0))
			world.fx_spark(position + Vector3(0, 1.4, -radius * 0.6), position + Vector3(0, 0.3, radius * 0.6))
		Style.FROST:
			world.fx_mist(position + Vector3.UP * 0.6, radius * 0.4)
		Style.QUAKE, Style.BOULDER:
			world.fx_gore(position + Vector3.UP * 0.4, Color(0.42, 0.36, 0.3))
			if _boulder:
				_boulder.visible = false
		Style.WAVE, Style.SLAM:
			world.fx_water(position, radius * 0.8)
		Style.LAMP:
			world.fx_water(position, radius * 0.5, Color(1.0, 0.55, 0.15))
			world.fx_fire_patch(position, radius * 0.7)
			if _boulder:
				_boulder.visible = false
		Style.NET:
			if _boulder:
				_boulder.global_position = position + Vector3.UP * 0.12
				_boulder.scale = Vector3.ONE * radius / 1.4
		Style.FLASH:
			world.fx_blast(position + Vector3.UP * 3.0, radius * 0.5, Color(1.0, 1.0, 0.9, 0.9))
		Style.CROWN:
			world.fx_water(position, radius * 0.6, Color(0.95, 0.82, 0.4))
			world.flash_bolt(position)
		Style.STINGER, Style.BITE:
			world.fx_gore(position + Vector3.UP * 0.8, col)
		Style.WEB:
			world.fx_mist(position + Vector3.UP * 0.4, radius * 0.35)
			world.show_ring(position + Vector3.UP * 0.05, radius * 0.6, Color(0.9, 0.88, 1.0))
		Style.KICK:
			world.fx_gore(position + Vector3.UP * 0.5, Color(0.5, 0.42, 0.32))
		Style.DUST:
			world.fx_fire_patch(position, radius * 0.6)
			world.fx_mist(position + Vector3.UP * 1.0, radius * 0.5)
		Style.ELIXIR:
			world.fx_water(position, radius * 0.5, Color(0.5, 1.0, 0.42))
			world.fx_mist(position + Vector3.UP * 0.5, radius * 0.45)
			if _boulder:
				_boulder.visible = false
		Style.BASH:
			world.fx_gore(position + Vector3.UP * 0.6, Color(0.62, 0.5, 0.3))
			world.show_ring(position + Vector3.UP * 0.05, radius, Color(0.95, 0.75, 0.35))
		Style.CHANGE:
			# The ground changes: violet light bursts up out of it, and green.
			world.fx_ring(position + Vector3.UP * 0.1, radius, Color(0.8, 0.5, 1.0))
			world.fx_mist(position + Vector3.UP * 0.6, radius * 0.5)
			world.fx_gore(position + Vector3.UP * 0.5, Color(0.5, 1.0, 0.45))
		Style.NOVA:
			world.fx_ring(position + Vector3.UP * 0.2, radius, Color(0.75, 1.0, 0.6))
			world.show_ring(position + Vector3.UP * 0.1, radius * 0.6, Color(1.0, 0.95, 0.7))
			world.fx_fire_patch(position, radius * 0.25)
		Style.SHARD:
			world.fx_gore(position + Vector3.UP * 0.8, Color(0.8, 0.6, 1.0))
			world.show_ring(position + Vector3.UP * 0.05, radius, Color(0.85, 0.7, 1.0))
		Style.SWEEP:
			# The spear's sweep: dust thrown up along the arc, a bronze ring where the blade passed.
			world.show_ring(position + Vector3.UP * 0.05, radius, Color(1.0, 0.8, 0.4))
			for k in 3:
				var a := -0.8 + k * 0.8
				world.fx_gore(position + Vector3(sin(a + rotation.y), 0.3, cos(a + rotation.y)) * radius * 0.7, Color(0.62, 0.52, 0.4))
		Style.INK:
			world.fx_gore(position + Vector3.UP * 0.6, Color(0.1, 0.03, 0.12))
			world.fx_gore(position + Vector3(radius * 0.4, 0.4, 0), Color(0.16, 0.05, 0.18))
			world.fx_gore(position + Vector3(-radius * 0.4, 0.4, 0), Color(0.16, 0.05, 0.18))
			if _boulder:
				_boulder.visible = false
	var strike_sound: String = STRIKE_SOUNDS.get(style, "")
	if world.player and strike_sound != "":
		Sfx.play_at(strike_sound, position, world.player.global_position, 0.0)
	var source := world.zombie_by_id(source_id)
	var targets: Array = world.players.duplicate()
	if not Net.active() or Net.is_host():
		targets.append_array(world.allies)
	for target: Target in targets:
		if target.dead or target is Avatar or not contains(target.global_position):
			continue
		if style == Style.FLASH:
			# Only whoever is looking at the lamp as it blazes.
			if target is Player and looking_at(target as Player, position + Vector3.UP * 2.5):
				(target as Player).stun_by_creature(FLASH_STUN)
				(target as Player).say("Dazzled!")
			continue
		target.hurt(damage, position, source)
		if target is Player:
			var p := target as Player
			match style:
				Style.SALT: p.slow_by_creature(1.5)
				Style.BRINE_BOLT: p.stun_by_creature(0.35)
				Style.KNELL: p.slow_by_creature(2.0)
				Style.NET: p.root_by_creature(NET_HOLD)
				Style.WAVE:
					var away := Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z)
					if source:
						away = Vector3(p.global_position.x - source.position.x, 0, p.global_position.z - source.position.z)
					p.velocity += away.normalized() * WAVE_KNOCK + Vector3.UP * 3.0
					p.slow_by_creature(WAVE_SLOW)
				Style.HOOK:
					if source and source.is_alive():
						p.drag_to(source.position, HOOK_STOP)
					p.stun_by_creature(HOOK_STUN)
				Style.LAMP: p.ignite(LAMP_BURN)
				Style.SLAM:
					p.stun_by_creature(SLAM_STUN)
					p.velocity += Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z).normalized() * 6.0 + Vector3.UP * 4.0
				Style.CROWN: p.stun_by_creature(JUDGEMENT_STUN)
				Style.INK:
					# Ink in your eyes: the dark closes in round the edges for a while, and you stumble.
					p.night_blind_left = maxf(p.night_blind_left, INK_BLIND)
					p.slow_by_creature(INK_SLOW)
					p.say("Ink in your eyes!")
				Style.STINGER: p.poison_by_creature(STING_POISON)
				Style.WEB:
					p.root_by_creature(WEB_ROOT)
					p.poison_by_creature(WEB_POISON)
					p.say("Caught in a web!")
				Style.KICK:
					var away := Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z)
					if source:
						away = Vector3(p.global_position.x - source.position.x, 0, p.global_position.z - source.position.z)
					p.velocity += away.normalized() * KICK_KNOCK + Vector3.UP * 3.5
				Style.DUST:
					p.night_blind_left = maxf(p.night_blind_left, DUST_BLIND)
					p.ignite(DUST_BURN)
					p.say("Burning dust in your eyes!")
				Style.ELIXIR:
					p.poison_by_creature(ELIXIR_POISON)
					p.slow_by_creature(ELIXIR_SLOW)
				Style.BASH:
					var shoved := Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z)
					if source:
						shoved = Vector3(p.global_position.x - source.position.x, 0, p.global_position.z - source.position.z)
					p.velocity += shoved.normalized() * BASH_KNOCK + Vector3.UP * 2.5
					p.stun_by_creature(BASH_STUN)
				Style.CHANGE:
					p.poison_by_creature(CHANGE_POISON)
					p.root_by_creature(CHANGE_ROOT)
					p.say("The ground changes under you!")
				Style.NOVA:
					var thrown := Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z)
					p.velocity += (thrown.normalized() if thrown.length() > 0.1 else Vector3.FORWARD) * NOVA_KNOCK + Vector3.UP * 4.0
					p.ignite(NOVA_BURN)
				Style.SHARD:
					p.slow_by_creature(SHARD_SLOW)
				Style.SWEEP:
					var flung := Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z)
					if source:
						flung = Vector3(p.global_position.x - source.position.x, 0, p.global_position.z - source.position.z)
					p.velocity += flung.normalized() * SPEAR_KNOCK + Vector3.UP * 3.0
					p.stun_by_creature(SPEAR_STUN)
				Style.MIST: p.apply_status(Net.Status.SLOW, 2.0)
				Style.QUAKE, Style.BOULDER:
					p.apply_status(Net.Status.STUN, 0.8)
					p.velocity += Vector3(p.global_position.x - position.x, 0, p.global_position.z - position.z).normalized() * 6.0 + Vector3.UP * 4.0
				Style.STORM: p.apply_status(Net.Status.STUN, 0.5)
				Style.STING: p.stun_by_creature(STING_STUN)
				Style.FIRE: p.ignite(3.0)
				Style.FROST:
					p.apply_status(Net.Status.FREEZE, FROST_FREEZE)
					p.apply_status(Net.Status.SLOW, FROST_SLOW)
		elif style == Style.FIRE or style == Style.LAMP:
			target.ignite(3.0)
	# What falls on a stronghold's portal hurts it, as surely as claws do. The host decides.
	if world.fort and (not Net.active() or Net.is_host()) and Vector2(world.fort.heart_at.x - position.x, world.fort.heart_at.z - position.z).length() <= radius + 1.0:
		world.fort.hit_heart(damage * PORTAL_SHARE)

## Whether someone is facing a point: within VaelMind.FLASH_CONE degrees of looking straight at it.
static func looking_at(p: Player, at: Vector3) -> bool:
	var look := -p.global_basis.z
	if p.camera:
		look = -p.camera.global_basis.z
	look.y = 0.0
	var to := at - p.global_position
	to.y = 0.0
	if to.length_squared() < 0.01 or look.length_squared() < 0.001:
		return true
	return look.normalized().dot(to.normalized()) >= cos(deg_to_rad(VaelMind.FLASH_CONE))


func contains(at: Vector3) -> bool:
	var distance := Vector2(at.x - position.x, at.z - position.z).length()
	return distance <= radius and distance >= inner and absf(at.y - position.y) <= 3.5 and world.terrain.is_walkable(at.x, at.z)
