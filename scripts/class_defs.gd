class_name ClassDefs
## Classes, their prices and how fast they level. Their abilities are in AbilityData.

const MAX_LEVEL := 10
## Experience from each level to the next. A good night reaches the final ability around minute 7.
const XP_TO_NEXT := [45, 65, 80, 110, 160, 220, 270, 330, 420]

const ALL := {
	"infantry": {"name": "Infantry", "weapon": "dagger", "arrows": 0, "hp": 110.0, "speed": 1.0, "ranged": true, "kill_heal": 2.0,
		"desc": "Fast close fighter. Starts with a Dagger, and heals 2 from each kill. Uses melee and ranged weapons."},
	"ranger": {"name": "Ranger", "weapon": "bow", "arrows": 30, "hp": 90.0, "speed": 1.05, "ranged": true, "kill_arrows": 2,
		"desc": "Precise archer. Starts with a Short Bow and 30 arrows, and takes 2 back from each kill. Uses melee and ranged weapons."},
	"heavy": {"name": "Heavy Infantry", "weapon": "mace", "arrows": 0, "hp": 130.0, "speed": 0.9, "ranged": false, "shield": true,
		"desc": "Slow wall of iron. Starts with a Mace and a shield that blocks from the front. No ranged weapons."},
	"chivalry": {"name": "Chivalry", "weapon": "lance", "arrows": 0, "hp": 110.0, "speed": 1.0, "ranged": false, "horse": true, "hidden": true, "earned": "rider",
		"desc": "Mounted charger. Starts with a Lance. Kills call a horse to ride. No ranged weapons, unless unlocked."},
	"magician": {"name": "Magician", "weapon": "staff", "arrows": 0, "hp": 70.0, "speed": 1.0, "ranged": true, "mana": true, "hidden": true, "earned": "games",
		"desc": "Fragile caster. Keeps a Staff that uses refilling mana. Elements and summoned allies."},
	"revenant": {"name": "Revenant", "weapon": "claws", "arrows": 0, "hp": 100.0, "speed": 1.05, "ranged": false, "mana": true, "mist": true, "mana_regen": 0.75, "kill_mist": 7.0,
		"no_weapons": true, "hidden": true, "earned": "mists",
		"desc": "Dead, and not done. No weapons, only claws of Mist, which it spends with every blow."},
	"monk": {"name": "Monk", "weapon": "fists", "arrows": 0, "hp": 95.0, "speed": 1.1, "ranged": true, "mana": true, "ki": true, "mana_regen": 0.0, "hidden": true, "price": 920, "one_weapon": true,
		"desc": "Master of Ki. Every hit fills the Ki bar, and Ki pays for the Monk's ability. Carries one weapon at a time and punches when it has none. Only a Monk can use the Bo."},
	"adept": {"name": "Adept", "weapon": "sword", "arrows": 0, "hp": 100.0, "speed": 1.0, "ranged": false, "hidden": true, "price": 1150, "disabled": true,
		"desc": "Master of stances. Commit to each stance for 6 seconds; changing takes a moment. Land three blows for +15% melee damage until you switch, and an empowered transition. Wind: 25% faster, and each blow strikes twice for less. Stone: 30% less damage, and blows throw enemies back. Flame: blows burn, and you take 15% more. Starts with a Sword. No ranged weapons."},
	"plague_doctor": {"name": "Plague Doctor", "weapon": "blowgun", "arrows": 32, "hp": 105.0, "speed": 1.05, "damage_taken": 0.9, "ranged": true, "kill_arrows": 2, "hidden": true, "earned": "poison",
		"desc": "The beaked mask has seen it all. Starts with a Blowgun and 32 darts. Takes 10% less damage. Cures friends, spreads sickness, or commands the rats."},
	"artificer": {"name": "Artificer", "weapon": "torch", "arrows": 0, "hp": 115.0, "speed": 1.0, "ranged": true, "one_weapon": true, "hidden": true, "price": 598,
		"desc": "Builds what the night calls for. Carries one weapon at a time, and starts with a Torch. Bombs, a war chariot, or a bag of inventions."},
	"commander": {"name": "Commander", "weapon": "sword", "arrows": 0, "hp": 110.0, "speed": 1.0, "ranged": true, "hidden": true, "unavailable": true, "unique": true, "no_bots": true,
		"desc": "First prize in VRAIN tournaments. Only one Commander per match; never a bot. Command rallies allies, then becomes Last Command at level 10."},
}

static func icon(id: String) -> String:
	return "crest_%s" % id


static func color(id: String) -> Color:
	return {"commander": Color(0.78, 0.59, 0.2), "infantry": Color(0.62, 0.2, 0.14), "ranger": Color(0.22, 0.46, 0.26), "heavy": Color(0.36, 0.4, 0.48),
		"adept": Color(0.3, 0.36, 0.72), "chivalry": Color(0.68, 0.48, 0.16), "magician": Color(0.36, 0.26, 0.66), "revenant": Color(0.16, 0.48, 0.5), "artificer": Color(0.52, 0.37, 0.22), "monk": Color(0.76, 0.46, 0.14), "plague_doctor": Color(0.26, 0.32, 0.24)}[id]


## Some classes share a body with another, but not its clothes or its gear.
static func dress(body: Node3D, id: String) -> void:
	ClassGear.wear(body, id)


## Switched off for now: nobody can play, buy or be given it. Phones that own it keep it, so it
## comes back to them when the flag goes.
static func disabled(id: String) -> bool:
	return bool(ALL.get(id, {}).get("disabled", false))


## The classes this phone can play. Some have to be bought or earned first.
static func available() -> Array[String]:
	var out: Array[String] = []
	for id: String in ALL:
		if Game.owns_class(id) and not disabled(id):
			out.append(id)
	return out


static func for_sale() -> Array[String]:
	var out: Array[String] = []
	for id: String in ALL:
		if price(id) > 0 and not disabled(id):
			out.append(id)
	return out


static func price(id: String) -> int:
	return int(ALL[id].get("price", 0))


static func xp_for_level(level: int) -> int:
	return XP_TO_NEXT[clampi(level - 1, 0, XP_TO_NEXT.size() - 1)]
