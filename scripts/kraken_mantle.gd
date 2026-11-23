class_name KrakenMantle
extends Node3D
## One mantle for the encounter, chosen deterministically from the replicated arms.
## It shares the leading arm's health and hit capsule; the remaining arms keep their own health.
var mob: Zombie
var flesh: Node3D
var beak: Node3D
var links: Array[MeshInstance3D] = []
var head_hit: CollisionShape3D
var age := 0.0
static func install(z: Zombie, root: Node3D) -> void:
	var body := KrakenMantle.new()
	body.mob = z
	root.add_child(body)
	body.build()
	body.head_hit = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.8
	capsule.height = 3.6
	body.head_hit.shape = capsule
	body.head_hit.disabled = true
	z.add_child(body.head_hit)
	for i in 10:
		var link := MesenllaModels._part(root,MesenllaModels._mesh("kraken_attached_root",func(l: LowPoly) -> void:
			l.prism(Vector3.ZERO,Vector3(0,0,1.04),1,0.9,10,VaelModels.KRAKEN)
			for side: float in [-0.38,0.38]:
				l.prism(Vector3(side,0.8,0.3),Vector3(side,0.94,0.3),0.16,0.12,7,VaelModels.SUCKER)))
		body.links.append(link)
	for mesh: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("own_material",mesh.material_override)
		z._parts.append(mesh)
func build() -> void:
	flesh = MesenllaModels._pivot(self,Vector3.ZERO,"Mantle")
	var mesh := MesenllaModels._mesh("kraken_mantle",func(l: LowPoly) -> void:
		l.prism(Vector3(0,-0.5,-0.7),Vector3(0,1.7,-1.1),2.0,1.5,12,VaelModels.KRAKEN)
		l.prism(Vector3(0,1.7,-1.1),Vector3(0,3.0,-1.6),1.5,0.15,12,VaelModels.KRAKEN_DARK)
		for side: float in [-1,1]:
			l.leaf(Vector3(side*1.5,0.2,-1),Vector3(side*2.8,1,-2),Vector3(side*1.1,2,-1.8),VaelModels.CORAL.darkened(0.35))
			l.prism(Vector3(side*1.5,0.8,0.2),Vector3(side*1.2,1.25,0.25),0.45,0.25,8,VaelModels.KRAKEN_DARK)
			for scar in 4:
				l.prism(Vector3(side*1.4,1+scar*0.2,-0.8),Vector3(side*1.5,1.1+scar*0.2,-1.1),0.04,0.01,4,VaelModels.SUCKER.darkened(0.2)))
	MesenllaModels._part(flesh,mesh)
	var eyes := MesenllaModels._part(flesh,MesenllaModels._mesh("kraken_mantle_eyes",func(l: LowPoly) -> void:
		for side: float in [-1,1]:
			l.prism(Vector3(side*1.38,1.05,0.55),Vector3(side*1.38,1.05,0.61),0.24,0.24,9,Color(0.9,0.65,0.18))
			l.box(Vector3(side*1.38,1.05,0.65),Vector3(0.045,0.38,0.03),Color(0.01,0.01,0.02))))
	eyes.material_override = MesenllaModels.glow_material()
	beak = MesenllaModels._pivot(flesh,Vector3(0,0.4,0.9),"Beak")
	MesenllaModels._part(beak,MesenllaModels._mesh("kraken_beak",func(l: LowPoly) -> void:
		l.prism(Vector3(0,0.2,0),Vector3(0,-0.35,0.8),0.4,0,7,Color(0.12,0.1,0.12))
		l.prism(Vector3(0,-0.35,0),Vector3(0,-0.1,0.6),0.3,0,7,VaelModels.BARNACLE.darkened(0.4))))
func _process(delta: float) -> void:
	age += delta
	if not mob.active:
		age = 0.0
		visible = false
		head_hit.disabled = true
		for link in links: link.visible = false
		return
	var arms: Array[Zombie] = []
	var centre := Vector3.ZERO
	var leader := -1
	for arm: Zombie in mob.world.zombies:
		if arm.type_id == "kraken_arm" and arm.active:
			arms.append(arm)
			centre += arm.position
			if arm.is_alive(): leader = maxi(leader,arm.net_id)
	if arms.is_empty(): return
	centre /= arms.size()
	if not mob.world.has_meta("kraken_origin") and (arms.size() >= VaelMind.ARMS or age > 0.5):
		centre.y = maxf(mob.world.tide.level, centre.y + 0.3) if mob.world.tide else centre.y + 0.3
		mob.world.set_meta("kraken_origin",centre)
		mob.world.set_meta("kraken_head",leader)
	centre = mob.world.get_meta("kraken_origin",centre)
	# The mantle stays at the same origin as individual arms fall. Its collider forwards
	# subsequent hits to the next living arm instead of leaving a detached body behind.
	if leader >= 0: mob.world.set_meta("kraken_head",leader)
	leader = int(mob.world.get_meta("kraken_head",leader))
	visible = leader == mob.net_id
	var phase_time := float(mob._visual.get_meta("act_t",0.0))
	if mob._current_anim == "m_rise":
		centre.y -= 3.5 * (1.0 - smoothstep(0.0,VaelMind.RISE_TIME,phase_time))
	elif mob._current_anim == "m_sink":
		centre.y -= 3.5 * smoothstep(0.0,VaelMind.SINK_TIME,phase_time)
	head_hit.disabled = not visible or not mob.is_alive()
	if visible:
		global_position = centre
		var target := mob.world.nearest_player(centre)
		if target:
			var toward := target.global_position-centre
			global_rotation.y = atan2(toward.x,toward.z)
		head_hit.position = mob.to_local(centre+Vector3.UP*1.1)
		if mob._dying > 0: position.y -= (2.8-mob._dying)*1.4
	var t := mob.world.now
	var radial := mob.position-centre
	radial.y = 0
	var base := centre+radial.normalized()*1.3
	var last := base
	for i in links.size():
		var f := float(i+1)/links.size()
		var end := base.lerp(mob.position+Vector3.UP*0.2,f)
		var side := Vector3(-radial.z,0,radial.x).normalized()
		end += side*sin(f*PI)*sin(t*0.8+mob.net_id)*0.55
		end.y += sin(f*PI)*0.35
		var span := end-last
		links[i].visible = mob.is_alive() and span.length() > 0.01
		if span.length() > 0.01:
			var width := lerpf(0.95,0.65,float(i)/links.size())
			links[i].global_transform = Transform3D(Basis.looking_at(-span,Vector3.UP if absf(span.normalized().y)<0.95 else Vector3.RIGHT).scaled(Vector3(width,width,span.length())),last)
		last = end
	flesh.scale = Vector3(1+sin(t*1.5)*0.025,1+sin(t*1.5-0.8)*0.04,1)
	beak.rotation.x = lerpf(beak.rotation.x,-0.6 if mob.is_warning() else sin(t*1.3)*0.06,minf(1,delta*6))
