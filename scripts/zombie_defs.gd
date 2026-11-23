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
	# Port Vael: the drowned, and what the Mist Tide brings in with it. Those marked "drowned" are
	# quicker while the tide is high (MistTide.QUICKEN). The special moves of the Siren, the Press Gang,
	# the Tide Witch, the three "miniboss" foes and the Hollow Sovereign are VaelMind's.
	"drowned_sailor": {"loot_chance": 0.2, "loot": ["weapon", "food"], "name": "Drowned Sailor", "icon": "drowned_sailor", "desc": "A sailor of Vael come back out of the sea, with a cutlass, a boarding hook or a knife in its hand. A quarter quicker while the tide is high. One time in five it leaves something when it falls: that weapon or some food.", "hp": 75.0, "roam_speed": 1.4, "speed": 3.2, "damage": 10.0, "scale": 1.0, "xp": 14,
		"sight": 30.0, "tint": Color(0.42, 0.56, 0.58), "models": ["drowned"], "from": 0.0, "weight": 10.0, "maps": ["vael", "lantern_road"], "weapons": ["cutlass", "boarding_hook", "dagger"], "weapon_odds": [3, 2, 2], "drowned": true,
		"lore": "The crews of Vael went down with their harbour on the night the crown was lost. The tide brings them home every night, and every night they look for the ships they sailed."},
	"barnacle_brute": {"name": "Barnacle Brute", "icon": "barnacle_brute", "desc": "A drowned dock-hand grown over with barnacles and coral. Its crust takes half of every blow struck from in front: get round it. Its blows throw you back. A quarter quicker while the tide is high.", "hp": 290.0, "roam_speed": 1.2, "speed": 2.3, "damage": 19.0, "scale": 1.4, "xp": 44,
		"sight": 30.0, "tint": Color(0.5, 0.52, 0.48), "models": ["barnacle_brute"], "from": 120.0, "weight": 1.8, "maps": ["vael", "lantern_road"], "shoves": true, "shielded": true, "drowned": true,
		"lore": "Some of the drowned stood so long on the harbour floor that the sea built on them. They still carry the anchor chains they were hauling when the water came."},
	"brine_hound": {"name": "Brine Hound", "icon": "brine_hound", "desc": "A hound the sea took back. Hunts in a pack of three: crouches, then lunges at you from a few metres off. A quarter quicker while the tide is high.", "hp": 90.0, "roam_speed": 2.4, "speed": 6.2, "damage": 12.0, "scale": 1.0, "xp": 20,
		"sight": 36.0, "models": ["brine_hound"], "from": 150.0, "weight": 0.0, "custom": true, "maps": ["vael", "lantern_road"], "drowned": true, "pack": 3, "radius": 0.5, "tall": 1.0,
		"lore": "The harbour's dogs swam out after their masters' boats. What swims back is longer and slicker, with gills in its neck and a mouth full of needles."},
	"lantern_jelly": {"name": "Lantern Jelly", "icon": "lantern_jelly", "desc": "Drifts in on the high tide with a ship's lantern still burning inside it. Its threads flare, then it stings everything within 2.4 m, stunning for 0.8 s. When it dies it stings once more. Back away when the threads flare.", "hp": 60.0, "roam_speed": 1.0, "speed": 1.8, "damage": 14.0, "scale": 1.0, "xp": 18,
		"sight": 26.0, "models": ["lantern_jelly"], "from": 60.0, "weight": 0.0, "custom": true, "maps": ["vael", "lantern_road"], "sting_reach": 2.4, "sting_stun": 0.8, "radius": 0.6, "tall": 2.4,
		"lore": "Jellies drifted into the drowned harbour and grew round its lanterns, which never went out. Sailors once steered home by those lights. Now the lights come looking for them."},
	"wreck_gull": {"name": "Wreck Gull", "icon": "wreck_gull", "desc": "A salt-crusted gull from the wrecks. Circles above the quay, swells its glowing throat and spits a salt glob from up to 24 m away. The marked splash slows for 1.5 s. Step out of the circle; after spitting it drops low for 1.8 s, within sword reach.", "hp": 65.0, "roam_speed": 2.0, "speed": 5.2, "damage": 12.0, "scale": 1.0, "xp": 22,
		"sight": 36.0, "models": ["wreck_gull"], "from": 75.0, "weight": 1.5, "custom": true, "flies": true, "fly_height": 3.0, "radius": 0.55, "tall": 1.0, "maps": ["vael"],
		"lore": "Gulls nested in the ribs of Vael's wrecks until salt grew through their feathers. They no longer wait for the tide to uncover a meal."},
	"storm_ray": {"name": "Storm Ray", "icon": "storm_ray", "desc": "A broad-finned ray swimming through the sea mist. Folds its fins and charges its luminous spine, then sends three lightning strikes across a fixed line. Move sideways out of the circles. Each hit briefly stuns. It sinks low after firing; roofs break its aim.", "hp": 145.0, "roam_speed": 1.6, "speed": 3.8, "damage": 15.0, "scale": 1.0, "xp": 38,
		"sight": 40.0, "models": ["storm_ray"], "from": 210.0, "weight": 0.8, "custom": true, "flies": true, "fly_height": 3.8, "radius": 0.7, "tall": 1.2, "maps": ["vael"],
		"lore": "When the drowned city's lightning rods vanished below the water, something began carrying their storms above it. Sailors know the pale ribs of light moving through the fog."},
	"bell_wraith": {"name": "Bell Wraith", "icon": "bell_wraith", "desc": "A cracked ship's bell borne on ragged sails and trailing weed. The clapper shakes before it casts a distant knell: a marked ring that slows for 2 s. Stand inside its safe centre or leave the ring. Stun the wraith before it releases the knell to interrupt it; punish its low recovery.", "hp": 115.0, "roam_speed": 1.3, "speed": 3.3, "damage": 18.0, "scale": 1.0, "xp": 36,
		"sight": 38.0, "models": ["bell_wraith"], "from": 300.0, "weight": 0.65, "custom": true, "flies": true, "fly_height": 2.8, "radius": 0.6, "tall": 1.8, "maps": ["vael"],
		"lore": "Every lost ship owed the harbour one last toll of its bell. Some bells are still trying to pay, with the bell-ringer's empty coat caught in their rigging."},

	"angler": {"name": "Angler", "icon": "angler", "desc": "Lies buried in the sand with only its lure showing, like a lamp someone left on the shore. Come close and it bursts out to bite.", "hp": 160.0, "roam_speed": 0.0, "speed": 3.0, "damage": 28.0, "scale": 1.0, "xp": 30,
		"sight": 4.0, "models": ["angler"], "from": 90.0, "weight": 0.0, "custom": true, "dormant": true, "maps": ["vael", "lantern_road"], "radius": 0.65, "tall": 1.4,
		"lore": "The fishermen of Vael told of a fish that lit its own lamp to bring the boats in. On the flats of Port Vael there are a great many lamps."},
	"siren": {"name": "Siren", "icon": "siren", "desc": "Keeps to the water's edge and sings. While she sings, everyone within 16 m is drawn toward her, 2.6 m a second. A stun, or a fifth of her health struck off while she sings, breaks the song. Close by, she claws.", "hp": 110.0, "roam_speed": 1.2, "speed": 2.6, "damage": 12.0, "scale": 1.0, "xp": 34,
		"sight": 34.0, "models": ["siren"], "from": 150.0, "weight": 0.0, "custom": true, "maps": ["vael", "lantern_road"], "radius": 0.5, "tall": 1.9,
		"lore": "Vael's sailors swore the sea sang them home. The night the harbour drowned it sang louder than ever, and every ship in the bay turned toward the rocks."},
	"press_gang": {"loot_chance": 0.2, "loot": ["weapon", "food"], "name": "Press Gang", "icon": "press_gang", "desc": "Come in threes, still looking for hands for the Sovereign's ships. Each throws a weighted net where you are about to be: caught in it, you cannot move for 1.6 s. Step out of the ring before it lands. A quarter quicker while the tide is high. One time in five one leaves its hook or some food when it falls.", "hp": 110.0, "roam_speed": 1.6, "speed": 3.4, "damage": 12.0, "scale": 1.05, "xp": 26,
		"sight": 32.0, "tint": Color(0.42, 0.52, 0.56), "models": ["press_gang"], "from": 200.0, "weight": 0.0, "maps": ["vael", "lantern_road"], "weapon": "boarding_hook", "pack": 3, "drowned": true,
		"lore": "The Sovereign's ships were never short of crew. The press gangs saw to that, with a net, a cosh and the King's shilling, and they are at it still."},
	"tide_witch": {"name": "Tide Witch", "icon": "tide_witch", "desc": "Keeps her distance and calls the sea up in a line of 3 waves that roll toward you, one after another: each throws you back and slows you for 2 s. At high tide she also raises 2 Drowned Sailors out of the water near you. Step out of the line.", "hp": 130.0, "roam_speed": 1.2, "speed": 2.6, "damage": 10.0, "scale": 1.0, "xp": 40,
		"sight": 38.0, "tint": Color(0.36, 0.5, 0.5), "models": ["tide_witch"], "from": 240.0, "weight": 1.2, "maps": ["vael", "lantern_road"], "drowned": true,
		"lore": "The sea-wives of Vael read the tide for the fishing fleet. When the Mists rose like a sea they read something else in it, and the water has done as they say ever since."},
	"harbourmaster": {"name": "Harbourmaster", "icon": "harbourmaster", "desc": "The keeper of the drowned harbour, in his coat and cap. Throws a hook on a chain where you stand: caught, you are dragged to him. His blows throw you back. Below half health he rings his bell and a Press Gang answers. Climbs the quay stairs once, around 3:00.", "hp": 700.0, "roam_speed": 1.8, "speed": 2.8, "damage": 21.0, "scale": 1.5, "xp": 150,
		"sight": 60.0, "tint": Color(0.4, 0.5, 0.52), "models": ["harbourmaster"], "from": 9999.0, "weight": 0.0, "maps": ["vael", "lantern_road"], "miniboss": true, "shoves": true, "claws": true, "drowned": true,
		"first_words": "Papers! No ship leaves my harbour without papers.",
		"last_words": "The harbour... is closed...",
		"lore": "He kept the harbour of Vael for forty years and never let a ship leave without its dues. The tide took the harbour, and he went on keeping it."},
	"lighthouse_keeper": {"name": "Mad Lighthouse Keeper", "icon": "lighthouse_keeper", "desc": "Kept the lighthouse burning long after the harbour drowned, and still does. Throws burning oil lamps where you stand. When he lifts his great lamp, turn your back: anyone within 14 m looking at him when it blazes is dazzled for 1.5 s. Below half health he throws 2 lamps at a time. Comes down the East Mole once, around 6:00.", "hp": 800.0, "roam_speed": 1.8, "speed": 3.2, "damage": 20.0, "scale": 1.35, "xp": 140,
		"sight": 60.0, "tint": Color(0.45, 0.48, 0.42), "models": ["lighthouse_keeper"], "from": 9999.0, "weight": 0.0, "maps": ["vael", "lantern_road"], "miniboss": true, "claws": true,
		"first_words": "Look at the light! LOOK AT IT!",
		"last_words": "Who will... keep the light...",
		"lore": "When the Mists drowned Vael the lighthouse alone stayed above the water, and its keeper alone stayed in it. He has not let the lamp go out once since, and he no longer remembers why."},
	"kraken_arm": {"name": "Kraken's Arm", "icon": "kraken_arm", "desc": "Four great arms rise out of the flooded flats around you at the high tide after 4:30. Each rears up and slams down where you stand: step out of the ring. Close by, it sweeps you away. When the tide goes out, any still standing sink back into the sea.", "hp": 230.0, "roam_speed": 0.0, "speed": 0.0, "damage": 22.0, "scale": 1.0, "xp": 60,
		"sight": 26.0, "models": ["kraken_arm"], "from": 9999.0, "weight": 0.0, "custom": true, "maps": ["vael", "lantern_road"], "miniboss": true, "rooted": true, "shoves": true, "radius": 0.6, "tall": 6.6,
		"lore": "Nobody in Vael ever saw the whole of it. The divers who went down to the drowned harbour came up and said the bay floor moved."},
	"hollow_sovereign": {"name": "Hollow Sovereign", "icon": "hollow_sovereign+crown", "desc": "The drowned king of Vael, an empty robe of state under the Sunken Crown. Sends waves rolling along the ground at you, 4 in a line. Twice, at two thirds and at one third of his health, he calls the tide in for 45 s and 4 Drowned Sailors rise to guard him. Below half health the crown's judgement falls where one of you stands, and stuns. A quarter quicker while the tide is high. Rises from the flats once, around 8:30. Survive until dawn and defeat him to win.", "hp": 1400.0, "roam_speed": 1.6, "speed": 2.8, "damage": 26.0, "scale": 1.9, "xp": 240,
		"sight": 100.0, "tint": Color(0.36, 0.46, 0.5), "models": ["hollow_sovereign"], "from": 9999.0, "weight": 0.0, "maps": ["vael"], "vael_boss": true, "shoves": true, "claws": true, "drowned": true, "tall": 2.7,
		"first_words": "Kneel. The tide answers to its king, and so will you.",
		"last_words": "Take it, then. The crown has drowned better heads than yours.",
		"lore": "The last king of Vael sold the harbour to the Mists for a crown that would never sink. It never has. Everything under it did."},
	"leviathan": {"name": "Leviathan of the Mists", "icon": "leviathan", "desc": "Rises from the drowned harbour late in the night. Its head strikes down where you stand: step out of the ring. It sends waves rolling across the shore in a line. Now and then it dives and returns with Drowned Sailors. Defeat it and the Hollow Sovereign, then survive until dawn to reclaim Port Vael.", "hp": 2300.0, "roam_speed": 0.0, "speed": 0.0, "damage": 30.0, "scale": 1.35, "xp": 320,
		"sight": 60.0, "models": ["leviathan"], "from": 9999.0, "weight": 0.0, "custom": true, "maps": ["vael", "lantern_road"], "vael_boss": true, "rooted": true, "radius": 1.6, "tall": 10.0,
		"lore": "The ferrymen said the Isle of Lamps was lit to keep something asleep. The lamps went out when the Mists rose, and nobody ever said what it was."},
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
	"veil_regent": {"name": "Veil Regent", "icon": "veil_regent+crown", "desc": "Sovereign of the Mists. Sees through concealment and resists stun and freezing. Awakens once around 8:30. Its expanding crown leaves a safe eye at the centre. Below half health it weaves three distant seals and calls two Lantern Wisps. Survive ten minutes and defeat the Regent to win.", "hp": 850.0, "roam_speed": 2.5, "speed": 3.2, "damage": 22.0, "scale": 1.6, "xp": 180, "sight": 100.0, "models": ["veil_regent"], "from": 525.0, "weight": 0.0, "custom": true, "phases": true, "only_islands": true, "maps": ["mists"], "mist_boss": true,
		"first_words": "Kneel, little lights. Every road in the Mists ends at my throne.",
		"last_words": "You have only parted the veil. It closes behind every one of you."},

	# Beyond the Mists: only on the Valleys of Mesenlla and Mist Bastion ("Map Exclusive · Mesenlla").
	"bear": {"name": "Bear", "icon": "bear", "desc": "A mountain bear. Claws anyone close, and when it rears up on its hind legs, a heavy maul follows: step out of reach.", "hp": 210.0, "roam_speed": 1.6, "speed": 3.7, "damage": 18.0, "scale": 1.0, "xp": 34,
		"sight": 30.0, "models": ["bear"], "from": 60.0, "weight": 2.5, "custom": true, "maps": ["mesenlla", "bastion"], "radius": 0.75, "tall": 1.6},
	"mist_bear": {"name": "Mist Bear", "icon": "mist_bear", "desc": "A bear the Mists have soaked through. Paws the ground in a cloud of mist, then charges in a straight line and throws you back. Sidestep the charge.", "hp": 300.0, "roam_speed": 1.6, "speed": 3.9, "damage": 22.0, "scale": 1.15, "xp": 48,
		"sight": 34.0, "models": ["mist_bear"], "from": 200.0, "weight": 1.4, "custom": true, "maps": ["mesenlla", "bastion"], "shoves": true, "radius": 0.85, "tall": 1.75},
	"eagle": {"name": "Eagle", "icon": "eagle", "desc": "Circles high over the slopes, then folds its wings and stoops on you. A roof or an overhang stops it.", "hp": 40.0, "roam_speed": 6.0, "speed": 7.0, "damage": 8.0, "scale": 1.0, "xp": 10,
		"sight": 40.0, "models": ["eagle"], "from": 120.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 7.0, "maps": ["mesenlla", "bastion"]},
	"mist_eagle": {"name": "Mist Eagle", "icon": "mist_eagle", "desc": "An eagle of living mist. Its stoop throws you back and leaves a ring of mist that bursts a moment later and slows: keep moving after it strikes.", "hp": 70.0, "roam_speed": 6.0, "speed": 7.4, "damage": 12.0, "scale": 1.2, "xp": 20,
		"sight": 44.0, "models": ["mist_eagle"], "from": 180.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 8.0, "maps": ["mesenlla", "bastion"], "shoves": true},
	"shapeshifter": {"name": "Shapeshifter", "icon": "antlers", "desc": "Looks like a white stag until you come close or hurt it. Then it takes another shape, and a different one every 12 seconds: a great clawed beast; a Mist Wolf that lunges and howls to hasten the creatures near it; a Great Owl that circles out of reach and dives with its talons; or a Tusked Boar that paws the ground and charges, knocking you down. Badly hurt, it turns back into the stag and flees. Catch it within ten seconds, or it comes back whole.", "hp": 240.0, "roam_speed": 2.2, "speed": 5.2, "damage": 20.0, "scale": 1.0, "xp": 40,
		"sight": 34.0, "models": ["shapeshifter"], "from": 150.0, "weight": 1.2, "custom": true, "maps": ["mesenlla", "bastion"], "radius": 0.7, "tall": 1.9},
	"child_of_woods": {"loot_chance": 0.2, "loot": ["weapon", "arrows", "food"], "name": "Child of the Woods", "icon": "sprout", "desc": "Small, quick and never alone. Each carries whatever weapon it found: most often a blade or a flail, now and then a spear, a bow or a crossbow. One time in five it leaves something when it falls: that weapon, a bundle of arrows or some food, each as likely.", "hp": 70.0, "roam_speed": 1.8, "speed": 3.8, "damage": 9.0, "scale": 0.8, "xp": 14,
		"sight": 32.0, "tint": Color(0.55, 0.62, 0.36), "models": ["woods_child"], "from": 0.0, "weight": 10.0, "maps": ["mesenlla", "bastion"], "weapons": ["dagger", "sword", "spear", "flail", "bow", "crossbow"], "weapon_odds": [3, 3, 1, 2, 1, 1]},
	"woodland_cavalry": {"loot_chance": 0.2, "loot": ["weapon", "arrows", "food"], "name": "Woodland Cavalry", "icon": "woodland_cavalry", "desc": "A Child of the Woods riding a bear. Rushes through you with a spear and turns wide to come again. Bring the bear down and its rider fights on foot.", "hp": 280.0, "roam_speed": 3.0, "speed": 7.4, "damage": 18.0, "scale": 0.85, "xp": 46,
		"sight": 40.0, "tint": Color(0.55, 0.62, 0.36), "models": ["woods_child"], "from": 300.0, "weight": 0.0, "weapon": "spear", "rider": true, "mount": "bear", "maps": ["mesenlla", "bastion"]},
	"earth_elemental": {"name": "Earth Elemental", "icon": "boulder", "desc": "Mossy boulders held together by old mist. Slow, but it pounds the ground: get out of the amber circle before it closes.", "hp": 280.0, "roam_speed": 1.1, "speed": 2.5, "damage": 20.0, "scale": 1.0, "xp": 42,
		"sight": 28.0, "models": ["earth_elemental"], "from": 120.0, "weight": 1.6, "custom": true, "maps": ["mesenlla", "bastion"], "shoves": true, "radius": 0.8, "tall": 2.3},
	"mist_elemental": {"name": "Mist Elemental", "icon": "mist_elemental", "desc": "A swirl of mist around a bone-white heart. Passes through walls and vanishes, to appear behind you. When it falls, its mist bursts and slows everyone near.", "hp": 130.0, "roam_speed": 2.0, "speed": 3.2, "damage": 15.0, "scale": 1.0, "xp": 30,
		"sight": 32.0, "models": ["mist_elemental"], "from": 180.0, "weight": 1.3, "custom": true, "phases": true, "maps": ["mesenlla", "bastion"], "tall": 2.2},
	"storm_elemental": {"name": "Storm Elemental", "icon": "storm_elemental", "desc": "A crackling thundercloud over a ring of stones. Keeps its distance and calls lightning where you stand. Keep moving when the ground glows white.", "hp": 120.0, "roam_speed": 1.6, "speed": 2.6, "damage": 16.0, "scale": 1.0, "xp": 32,
		"sight": 38.0, "models": ["storm_elemental"], "from": 240.0, "weight": 1.1, "custom": true, "maps": ["mesenlla", "bastion"], "tall": 2.4},
	"wyvern": {"name": "Wyvern", "icon": "wyvern", "desc": "Glides over the valleys and breathes on the ground below. Each is of Fire, Ice or Storm: fire burns, ice freezes you and slows you after, lightning stuns. Leave the circle before its breath comes down. Where it dives on you, its element bursts a moment later.", "hp": 260.0, "roam_speed": 5.0, "speed": 6.2, "damage": 16.0, "scale": 1.0, "xp": 50,
		"sight": 46.0, "models": ["wyvern"], "from": 300.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 9.0, "maps": ["mesenlla", "bastion"],
		"elements": ["fire", "ice", "storm"]},
	"great_revenant_elemental": {"name": "Great Revenant Elemental", "icon": "boulder+crown", "desc": "Lord of the valleys: a giant of boulders bound by mist. Pounds the ground around it and throws boulders where you stand. Below half health its boulders break loose and it throws two at a time. Rises once in the Valleys of Mesenlla around 8:30.", "hp": 1200.0, "roam_speed": 1.4, "speed": 2.4, "damage": 26.0, "scale": 1.0, "xp": 200,
		"sight": 100.0, "models": ["great_revenant_elemental"], "from": 9999.0, "weight": 0.0, "custom": true, "maps": ["mesenlla"], "mesenlla_boss": true, "shoves": true, "radius": 1.5, "tall": 4.6,
		"first_words": "You woke the valley. Now the stones will bury you in it.",
		"last_words": "Stone forgets nothing. The valley will raise me again."},
	"war_wyvern": {"name": "War Wyvern", "icon": "wyvern+crown", "desc": "An armoured wyvern under a war banner, of Fire, Ice or Storm. Makes passes along the lanes to the Great Portal, breathing its element. Two Children of the Woods ride it with bows, 90 health each: shoot them out of the saddle one by one, or bring the wyvern down and they fall with it. Below half health it calls the eagles of the peaks. Attacks Mist Bastion once, late in the night.", "hp": 1300.0, "roam_speed": 5.0, "speed": 6.6, "damage": 24.0, "scale": 1.0, "xp": 220,
		"sight": 100.0, "models": ["war_wyvern"], "from": 9999.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 11.0, "maps": ["bastion"], "mesenlla_boss": true,
		"elements": ["fire", "ice", "storm"], "riders": 2,
		"first_words": "Burn the gate. Tonight the Great Portal falls, and the sky with it.",
		"last_words": "My fire goes out, but the sky was never yours."},
	"wyvern_rider": {"loot_chance": 0.2, "loot": ["weapon", "arrows", "food"], "name": "War Wyvern Rider", "icon": "sprout+bow", "desc": "A Child of the Woods in the War Wyvern's saddle, shooting at whoever is nearest. It has its own health: shoot it out of the saddle and it falls. When the wyvern falls, its riders fall with it. One time in five it leaves something where it lands: its bow, a bundle of arrows or some food, each as likely.", "hp": 90.0, "roam_speed": 0.0, "speed": 0.0, "damage": 0.0, "scale": 0.8, "xp": 20,
		"sight": 34.0, "tint": Color(0.55, 0.62, 0.36), "models": ["woods_child"], "from": 9999.0, "weight": 0.0, "weapon": "bow", "carried": true, "maps": ["bastion"]},

	"fallen_revenant": {"name": "Fallen Revenant", "icon": "fallen_revenant", "desc": "A fallen wielder of Mist. Spectral claws drain life. Its marked mist leap bursts after a warning; move out of the seal before it arrives.", "hp": 160.0, "roam_speed": 2.0, "speed": 3.5, "damage": 16.0, "scale": 1.1, "xp": 45, "sight": 36.0, "models": ["fallen_revenant"], "from": 240.0, "weight": 1.5, "phases": true, "only_islands": true, "maps": ["mists"],
		"weapon": "claws", "weapon_drop": 0.0, "fallen": true},
	"crow": {"maps": ["village", "fort"], "name": "Carrion Crow", "icon": "feather", "desc": "Comes in flocks that circle and dive. A roof stops them.", "hp": 25.0, "roam_speed": 5.0, "speed": 6.0, "damage": 5.0, "scale": 1.0, "xp": 6,
		"sight": 32.0, "models": ["crow"], "from": 120.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 4.5},
	"gargoyle": {"name": "Gargoyle", "icon": "wings", "desc": "A statue on a rooftop, until you walk too close. Then it hunts from the air.", "hp": 120.0, "roam_speed": 4.0, "speed": 7.5, "damage": 18.0, "scale": 1.0, "xp": 28,
		"sight": 14.0, "models": ["gargoyle"], "from": 240.0, "weight": 0.0, "flies": true, "custom": true, "statue": true, "fly_height": 6.0},
	"mimic": {"name": "Mimic", "icon": "tooth", "desc": "Looks just like a weapon on the ground. Bites when you reach for it.", "hp": 60.0, "roam_speed": 0.0, "speed": 4.6, "damage": 15.0, "scale": 1.0, "xp": 20,
		"sight": 4.0, "models": ["mimic"], "from": 90.0, "weight": 0.0, "custom": true, "dormant": true},
	"scarecrow": {"maps": ["village"], "name": "Scarecrow", "icon": "eye", "desc": "Stands still while you watch it. Walks when you look away.", "hp": 90.0, "roam_speed": 0.0, "speed": 3.4, "damage": 14.0, "scale": 1.0, "xp": 18,
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
	"rider": {"maps": ["village", "fort"], "name": "Dread Rider", "icon": "horse", "desc": "Gallops through you with a lance and turns wide to come again. Hit it while it turns. Bring down its horse and it fights on foot.", "hp": 260.0, "roam_speed": 3.5, "speed": 8.2, "damage": 20.0, "scale": 1.3, "xp": 45,
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


## Whether this kind wanders the given map at this point of the night. Beyond the Mists only its own
## creatures roam, and they roam nowhere else.
static func roams(id: String, elapsed: float, map_id: String) -> bool:
	var d: Dictionary = ALL[id]
	if elapsed < float(d.get("from", 9999.0)):
		return false
	if map_id in SpawnRules.MESENLLA or map_id in SpawnRules.VAEL:
		return d.get("maps", []).has(map_id)
	if d.get("only_islands", false) and map_id != "mists":
		return false
	return SpawnRules.allows(d, map_id)


static func pick_roamer(elapsed: float, map_id := "village") -> String:
	var total := 0.0
	for id: String in ALL:
		if roams(id, elapsed, map_id):
			total += float(ALL[id].get("weight", 0.0))
	var r := randf() * total
	for id: String in ALL:
		if roams(id, elapsed, map_id):
			var w: float = ALL[id].get("weight", 0.0)
			if w <= 0.0:
				continue
			r -= w
			if r <= 0.0:
				return id
	return "child_of_woods" if map_id in SpawnRules.MESENLLA else "drowned_sailor" if map_id in SpawnRules.VAEL else "normal"
