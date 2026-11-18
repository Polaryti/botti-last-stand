class_name TrapperScenes
extends RefCounted
## The Store's scene for the Trappers' Guild (a Map Upgrade of the Valleys): a creature steps into a
## snare and is whipped off its feet and held, a Lodge hunter on a watchtower looses Long Bow arrows at
## it, and by the camp fire the hunters' cache is set down. The snare, the hunter and the camp are the
## ones a night has (TrappersGuild, ClassGear).

const TOWER := Vector2(1.45, -0.85)
const TOWER_TOP := 2.3
const SNARE := Vector2(-0.45, 0.55)
const FOE_FROM := Vector2(-2.7, 1.35)
const SECOND_FROM := Vector2(-3.0, 0.1)
const FIRE := Vector2(-1.55, -1.45)
const CAUGHT := 1.0
const SHOTS := [1.45, 2.3, 3.15]
const CACHE_AT := 2.6


static func build(s: UpgradeShowcase) -> void:
	# A short watchtower: four posts, a plank floor and a rail, low enough to keep everyone in view.
	var tower := s._mesh(func(l: LowPoly) -> void:
		var timber := Color(0.42, 0.29, 0.17)
		var dark := Color(0.3, 0.2, 0.12)
		for c: Vector2 in [Vector2(-0.65, -0.65), Vector2(0.65, -0.65), Vector2(-0.65, 0.65), Vector2(0.65, 0.65)]:
			l.prism(Vector3(c.x, 0, c.y), Vector3(c.x * 0.9, TOWER_TOP + 0.9, c.y * 0.9), 0.1, 0.09, 6, dark)
		l.box(Vector3(0, TOWER_TOP - 0.06, 0), Vector3(1.7, 0.12, 1.7), timber)
		for side in 4:
			var a := side * PI * 0.5
			var along := Vector3(cos(a), 0, sin(a))
			l.box(Vector3(0, TOWER_TOP + 0.45, 0) + along * 0.82, Vector3(0.08, 0.1, 1.7) if side % 2 == 0 else Vector3(1.7, 0.1, 0.08), timber)
		l.box(Vector3(0, TOWER_TOP * 0.45, 0.66), Vector3(1.3, 0.1, 0.1), timber, Vector3(0, 0, 25))
		l.box(Vector3(0, TOWER_TOP * 0.45, -0.66), Vector3(1.3, 0.1, 0.1), timber, Vector3(0, 0, -25)))
	var tower_piece := s._piece(tower)
	tower_piece.position = PathScenes._sp(s, TOWER)
	s._parts["tower"] = tower_piece
	var hunter := PathScenes._person_at(s, "lodge_hunter", "longbow", TOWER, SNARE)
	(hunter["holder"] as Node3D).position += Vector3.UP * TOWER_TOP
	s._person = hunter
	var snare := s._piece(TrappersGuild.snare_mesh(false))
	snare.position = PathScenes._sp(s, SNARE)
	snare.rotation.y = -s.rotation.y + 0.4
	s._parts["snare"] = snare
	var camp := TrappersGuild.camp_model()
	camp.scale = Vector3.ONE * 0.7
	s.add_child(camp)
	camp.position = PathScenes._sp(s, FIRE)
	camp.rotation.y = -s.rotation.y + 0.5
	s._parts["camp"] = camp
	s._parts["foe"] = PathScenes._zombie_at(s, FOE_FROM, "normal_a", SNARE)
	s._parts["second"] = PathScenes._zombie_at(s, SECOND_FROM, "normal_b", TOWER)
	var arrows: Array[MeshInstance3D] = []
	for i in SHOTS.size():
		arrows.append(PathScenes._bar(s, Color(0.85, 0.78, 0.6), 0.035))
	s._parts["arrows"] = arrows
	s._parts["stars"] = PathScenes._stars(s)
	s._parts["dust"] = s._puff(Color(0.7, 0.62, 0.48), 6)
	# The cache: a pack of hide tied with cord, and a glint where it lands.
	var pack := s._mesh(func(l: LowPoly) -> void:
		l.box(Vector3(0, 0.16, 0), Vector3(0.42, 0.3, 0.3), Color(0.55, 0.42, 0.28))
		l.box(Vector3(0, 0.33, 0), Vector3(0.36, 0.06, 0.26), Color(0.45, 0.33, 0.2))
		l.box(Vector3(0, 0.17, 0.16), Vector3(0.05, 0.32, 0.02), Color(0.82, 0.74, 0.52))
		l.prism(Vector3(0.12, 0.32, -0.02), Vector3(0.18, 0.62, -0.08), 0.012, 0.012, 4, Color(0.8, 0.68, 0.45))
		l.box(Vector3(0.18, 0.66, -0.08), Vector3(0.06, 0.1, 0.02), Color(0.55, 0.55, 0.58)))
	var cache := s._piece(pack)
	cache.visible = false
	s._parts["cache"] = cache
	s._parts["glint"] = s._puff(TrappersGuild.COLOR.lightened(0.3), 6)


static func play(s: UpgradeShowcase, t: float) -> void:
	var hunter: Dictionary = s._person
	var foe: Dictionary = s._parts["foe"]
	var fh: Node3D = foe["holder"]
	var snare_at := PathScenes._sp(s, SNARE)
	# The creature walks into the snare; it is whipped up off one foot and held there.
	var walk := UpgradeShowcase._window(t, 0.0, CAUGHT)
	var held := t >= CAUGHT and t < CAUGHT + 2.6
	fh.position = PathScenes._sp(s, FOE_FROM).lerp(snare_at, walk) if t < 3.9 else PathScenes._sp(s, FOE_FROM)
	fh.rotation.y = UpgradeShowcase._facing(PathScenes._sp(s, FOE_FROM), snare_at)
	var lift := sin(UpgradeShowcase._window(t, CAUGHT, CAUGHT + 0.35) * PI * 0.5) * (1.0 - UpgradeShowcase._window(t, CAUGHT + 2.4, CAUGHT + 2.7))
	fh.rotation.x = -0.35 * lift
	fh.position.y = 0.12 * lift
	fh.visible = t < 3.75
	if t < CAUGHT:
		s._play(foe["anim"], "Walking_A")
	elif held:
		s._play(foe["anim"], "Hit_A", 0.45)
	else:
		s._play(foe["anim"], "Death_A", 1.2)
	(s._parts["snare"] as MeshInstance3D).mesh = TrappersGuild.snare_mesh(t >= CAUGHT and t < 4.1)
	PathScenes._show_stars(s._parts["stars"], fh.position, t, held and t > CAUGHT + 0.2)
	s._show_puff(s._parts["dust"], t - CAUGHT, 0.45, 0.5)
	(s._parts["dust"] as Node3D).position = snare_at + Vector3.UP * 0.2
	# The second creature comes on behind, and walks on by the snare that has already gone off.
	var second: Dictionary = s._parts["second"]
	var sh: Node3D = second["holder"]
	var pass_k := UpgradeShowcase._window(t, 1.2, 4.2)
	sh.position = PathScenes._sp(s, SECOND_FROM).lerp(PathScenes._sp(s, Vector2(0.2, -0.2)), pass_k)
	sh.rotation.y = UpgradeShowcase._facing(PathScenes._sp(s, SECOND_FROM), PathScenes._sp(s, Vector2(0.2, -0.2)))
	s._play(second["anim"], "Walking_A" if t > 1.2 else "Idle")
	# The hunter on the tower draws and looses at the one held.
	var holder: Node3D = hunter["holder"]
	holder.rotation.y = UpgradeShowcase._facing(holder.position, fh.position)
	var drawing := false
	for at: float in SHOTS:
		if t > at - 0.35 and t < at + 0.15:
			drawing = true
	s._play(hunter["anim"], "2H_Ranged_Shoot" if drawing else "Idle", 1.3)
	var arrows: Array = s._parts["arrows"]
	var from := holder.position + Vector3.UP * 1.4
	for i in SHOTS.size():
		var k := UpgradeShowcase._window(t, SHOTS[i], SHOTS[i] + 0.22)
		var to := fh.position + Vector3.UP * 1.0
		var head := from.lerp(to, k)
		PathScenes._lay(arrows[i], head - (to - from).normalized() * 0.55, head)
		(arrows[i] as MeshInstance3D).visible = k > 0.0 and k < 1.0
		PathScenes._struck(s, foe, t, SHOTS[i] + 0.22)
	# By the fire, the cache is set down, and glints.
	var camp: Node3D = s._parts["camp"]
	var flame := camp.get_node("Flame") as Node3D
	flame.scale = Vector3(1.0 + 0.08 * sin(t * 13.0), 0.85 + 0.25 * sin(t * 9.0) * sin(t * 5.3), 1.0 + 0.08 * cos(t * 11.0))
	var cache: MeshInstance3D = s._parts["cache"]
	var drop := UpgradeShowcase._window(t, CACHE_AT, CACHE_AT + 0.25)
	cache.visible = drop > 0.0 and t < 4.3
	var lies := PathScenes._sp(s, FIRE) + PathScenes._sp(s, Vector2(0.85, 0.35))
	cache.position = lies + Vector3.UP * 0.7 * (1.0 - drop * drop)
	cache.rotation.y = 0.5
	s._show_puff(s._parts["glint"], t - CACHE_AT - 0.25, 0.5, 0.4)
	(s._parts["glint"] as Node3D).position = lies + Vector3.UP * 0.35
