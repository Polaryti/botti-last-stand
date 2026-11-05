class_name ClassDefs
## Classes, their prices and how fast they level. Their abilities are in AbilityData.

const MAX_LEVEL := 10
## Experience from each level to the next. A good night reaches the final ability around minute 7.
const XP_TO_NEXT := [45, 65, 80, 110, 160, 220, 270, 330, 420]

const ALL := {
	"infantry": {"name": "Infantry", "weapon": "dagger", "arrows": 0, "hp": 100.0, "speed": 1.0, "ranged": true,
		"desc": "Fast close fighter. Starts with a Dagger. Uses melee and ranged weapons."},
	"ranger": {"name": "Ranger", "weapon": "bow", "arrows": 30, "hp": 90.0, "speed": 1.05, "ranged": true, "kill_arrows": 2,
		"desc": "Precise archer. Starts with a Short Bow and 30 arrows, and takes 2 back from each kill. Uses melee and ranged weapons."},
	"heavy": {"name": "Heavy Infantry", "weapon": "mace", "arrows": 0, "hp": 130.0, "speed": 0.9, "ranged": false, "shield": true,
		"desc": "Slow wall of iron. Starts with a Mace and a shield that blocks from the front. No ranged weapons."},
	"chivalry": {"name": "Chivalry", "weapon": "lance", "arrows": 0, "hp": 110.0, "speed": 1.0, "ranged": false, "horse": true, "hidden": true, "earned": "rider",
		"desc": "Mounted charger. Starts with a Lance. Kills call a horse to ride. No ranged weapons, unless unlocked."},
	"magician": {"name": "Magician", "weapon": "staff", "arrows": 0, "hp": 70.0, "speed": 1.0, "ranged": true, "mana": true, "hidden": true, "earned": "games",
		"desc": "Fragile caster. Keeps a Staff that uses refilling mana. Elements and summoned allies."},
	"revenant": {"name": "Revenant", "weapon": "claws", "arrows": 0, "hp": 100.0, "speed": 1.05, "ranged": false, "mana": true, "mist": true, "mana_regen": 0.5, "kill_mist": 5.0,
		"no_weapons": true, "hidden": true, "price": 650,
		"desc": "Dead, and not done. No weapons, only claws of Mist, which it spends with every blow."},
	"monk": {"name": "Monk", "weapon": "fists", "arrows": 0, "hp": 95.0, "speed": 1.1, "ranged": true, "hidden": true,
		"desc": "Spirit and martial arts. Fights with bare hands, quick on its feet, and can use any weapon it finds."},
	"plague_doctor": {"name": "Plague Doctor", "weapon": "blowgun", "arrows": 24, "hp": 90.0, "speed": 1.0, "ranged": true, "kill_arrows": 1, "hidden": true,
		"desc": "The beaked mask has seen it all. Starts with a Blowgun and 24 darts. Cures friends, spreads sickness, or commands the rats."},
	"artificer": {"name": "Artificer", "weapon": "torch", "arrows": 0, "hp": 115.0, "speed": 1.0, "ranged": true, "one_weapon": true, "hidden": true, "price": 520,
		"desc": "Builds what the night calls for. Carries one weapon at a time, and starts with a Torch. Bombs, a war chariot, or a bag of inventions."},
}

static func icon(id: String) -> String:
	return "crest_%s" % id


static func color(id: String) -> Color:
	return {"infantry": Color(0.62, 0.2, 0.14), "ranger": Color(0.22, 0.46, 0.26), "heavy": Color(0.36, 0.4, 0.48),
		"chivalry": Color(0.68, 0.48, 0.16), "magician": Color(0.36, 0.26, 0.66), "revenant": Color(0.16, 0.48, 0.5), "artificer": Color(0.52, 0.37, 0.22), "monk": Color(0.76, 0.46, 0.14), "plague_doctor": Color(0.26, 0.32, 0.24)}[id]


## Some classes share a body with another, but not its clothes.
static func dress(body: Node3D, id: String) -> void:
	if id != "monk" and id != "plague_doctor":
		return
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		if part.mesh == null or part.mesh.get_surface_count() == 0:
			continue
		var look: Material = part.mesh.surface_get_material(0)
		if not look is BaseMaterial3D:
			continue
		if id == "monk":
			var robe := ShaderMaterial.new()
			robe.shader = load("res://assets/shaders/recolour.gdshader")
			robe.set_shader_parameter("tex", (look as BaseMaterial3D).albedo_texture)
			part.material_override = robe
		else:
			var worn: BaseMaterial3D = look.duplicate()
			worn.albedo_color = Color(0.5, 0.5, 0.55)
			part.material_override = worn
	if id == "plague_doctor":
		var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0] if not body.find_children("*", "Skeleton3D", true, false).is_empty() else null
		if skeleton and skeleton.find_bone("head") >= 0:
			var at := BoneAttachment3D.new()
			at.bone_name = "head"
			skeleton.add_child(at)
			var beak := MeshInstance3D.new()
			beak.mesh = LowPoly.new().prism(Vector3(0, 0.45, 0.45), Vector3(0, 0.3, 1.05), 0.2, 0.02, 6, Color(0.82, 0.76, 0.6)).commit()
			beak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			at.add_child(beak)


## The classes this phone can play. Some have to be bought or opened with a code first.
static func available() -> Array[String]:
	var out: Array[String] = []
	for id: String in ALL:
		if Game.owns_class(id):
			out.append(id)
	return out


static func for_sale() -> Array[String]:
	var out: Array[String] = []
	for id: String in ALL:
		if price(id) > 0:
			out.append(id)
	return out


static func price(id: String) -> int:
	return int(ALL[id].get("price", 0))


static func xp_for_level(level: int) -> int:
	return XP_TO_NEXT[clampi(level - 1, 0, XP_TO_NEXT.size() - 1)]
