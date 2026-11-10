class_name ZombieDefs
## Stats per enemy type. Behaviour differences live in zombie.gd.

const BURN_SECONDS := 3.0
const ARMED_DAMAGE := 14.0
# Whatever rises late in the night is worse than what came before it, by this much per minute.
const NIGHT_HP := 0.07
const NIGHT_DAMAGE := 0.05
const NIGHT_SPEED := 0.02
const CROW_STAY := 40.0
const FLYER_RECOVER := 1.7
const HERO_HP_PER_MINUTE := 25.0
const HERO_XP_PER_MINUTE := 4

const ALL := {
	"normal": {"name": "Zombie", "icon": "skull", "desc": "Slow and unarmed. Dangerous in numbers.", "hp": 75.0, "roam_speed": 1.0, "speed": 2.95, "damage": 10.0, "scale": 1.0, "xp": 10,
		"sight": 28.0, "tint": Color(0.46, 0.62, 0.36), "models": ["normal_a", "normal_b"], "from": 0.0, "weight": 10.0},
	"clever": {"name": "Clever", "icon": "grab", "desc": "Picks up weapons from the ground and uses them. Drops them when it falls.", "hp": 75.0, "roam_speed": 1.7, "speed": 3.45, "damage": 10.0, "scale": 1.0, "xp": 14,
		"sight": 30.0, "tint": Color(0.5, 0.56, 0.42), "models": ["clever"], "from": 60.0, "weight": 3.5},
	"magic": {"name": "Magic", "icon": "flame", "desc": "Keeps its distance and throws fireballs that set you alight.", "hp": 50.0, "roam_speed": 1.2, "speed": 2.2, "damage": 8.0, "scale": 1.0, "xp": 16,
		"sight": 34.0, "tint": Color(0.42, 0.5, 0.66), "models": ["magic"], "from": 120.0, "weight": 2.2, "caster": true},
	"beast": {"name": "Beast", "icon": "claw", "desc": "Arrives with a howl. Fast, clawed, and it tracks by scent, so hiding only delays it.", "hp": 150.0, "roam_speed": 6.2, "speed": 6.4, "damage": 20.0, "scale": 1.2, "xp": 40,
		"sight": 45.0, "tint": Color(0.46, 0.22, 0.2), "models": ["beast"], "from": 170.0, "weight": 0.0, "claws": true},
	"leaper": {"name": "Leaper", "icon": "boot+up", "desc": "Small and quick. Jumps at you from up to nine metres away.", "hp": 55.0, "roam_speed": 1.5, "speed": 3.4, "damage": 12.0, "scale": 0.88, "xp": 14,
		"sight": 30.0, "tint": Color(0.74, 0.72, 0.22), "models": ["normal_b"], "from": 100.0, "weight": 3.5, "leaps": true},
	# Only in the Mists.
	"rift_stalker": {"name": "Rift Stalker", "icon": "stalker", "desc": "Hunts only in the Mists. Bounds over gaps a Zombie could never clear, and a stone line is no escape from it.", "hp": 65.0, "roam_speed": 2.0, "speed": 3.6, "damage": 12.0, "scale": 0.95, "xp": 16,
		"sight": 36.0, "tint": Color(0.3, 0.82, 0.76), "models": ["normal_b"], "from": 45.0, "weight": 3.0, "leaps": true, "only_islands": true, "maps": ["mists"], "hop_reach": 20.0, "hop_up": 10.0},
	"mist_harrier": {"name": "Mist Harrier", "icon": "harrier", "desc": "Hunts only in the Mists. Glides over the void and dives. Its blow throws you back, so keep away from the edge.", "hp": 70.0, "roam_speed": 4.0, "speed": 5.4, "damage": 11.0, "scale": 1.0, "xp": 18,
		"sight": 40.0, "models": ["harrier"], "from": 150.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 6.0, "only_islands": true, "maps": ["mists"], "shoves": true},
	"lantern_wisp": {"name": "Lantern Wisp", "icon": "lantern_wisp", "desc": "A lost lantern carried by living mist. Marks your last position with a cyan seal, then bursts it. Step outside the ring before it closes.", "hp": 60.0, "roam_speed": 2.0, "speed": 3.8, "damage": 9.0, "scale": 1.0, "xp": 20, "sight": 32.0, "models": ["lantern_wisp"], "from": 50.0, "weight": 3.0, "custom": true, "phases": true, "only_islands": true, "maps": ["mists"]},
	"mist_weaver": {"name": "Mist Weaver", "icon": "mist_weaver", "desc": "An antlered moth woven from funeral veils. Lays three mist seals around your last position. The seals slow as well as wound; move through a gap instead of retreating along the line.", "hp": 115.0, "roam_speed": 2.0, "speed": 2.9, "damage": 13.0, "scale": 1.1, "xp": 32, "sight": 36.0, "models": ["mist_weaver"], "from": 180.0, "weight": 1.8, "custom": true, "phases": true, "only_islands": true, "maps": ["mists"]},
	"veil_regent": {"name": "Veil Regent", "icon": "veil_regent", "desc": "Sovereign of the Mists. Sees through concealment and resists stun and freezing. Awakens once around 8:30. Its expanding crown leaves a safe eye at the centre. Below half health it weaves three distant seals and calls two Lantern Wisps. Killing it leaves an Angel familiar. Survive ten minutes and defeat the Regent to win.", "hp": 850.0, "roam_speed": 2.5, "speed": 3.2, "damage": 22.0, "scale": 1.6, "xp": 180, "sight": 100.0, "models": ["veil_regent"], "from": 525.0, "weight": 0.0, "custom": true, "phases": true, "only_islands": true, "maps": ["mists"], "mist_boss": true},

	"fallen_revenant": {"name": "Fallen Revenant", "icon": "fallen_revenant", "desc": "A fallen wielder of Mist. Spectral claws drain life. Its marked mist leap bursts after a warning; move out of the seal before it arrives.", "hp": 160.0, "roam_speed": 2.0, "speed": 3.5, "damage": 16.0, "scale": 1.1, "xp": 45, "sight": 36.0, "models": ["fallen_revenant"], "from": 240.0, "weight": 1.5, "custom": true, "phases": true, "only_islands": true, "maps": ["mists"]},
	"crow": {"name": "Carrion Crow", "icon": "feather", "desc": "Comes in flocks that circle and dive. A roof stops them.", "hp": 25.0, "roam_speed": 5.0, "speed": 6.0, "damage": 5.0, "scale": 1.0, "xp": 6,
		"sight": 32.0, "models": ["crow"], "from": 120.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 4.5},
	"gargoyle": {"name": "Gargoyle", "icon": "wings", "desc": "A statue on a rooftop, until you walk too close. Then it hunts from the air.", "hp": 120.0, "roam_speed": 4.0, "speed": 7.5, "damage": 18.0, "scale": 1.0, "xp": 28,
		"sight": 14.0, "models": ["gargoyle"], "from": 240.0, "weight": 0.0, "flies": true, "custom": true, "statue": true, "fly_height": 6.0},
	"mimic": {"name": "Mimic", "icon": "tooth", "desc": "Looks just like a weapon on the ground. Bites when you reach for it.", "hp": 60.0, "roam_speed": 0.0, "speed": 4.6, "damage": 15.0, "scale": 1.0, "xp": 20,
		"sight": 4.0, "models": ["mimic"], "from": 90.0, "weight": 0.0, "custom": true, "dormant": true},
	"scarecrow": {"name": "Scarecrow", "icon": "eye", "desc": "Stands still while you watch it. Walks when you look away.", "hp": 90.0, "roam_speed": 0.0, "speed": 3.4, "damage": 14.0, "scale": 1.0, "xp": 18,
		"sight": 18.0, "models": ["scarecrow"], "from": 90.0, "weight": 0.0, "custom": true, "scarecrow": true},
	"wraith": {"name": "Wraith", "icon": "ghost", "desc": "Drifts through walls. Fire hurts it far more than steel.", "hp": 70.0, "roam_speed": 1.4, "speed": 2.1, "damage": 12.0, "scale": 1.05, "xp": 24,
		"sight": 24.0, "tint": Color(0.5, 0.8, 1.0), "models": ["magic"], "from": 270.0, "weight": 1.4, "phases": true, "ghost": Color(0.5, 0.82, 1.0, 0.5)},
	"banshee": {"name": "Banshee", "icon": "shout", "desc": "Harmless alone. Her scream tells every zombie around where you are. A stun cuts it short.", "hp": 40.0, "roam_speed": 1.6, "speed": 2.8, "damage": 0.0, "scale": 1.0, "xp": 22,
		"sight": 24.0, "tint": Color(0.9, 0.9, 1.0), "models": ["clever"], "from": 240.0, "weight": 1.2, "screams": true, "ghost": Color(0.93, 0.9, 1.0, 0.65)},
	# Fallen Heroes: undead versions of the player's classes, stronger each minute.
	"hero_infantry": {"name": "Fallen Infantry", "icon": "sword", "desc": "Sword in hand, faster than the rest. Learns to leap at minute 4. Drops its sword.", "hp": 130.0, "roam_speed": 1.8, "speed": 3.7, "damage": 13.0, "scale": 1.12, "xp": 30, "sight": 32.0,
		"tint": Color(0.44, 0.3, 0.56), "models": ["normal_a"], "hero": true, "weapon": "sword", "attack_rate": 0.8},
	"hero_ranger": {"name": "Fallen Ranger", "icon": "bow", "desc": "Shoots from far away. Fire arrows at minute 4, two at a time at minute 7. Drops its bow.", "hp": 100.0, "roam_speed": 1.8, "speed": 3.2, "damage": 11.0, "scale": 1.12, "xp": 30, "sight": 38.0,
		"tint": Color(0.3, 0.44, 0.4), "models": ["clever"], "hero": true, "weapon": "longbow"},
	"hero_heavy": {"name": "Fallen Heavy", "icon": "shield_rect", "desc": "Blocks half the damage from the front. Hits push you back at minute 4, shockwaves at minute 7.", "hp": 200.0, "roam_speed": 1.4, "speed": 2.6, "damage": 18.0, "scale": 1.22, "xp": 36, "sight": 28.0,
		"tint": Color(0.42, 0.42, 0.52), "models": ["beast"], "hero": true, "weapon": "mace", "shielded": true},
	"hero_chivalry": {"name": "Fallen Knight", "icon": "lance", "desc": "Charges in a straight line with its lance. Charges more often at minute 6.", "hp": 150.0, "roam_speed": 1.8, "speed": 3.4, "damage": 16.0, "scale": 1.18, "xp": 34, "sight": 34.0,
		"tint": Color(0.56, 0.42, 0.24), "models": ["beast"], "hero": true, "weapon": "lance", "charges": true},
	"rider": {"name": "Dread Rider", "icon": "horse", "desc": "Gallops through you with a lance and turns wide to come again. Hit it while it turns. Bring down its horse and it fights on foot.", "hp": 260.0, "roam_speed": 3.5, "speed": 8.2, "damage": 20.0, "scale": 1.3, "xp": 45,
		"sight": 42.0, "tint": Color(0.5, 0.3, 0.26), "models": ["beast"], "from": 300.0, "weight": 0.0, "weapon": "lance", "rider": true},
	"hero_magician": {"name": "Fallen Mage", "icon": "staff", "desc": "Two fireballs at minute 4. Raises zombies around itself at minute 7.", "hp": 90.0, "roam_speed": 1.4, "speed": 2.5, "damage": 11.0, "scale": 1.12, "xp": 32, "sight": 38.0,
		"tint": Color(0.5, 0.26, 0.54), "models": ["magic"], "hero": true, "caster": true},
}

## Only in the Sandbox: something to hit that never dies and never hits back.
const DUMMY := {"name": "Training Dummy", "icon": "target", "desc": "Never dies and never hits back. Shows how hard you hit it.", "hp": 10000000.0, "roam_speed": 0.0, "speed": 0.0, "damage": 0.0, "scale": 1.0, "xp": 0,
	"sight": 0.0, "tint": Color(0.72, 0.6, 0.3), "models": ["dummy"], "from": 9999.0, "weight": 0.0, "custom": true, "dummy": true}

const HEROES := ["hero_infantry", "hero_ranger", "hero_heavy", "hero_chivalry", "hero_magician"]


static func def_of(id: String) -> Dictionary:
	return DUMMY if id == "dummy" else ALL[id]


static func pick_roamer(elapsed: float, islands := false) -> String:
	var total := 0.0
	for id: String in ALL:
		if elapsed >= float(ALL[id].get("from", 9999.0)) and (islands or not ALL[id].get("only_islands", false)):
			total += float(ALL[id].get("weight", 0.0))
	var r := randf() * total
	for id: String in ALL:
		if elapsed >= float(ALL[id].get("from", 9999.0)) and (islands or not ALL[id].get("only_islands", false)):
			var w: float = ALL[id].get("weight", 0.0)
			if w <= 0.0:
				continue
			r -= w
			if r <= 0.0:
				return id
	return "normal"
