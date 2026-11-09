class_name MistCaches
extends Node3D
## Chests at the end of the lines of stones, each with a beam of light that can be seen from far away.
## Each player opens each chest once, on their own phone: nobody takes it from the others.

const REACH := 2.4
const XP := 60

var world: World
var caches: Array[Dictionary] = []


func _init(owner_world: World) -> void:
	world = owner_world


func add(at: Vector3, coins: int, power: String, weapon: String) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	var chest := MeshInstance3D.new()
	var l := LowPoly.new()
	l.box(Vector3(0, 0.34, 0), Vector3(1.5, 0.68, 0.95), Color(0.42, 0.26, 0.13))
	l.box(Vector3(0, 0.34, 0), Vector3(1.56, 0.12, 1.0), Color(0.95, 0.74, 0.28))
	chest.mesh = l.commit()
	chest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(chest)
	var lid := MeshInstance3D.new()
	var t := LowPoly.new()
	t.box(Vector3(0, 0.14, 0.47), Vector3(1.5, 0.28, 0.95), Color(0.5, 0.3, 0.15))
	t.box(Vector3(0, 0.14, 0.47), Vector3(0.24, 0.3, 1.0), Color(0.95, 0.74, 0.28))
	lid.mesh = t.commit()
	lid.position = Vector3(0, 0.68, -0.47)
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lid)
	var beam := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.7
	tube.bottom_radius = 0.7
	tube.height = 60.0
	tube.radial_segments = 8
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	look.albedo_color = Color(1.0, 0.82, 0.35, 0.3)
	tube.material = look
	beam.mesh = tube
	beam.position.y = 30.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(beam)
	caches.append({"at": at, "coins": coins, "power": power, "weapon": weapon, "open": false, "lid": lid, "beam": beam})


func _process(_delta: float) -> void:
	var p := world.player
	if p == null or p.dead:
		return
	for c: Dictionary in caches:
		if not c["open"] and p.global_position.distance_to(c["at"]) < REACH:
			open_cache(c, p)


func open_cache(c: Dictionary, p: Player) -> void:
	c["open"] = true
	(c["lid"] as Node3D).rotation.x = -1.9
	(c["beam"] as Node3D).visible = false
	Game.doubloons += int(c["coins"])
	Game.save_settings()
	p.add_xp(XP)
	p.heal(30.0)
	var got := "%d doubloons" % int(c["coins"])
	var weapon: String = c["weapon"]
	if weapon != "" and p.can_use(weapon):
		p.give_weapon(weapon)
		got += " and a %s" % WeaponDefs.ALL[weapon]["name"]
	elif c["power"] != "":
		p.activate_power(c["power"])
		got += " and %s" % PowerDefs.ALL[c["power"]]["name"]
	world.banner("Mist cache: %s" % got, 3.5)
	world.fx_ring(c["at"], 3.0, Color(1.0, 0.82, 0.35))
	Sfx.play("bell", -3.0, 1.2)
