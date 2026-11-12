class_name ClassPresentation
extends RefCounted

const COPY := {
	"infantry": [
		"The line holds while you stand.",
		"Heal from kills and fight with melee or ranged weapons."
	],
	"ranger": [
		"Every shot answers the dark.",
		"Recover arrows from kills and specialize in archery, traps or pets."
	],
	"heavy": [
		"Iron stands between the living and the horde.",
		"Block frontal attacks with a shield and wield melee weapons."
	],
	"chivalry": [
		"Ride where the line would break.",
		"Earn a summoned horse through kills and fight with your exclusive lance."
	],
	"magician": [
		"Old magic still burns in mortal hands.",
		"Wield only a mana-powered staff and master spells or summons."
	],
	"revenant": [
		"Death has left a debt unpaid.",
		"Spend Mist to attack with spectral claws instead of weapons."
	],
	"monk": [
		"Discipline survives where steel fails.",
		"Build Ki with hits to fuel abilities and carry one weapon."
	],
	"adept": [
		"Three paths meet at the edge of a blade.",
		"Commit to timed stances with distinct combat bonuses."
	],
	"artificer": [
		"Ingenuity arms the last survivors.",
		"Build devices and specialize in machines, explosives or constructs."
	],
	"plague_doctor": [
		"Carry the cure into the sickness.",
		"Fight with an exclusive blowgun and master poison, medicine or vermin."
	],
	"bandit": [
		"What the dark hides, the Bandit keeps.",
		"Turn invisible on demand and specialize in stealing, mercenary night or knife-throwing plunder."
	],
	"cartographer": [
		"Every road beyond the Mists was drawn by someone first.",
		"Plant linked beacons that speed, mend and mark, and specialize in constellations, waygates or hidden finds."
	],
	"commander": [
		"A single voice can turn the battle.",
		"Use Command and unlock a profession-specific Last Command at level ten."
	]
}

static func description(id: String) -> String:
	return " ".join(COPY[id])


## The same stat line on the Codex, the Armory and the class screen.
static func stats_line(id: String) -> String:
	var d: Dictionary = ClassDefs.ALL[id]
	return "Base health %d · Speed %d%%" % [int(d["hp"]), roundi(float(d["speed"]) * 100.0)]


## Tag colours: background, border, text. Map badges and weapon groups share one shape.
const TAG_STYLES := {
	"melee": [Color("2b3140"), Color("9aa5ba"), Color("dfe5ef")],
	"two_handed": [Color("3d2a14"), Color("efa93f"), Color("ffd99a")],
	"ranged": [Color("1d3c2c"), Color("7fc08a"), Color("b2e8b5")],
	"exclusive": [Color("33213f"), Color("b98ae0"), Color("e3ccff")],
	"map_green": [Color("1d3c2c"), Color("7fc08a"), Color("b2e8b5")],
	"map_mists": [Color("193e4b"), Color("6fb6d6"), Color("a5f0ec")],
	"map_mesenlla": [Color("2a1f4d"), UiTheme.TWILIGHT, Color("e2d8ff")], # the twilight violet of the lands beyond the Mists
}


static func tag(text: String, style: String) -> PanelContainer:
	var colors: Array = TAG_STYLES[style]
	var badge := PanelContainer.new()
	badge.set_meta("tag", true) # a tag's word never wraps
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override("panel", UiTheme.flat(colors[0], colors[1], 6, 7.0))
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", colors[2])
	badge.add_child(label)
	return badge


## Which weapon groups a class can wield, as a row of tags.
static func weapon_tags(id: String) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.name = "WeaponTags"
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	for cat: String in ClassDefs.weapon_categories(id):
		row.add_child(tag(WeaponDefs.CATEGORY_NAMES[cat], cat))
	return row


## "Map Exclusive · …" in the colour of the maps it belongs to.
static func map_tag(data: Dictionary) -> PanelContainer:
	var style := "map_mesenlla" if SpawnRules.is_mesenlla(data) else ("map_green" if data.get("maps", []).has("village") or data.get("maps", []).has("fort") else "map_mists")
	return tag("Map Exclusive · " + SpawnRules.names(data), style)

static func profession(spec: Dictionary) -> String:
	return spec["desc"].strip_edges().trim_suffix(".") + ". " + str(spec["entry"]["desc"]).split(". ")[0].trim_suffix(".") + "."
