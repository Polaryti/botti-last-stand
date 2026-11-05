class_name ShopDefs
## Things to buy that stay yours, besides classes. A full night pays about 65 doubloons, so an upgrade
## is three or four good nights. An upgrade works only on its own path, and can be switched off in
## the Armory. Pets are for the Beastmaster, and one is chosen at a time.

const SECTIONS := {"classes": "Classes", "upgrades": "Class upgrades"}
const PETS := ["wolf", "raven", "snake", "fox"]

const ITEMS := {
	"rain_of_arrows": {"name": "Rain of Arrows", "section": "upgrades", "class": "ranger", "spec": "sharpshooter", "price": 260, "icon": "rain", "model": "longbow",
		"desc": "Hold the ability button to place a circle on the ground. Let go, stand still for 2 s, and a volley of arrows falls on it. Costs 8 arrows.",
		"art": {"name": "Rain of Arrows", "cost": 0.0, "cast": 2.0, "cd": 18.0, "icon": "arrows", "hold": true}},
	"trap_satchel": {"name": "Trap Satchel", "section": "upgrades", "class": "ranger", "spec": "trapper", "price": 220, "icon": "satchel", "model": "trap",
		"desc": "Traps no longer drop by themselves. You carry up to 5, and set one with the ability button. It arms 3 s later.",
		"art": {"name": "Set Trap", "cost": 0.0, "cast": 0.0, "cd": 0.6, "icon": "trap"}},
	"blade_flurry": {"name": "Blade Flurry", "section": "upgrades", "class": "infantry", "spec": "duelist", "price": 240, "icon": "flurry", "model": "sword",
		"desc": "An ability: for 4 s you attack 60% faster, and every hit is a critical. Ready again after 25 s.",
		"art": {"name": "Blade Flurry", "cost": 0.0, "cast": 0.0, "cd": 25.0, "icon": "sword"}},
	"undying_rage": {"name": "Undying Rage", "section": "upgrades", "class": "infantry", "spec": "berserker", "price": 280, "icon": "rage", "model": "mace",
		"desc": "When you would die, you rise again in a rage for 5 s: 30% faster, attacks 30% faster, and your blows set enemies on fire. Once every 60 s."},
	"shadow_shroud": {"name": "Shadow Shroud", "section": "upgrades", "class": "infantry", "spec": "shadow", "price": 240, "icon": "shroud", "model": "dagger",
		"desc": "Every 8 kills, an ability makes you Invisible for 3 s. Nothing can see you, even right next to it.",
		"art": {"name": "Shadow Shroud", "cost": 0.0, "cast": 0.0, "cd": 0.0, "icon": "eye_closed"}},
	"raven": {"name": "Raven", "section": "upgrades", "class": "ranger", "spec": "beastmaster", "price": 150, "icon": "raven", "pet": true,
		"desc": "Attacks from the air, where few can reach it. It is frail, and bites a little softer than a wolf."},
	"snake": {"name": "Snake", "section": "upgrades", "class": "ranger", "spec": "beastmaster", "price": 180, "icon": "snake", "pet": true,
		"desc": "Slow and weak, but a third of its bites poison the enemy: damage over time, and 5% more from everything."},
	"fox": {"name": "Fox", "section": "upgrades", "class": "ranger", "spec": "beastmaster", "price": 150, "icon": "fox", "pet": true,
		"desc": "Quick, with a softer bite. Now and then it digs up some food for you."},
}


## The item that gives a path its ability button.
static func art_item(spec_id: String) -> String:
	for id: String in ITEMS:
		if ITEMS[id].get("spec", "") == spec_id and ITEMS[id].has("art"):
			return id
	return ""


static func in_section(section: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["section"] == section:
			out.append(id)
	# Same class together, and within it the same path.
	out.sort_custom(func(a: String, b: String) -> bool:
		var ca: String = ITEMS[a]["class"] + ITEMS[a]["spec"]
		var cb: String = ITEMS[b]["class"] + ITEMS[b]["spec"]
		return ca < cb)
	return out


## "Sharpshooter", for showing whose an upgrade is.
static func spec_name(id: String) -> String:
	var d: Dictionary = ITEMS[id]
	for s: Dictionary in AbilityData.tree(d["class"])["specs"]:
		if s["id"] == d["spec"]:
			return s["name"]
	return ""


## "Ranger, Sharpshooter", or "Ranger, Beastmaster pet".
static func whose(id: String) -> String:
	var d: Dictionary = ITEMS[id]
	return "%s, %s%s" % [ClassDefs.ALL[d["class"]]["name"], spec_name(id), " pet" if d.get("pet", false) else ""]


static func for_class(class_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["class"] == class_id:
			out.append(id)
	return out
