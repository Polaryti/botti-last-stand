class_name SovereignRegalia
extends Node3D
## The drowned king's spectral body: a broken halo, empty ribs, funeral streamers and
## a separately articulated royal trident. Driven by replicated boss poses on every phone.
var owner_mob: Zombie
var halo: Node3D
var weapon: Node3D
var streamers: Array[Node3D] = []
var ribs: Node3D
var arms: Array[Node3D] = []

static func install(z: Zombie) -> void:
	var rig := SovereignRegalia.new()
	rig.owner_mob = z
	# Keep the inherited skeleton for combat timings; the king has an entirely separate silhouette.
	for mesh: MeshInstance3D in z._visual.find_children("*", "MeshInstance3D", true, false): mesh.visible = false
	z._visual.add_child(rig)
	rig.build()
	for mesh: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		mesh.set_meta("own_material", mesh.material_override)
		z._parts.append(mesh)

func part(parent: Node3D, key: String, draw: Callable, glow := false) -> void:
	var mesh := MesenllaModels._part(parent, MesenllaModels._mesh("royal_" + key, draw))
	if glow: mesh.material_override = MesenllaModels.glow_material()

func build() -> void:
	part(self, "empty_hood", func(l: LowPoly) -> void:
		var black := Color(0.015,0.027,0.03)
		l.prism(Vector3(0,2.05,0),Vector3(0,2.6,-0.15),0.26,0.22,7,black)
		for side: float in [-1,1]:
			l.prism(Vector3(side*0.24,2.02,0.13),Vector3(side*0.23,2.55,0),0.065,0.025,5,VaelModels.ROYAL.darkened(0.6))
			l.prism(Vector3(side*0.19,2.12,0.23),Vector3(side*0.08,2.38,0.22),0.013,0.004,4,VaelModels.BARNACLE)
		l.prism(Vector3(0,2.55,-0.12),Vector3(0,2.85,-0.4),0.16,0,6,black))
	part(self, "abyss", func(l: LowPoly) -> void:
		l.prism(Vector3(0,2.16,0.25),Vector3(0,2.41,0.25),0.009,0.002,4,Color(0.28,0.9,0.78)), true)
	for side: float in [-1,1]:
		var arm := MesenllaModels._pivot(self,Vector3(side*0.6,1.95,0),"Arm")
		arms.append(arm)
		part(arm,"long_arm%s" % side,func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO,Vector3(side*0.15,-0.6,0.08),0.11,0.06,7,Color(0.04,0.09,0.1))
			l.prism(Vector3(side*0.15,-0.6,0.08),Vector3(side*0.12,-1.05,0.22),0.06,0.035,6,VaelModels.BARNACLE.darkened(0.3))
			for finger in 4:
				var p := Vector3(side*0.12+(finger-1.5)*0.055,-1.05,0.22)
				l.prism(p,p+Vector3(0,-0.18,0.12),0.022,0.015,4,VaelModels.BARNACLE)
				l.prism(p+Vector3(0,-0.18,0.12),p+Vector3(0,-0.1,0.23),0.015,0,4,Color(0.28,0.9,0.78)))
	halo = MesenllaModels._pivot(self, Vector3(0, 2.65, -0.15), "BrokenHalo")
	part(halo, "halo", func(l: LowPoly) -> void:
		for i in 11:
			var a := TAU * i / 12.0
			var b := a + 0.38
			var p := Vector3(cos(a), 0, sin(a)) * 0.78
			l.prism(p, Vector3(cos(b), 0, sin(b)) * 0.78, 0.035, 0.035, 5, VaelModels.GOLD_OLD)
			l.prism(p, p + Vector3(cos(a) * 0.12, 0.25 + (i % 3) * 0.1, sin(a) * 0.12), 0.055, 0, 5, Color(0.28,0.9,0.78)), true)
	ribs = MesenllaModels._pivot(self, Vector3(0, 1.5, 0.16), "EmptyRibs")
	part(ribs, "ribcage", func(l: LowPoly) -> void:
		for side: float in [-1, 1]:
			for i in 6:
				var p := Vector3(side * 0.16, 0.4 - i * 0.13, 0.12)
				var q := Vector3(side * (0.58 - i * 0.03), p.y - 0.04, 0.38)
				l.prism(p, q, 0.035, 0.026, 5, VaelModels.BARNACLE)
				l.prism(q, Vector3(side * 0.25, p.y - 0.1, 0.56), 0.026, 0.008, 5, Color(0.28,0.9,0.78)), true)
	for i in 12:
		var a := TAU * i / 12
		var strip := MesenllaModels._pivot(self, Vector3(cos(a)*0.55, 1.35, sin(a)*0.55), "Shroud%d" % i)
		streamers.append(strip)
		part(strip, "shroud%d" % i, func(l: LowPoly) -> void:
			var end := Vector3(cos(a)*0.45, -1.25 - (i%3)*0.14, sin(a)*0.45)
			l.leaf(Vector3.ZERO, Vector3(-sin(a)*0.2, -0.55, cos(a)*0.2), end, Color(0.035,0.08,0.095))
			l.prism(Vector3.ZERO, end, 0.013, 0.002, 4, Color(0.28,0.9,0.78)))
	weapon = MesenllaModels._pivot(self, Vector3(0.9, 1.0, 0.25), "RoyalTrident")
	MesenllaModels._part(weapon, VaelModels.sovereign_gear()["handslot.r"])
	part(self, "drowned_seal", func(l: LowPoly) -> void:
		for i in 24:
			var a := TAU*i/24
			var b := a+0.13
			l.prism(Vector3(cos(a),0.06,sin(a))*0.9, Vector3(cos(b),0.06,sin(b))*0.9,0.015,0.015,4,Color(0.28,0.9,0.78)), true)

func _process(delta: float) -> void:
	var z := owner_mob
	if not z.active: return
	var t := z.world.now
	var tell := z.is_warning()
	for i in arms.size():
		arms[i].rotation.x = lerpf(arms[i].rotation.x, -1.8 if tell else (-0.5 if z._attack_left > 0 else sin(t*1.3+i)*0.08), minf(1,delta*7))
	scale = Vector3.ONE * (maxf(0.01, z._dying / 2.6) if z._dying > 0 else 1.0)
	position.y = -maxf(0, 2.6-z._dying)*0.3 if z._dying > 0 else sin(t*1.4)*0.035
	var casting := z._current_anim in ["Raise", "Spellcast_Shoot", "WindUp"]
	halo.rotation = Vector3(sin(t*0.8)*0.12, -t*0.35, cos(t)*0.1)
	halo.scale = Vector3.ONE * (1.15 if tell else 1.0)
	halo.position.y = 2.65 + sin(t*1.6)*0.08 + (0.3 if tell else 0.0)
	ribs.scale = Vector3.ONE * (1 + sin(t*2)*0.035)
	for i in streamers.size():
		streamers[i].rotation.x = sin(t*2.3-i*0.6)*0.2
		streamers[i].rotation.z = cos(t*1.8-i*0.7)*0.16
		streamers[i].rotation.y = sin(t-i)*0.12
	weapon.position.y = lerpf(weapon.position.y, 1.5 if casting else 1.0, minf(1,delta*6))
	weapon.rotation.x = lerpf(weapon.rotation.x, -0.6 if tell else (1.1 if z._attack_left > 0 else 0.08*sin(t)),minf(1,delta*10))
	weapon.rotation.z = sin(t*0.9)*0.08
	if z._dying > 0:
		halo.position.y += 0.2
		for strip in streamers: strip.scale = Vector3.ONE * maxf(0.01,z._dying/2.6)
	else:
		for strip in streamers: strip.scale = Vector3.ONE
