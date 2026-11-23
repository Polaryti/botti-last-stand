class_name KrakenMantle
extends Node3D
## One mantle for the encounter, chosen deterministically from the replicated arms.
## It shares the leading arm's health and hit capsule; the remaining arms keep their own health.
var mob: Zombie
var flesh: Node3D
var beak: Node3D
static func install(z: Zombie, root: Node3D) -> void:
	var body := KrakenMantle.new()
	body.mob = z
	root.add_child(body)
	body.build()
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
	if not mob.active:
		visible = false
		return
	var leader := int(mob.world.get_meta("kraken_head", -1))
	if leader < 0:
		leader = mob.net_id
		for arm: Zombie in mob.world.zombies:
			if arm.type_id == "kraken_arm" and arm.active: leader = maxi(leader,arm.net_id)
		mob.world.set_meta("kraken_head", leader)
	visible = leader == mob.net_id
	mob._capsule.radius = 2.0 if visible else 0.6
	if not visible: return
	var t := mob.world.now
	var rising := smoothstep(0,VaelMind.RISE_TIME,float(mob._visual.get_meta("act_t",0))) if mob._current_anim == "m_rise" else 1.0
	position.y = lerpf(-3.5,0,rising)
	if mob._dying > 0: position.y -= (2.8-mob._dying)*1.4
	flesh.scale = Vector3(1+sin(t*1.5)*0.025,1+sin(t*1.5-0.8)*0.04,1)
	beak.rotation.x = lerpf(beak.rotation.x,-0.6 if mob.is_warning() else sin(t*1.3)*0.06,minf(1,delta*6))
