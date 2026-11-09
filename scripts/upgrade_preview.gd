class_name UpgradePreview
extends Node3D
## A small, silent demonstration. Fixed mesh counts; no gameplay nodes or timers.
var item := ""
var clock := 0.0
var particles: Array[MeshInstance3D] = []
var weapon: MeshInstance3D
var actor: Node3D
var pet := {}
var actor_scale := Vector3.ONE
var pet_root: Node3D

func configure(id: String, body: Node3D = null) -> void:
	item = id
	actor = body
	if actor: actor_scale = actor.scale
	if ShopDefs.PETS.has(id):
		pet_root = Node3D.new()
		add_child(pet_root)
		pet_root.position.y = 0.6 if id == "raven" else 0
		pet = Ally.build_beast_model(id, pet_root)
		return
	var definition: Dictionary = ShopDefs.ITEMS[id]
	weapon = MeshInstance3D.new()
	weapon.mesh = World.trap_mesh() if id == "trap_satchel" else WeaponDefs.mesh(definition.get("model", "sword"))
	var bounds := weapon.mesh.get_aabb()
	weapon.scale = Vector3.ONE * 0.8 / maxf(bounds.size.length(), 0.01)
	weapon.position = Vector3(0.45, 0.9, 0.3)
	add_child(weapon)
	var count := 18 if id == "rain_of_arrows" else 24 if id in ["undying_rage", "last_rites"] else 12
	for i in count:
		var p := MeshInstance3D.new()
		var l := LowPoly.new()
		if id == "rain_of_arrows":
			l.prism(Vector3.ZERO, Vector3.UP * 0.45, 0.012, 0.012, 4, Color(0.65, 0.45, 0.22))
			l.prism(Vector3.DOWN * 0.08, Vector3.ZERO, 0, 0.04, 4, Color(0.75, 0.82, 0.86))
		elif id in ["undying_rage", "last_rites"]:
			l.prism(Vector3.ZERO, Vector3.UP * 0.55, 0.12, 0, 5, Color(1, 0.42, 0.06))
			l.prism(Vector3.ZERO, Vector3.UP * 0.3, 0.07, 0, 5, Color(1, 0.85, 0.15))
		else:
			l.box(Vector3.ZERO, Vector3(0.13, 0.035, 0.06), Color(0.9, 0.72, 0.3) if id != "shadow_shroud" else Color(0.5, 0.3, 0.8))
		p.mesh = l.commit()
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		particles.append(p)

func _process(delta: float) -> void:
	clock += delta
	if pet_root:
		pet_root.position.y = (0.6 + sin(clock * 3) * 0.08) if item == "raven" else absf(sin(clock * 5)) * 0.035
		if item == "snake":
			(pet["snake"] as SnakeBody).moving = true
		elif item == "raven":
			pet_root.get_child(1).rotation.z = sin(clock * 9) * 0.6
			pet_root.get_child(2).rotation.z = -sin(clock * 9) * 0.6
		else:
			var legs: Array = pet.get("legs", [])
			for i in legs.size(): legs[i].rotation.x = sin(clock * 7 + (i % 2) * PI) * 0.5
			(pet["head"] as Node3D).rotation.x = sin(clock * 2) * 0.12
			(pet["tail"] as Node3D).rotation.y = sin(clock * 5) * 0.4
		return
	var phase := fmod(clock, 3.0) / 3.0
	if actor:
		actor.visible = item != "shadow_shroud" or phase < 0.55
		actor.position.y = -0.65 * pow(1.0 - minf(phase * 5, 1.0), 2) if item == "undying_rage" else 0
		actor.scale = actor_scale * (0.78 + sin(clock * 4) * 0.025) if item == "shadow_shroud" else actor_scale
	if weapon:
		weapon.rotation.z = sin(clock * (14 if item == "blade_flurry" else 3)) * 0.55
		weapon.position.y = 0.15 if item == "trap_satchel" else 0.9
		if item == "trap_satchel": weapon.scale.y = 0.45 + absf(sin(clock * 2.5)) * 0.65
	for i in particles.size():
		var p := particles[i]
		var angle := TAU * i / particles.size()
		var pulse := fmod(clock * 0.8 + i * 0.137, 1.0)
		if item == "rain_of_arrows":
			p.position = Vector3(cos(angle) * (0.3 + (i % 3) * 0.25), 2.6 * (1 - pulse), sin(angle) * 0.8)
		elif item in ["undying_rage", "last_rites"]:
			p.position = Vector3(cos(angle) * 0.42, pulse * 1.5, sin(angle) * 0.42)
			p.scale = Vector3.ONE * (1.0 - pulse * 0.7)
		elif item == "faultline":
			p.position = Vector3(sin(i * 2.0) * 0.1, 0.04 + sin(clock * 6 - i) * 0.03, -0.8 + i * 0.15)
			p.scale.x = 1 + pulse * 2
		else:
			p.position = Vector3(cos(angle + clock) * 0.8, 0.1 + (pulse if item == "shadow_shroud" else 0), sin(angle + clock) * 0.8)
			p.scale = Vector3.ONE * (0.7 + sin(clock * 5) * 0.3)
