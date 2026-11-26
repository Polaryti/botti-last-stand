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
	# Fontanova: the mutants Al'quimelea made (FontaMind, FontaModels).
	"mutant_bee": {"name": "Mutant Bee", "icon": "mutant_bee", "desc": "A bee the size of a dog, changed by the island's god. Circles low, then curls its stinger forward and dives at where you stood: step aside. Its sting poisons you for 4 s. Half the time it leaves Honey when it dies.", "hp": 40.0, "roam_speed": 3.0, "speed": 6.0, "damage": 9.0, "scale": 1.0, "xp": 10,
		"sight": 30.0, "models": ["mutant_bee"], "from": 0.0, "weight": 2.4, "custom": true, "flies": true, "fly_height": 1.8, "radius": 0.5, "tall": 0.9, "maps": ["fontanova"], "tint": Color(0.85, 0.6, 0.15),
		"lore": "The worshippers kept bees on the terraces and offered the god their honey. The god kept the bees."},
	"beehive": {"name": "Beehive", "icon": "beehive", "desc": "A great comb grown over an old olive stump, its cells glowing where the god touched it. It neither moves nor strikes, but every blow sends 2 bees out of it, no more than 6 at once. Broken, it spills 4 Honey.", "hp": 260.0, "roam_speed": 0.0, "speed": 0.0, "damage": 0.0, "scale": 1.0, "xp": 30,
		"sight": 18.0, "models": ["beehive"], "from": 9999.0, "weight": 0.0, "custom": true, "rooted": true, "fixture": true, "radius": 1.0, "tall": 2.4, "maps": ["fontanova"], "tint": Color(0.85, 0.62, 0.2),
		"lore": "Old hives, older than the ruins round them. The comb never stops growing, and nobody has ever seen a queen."},
	"mutant_wasp": {"name": "Mutant Wasp", "icon": "mutant_wasp", "desc": "A red-and-black wasp as long as your arm. Keeps its distance and shoots its stinger, which poisons you for 3 s; up close it dives to bite. It arches its abdomen under itself before it shoots.", "hp": 50.0, "roam_speed": 3.0, "speed": 6.5, "damage": 11.0, "scale": 1.0, "xp": 14,
		"sight": 34.0, "models": ["mutant_wasp"], "from": 120.0, "weight": 1.6, "custom": true, "flies": true, "fly_height": 3.0, "radius": 0.5, "tall": 0.9, "maps": ["fontanova"], "tint": Color(0.62, 0.13, 0.08),
		"lore": "Paper wasps used to nest under the temple's eaves. What hatches there now has learned to throw its sting."},
	"mutant_snail": {"name": "Mutant Snail", "icon": "mutant_snail", "desc": "A snail as big as a boar, its shell grown into glowing seams. Slow, but it leaves a trail behind it that lasts 8 s: green poison or burning embers, whichever its seams glow with. Don't walk in its track.", "hp": 220.0, "roam_speed": 0.8, "speed": 1.3, "damage": 14.0, "scale": 1.0, "xp": 24,
		"sight": 20.0, "models": ["mutant_snail"], "from": 60.0, "weight": 1.4, "custom": true, "radius": 0.9, "tall": 1.4, "maps": ["fontanova"], "tint": Color(0.52, 0.47, 0.38),
		"lore": "After rain the olive groves used to be full of snails. Some of them grew, and kept growing, and the grass where they crawl never grows back."},
	"wasp_hive_snail": {"name": "Wasp-Hive Snail", "icon": "wasp_hive_snail", "desc": "A snail carrying a paper wasps' nest for a shell. Every 12 s its nest shudders and a Mutant Wasp crawls out, no more than 3 of its own at once. Kill the snail and no more come.", "hp": 320.0, "roam_speed": 0.7, "speed": 1.1, "damage": 16.0, "scale": 1.0, "xp": 40,
		"sight": 22.0, "models": ["wasp_hive_snail"], "from": 300.0, "weight": 0.6, "custom": true, "radius": 1.0, "tall": 2.4, "maps": ["fontanova"], "tint": Color(0.6, 0.58, 0.54),
		"lore": "Nobody can say whether the wasps built their nest on the snail, or the snail grew it."},
	"mutant_spider": {"name": "Mutant Spider", "icon": "mutant_spider", "desc": "A long-legged spider that clings head down to tree trunks. Come within 14 m and it drops on you: its web where it lands holds you for 1.2 s and poisons you for 3 s. On the ground it crouches before each pounce. Watch the trees.", "hp": 110.0, "roam_speed": 3.0, "speed": 5.0, "damage": 16.0, "scale": 1.0, "xp": 26,
		"sight": 26.0, "models": ["mutant_spider"], "from": 200.0, "weight": 0.0, "custom": true, "radius": 0.7, "tall": 0.9, "maps": ["fontanova"], "tint": Color(0.3, 0.24, 0.2),
		"lore": "The holm oaks are full of webs as wide as a doorway. The birds that lived in them are gone."},
	"battle_ostrich": {"name": "Battle Ostrich", "icon": "battle_ostrich", "desc": "An ostrich in a war-harness of bronze, as tall as a rider. Paws the ground with its head low, then charges straight at you: whoever it reaches is kicked away. Step out of its line.", "hp": 160.0, "roam_speed": 3.0, "speed": 7.0, "damage": 18.0, "scale": 1.0, "xp": 30,
		"sight": 32.0, "models": ["battle_ostrich"], "from": 180.0, "weight": 1.1, "custom": true, "radius": 0.7, "tall": 2.6, "maps": ["fontanova"], "tint": Color(0.12, 0.1, 0.1),
		"lore": "The cult's guardians rode them to war. The harnesses outlasted the riders."},
	"ember_moth": {"name": "Ember Moth", "icon": "ember_moth", "desc": "A moth wider than a man, with eye-spots on its wings. It spreads its wings and holds them for 1 s, eye-spots blazing, then claps them: the dust where it was looking dazzles you for 2.5 s and sets you alight. Leave the circle.", "hp": 70.0, "roam_speed": 2.0, "speed": 3.5, "damage": 10.0, "scale": 1.0, "xp": 18,
		"sight": 30.0, "models": ["ember_moth"], "from": 240.0, "weight": 0.8, "custom": true, "flies": true, "fly_height": 3.4, "radius": 0.6, "tall": 1.0, "maps": ["fontanova"], "tint": Color(0.95, 0.55, 0.2),
		"lore": "Drawn to the cult's braziers for so long that they became something like them."},
	"thornback": {"name": "Thornback", "icon": "thornback", "desc": "A tortoise as big as a cart, its shell grown into limestone thorns. Slow, but blows from the front glance off its shell for half. Get round it.", "hp": 380.0, "roam_speed": 0.8, "speed": 1.4, "damage": 22.0, "scale": 1.0, "xp": 36,
		"sight": 20.0, "models": ["thornback"], "from": 150.0, "weight": 0.9, "custom": true, "shielded": true, "radius": 1.1, "tall": 1.6, "maps": ["fontanova"], "tint": Color(0.4, 0.36, 0.26),
		"lore": "Tortoises live long. This one has lived long enough to have known the island's people, and to have changed with it."},
	# The cult of Al'quimelea (CultGear, CultMind).
	"cult_worshipper": {"loot_chance": 0.15, "loot": ["weapon", "food"], "name": "Worshipper", "icon": "cult_worshipper", "desc": "A worshipper of Al'quimelea in a mask of beeswax, with a bronze sickle. They come down from the Worshippers' Village in threes. When one falls, the others within 12 m rush you, a third quicker, for 4 s. One time in four one leaves the Honey it would have offered.", "hp": 90.0, "roam_speed": 1.5, "speed": 3.4, "damage": 11.0, "scale": 1.0, "xp": 18,
		"sight": 30.0, "tint": Color(0.66, 0.58, 0.5), "models": ["cult_worshipper"], "from": 60.0, "weight": 1.8, "maps": ["fontanova"], "cult": true, "pack": 3,
		"lore": "The people of Fontanova kept bees for their god and wore its wax to pray. They are still praying."},
	"cult_priest": {"loot_chance": 0.25, "loot": ["food", "power"], "name": "Priest of Change", "icon": "cult_priest", "desc": "Keeps 8 to 16 m from you and throws a flask of elixir where you are going: the ring it marks poisons you for 3 s and slows you for 2 s. Every 12 s it raises its staff over a hurt creature of the island within 14 m, healing a third of its health and quickening it for 5 s. Stun it to break off the rite.", "hp": 140.0, "roam_speed": 1.2, "speed": 2.6, "damage": 10.0, "scale": 1.0, "xp": 34,
		"sight": 36.0, "tint": Color(0.6, 0.54, 0.5), "models": ["cult_priest"], "from": 180.0, "weight": 1.0, "maps": ["fontanova"], "cult": true,
		"lore": "Al'quimelea's priests brewed the god's elixirs in the temple, and tasted them first. Nothing they brew now is meant for them."},
	"cult_guardian": {"loot_chance": 0.25, "loot": ["weapon", "food"], "name": "Temple Guardian", "icon": "cult_guardian", "desc": "A guardian of the temple in bronze. Blows from the front glance off its shield for half. It braces behind the shield, then rushes you: whoever it reaches is thrown back and stunned for 0.8 s. Get round it, or out of its line.", "hp": 230.0, "roam_speed": 1.4, "speed": 2.8, "damage": 18.0, "scale": 1.08, "xp": 40,
		"sight": 30.0, "tint": Color(0.62, 0.52, 0.44), "models": ["cult_guardian"], "from": 300.0, "weight": 0.8, "maps": ["fontanova"], "cult": true, "shielded": true,
		"lore": "The temple's guard kept the Sacred Way in bronze for a thousand years. Their god changed everything on the island except them, and they have not forgiven it."},
	"ostrich_rider": {"loot_chance": 0.3, "loot": ["weapon", "food"], "name": "Ostrich Guardian", "icon": "ostrich_rider", "desc": "A Temple Guardian on a battle ostrich. Gallops through you with its spear and turns wide to come again: hit it while it turns. Bring the ostrich down and the Guardian fights on foot, shield and all.", "hp": 300.0, "roam_speed": 3.0, "speed": 8.0, "damage": 20.0, "scale": 1.08, "xp": 52,
		"sight": 40.0, "tint": Color(0.62, 0.52, 0.44), "models": ["cult_guardian"], "from": 420.0, "weight": 0.0, "maps": ["fontanova"], "cult": true, "shielded": true, "rider": true, "mount": "ostrich",
		"lore": "The Guardians bred their war-birds in the hills under the Acropolis and rode them in the god's processions. They still ride the processions, though nobody follows."},
	# The cult's two great ones, each come once in the night (Director._tick_cult).
	"hierophant": {"loot_chance": 1.0, "loot": ["power", "weapon"], "name": "The Hierophant", "icon": "hierophant", "desc": "High priest of Al'quimelea, a third eye lit in its golden mask. Keeps 7 to 14 m off and throws 3 flasks of elixir at once, one where you are going and one to either side: each ring poisons you for 3 s and slows you for 2 s. Below half health, every 20 s it pours the elixir of change over the Worshippers within 18 m: up to 2 of them become mutants. With none near, it calls 2 down to it. Comes down the Sacred Way once, around 3:30.", "hp": 900.0, "roam_speed": 1.3, "speed": 2.6, "damage": 16.0, "scale": 1.45, "xp": 160,
		"sight": 60.0, "tint": Color(0.6, 0.54, 0.5), "models": ["hierophant"], "from": 9999.0, "weight": 0.0, "maps": ["fontanova"], "miniboss": true, "cult": true,
		"first_words": "Kneel, and be changed.",
		"last_words": "I was... only... the first...",
		"lore": "The Hierophant was first to drink each of the god's elixirs, and first to be changed by them. It has a third eye now, and uses it to see what everything else could become."},
	"polemarch": {"loot_chance": 1.0, "loot": ["weapon", "power"], "name": "The Polemarch", "icon": "polemarch", "desc": "Commander of the Temple Guardians, behind a tower shield: blows from the front glance off it for three quarters. Close in, it sweeps its long spear across the ground in front of it: whoever it catches is thrown back and stunned for 1 s. Further off it charges behind the shield. At 60% and 30% health it calls 2 Temple Guardians to its sides. Get behind it. Marches out of the Worshippers' Village once, around 6:30.", "hp": 1100.0, "roam_speed": 1.6, "speed": 3.0, "damage": 24.0, "scale": 1.55, "xp": 180,
		"sight": 60.0, "tint": Color(0.62, 0.52, 0.44), "models": ["polemarch"], "from": 9999.0, "weight": 0.0, "maps": ["fontanova"], "miniboss": true, "cult": true, "shielded": true, "shield_cut": 0.25,
		"first_words": "The Sacred Way is closed. Turn back, or lie on it.",
		"last_words": "Hold... the line...",
		"lore": "Every Guardian of the temple served under a Polemarch, and this one has commanded them for longer than any of them has been alive. It has never once lowered its shield."},
	# Fontanova's god (GodModels, GodMind).
	"alquimelea": {"name": "Al'quimelea", "icon": "alquimelea+crown", "desc": "The fallen god of change, who made the island's mutants. Comes down from its temple at 11:00, floats 9 to 18 m from you over cliffs and all, and dawn will not come until it falls. Flasks of its elixir rain round each of you: each ring poisons you for 3 s and slows you for 2 s. A great ring of change opens under each of you: still in it when it opens, you are poisoned for 3 s and held fast for 1.2 s. Come within 8 m and its crucible blazes: the light throws you back and sets you burning for 2 s. Stand far off and a line of 7 crystal shards strikes out toward you, each slowing you for 1.5 s. At two thirds and one third of its health mutants are born of it, and it grows quicker.", "hp": 5200.0, "roam_speed": 2.4, "speed": 2.4, "damage": 26.0, "scale": 1.0, "xp": 600,
		"sight": 70.0, "models": ["alquimelea"], "from": 9999.0, "weight": 0.0, "custom": true, "god_boss": true, "radius": 2.6, "tall": 12.0, "maps": ["fontanova"], "tint": Color(0.6, 0.4, 0.8),
		"first_words": "Everything that is, I can change. Everything I change is mine.",
		"last_words": "Change... me... then...",
		"lore": "The god Fontanova kept bees for, and brewed for, and drank for. It never wanted worship: it wanted to see what everything could become. It began with its people, and when they were done it began with itself."},
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
	"kraken_arm": {"name": "Kraken's Arm", "icon": "kraken_arm", "desc": "Four great arms rise out of the flooded flats around you at the high tide after 4:30. Each rears up and slams down where you stand: step out of the ring. Close by, it sweeps you away. When the tide goes out, any still standing sink back into the sea. They are the Kraken's own arms, and the rest of it comes at the end of the night.", "hp": 230.0, "roam_speed": 0.0, "speed": 0.0, "damage": 22.0, "scale": 1.0, "xp": 60,
		"sight": 26.0, "models": ["kraken_arm"], "from": 9999.0, "weight": 0.0, "custom": true, "maps": ["vael", "lantern_road"], "miniboss": true, "rooted": true, "shoves": true, "radius": 0.6, "tall": 6.6,
		"lore": "Nobody in Vael ever saw the whole of it. The divers who went down to the drowned harbour came up and said the bay floor moved."},
	"hollow_sovereign": {"name": "Hollow Sovereign", "icon": "hollow_sovereign+crown", "desc": "The drowned king of Vael, an empty robe of state under the Sunken Crown. Sends waves rolling along the ground at you, 4 in a line. Twice, at two thirds and at one third of his health, he calls the tide in for 45 s and 4 Drowned Sailors rise to guard him. Below half health the crown's judgement falls where one of you stands, and stuns. A quarter quicker while the tide is high. Rises from the flats once, around 8:30. Once he and the Leviathan have both fallen, the Kraken rises.", "hp": 1400.0, "roam_speed": 1.6, "speed": 2.8, "damage": 26.0, "scale": 1.9, "xp": 240,
		"sight": 100.0, "tint": Color(0.36, 0.46, 0.5), "models": ["hollow_sovereign"], "from": 9999.0, "weight": 0.0, "maps": ["vael"], "vael_boss": true, "shoves": true, "claws": true, "drowned": true, "tall": 2.7,
		"first_words": "Kneel. The tide answers to its king, and so will you.",
		"last_words": "Take it, then. The crown has drowned better heads than yours.",
		"lore": "The last king of Vael sold the harbour to the Mists for a crown that would never sink. It never has. Everything under it did."},
	"leviathan": {"name": "Leviathan of the Mists", "icon": "leviathan+crown", "desc": "Rises from the drowned harbour late in the night. Its head strikes down where you stand: step out of the ring. It sends waves rolling across the shore in a line. Now and then it dives and returns with Drowned Sailors. Once it and the Hollow Sovereign have both fallen, the Kraken rises.", "hp": 2300.0, "roam_speed": 0.0, "speed": 0.0, "damage": 30.0, "scale": 1.35, "xp": 320,
		"sight": 60.0, "models": ["leviathan"], "from": 9999.0, "weight": 0.0, "custom": true, "maps": ["vael", "lantern_road"], "vael_boss": true, "rooted": true, "radius": 1.6, "tall": 10.0,
		"lore": "The ferrymen said the Isle of Lamps was lit to keep something asleep. The lamps went out when the Mists rose, and nobody ever said what it was."},
	"kraken": {"name": "The Kraken", "icon": "kraken+crown", "desc": "The last of Vael. Once the Hollow Sovereign and the Leviathan have both fallen, it rises in front of the quay and holds the tide in, and dawn will not come until it sinks. Its arms rear up over each of you and whip down: step out of the rings. Come within 7.5 m and every arm sweeps round and throws you back into the sea. It hooks whoever stands furthest off and drags them in. Below two thirds of its health it spits ink that blinds you for 3.5 s. At two thirds and at one third it roars, draws everyone within 24 m toward it for 6 s and raises 4 Drowned Sailors. In its last third its arms come down three at a time and waves roll out from it toward each of you.", "hp": 3600.0, "roam_speed": 0.0, "speed": 0.0, "damage": 30.0, "scale": 1.0, "xp": 600,
		"sight": 120.0, "models": ["kraken"], "from": 9999.0, "weight": 0.0, "custom": true, "maps": ["vael"], "vael_boss": true, "rooted": true, "radius": 3.0, "tall": 8.0,
		"lore": "The kings of Vael wore a crown that would never sink. Under the harbour, something wore the rest of the city. When the Hollow Sovereign gave his people to the Mists for that crown, it was this that took the price, and it has been growing into the drowned towers ever since."},
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
	"earth_elemental": {"stone": true, "name": "Earth Elemental", "icon": "boulder", "desc": "Mossy boulders held together by old mist. Slow, but it pounds the ground: get out of the amber circle before it closes.", "hp": 280.0, "roam_speed": 1.1, "speed": 2.5, "damage": 20.0, "scale": 1.0, "xp": 42,
		"sight": 28.0, "models": ["earth_elemental"], "from": 120.0, "weight": 1.6, "custom": true, "maps": ["mesenlla", "bastion"], "shoves": true, "radius": 0.8, "tall": 2.3},
	"mist_elemental": {"name": "Mist Elemental", "icon": "mist_elemental", "desc": "A swirl of mist around a bone-white heart. Passes through walls and vanishes, to appear behind you. When it falls, its mist bursts and slows everyone near.", "hp": 130.0, "roam_speed": 2.0, "speed": 3.2, "damage": 15.0, "scale": 1.0, "xp": 30,
		"sight": 32.0, "models": ["mist_elemental"], "from": 180.0, "weight": 1.3, "custom": true, "phases": true, "maps": ["mesenlla", "bastion"], "tall": 2.2},
	"storm_elemental": {"name": "Storm Elemental", "icon": "storm_elemental", "desc": "A crackling thundercloud over a ring of stones. Keeps its distance and calls lightning where you stand. Keep moving when the ground glows white.", "hp": 120.0, "roam_speed": 1.6, "speed": 2.6, "damage": 16.0, "scale": 1.0, "xp": 32,
		"sight": 38.0, "models": ["storm_elemental"], "from": 240.0, "weight": 1.1, "custom": true, "maps": ["mesenlla", "bastion"], "tall": 2.4},
	"wyvern": {"name": "Wyvern", "icon": "wyvern", "desc": "Glides over the valleys and breathes on the ground below. Each is of Fire, Ice or Storm: fire burns, ice freezes you and slows you after, lightning stuns. Leave the circle before its breath comes down. Where it dives on you, its element bursts a moment later.", "hp": 260.0, "roam_speed": 5.0, "speed": 6.2, "damage": 16.0, "scale": 1.0, "xp": 50,
		"sight": 46.0, "models": ["wyvern"], "from": 300.0, "weight": 0.0, "flies": true, "custom": true, "fly_height": 9.0, "maps": ["mesenlla", "bastion"],
		"elements": ["fire", "ice", "storm"]},
	"great_revenant_elemental": {"stone": true, "name": "Great Revenant Elemental", "icon": "boulder+crown", "desc": "Lord of the valleys: a giant of boulders bound by mist. Pounds the ground around it and throws boulders where you stand. Below half health its boulders break loose and it throws two at a time. Rises once in the Valleys of Mesenlla around 8:30.", "hp": 1200.0, "roam_speed": 1.4, "speed": 2.4, "damage": 26.0, "scale": 1.0, "xp": 200,
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
	"gargoyle": {"stone": true, "name": "Gargoyle", "icon": "wings", "desc": "A statue on a rooftop, until you walk too close. Then it hunts from the air.", "hp": 120.0, "roam_speed": 4.0, "speed": 7.5, "damage": 18.0, "scale": 1.0, "xp": 28,
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
	if map_id in SpawnRules.MESENLLA or map_id in SpawnRules.VAEL or map_id in SpawnRules.ARCHIPELAGO:
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
	return "child_of_woods" if map_id in SpawnRules.MESENLLA else "drowned_sailor" if map_id in SpawnRules.VAEL else "mutant_bee" if map_id in SpawnRules.ARCHIPELAGO else "normal"
