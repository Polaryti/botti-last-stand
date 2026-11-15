class_name ShopDefs
## Things to buy that stay yours, besides classes. A full night pays about 65 doubloons, so an upgrade
## is three or four good nights. An upgrade works only on its own path, and can be switched off in
## the Armory. Pets are for the Beastmaster, and one is chosen at a time.

const SECTIONS := {"classes": "Classes", "upgrades": "Class upgrades", "cosmetics": "Cosmetics", "maps": "Map Upgrades"}
const PETS := ["wolf", "raven", "snake", "fox"]

const ITEMS := {
	"oathkeeper": {"name": "Oathkeeper", "section": "upgrades", "class": "heavy", "spec": "guardian", "price": 240, "icon": "shield", "model": "mace", "desc": "Blocked attacks store 4 healing, up to 20. Shield Dome spends it to mend nearby allies and summons."},
	"last_rites": {"name": "Last Rites", "section": "upgrades", "class": "heavy", "spec": "warpriest", "price": 260, "icon": "cross", "model": "bell_hammer", "desc": "Every third kill releases a funeral flame: heal allies within 6 m by 10 and ignite enemies within 4 m. 4 s cooldown.", "effect": {"when": "kill", "do": "last_rites", "nth": 3, "cd": 4.0}},
	"faultline": {"name": "Faultline", "section": "upgrades", "class": "heavy", "spec": "warlord", "price": 280, "icon": "quake", "model": "mace", "desc": "Every third connecting swing splits a 12 m fissure: 40 damage, knockback and 2 s slow. Walls stop it. 6 s cooldown.", "effect": {"when": "melee_swing", "do": "faultline", "nth": 3, "cd": 6.0}},

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
	"lance_charge": {"name": "Lance Charge", "section": "upgrades", "class": "chivalry", "spec": "lancer", "price": 260, "icon": "lance", "model": "lance",
		"desc": "An ability: dash 10 m forward with your lance couched, on foot or riding. Everything in the way takes 55 damage and is thrown aside. Ready again after 16 s.",
		"art": {"name": "Lance Charge", "cost": 0.0, "cast": 0.0, "cd": 16.0, "icon": "lance"}},
	"consecration": {"name": "Consecration", "section": "upgrades", "class": "chivalry", "spec": "paladin", "price": 280, "icon": "sun", "model": "lance",
		"desc": "An ability: plant a holy standard for 8 s. Friends within 6 m heal 4 health a second; enemies inside burn and are slowed. Ready again after 30 s.",
		"art": {"name": "Consecration", "cost": 0.0, "cast": 0.3, "cd": 30.0, "icon": "banner", "anim": "Stance"}},
	"wild_hunt": {"name": "Wild Hunt", "section": "upgrades", "class": "chivalry", "spec": "horse_archer", "price": 320, "icon": "bow+horse", "model": "bow",
		"desc": "An ability: on foot, your horse comes at once. Then for 6 s you loose an arrow every 0.4 s at the nearest enemy within 22 m, without spending arrows, while you ride and shoot as ever. Ready again after 40 s.",
		"art": {"name": "Wild Hunt", "cost": 0.0, "cast": 0.1, "cd": 40.0, "icon": "bow"}},
	"grave_call": {"name": "Grave Call", "section": "upgrades", "class": "magician", "spec": "necromancer", "price": 260, "icon": "bones", "model": "staff",
		"desc": "An ability: up to 3 enemies that fell within 12 m in the last 10 s rise as skeletons and fight for you for 15 s. Costs 30 mana; ready again after 25 s.",
		"art": {"name": "Grave Call", "cost": 30.0, "cast": 0.4, "cd": 25.0, "icon": "skull", "anim": "Stance"}},
	"frost_nova": {"name": "Frost Nova", "section": "upgrades", "class": "magician", "spec": "elementalist", "price": 260, "icon": "snow", "model": "staff",
		"desc": "An ability: every enemy within 6 m takes 25 damage and is frozen for 2 s. Costs 35 mana; ready again after 20 s.",
		"art": {"name": "Frost Nova", "cost": 35.0, "cast": 0.2, "cd": 20.0, "icon": "snow"}},
	"hall_of_mirrors": {"name": "Hall of Mirrors", "section": "upgrades", "class": "magician", "spec": "illusionist", "price": 280, "icon": "mirror", "model": "staff",
		"desc": "A hit that would take a quarter of your health or more misses: you swap away as Mirror Swap does, and a decoy stays where you stood. Once every 30 s."},
	"mist_wake": {"name": "Mist Wake", "section": "upgrades", "class": "revenant", "spec": "leaper", "price": 260, "icon": "mist", "model": "claws",
		"desc": "Each Mist Leap landing leaves a pool of mist 3 m across for 4 s. Enemies in it are slowed and take 8 damage a second."},
	"torn_rifts": {"name": "Torn Rifts", "section": "upgrades", "class": "revenant", "spec": "rift", "price": 280, "icon": "rift", "model": "claws",
		"desc": "Every enemy a Rift Jump goes through is torn. When the jump ends, each tear bursts for 30 damage within 2.5 m."},
	"soul_link": {"name": "Soul Link", "section": "upgrades", "class": "revenant", "spec": "summoner", "price": 300, "icon": "link", "model": "claws",
		"desc": "A quarter of every hit you take goes to the nearest of your called Revenants instead. When one of them is struck down, you heal 20."},
	"dragon_spin": {"name": "Dragon Spin", "section": "upgrades", "class": "monk", "spec": "bo_master", "price": 260, "icon": "spiral", "model": "bo",
		"desc": "Pole Vault's landing goes on into a 1.5 s spin: everything within 3 m is struck 3 times for 15 damage and pulled in."},
	"fighting_body": {"name": "Fighting Body", "section": "upgrades", "class": "monk", "spec": "spirit_walker", "price": 280, "icon": "body_out", "model": "fists",
		"desc": "The body you leave behind fights: once a second it strikes every enemy within 2.5 m for 20 damage, and it takes 30% less damage."},
	"avalanche": {"name": "Avalanche", "section": "upgrades", "class": "monk", "spec": "iron_mountain", "price": 280, "icon": "mountain", "model": "fists",
		"desc": "0.6 s after Mountain Stomp, a second ring of stone breaks out to twice its reach: half its damage, and a 1.5 s stun."},
	"healing_mist": {"name": "Healing Mist", "section": "upgrades", "class": "plague_doctor", "spec": "apothecary", "price": 260, "icon": "mist+heart", "model": "blowgun",
		"desc": "Healing Tonic leaves a healing cloud within 4 m of you for 6 s. Friends in it heal 5 health a second, and stop burning, bleeding and being poisoned."},
	"plague_censer": {"name": "Plague Censer", "section": "upgrades", "class": "plague_doctor", "spec": "pestilence", "price": 280, "icon": "poison", "model": "blowgun",
		"desc": "An ability: for 6 s a plague cloud follows you, 5 m around. Enemies in it are slowed and poisoned for 10 damage a second. Ready again after 25 s.",
		"art": {"name": "Plague Censer", "cost": 0.0, "cast": 0.3, "cd": 25.0, "icon": "poison", "anim": "Stance"}},
	"rat_tide": {"name": "Rat Tide", "section": "upgrades", "class": "plague_doctor", "spec": "rat_king", "price": 280, "icon": "rat", "model": "blowgun",
		"desc": "An ability: 8 rats pour out ahead of you, 10 m. Every enemy in their way takes 15 damage and is knocked down for 0.6 s. Ready again after 20 s.",
		"art": {"name": "Rat Tide", "cost": 0.0, "cast": 0.2, "cd": 20.0, "icon": "rat"}},
	"great_keg": {"name": "Great Keg", "section": "upgrades", "class": "artificer", "spec": "pyromaniac", "price": 260, "icon": "bomb+up", "model": "torch",
		"desc": "Every fourth Incendiary Bomb is a great keg of powder: twice the blast's reach and damage."},
	"field_turret": {"name": "Field Turret", "section": "upgrades", "class": "artificer", "spec": "mechanic", "price": 280, "icon": "turret", "model": "torch",
		"desc": "An ability: set down a Clockwork Sentry that shoots for 20 s. Ready again after 35 s.",
		"art": {"name": "Field Turret", "cost": 0.0, "cast": 0.3, "cd": 35.0, "icon": "turret"}},
	"tesla_coil": {"name": "Tesla Coil", "section": "upgrades", "class": "artificer", "spec": "inventor", "price": 280, "icon": "bolt", "model": "torch",
		"desc": "A new invention, and the first one the bag gives: a coil that zaps the 4 nearest enemies within 8 m every 0.5 s for 6 s, 12 damage each zap."},
	"arcane_surge": {"name": "Arcane Surge", "section": "upgrades", "class": "commander", "spec": "warlock", "price": 300, "icon": "staff+bolt", "model": "staff",
		"desc": "The War Staff's empowered bolt comes every third attack instead of every fifth."},
	"grapeshot": {"name": "Grapeshot", "section": "upgrades", "class": "commander", "spec": "gunner", "price": 300, "icon": "burst", "model": "crossbow",
		"desc": "Every fourth musket shot is grapeshot: 6 pellets of 20 base damage, spread in a cone."},
	"shield_wall": {"name": "Shield Wall", "section": "upgrades", "class": "commander", "spec": "vanguard", "price": 300, "icon": "shield_round", "model": "sword",
		"desc": "Command and Last Command also shield you and friends within 10 m: the next 40 damage each takes within 8 s is stopped."},
	"mist_reinforcements": {"name": "Mist Reinforcements", "section": "maps", "class": "", "spec": "", "map": "bastion", "price": 2200, "icon": "mist_ranger",
		"desc": "On Mist Bastion, a Mist Ranger holds the top of each gate with a bow, and every Mist Soldier deals 15% more damage and has 15% more health. If anyone in the match owns it, it works for the whole match, once."},
	"stag_steed": {"name": "White Stag", "section": "cosmetics", "class": "chivalry", "spec": "", "price": 400, "icon": "antlers", "skin": "stag",
		"desc": "Your horse comes as a white stag of the Valleys, the shape the Shapeshifter takes, antlers and all. It rides exactly as the horse does; only its look changes, for you and everyone you play with."},
	"raven": {"name": "Raven", "section": "upgrades", "class": "ranger", "spec": "beastmaster", "price": 150, "icon": "raven", "pet": true,
		"desc": "Attacks from the air, where few can reach it. It is frail, and bites a little softer than a wolf."},
	"snake": {"name": "Snake", "section": "upgrades", "class": "ranger", "spec": "beastmaster", "price": 180, "icon": "snake", "pet": true,
		"desc": "Slow and weak, but a third of its bites poison the enemy: damage over time, and 5% more from everything."},
	"fox": {"name": "Fox", "section": "upgrades", "class": "ranger", "spec": "beastmaster", "price": 150, "icon": "fox", "pet": true,
		"desc": "Quick, with a softer bite. Now and then it digs up some food for you."},
}


## The look a class has before any from the Store's Cosmetics, for the classes that have others.
const DEFAULT_LOOKS := {"chivalry": {"name": "Brown Horse", "desc": "The horse every Chivalry rider starts with."}}


## Whether a skin is on: bought, and not turned off in the Armory.
static func skin_on(id: String) -> bool:
	return ITEMS.has(id) and Game.item_active(id)


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
	if d.has("map"):
		return "%s, for everyone in the match" % Places.ALL[d["map"]]["name"]
	if d["spec"] == "":
		return "%s, every path" % ClassDefs.ALL[d["class"]]["name"]
	return "%s, %s%s" % [ClassDefs.ALL[d["class"]]["name"], spec_name(id), " pet" if d.get("pet", false) else ""]


## The colour an item is shown in: its class's, or its place's for a Map Upgrade.
static func color_of(id: String) -> Color:
	var d: Dictionary = ITEMS[id]
	return Places.ALL[d["map"]]["color"] if d.has("map") else ClassDefs.color(str(d["class"]))


## Whether a Map Upgrade works in this match: on the phone alone, if it is bought and on; in a match
## together, if anyone in it (not a bot) has it. Never more than once, however many have it.
static func map_upgrade_on(id: String) -> bool:
	if not Net.active():
		return Game.item_active(id)
	return anyone_has(Net.roster, id)


## Whether anyone in a match's roster (a person, not a bot) brought this Map Upgrade.
static func anyone_has(roster: Dictionary, id: String) -> bool:
	for peer: int in roster:
		if not Net.is_bot(peer) and (roster[peer].get("maps", []) as Array).has(id):
			return true
	return false


static func for_class(class_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ITEMS:
		if ITEMS[id]["class"] == class_id:
			out.append(id)
	return out
