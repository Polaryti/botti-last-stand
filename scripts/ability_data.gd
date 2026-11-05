class_name AbilityData
## Every class's tree: 3 shared choices, then 1 of 3 specializations, then 4 either/or choices on that
## branch, then its final ability. Nine picks in a night, so each one should change how you play.
## "add" changes a stat, "on" reacts to events through Player._act, and "flag" switches on a rule coded
## elsewhere. Icons are "shape" or "shape+corner badge".

static var _cache := {}


static func a(id: String, name: String, desc: String, icon: String, add := {}, on := [], flag := "") -> Dictionary:
	return {"id": id, "name": name, "desc": desc, "icon": icon, "add": add, "on": on, "flag": flag}


static func t(when: String, action: String, params := {}) -> Dictionary:
	var d := {"when": when, "do": action}
	d.merge(params)
	return d


static func _spec(id: String, name: String, desc: String, color: Color, entry: Dictionary, path: Array, final: Dictionary) -> Dictionary:
	final["final"] = true
	entry["icon"] = "spec_%s" % id
	final["icon"] = "spec_%s+crown" % id
	return {"id": id, "name": name, "desc": desc, "color": color, "entry": entry, "path": path, "final": final}


static func tree(class_id: String) -> Dictionary:
	if not _cache.has(class_id):
		match class_id:
			"infantry": _cache[class_id] = _infantry()
			"ranger": _cache[class_id] = _ranger()
			"heavy": _cache[class_id] = _heavy()
			"chivalry": _cache[class_id] = _chivalry()
			"magician": _cache[class_id] = _magician()
			"revenant": _cache[class_id] = _revenant()
			"artificer": _cache[class_id] = _artificer()
			"monk": _cache[class_id] = _monk()
			"plague_doctor": _cache[class_id] = _plague_doctor()
	return _cache[class_id]


static func _monk() -> Dictionary:
	return {"core": [
		[a("focus", "Focus", "+20% melee damage", "sun+up", {"melee_damage": 0.2}),
		a("agility", "Agility", "+12% move speed", "boot+wind", {"speed": 0.12})],
		[a("meditation", "Meditation", "Heal 3 per kill", "sun+heart", {}, [t("kill", "heal", {"n": 3.0})]),
		a("hardened", "Hardened Body", "+30 max health", "heart+up", {"max_hp": 30.0})],
		[a("patience", "Patience", "15% chance to avoid any hit", "wind+shield", {"dodge": 0.15}),
		a("ki_strike", "Ki Strike", "15% crit chance", "star+sun", {"crit_chance": 0.15})],
	], "specs": [
		_spec("way_staff", "Way of the Staff", "The bo replaces every other weapon", Color(0.62, 0.42, 0.18),
			a("way_staff", "Way of the Staff", "Your weapon becomes a Bo Staff, for good. +20% melee damage with it", "staff+star", {"melee_damage": 0.2}, [t("take", "give_weapon", {"id": "bo"})], "bo_master"),
			[[a("long_sweep", "Long Sweep", "+1 m reach", "staff+plus", {"melee_reach": 1.0}),
			a("whirlwind", "Whirlwind", "Hits 2 more enemies", "spiral+staff", {"melee_hits": 2})],
			[a("iron_stance", "Iron Stance", "Take 20% less damage", "shield+staff", {"damage_taken": -0.2}),
			a("flowing", "Flowing Strikes", "+25% attack speed", "wind+staff", {"melee_rate": 0.25})],
			[a("staggering", "Staggering Blow", "25% chance to stun for 0.8 s", "star+staff", {}, [t("hit", "stun", {"chance": 0.25, "secs": 0.8})]),
			a("bone_breaker", "Bone Breaker", "+35% melee damage", "bones+staff", {"melee_damage": 0.35})],
			[a("deflect", "Deflect", "20% chance to avoid any hit", "shield_round+staff", {"dodge": 0.2}),
			a("rising_dragon", "Rising Dragon", "Double knockback", "quake+staff", {"knock": 1.0})]],
			a("hundred_hands", "Hundred Hands", "+30% attack speed, and every 12 s stun everything near you", "staff+crown", {"melee_rate": 0.3}, [t("every", "stun_around", {"secs_every": 12.0, "r": 5.0, "secs": 1.0, "sound": "hammer"})])),
		_spec("spirit", "Way of the Spirit", "Stillness that nothing can touch", Color(0.8, 0.68, 0.3),
			a("spirit", "Way of the Spirit", "Unlocks Inner Peace: 2.5 s untouchable, and heal 25. Heal 1 per second", "sun+cross", {"regen": 1.0}),
			[[a("deep_calm", "Deep Calm", "Heal 1 more per second", "sun+clock", {"regen": 1.0}),
			a("mantra", "Mantra", "Heal 4 per kill", "cross+heart", {}, [t("kill", "heal", {"n": 4.0})])],
			[a("still_water", "Still Water", "Inner Peace comes back 30% sooner", "drop+clock", {"art_cd": -0.3}),
			a("long_life", "Long Life", "+40 max health", "heart+clock", {"max_hp": 40.0})],
			[a("open_palm", "Open Palm", "Hits mark enemies: +25% damage for 4 s", "target+sun", {}, [t("hit", "mark", {"mult": 1.25, "secs": 4.0})]),
			a("quiet_mind", "Quiet Mind", "Zombies see you 35% less far", "eye_closed+sun", {"sight": -0.35})],
			[a("ki_burst", "Ki Burst", "Every 12 s, stun enemies within 5 m", "burst+sun", {}, [t("every", "stun_around", {"secs_every": 12.0, "r": 5.0, "secs": 1.0})]),
			a("calm_aura", "Aura of Calm", "Every 8 s, slow enemies within 6 m", "wind+sun", {}, [t("every", "slow_around", {"secs_every": 8.0, "r": 6.0, "secs": 3.0})])]],
			a("enlightenment", "Enlightenment", "Inner Peace also heals 25 more and burns everything within 6 m", "sun+crown", {}, [], "enlightened")),
		_spec("iron_fist", "Way of the Fist", "Bare hands are enough", Color(0.7, 0.3, 0.16),
			a("iron_fist", "Way of the Fist", "+25% melee damage and +15% attack speed", "claw+star", {"melee_damage": 0.25, "melee_rate": 0.15}),
			[[a("drunken_step", "Drunken Step", "25% chance to avoid any hit", "boot+star", {"dodge": 0.25}),
			a("swift_feet", "Swift Feet", "+20% move speed", "boot+up", {"speed": 0.2})],
			[a("combo", "Combination", "Each hit: +8% attack speed for 3 s, up to 5 times", "claw+clock", {}, [t("hit", "buff", {"stat": "melee_rate", "val": 0.08, "secs": 3.0, "key": "combo", "max": 5})]),
			a("heavy_palm", "Heavy Palm", "20% crit chance", "claw+up", {"crit_chance": 0.2})],
			[a("pressure_point", "Pressure Point", "Crits stun for 1.2 s", "target+star", {}, [t("crit", "stun", {"secs": 1.2})]),
			a("bleeding_palm", "Bleeding Palm", "Hits bleed for 10 per second, 3 s", "drop+claw", {}, [t("hit", "dot", {"dps": 10.0, "secs": 3.0, "bleed": true})])],
			[a("second_breath", "Second Breath", "Heal 4 per kill", "wind+heart", {}, [t("kill", "heal", {"n": 4.0})]),
			a("momentum", "Momentum", "Each kill: +30% speed for 3 s", "skull+boot", {}, [t("kill", "buff", {"stat": "speed", "val": 0.3, "secs": 3.0, "key": "momentum"})])]],
			a("seven_strikes", "Seven-Sided Strike", "Every 8 s, a blur of blows: 70 damage to everything within 5 m", "claw+crown", {}, [t("every", "quake", {"secs_every": 8.0, "r": 5.0, "dmg": 70.0})])),
	]}


static func _plague_doctor() -> Dictionary:
	return {"core": [
		[a("steady_hand", "Steady Hand", "+25% ranged damage", "poison+up", {"ranged_damage": 0.25}),
		a("long_breath_pd", "Long Breath", "+25% range and dart speed", "wind+arrow", {"ranged_power": 0.25})],
		[a("thick_cloak", "Waxed Cloak", "Take 15% less damage", "mask+shield", {"damage_taken": -0.15}),
		a("bird_mask", "Bird Mask", "Zombies see you 25% less far", "mask+eye_closed", {"sight": -0.25})],
		[a("bandolier", "Bandolier", "Carry 30 more darts, and get 20 now", "arrows+plus", {"max_arrows": 30}, [t("take", "arrows", {"n": 20})]),
		a("cheap_darts", "Cheap Darts", "35% of shots use no dart", "arrows+clock", {"arrow_save": 0.35})],
	], "specs": [
		_spec("apothecary", "Apothecary", "Keeps everyone on their feet", Color(0.3, 0.56, 0.36),
			a("apothecary", "Apothecary", "Unlocks Healing Tonic: heal 30, and friends near you 25", "potion+heart", {}),
			[[a("strong_tonic", "Strong Tonic", "The Tonic heals 15 more", "potion+up", {}, [], "strong_tonic"),
			a("quick_brew", "Quick Brew", "The Tonic comes back 30% sooner", "potion+clock", {"art_cd": -0.3})],
			[a("bedside", "Bedside Manner", "Heal 1 health per second", "heart+clock", {"regen": 1.0}),
			a("field_medic", "Field Medic", "+40 max health", "cross+up", {"max_hp": 40.0})],
			[a("antidote", "Antidote", "Poison and bleeding do nothing to you", "drop+shield", {}, [], "antidote"),
			a("salts", "Smelling Salts", "Every 15 s, stun enemies within 5 m", "star+potion", {}, [t("every", "stun_around", {"secs_every": 15.0, "r": 5.0, "secs": 1.0})])],
			[a("last_rites", "Last Rites", "Heal 4 per kill", "cross+skull", {}, [t("kill", "heal", {"n": 4.0})]),
			a("sanitize", "Sanitize", "Every 8 s, burn enemies within 4.5 m", "flame+cross", {}, [t("every", "burn_around", {"secs_every": 8.0, "r": 4.5})])]],
			a("miracle_cure", "Miracle Cure", "The Tonic also makes you and those friends untouchable for 2 s", "potion+crown", {}, [], "miracle_cure")),
		_spec("pestilence", "Pestilence", "Everything you touch gets sick", Color(0.44, 0.56, 0.14),
			a("pestilence", "Pestilence", "Every hit, near or far, poisons for 10 per second, 4 s", "poison+skull", {}, [t("hit", "dot", {"dps": 10.0, "secs": 4.0}), t("shot", "dot", {"dps": 10.0, "secs": 4.0})]),
			[[a("virulence", "Virulence", "Poison does 18 per second, for 5 s", "poison+star", {}, [t("hit", "dot", {"dps": 18.0, "secs": 5.0}), t("shot", "dot", {"dps": 18.0, "secs": 5.0})]),
			a("rotting", "Rotting Touch", "Darts mark enemies: +25% damage for 4 s", "target+poison", {}, [t("shot", "mark", {"mult": 1.25, "secs": 4.0})])],
			[a("miasma", "Miasma", "Every 4 s, you leave a pool of poison behind you", "wind+poison", {}, [t("every", "miasma", {"secs_every": 4.0})]),
			a("contagion", "Contagious Darts", "Darts pass through 1 enemy", "arrow+poison", {"pierce": 1})],
			[a("sickly_air", "Sickly Air", "Every 8 s, slow enemies within 5 m", "wind+skull", {}, [t("every", "slow_around", {"secs_every": 8.0, "r": 5.0, "secs": 3.0})]),
			a("feed", "Feed on Sickness", "Heal 3 per kill", "heart+poison", {}, [t("kill", "heal", {"n": 3.0})])],
			[a("plague_bearer", "Plague Bearer", "Poisoned enemies leave a pool of poison when they die", "skull+drop", {}, [], "plague_burst"),
			a("dose", "The Right Dose", "+30% ranged damage", "drop+up", {"ranged_damage": 0.3})]],
			a("black_death", "Black Death", "When a poisoned enemy dies, everything within 6 m is poisoned", "skull+crown", {}, [], "black_death")),
		_spec("rat_king", "Rat King", "They come when you whistle", Color(0.38, 0.32, 0.28),
			a("rat_king", "Rat King", "Every 18 s, 2 rats come to fight for you for 14 s", "tooth+plus", {"ally_cap": 3}, [t("every", "summon", {"secs_every": 18.0, "kind": "rat", "n": 2, "secs": 14.0})]),
			[[a("litter", "Big Litter", "One more rat each time", "tooth+up", {"summon_extra": 1}),
			a("fat_rats", "Fat Rats", "Rats have 60% more health", "tooth+heart", {"ally_hp": 0.6})],
			[a("sharp_teeth", "Sharp Teeth", "Rats do 40% more damage", "tooth+star", {"ally_damage": 0.4}),
			a("long_lived", "Long Lived", "Rats stay 50% longer", "tooth+clock", {"ally_time": 0.5})],
			[a("fleas", "Fleas", "Heal 5 whenever a rat kills", "heart+tooth", {}, [], "bond"),
			a("filth", "Filth", "Half of all rat bites poison", "drop+tooth", {}, [], "rat_poison")],
			[a("scurry", "Scurry", "+15% move speed", "boot+tooth", {"speed": 0.15}),
			a("vermin_cloak", "Vermin Cloak", "Take 15% less damage", "shield+tooth", {"damage_taken": -0.15})]],
			a("the_swarm", "The Swarm", "Every 30 s, 5 more rats pour out for 10 s", "tooth+crown", {"ally_cap": 5}, [t("every", "summon", {"secs_every": 30.0, "kind": "rat", "n": 5, "secs": 10.0})])),
	]}


static func _revenant() -> Dictionary:
	var teal := Color(0.16, 0.48, 0.5)
	return {"core": [
		[a("cold_hands", "Cold Hands", "+25% claw damage", "claw+up", {"melee_damage": 0.25}),
		a("long_claws", "Long Claws", "+1 m reach, and claws hit one more", "claw+plus", {"melee_reach": 1.0, "melee_hits": 1})],
		[a("thick_mist", "Thick Mist", "+40 max Mist, and quieter steps", "mist+plus", {"mana": 40.0, "noise": -0.25}),
		a("deep_breath", "Deep Breath", "Mist refills 60% faster", "mist+clock", {"mana_regen": 0.3})],
		[a("hungry_dead", "Hungry Dead", "Kills give 4 more Mist, and heal 2", "skull+mist", {}, [t("kill", "mana", {"n": 4.0}), t("kill", "heal", {"n": 2.0})]),
		a("restless", "Restless", "+15% move speed", "boot+mist", {"speed": 0.15})],
	], "specs": [
		_spec("leaper", "Mist Leaper", "Crosses the map in bounds.", teal,
			a("mist_leaper", "Mist Leaper", "Unlocks Mist Leap: bound 9 m forward, untouchable in the air", "leap+mist", {}, [], "art_leaper"),
			[[a("long_stride", "Long Stride", "Leap 4 m further", "leap+up", {"leap_range": 4.0}),
			a("quick_hop", "Quick Hop", "Leap comes back 40% sooner", "leap+clock", {"art_cd": -0.4})],
			[a("hard_landing", "Hard Landing", "Landing deals 40 damage around you", "quake+leap", {"leap_damage": 40.0}),
			a("soft_landing", "Soft Landing", "Take 20% less damage", "mist+shield", {"damage_taken": -0.2})],
			[a("light_feet", "Light Feet", "Leap comes back 25% sooner, and costs 20% less Mist", "boot+clock", {"art_cd": -0.25, "art_cost": -0.2}),
			a("thin_air", "Thin Air", "Leap costs 40% less Mist", "wind+leap", {"art_cost": -0.4})],
			[a("stunning_fall", "Stunning Fall", "Landing stuns what is close", "star+leap", {}, [], "leap_stun"),
			a("after_image", "After Image", "Zombies see you 30% less far", "ghost+eye_closed", {"sight": -0.3})]],
			a("sky_rend", "Sky Rend", "Landing freezes everything close, and deals 40 more", "snow+leap", {"leap_damage": 40.0}, [], "leap_freeze")),
		_spec("rift", "Rift Traveller", "Hops between enemies, untouchable.", teal,
			a("rift_traveller", "Rift Traveller", "Unlocks Rift Jump: hop between 3 enemies, untouchable, dealing 40 to each", "rift+mist", {}, [], "art_rift"),
			[[a("long_chain", "Long Chain", "One more hop", "chain+rift", {"rift_hops": 1.0}),
			a("rift_scar", "Rift Scar", "+10 damage per hop, and ready 20% sooner", "rift+up", {"rift_damage": 10.0, "art_cd": -0.2})],
			[a("cutting", "Cutting Through", "+20 damage per hop", "claw+rift", {"rift_damage": 20.0}),
			a("gone_again", "Gone Again", "Zombies see you 30% less far", "mist+eye_closed", {"sight": -0.3})],
			[a("mist_thief", "Mist Thief", "Each hop gives 6 Mist", "mist+rift", {}, [], "rift_mist"),
			a("cheap_passage", "Cheap Passage", "Rift Jump costs 35% less Mist", "rift+clock", {"art_cost": -0.35})],
			[a("wide_chain", "Wide Chain", "One more hop, ready 20% sooner, and 20% less Mist", "spiral+rift", {"rift_hops": 1.0, "art_cost": -0.2, "art_cd": -0.2}),
			a("cold_way", "Cold Way", "Heal 1 health per second", "heart+rift", {"regen": 1.0})]],
			a("between_worlds", "Between Worlds", "3 more hops, and each one leaves the enemy frozen", "snow+rift", {"rift_hops": 3.0}, [], "rift_freeze")),
		_spec("summoner", "Summoner", "Calls other Revenants out of the mist.", teal,
			a("summoner_entry", "Summoner", "Unlocks Call Revenant: another Revenant fights by your side for 10 s", "ghost+mist", {}, [], "art_summoner"),
			[[a("long_stay", "Long Stay", "Revenants stay 5 s longer", "ghost+clock", {"summon_time": 5.0}),
			a("quick_call", "Quick Call", "Call comes back 20% sooner", "horn+up", {"art_cd": -0.2})],
			[a("two_from_mist", "Two from the Mist", "Call one more", "ghost+plus", {"summon_n": 1.0}),
			a("strong_call", "Strong Call", "Revenants hit 35% harder", "ghost+up", {"ally_damage": 0.35})],
			[a("dead_claws", "Claws of the Dead", "Revenants hit 20% harder and have 20% more health", "claw+ghost", {"ally_damage": 0.2, "ally_hp": 0.2}),
			a("thick_ghosts", "Thick Ghosts", "Revenants have 50% more health", "ghost+heart", {"ally_hp": 0.5})],
			[a("swift_call", "Swift Call", "Call comes back 25% sooner", "horn+clock", {"art_cd": -0.25}),
			a("cheap_call", "Cheap Call", "Call costs 30% less Mist", "mist+ghost", {"art_cost": -0.3})]],
			a("the_host", "The Host", "Each Revenant lets go a weak Mist Burst when it falls, and stays 2 s longer", "burst+ghost", {"summon_time": 2.0}, [], "host_burst")),
	]}


## One weapon at a time, and everything else is built. Each path adds something to make, and the tree
## improves it. The Inventor's steps mostly add new devices to the bag, or improve ones already in it.
static func _artificer() -> Dictionary:
	var copper := Color(0.62, 0.34, 0.16)
	var iron := Color(0.34, 0.38, 0.44)
	var brass := Color(0.6, 0.48, 0.14)
	return {"core": [
		[a("steady_hands", "Steady Hands", "+30% damage with any weapon", "hand+up", {"melee_damage": 0.3, "ranged_damage": 0.3}),
		a("greased_boots", "Greased Boots", "+18% move speed", "boot+up", {"speed": 0.18})],
		[a("leather_apron", "Leather Apron", "+40 max health", "heart+plus", {"max_hp": 40.0}),
		a("soot_and_ash", "Soot and Ash", "Fire cannot set you alight, and +15 max health", "flame+shield_round", {"max_hp": 15.0}, [], "fire_proof")],
		[a("scavenger", "Scavenger", "Heal 5 per kill", "drop+heart", {}, [t("kill", "heal", {"n": 5.0})]),
		a("quick_fingers", "Quick Fingers", "+30% attack speed with any weapon", "hand+clock", {"melee_rate": 0.3, "ranged_rate": 0.3})],
	], "specs": [
		_spec("pyromaniac", "Pyromaniac", "Throws bombs that leave the ground burning.", copper,
			a("pyromaniac", "Pyromaniac", "Unlocks Incendiary Bomb: throw a bomb that bursts into flame and sets the ground alight", "bomb+flame"),
			[[a("bigger_charge", "Bigger Charge", "Bombs reach 2 m further", "bomb+up", {"bomb_radius": 2.0}),
			a("pitch_mix", "Pitch Mix", "The ground burns 4 s longer", "flame+clock", {"bomb_fire": 4.0})],
			[a("quick_fuse", "Quick Fuse", "The next bomb is ready 25% sooner", "bomb+clock", {"art_cd": -0.25}),
			a("heavy_powder", "Heavy Powder", "+50 bomb damage", "bomb+plus", {"bomb_damage": 50.0})],
			[a("two_in_hand", "Two in Hand", "Throw two bombs at once", "bomb+swap", {"bomb_count": 1.0}),
			a("shrapnel", "Shrapnel", "Bombs stun what they hit for 1.5 s", "star+flame", {}, [], "bomb_stun")],
			[a("white_fire", "White Fire", "Burning enemies take 60% more", "flame+up", {"burn_damage": 0.6}),
			a("blast_shield", "Blast Shield", "Take 30% less damage for 3 s after a throw", "shield_round+flame", {}, [t("throw", "buff", {"stat": "damage_taken", "val": -0.3, "secs": 3.0, "key": "blast_shield"})])]],
			a("chaotic", "Chaotic", "Every bomb throws off 6 bomblets that bounce away at random, each with its own effect: fire, frost, thunder or poison", "spiral+flame", {}, [], "chaotic")),
		_spec("mechanic", "Mechanic", "Rolls a slow, deadly war chariot, with room for a friend.", iron,
			a("mechanic", "Mechanic", "6 kills build the War Chariot: it crawls, takes half of each hit off you, crushes what it rolls over, and seats a friend", "chariot+plus", {"riding_armor": -0.5, "horse_kills": -4}),
			[[a("mounted_ballista", "Mounted Ballista", "A turret on the chariot shoots the nearest enemy", "turret+plus", {}, [], "chariot_turret"),
			a("scythed_wheels", "Scythed Wheels", "Spikes on the wheels cut whatever comes close", "spikes+plus", {}, [], "chariot_spikes")],
			[a("iron_plates", "Iron Plates", "The chariot takes 20% more of each hit", "shield_rect+chariot", {"riding_armor": -0.2}),
			a("repair_kit", "Repair Kit", "Heal 6 health a second while riding", "heart+chariot", {"riding_regen": 6.0})],
			[a("twin_bolts", "Twin Mechanisms", "Turret and spikes work twice as fast", "turret+up", {"turret_rate": 1.0}),
			a("long_haul", "Long Haul", "The chariot lasts 20 s longer", "chariot+clock", {"horse_time": 20.0})],
			[a("caltrops", "Caltrops", "Drops a trap behind the chariot every 4 s", "trap+chariot", {}, [t("every", "trap", {"secs_every": 4.0, "riding": true})]),
			a("better_axles", "Better Axles", "The chariot is 30% faster, and tramples twice as hard", "chariot+up", {"horse_speed": 0.3, "trample": 1.0})]],
			a("war_machine", "War Machine", "Both turret and spikes. Bolts burst into flame, and the chariot lasts 15 s longer", "turret+flame", {"horse_time": 15.0}, [], "war_machine")),
		_spec("inventor", "Inventor", "A different device every time, and the button shows which is next.", brass,
			a("inventor", "Inventor", "Unlocks Invention: a random device each use, and the button shows the next one. Starts with Electric Volley and Cryo Flask", "gear+star"),
			[[a("sentry_plans", "Clockwork Sentry", "New invention: a turret that shoots for 14 s", "turret+gear", {}, [], "inv_sentry"),
			a("overcharge", "Overcharge", "Electric Volley: 3 more darts, and each spark jumps twice more", "dart+up", {"volley_darts": 3.0, "volley_jumps": 2.0})],
			[a("boots_plans", "Steam Boots", "New invention: a burst of speed, untouchable for 2 s", "steam+plus", {}, [], "inv_boots"),
			a("deep_freeze", "Deep Freeze", "Cryo Flask: freezes 1.5 s longer and reaches 2 m further", "flask+up", {"flask_time": 1.5, "flask_radius": 2.0})],
			[a("noise_plans", "Noise Box", "New invention: draws everything close to it, then bursts", "noisebox+plus", {}, [], "inv_noise"),
			a("better_bench", "Better Workbench", "Invention is ready 30% sooner", "gear+clock", {"art_cd": -0.3})],
			[a("magnet_plans", "Lodestone", "New invention: drags enemies together and holds them for 3 s", "magnet+plus", {}, [], "inv_magnet"),
			a("fine_gears", "Fine Gears", "Inventions do 50% more damage, and each one heals you 10", "gear+up", {"inv_damage": 0.5, "inv_heal": 10.0})]],
			a("eureka", "Eureka!", "Every invention goes off twice", "bolt+gear", {}, [], "eureka")),
	]}


static func _infantry() -> Dictionary:
	return {"core": [
		[a("keen_edge", "Heavy Hand", "+40% melee damage, but swings 10% slower", "sword+up", {"melee_damage": 0.4, "melee_rate": -0.1}),
		a("quick_hands", "Quick Hands", "+35% melee speed, but 10% less damage", "hand+clock", {"melee_rate": 0.35, "melee_damage": -0.1})],
		[a("sprinter", "Sprinter", "+20% move speed, but 15 less health", "boot+up", {"speed": 0.2, "max_hp": -15.0}),
		a("thick_skin", "Thick Skin", "+40 max health, but 8% slower", "heart+plus", {"max_hp": 40.0, "speed": -0.08})],
		[a("bloodlust", "Bloodlust", "Heal 5 per kill", "drop+heart", {}, [t("kill", "heal", {"n": 5.0})]),
		a("whirl", "Whirl", "Wide swings that hit 3 more", "spiral+sword", {"melee_cone": 60.0, "melee_hits": 3})],
	], "specs": [
		_spec("duelist", "Duelist", "Precise strikes and perfect defence", Color(0.2, 0.42, 0.72),
			a("duelist", "Duelist", "20% crit chance, and crits do double", "sword+star", {"crit_chance": 0.2}),
			[[a("footwork", "Footwork", "Each hit: +25% speed for 2 s", "boot+wind", {}, [t("hit", "buff", {"stat": "speed", "val": 0.25, "secs": 2.0, "key": "footwork"})]),
			a("measure", "Measure", "+1 m melee reach", "target+up", {"melee_reach": 1.0})],
			[a("bleeding_cut", "Bleeding Cut", "Hits bleed for 12 per second, 3 s", "drop+dagger", {}, [t("hit", "dot", {"dps": 12.0, "secs": 3.0, "bleed": true})]),
			a("feint", "Feint", "Crits stun for 1.2 s", "mask+star", {}, [t("crit", "stun", {"secs": 1.2})])],
			[a("parry", "Parry Stance", "30% chance to avoid any hit", "shield_round+sword", {"dodge": 0.3}),
			a("counterstroke", "Counterstroke", "When hit: +70% damage for 3 s", "swap+sword", {}, [t("hurt", "buff", {"stat": "melee_damage", "val": 0.7, "secs": 3.0, "key": "counter"})])],
			[a("blade_dance", "Blade Dance", "+25% crit chance", "star+sword", {"crit_chance": 0.25}),
			a("coup_de_grace", "Coup de Grace", "Melee kills enemies under 30% health", "skull+dagger", {}, [], "execution")]],
			a("perfect_riposte", "Perfect Riposte", "Every 8 s, the next blow is blocked and stuns all around you", "shield_round+crown", {}, [], "perfect_riposte")),
		_spec("berserker", "Berserker", "Pain becomes power", Color(0.68, 0.14, 0.1),
			a("berserker", "Berserker", "Up to +60% damage as your health falls", "axe+drop", {}, [], "rage"),
			[[a("thirst", "Thirst", "Heal 7 per kill", "drop+plus", {}, [t("kill", "heal", {"n": 7.0})]),
			a("thick_blood", "Thick Blood", "+60 max health", "heart+drop", {"max_hp": 60.0})],
			[a("savage", "Savage", "+45% melee damage, but take 20% more", "claw+up", {"melee_damage": 0.45, "damage_taken": 0.2}),
			a("reckless", "Reckless Swing", "Much wider swings that hit 4 more", "axe+spiral", {"melee_cone": 80.0, "melee_hits": 4})],
			[a("frenzy", "Frenzy", "Kills: +12% attack speed for 6 s, up to 5", "flame+wind", {}, [t("kill", "buff", {"stat": "melee_rate", "val": 0.12, "secs": 6.0, "max": 5, "key": "frenzy"})]),
			a("undying", "Undying", "Under 30% health: heal 50, once per 30 s", "cross+heart", {}, [t("low", "heal", {"n": 50.0, "cd": 30.0})])],
			[a("cleaver", "Cleaver", "Every 4th hit makes a small blast", "axe+flame", {}, [t("hit", "blast", {"nth": 4, "r": 3.2, "dmg": 45.0})]),
			a("war_cry", "War Cry", "Every 15 s, stun everything near you", "shout+up", {}, [t("every", "stun_around", {"secs_every": 15.0, "r": 7.0, "secs": 1.2, "sound": "attack"})])]],
			a("blood_frenzy", "Blood Frenzy", "Under 50% health: +50% attack speed and heal from every hit", "drop+crown", {}, [], "blood_frenzy")),
		_spec("shadow", "Shadow Blade", "Kill before they know you are there", Color(0.3, 0.2, 0.5),
			a("shadow", "Shadow Blade", "+80% damage on unaware enemies or from behind, 30% less noise", "dagger+eye_closed", {"backstab": 0.8, "noise": -0.3}),
			[[a("soft_steps", "Soft Steps", "Almost silent: 50% less noise", "boot+eye_closed", {"noise": -0.5}),
			a("cloak", "Cloak", "Zombies see you 40% less far", "mask+eye_closed", {"sight": -0.4})],
			[a("venom_blade", "Venom Blade", "Hits poison for 14 per second, 4 s", "poison+dagger", {}, [t("hit", "dot", {"dps": 14.0, "secs": 4.0})]),
			a("ambush", "Ambush", "+70% more backstab damage", "eye_closed+dagger", {"backstab": 0.7})],
			[a("smoke", "Smoke", "When hit: vanish for 3 s, every 20 s", "wind+eye_closed", {}, [t("hurt", "invis", {"secs": 3.0, "cd": 20.0})]),
			a("slip_away", "Slip Away", "+20% move speed", "wind+boot", {"speed": 0.2})],
			[a("throat_cut", "Throat Cut", "Backstabs stun for 1.5 s", "dagger+tooth", {}, [t("backstab", "stun", {"secs": 1.5})]),
			a("vanish", "Vanish", "Kills have a 25% chance to hide you for 3 s", "moon+skull", {}, [t("kill", "invis", {"chance": 0.25, "secs": 3.0})])]],
			a("death_dark", "Death from the Dark", "Unaware enemies die in one hit, and those kills hide you for 3 s", "skull+crown", {}, [], "assassin")),
	]}


static func _ranger() -> Dictionary:
	return {"core": [
		[a("steady_aim", "Steady Aim", "+35% arrow damage, but 10% slower shots", "arrow+up", {"ranged_damage": 0.35, "ranged_rate": -0.1}),
		a("quick_draw", "Quick Draw", "+35% firing speed, but 10% less damage", "bow+clock", {"ranged_rate": 0.35, "ranged_damage": -0.1})],
		[a("deep_quiver", "Deep Quiver", "Carry 30 more arrows, get 20 now, and 25% of shots use none", "arrows+plus", {"max_arrows": 30, "arrow_save": 0.25}, [t("take", "arrows", {"n": 20})]),
		a("light_feet", "Light Feet", "+18% move speed", "boot+feather", {"speed": 0.18})],
		[a("piercing", "Piercing", "Arrows pass through 2 enemies", "arrow+plus", {"pierce": 2}),
		a("twin_shot", "Twin Shot", "Each shot fires a second arrow", "arrows+star", {}, [], "twin_shot")],
	], "specs": [
		_spec("sharpshooter", "Sharpshooter", "One arrow, one kill", Color(0.18, 0.46, 0.34),
			a("sharpshooter", "Sharpshooter", "Headshots do double damage, +15% crit", "target+arrow", {"crit_chance": 0.15}, [], "sharpshooter"),
			[[a("eagle_eye", "Eagle Eye", "+50% arrow range and speed", "eye+up", {"ranged_power": 0.5}),
			a("still_aim", "Still Aim", "+50% ranged damage while standing still", "target+clock", {}, [], "still_aim")],
			[a("stopping_power", "Stopping Power", "Arrows have a 40% chance to stun for 0.8 s", "arrow+star", {}, [t("shot", "stun", {"chance": 0.4, "secs": 0.8})]),
			a("marked", "Marked Prey", "Arrows mark enemies: +35% damage for 4 s", "target+eye", {}, [t("shot", "mark", {"mult": 1.35, "secs": 4.0})])],
			[a("ricochet", "Ricochet", "Arrows bounce to 2 more enemies", "swap+arrow", {"bounces": 2}),
			a("overdraw", "Overdraw", "Every 3rd arrow does double damage", "bow+up", {}, [], "overdraw")],
			[a("deadeye", "Deadeye", "Crits do triple damage", "skull+target", {"crit_mult": 1.0}),
			a("long_breath", "Long Breath", "+25% crit chance", "wind+star", {"crit_chance": 0.25})]],
			a("killing_shot", "Killing Shot", "Every 6 s, your next arrow does 300 damage", "arrow+crown", {}, [], "killing_shot")),
		_spec("trapper", "Trapper", "The field itself fights for you", Color(0.5, 0.36, 0.14),
			a("trapper", "Trapper", "Every 10 s a trap drops at your feet: 70 damage and a 2 s stun", "trap+plus", {"trap_damage": 20.0}, [t("every", "trap", {"secs_every": 10.0})]),
			[[a("barbed", "Barbed Traps", "Traps bleed 16 per second for 4 s", "trap+drop", {}, [], "trap_bleed"),
			a("burning_tar", "Burning Tar", "Traps set enemies on fire", "trap+flame", {}, [], "trap_fire")],
			[a("spare_parts", "Spare Parts", "Keep 3 more traps on the ground", "trap+up", {"trap_cap": 3}),
			a("quick_setup", "Quick Setup", "Traps come 4 s sooner", "trap+clock", {"trap_cd": -4.0})],
			[a("snare_net", "Snare Net", "Traps hold enemies 2 s longer", "net+trap", {"trap_stun": 2.0}),
			a("powder_keg", "Powder Keg", "Traps also explode in a blast", "flame+trap", {}, [], "trap_blast")],
			[a("lure", "Lure", "Every trap also pulls roaming zombies to it", "horn+trap", {}, [], "trap_lure"),
			a("ghillie", "Ghillie Suit", "Zombies see you 40% less far", "mask+feather", {"sight": -0.4})]],
			a("field_snares", "Field of Snares", "Up to 8 traps, and each trap kill drops a new one", "net+crown", {"trap_cap": 5}, [], "field_snares")),
		_spec("beastmaster", "Beastmaster", "You never hunt alone", Color(0.34, 0.5, 0.2),
			a("beastmaster", "Beastmaster", "Your beast fights beside you, and returns 15 s after falling. Choose it in the Armory", "wolf+plus", {"wolves": 1}),
			[[a("alpha", "Alpha", "Allies do 30% more damage", "wolf+up", {"ally_damage": 0.3}),
			a("thick_fur", "Thick Fur", "Allies have 75% more health", "wolf+heart", {"ally_hp": 0.75})],
			[a("savage_bite", "Savage Bite", "Your beast's bites stun for 0.7 s", "tooth+star", {}, [], "wolf_stun"),
			a("scent", "Scent", "Enemies within 15 m are always marked", "wolf+eye", {}, [], "scent")],
			[a("second_wolf", "Second Beast", "One more beast at your side", "wolf+star", {"wolves": 1}),
			a("hawk", "Hunting Hawk", "Every 2.5 s a hawk strikes a nearby enemy", "feather+arrow", {}, [t("every", "hawk", {"secs_every": 2.5})])],
			[a("pack_tactics", "Pack Tactics", "+30% damage to enemies near your allies", "claw+plus", {}, [], "pack_tactics"),
			a("bond", "Blood Bond", "Heal 5 whenever one of your allies kills", "heart+wolf", {}, [], "bond")]],
			a("wolf_pack", "The Pack", "4 beasts, and a howl every 20 s stuns all around you", "moon+crown", {"wolves": 3}, [t("every", "stun_around", {"secs_every": 20.0, "r": 9.0, "secs": 1.2, "sound": "howl"})])),
	]}


static func _heavy() -> Dictionary:
	return {"core": [
		[a("banded", "Banded Shield", "Iron bands: blocks 25% more", "shield_round+up", {"shield": 0.25}, [t("take", "shield_up")]),
		a("heavy_swing", "Heavy Swing", "+35% melee damage", "mace+up", {"melee_damage": 0.35})],
		[a("thick_hide", "Thick Hide", "+45 max health", "heart+shield", {"max_hp": 45.0}),
		a("shockwave", "Shockwave", "Double knockback, and 20% chance to stun", "quake+mace", {"knock": 1.0}, [t("hit", "stun", {"chance": 0.2, "secs": 1.0})])],
		[a("thorns", "Thorns", "Melee attackers take 20 damage", "claw+shield", {"thorns": 20.0}),
		a("second_wind", "Second Wind", "Heal 5 per kill", "wind+heart", {}, [t("kill", "heal", {"n": 5.0})])],
	], "specs": [
		_spec("guardian", "Guardian", "Stands between the others and the dark", Color(0.34, 0.38, 0.46),
			a("guardian", "Guardian", "Iron shield, and Shield Dome: nobody inside can be hurt for 3 s. Friends near you take 25% less, and you bear part of it", "shield_rect+up", {"shield": 0.2, "cover": 0.25, "cover_radius": 8.0}, [t("take", "shield_max")]),
			[[a("take_the_blow", "Take the Blow", "Friends near you take 20% less, and get back up twice as fast", "shield_rect+heart", {"cover": 0.2}, [], "rescuer"),
			a("second_skin", "Second Skin", "+60 max health", "helm+heart", {"max_hp": 60.0})],
			[a("long_dome", "Long Dome", "The dome lasts 3 s longer", "shield_rect+clock", {"dome_time": 3.0}),
			a("wide_dome", "Wide Dome", "The dome reaches 4 m further", "shield_rect+plus", {"dome_radius": 4.0})],
			[a("challenge", "Challenge", "Raising the dome draws every enemy around to you", "shout+shield", {}, [], "dome_taunt"),
			a("hold_line", "Hold the Line", "Take 25% less damage, but 5% slower", "banner+helm", {"damage_taken": -0.25, "speed": -0.05})],
			[a("block_stuns", "Crushing Block", "Blocking stuns the attacker for 0.8 s", "shield+star", {}, [t("block", "stun_attacker", {"secs": 0.8})]),
			a("block_heals", "Faith in Iron", "Blocking heals 4", "shield+heart", {}, [t("block", "heal", {"n": 4.0})])]],
			a("aegis", "Aegis", "The dome also heals everyone inside by 30, and comes back 25% sooner", "helm+crown", {"art_cd": -0.25}, [], "aegis")),
		_spec("warpriest", "Warpriest", "Holy fire and endless faith", Color(0.76, 0.6, 0.2),
			a("warpriest", "Warpriest", "Heal 1 health per second", "cross+heart", {"regen": 1.0}),
			[[a("blessing", "Blessing", "Heal 1 more per second", "sun+heart", {"regen": 1.0}),
			a("healing_hands", "Healing Hands", "Heal 3 per kill", "hand+heart", {}, [t("kill", "heal", {"n": 3.0})])],
			[a("holy_fire", "Holy Fire", "Melee sets enemies on fire", "flame+cross", {}, [t("hit", "ignite")]),
			a("smite", "Smite", "Every 5th hit calls lightning", "bolt+cross", {}, [t("hit", "thunder", {"nth": 5})])],
			[a("consecrate", "Consecrate", "Every 6 s, burn enemies within 4.5 m", "sun+flame", {}, [t("every", "burn_around", {"secs_every": 6.0, "r": 4.5})]),
			a("shield_faith", "Shield of Faith", "Under 30% health: no damage for 3 s, every 35 s", "shield+cross", {}, [t("low", "guard", {"secs": 3.0, "cd": 35.0})])],
			[a("prayer", "Prayer", "Every 30 s, an Angel joins you for 10 s", "wings+cross", {}, [t("every", "power", {"secs_every": 30.0, "id": "angel", "time": 10.0})]),
			a("zeal", "Zeal", "+30% melee speed", "cross+wind", {"melee_rate": 0.3})]],
			a("divine_wrath", "Divine Wrath", "Every 15 s, lightning strikes all enemies within 12 m", "bolt+crown", {}, [t("every", "thunder_all", {"secs_every": 15.0, "r": 12.0})])),
		_spec("warlord", "Warlord", "Break whole crowds at once", Color(0.56, 0.24, 0.14),
			a("warlord", "Warlord", "Swings are much wider and hit 2 more", "mace+spiral", {"melee_cone": 40.0, "melee_hits": 2, "knock": 0.5}),
			[[a("great_swing", "Great Swing", "+35% melee damage", "hammer+up", {"melee_damage": 0.35}),
			a("swift_arm", "Swift Arm", "+30% melee speed", "hammer+clock", {"melee_rate": 0.3})],
			[a("aftershock", "Aftershock", "Every 3rd hit makes a shockwave", "quake+plus", {}, [t("hit", "blast", {"nth": 3, "r": 3.2, "dmg": 35.0})]),
			a("stomp", "Stomp", "Every 10 s, slow all around you for 3 s", "boot+quake", {}, [t("every", "slow_around", {"secs_every": 10.0, "r": 6.0, "secs": 3.0})])],
			[a("war_horn", "War Horn", "Every 15 s, stun enemies within 6 m", "horn+up", {}, [t("every", "stun_around", {"secs_every": 15.0, "r": 6.0, "secs": 1.5, "sound": "hammer"})]),
			a("crush", "Crush", "30% chance to stun on hit", "hammer+star", {}, [t("hit", "stun", {"chance": 0.3, "secs": 1.0})])],
			[a("war_banner", "War Banner", "Every 30 s, a spirit soldier fights with you for 15 s", "banner+ghost", {}, [t("every", "summon", {"secs_every": 30.0, "kind": "ghost", "n": 1, "secs": 15.0})]),
			a("sunder", "Sunder", "Hits mark enemies: +30% damage for 4 s", "axe+target", {}, [t("hit", "mark", {"mult": 1.3, "secs": 4.0})])]],
			a("earthbreaker", "Earthbreaker", "Every 5th attack shakes the ground: 60 damage and stun in 7 m", "quake+crown", {}, [t("hit", "quake", {"nth": 5, "r": 7.0, "dmg": 60.0})])),
	]}


static func _chivalry() -> Dictionary:
	return {"core": [
		[a("lance_mastery", "Lance Mastery", "+30% melee damage", "lance+up", {"melee_damage": 0.3}),
		a("swift_steed", "Swift Steed", "+25% riding speed", "horse+wind", {"horse_speed": 0.25})],
		[a("stable_bond", "Stable Bond", "Horse needs 4 fewer kills", "horseshoe+skull", {"horse_kills": -4}),
		a("long_ride", "Long Ride", "+12 s of riding", "horseshoe+clock", {"horse_time": 12.0})],
		[a("couched", "Couched Lance", "Double melee damage while riding", "lance+horse", {}, [], "couched"),
		a("barding", "Armored Barding", "Take 40% less damage while riding", "horse+shield", {"riding_armor": -0.4})],
	], "specs": [
		_spec("lancer", "Lancer", "A charge nothing survives", Color(0.6, 0.16, 0.14),
			a("lancer", "Lancer", "+1 m lance reach, +30% melee damage while riding", "lance+star", {"melee_reach": 1.0, "riding_damage": 0.3}),
			[[a("spur", "Spur", "+20% riding speed", "horse+up", {"horse_speed": 0.2}),
			a("long_lance", "Long Lance", "+1 m melee reach", "lance+plus", {"melee_reach": 1.0})],
			[a("impale", "Impale", "Thrusts hit 3 more enemies", "lance+skull", {"melee_hits": 3}),
			a("joust", "Joust", "+35% crit chance while riding", "target+lance", {"riding_crit": 0.35})],
			[a("bowl_over", "Bowl Over", "Trampled enemies are stunned for 1.5 s", "horseshoe+star", {}, [t("trample", "stun", {"secs": 1.5})]),
			a("heavy_hooves", "Heavy Hooves", "Trample twice as hard", "horseshoe+up", {"trample": 1.0})],
			[a("charge", "Charge", "Mounting: +50% speed for 4 s", "wind+horse", {}, [t("mount", "buff", {"stat": "horse_speed", "val": 0.5, "secs": 4.0, "key": "charge"})]),
			a("run_down", "Run Them Down", "Riding kills normal zombies outright, and each kill adds 1 s", "skull+horse", {}, [], "war_horse")]],
			a("unstoppable", "Unstoppable Charge", "While riding you take no damage, and trampling kills anything but Beasts", "horse+crown", {}, [], "unstoppable")),
		_spec("paladin", "Paladin", "A holy knight who keeps riding", Color(0.8, 0.66, 0.26),
			a("paladin", "Paladin", "Heal 10 on mounting, and 0.5 per second while riding", "sun+horse", {"riding_regen": 0.5}, [t("mount", "heal", {"n": 10.0})]),
			[[a("lay_hands", "Lay on Hands", "Heal 2 per kill", "hand+cross", {}, [t("kill", "heal", {"n": 2.0})]),
			a("holy_armor", "Holy Armor", "Take 15% less damage", "helm+cross", {"damage_taken": -0.15})],
			[a("smite_undead", "Smite the Undead", "Melee sets enemies on fire", "flame+lance", {}, [t("hit", "ignite")]),
			a("aura", "Aura of Dread", "Every 8 s, slow enemies within 6 m", "sun+skull", {}, [t("every", "slow_around", {"secs_every": 8.0, "r": 6.0, "secs": 3.0})])],
			[a("blessed_rally", "Blessed Rally", "Mounting and dismounting stun all around you", "horn+cross", {}, [t("mount", "stun_around", {"r": 7.0, "secs": 1.5}), t("dismount", "stun_around", {"r": 7.0, "secs": 1.5})]),
			a("flaming_trail", "Flaming Trail", "While riding, you leave burning ground", "flame+horseshoe", {}, [t("every", "poison", {"secs_every": 0.7, "riding": true})])],
			[a("spirit_knight", "Spirit Knight", "Under 30% health: a spirit knight fights for you, every 45 s", "ghost+cross", {}, [t("low", "summon", {"kind": "ghost", "n": 1, "secs": 15.0, "cd": 45.0})]),
			a("endurance", "Endurance", "+12 s of riding", "horse+clock", {"horse_time": 12.0})]],
			a("sacred_steed", "Sacred Steed", "The horse comes 60 s after your last ride, without kills, and heals 2 per second", "sun+crown", {"riding_regen": 2.0}, [], "sacred_steed")),
		_spec("horse_archer", "Horse Archer", "Strike from the saddle and be gone", Color(0.22, 0.46, 0.3),
			a("horse_archer", "Horse Archer", "Unlocks ranged weapons: a Short Bow, 30 arrows, an arrow back per kill, and +20% ranged damage while riding", "bow+horse", {"riding_ranged": 0.2}, [t("take", "arrows", {"n": 30}), t("take", "weapon", {"id": "bow"}), t("kill", "arrows", {"n": 1})], "ranged_ok"),
			[[a("swift_quiver", "Swift Quiver", "+25% firing speed", "arrows+clock", {"ranged_rate": 0.25}),
			a("saddle_bags", "Saddle Bags", "Carry 30 more arrows, and get 20 now", "arrows+horseshoe", {"max_arrows": 30}, [t("take", "arrows", {"n": 20})])],
			[a("mounted_aim", "Mounted Aim", "+50% ranged damage while riding", "target+horse", {"riding_ranged": 0.5}),
			a("dismounted", "Skirmisher", "+30% ranged damage", "bow+up", {"ranged_damage": 0.3})],
			[a("horse_pierce", "Piercing Bolts", "Arrows pass through 2 enemies", "arrow+horse", {"pierce": 2}),
			a("horse_twin", "Double Nock", "Each shot fires a second arrow", "arrows+star", {}, [], "twin_shot")],
			[a("fire_quiver", "Fire Quiver", "Arrows shot while riding set enemies on fire", "flame+arrow", {}, [], "riding_fire"),
			a("skip_shot", "Skip Shot", "Arrows bounce to 2 more enemies", "swap+horse", {"bounces": 2})]],
			a("parthian", "Parthian Volley", "While riding, every 3 s a volley of 5 arrows hits nearby enemies", "arrows+crown", {}, [t("every", "volley", {"secs_every": 3.0, "n": 5, "riding": true})])),
	]}


static func _magician() -> Dictionary:
	return {"core": [
		[a("deep_well", "Deep Well", "+60 max mana", "orb+plus", {"mana": 60.0}),
		a("flow", "Flow", "Mana refills 50% faster", "drop+clock", {"mana_regen": 0.5})],
		[a("arcane_focus", "Arcane Focus", "+30% spell damage, but bolts cost 15% more", "staff+up", {"spell_damage": 0.3, "spell_cost": 0.15}),
		a("quick_cast", "Quick Cast", "+30% casting speed", "staff+clock", {"spell_rate": 0.3})],
		[a("mana_shield", "Mana Shield", "Half of the damage drains mana instead", "orb+shield", {}, [], "mana_shield"),
		a("blink_step", "Light Step", "+18% move speed", "blink+boot", {"speed": 0.18})],
	], "specs": [
		_spec("necromancer", "Necromancer", "The dead fight for you", Color(0.26, 0.42, 0.22),
			a("necromancer", "Necromancer", "Every 30 s, a skeleton fights for you for 20 s", "skull+plus", {}, [t("every", "summon", {"secs_every": 30.0, "kind": "skeleton", "n": 1, "secs": 20.0, "soon": true})]),
			[[a("bone_armor", "Bone Armor", "+20 health, and allies have 30% more", "bones+shield", {"max_hp": 20.0, "ally_hp": 0.3}),
			a("reanimate", "Reanimate", "15% of your kills rise as skeletons", "skull+up", {}, [t("kill", "raise", {"chance": 0.15, "secs": 12.0})])],
			[a("legion", "Bone Legion", "Skeletons come in pairs", "bones+plus", {"summon_extra": 1}),
			a("long_unlife", "Long Unlife", "Allies last 50% longer", "skull+clock", {"ally_time": 0.5})],
			[a("corpse_blast", "Corpse Blast", "Your fallen skeletons burst for a little damage", "flame+bones", {}, [], "corpse_blast"),
			a("dark_pact", "Dark Pact", "Allies do 25% more damage", "book+skull", {"ally_damage": 0.25})],
			[a("life_tap", "Life Tap", "Kills give 3 health and 5 mana", "drop+orb", {}, [t("kill", "heal", {"n": 3.0}), t("kill", "mana", {"n": 5.0})]),
			a("bone_cage", "Bone Cage", "Every 15 s, stun enemies within 5 m", "bones+net", {}, [t("every", "stun_around", {"secs_every": 15.0, "r": 5.0, "secs": 1.0})])]],
			a("army_dead", "Army of the Dead", "Every 35 s, 3 skeletons rise around you. Up to 6 allies", "bones+crown", {"ally_cap": 2}, [t("every", "summon", {"secs_every": 35.0, "kind": "skeleton", "n": 3, "secs": 20.0})])),
		_spec("elementalist", "Elementalist", "Fire, frost and storm", Color(0.2, 0.42, 0.74),
			a("elementalist", "Elementalist", "Bolts cycle through fire, frost and lightning", "flame+snow", {}, [], "elements"),
			[[a("scorch", "Scorch", "Burns do double damage", "flame+up", {"burn_damage": 1.0}),
			a("deep_freeze", "Deep Freeze", "Bolts have a 25% chance to freeze for 1 s", "snow+star", {}, [t("shot", "stun", {"chance": 0.25, "secs": 1.0})])],
			[a("meteor", "Meteor", "Every 4th bolt is a large blast", "orb+flame", {}, [], "meteor"),
			a("chain", "Chain Lightning", "All bolts jump to 2 more enemies", "bolt+chain", {"bounces": 2})],
			[a("surge", "Mana Surge", "Kills give 8 mana", "orb+skull", {}, [t("kill", "mana", {"n": 8.0})]),
			a("focus_lens", "Focus Lens", "Bolts cost 35% less", "eye+orb", {"spell_cost": -0.35})],
			[a("storm_caller", "Storm Caller", "Every 6 s, lightning strikes near you", "bolt+clock", {}, [t("every", "thunder", {"secs_every": 6.0})]),
			a("overload", "Overload", "+40% spell damage, but bolts cost 25% more", "bolt+up", {"spell_damage": 0.4, "spell_cost": 0.25})]],
			a("cataclysm", "Cataclysm", "Every 20 s, a firestorm hits all enemies within 18 m", "sun+crown", {}, [t("every", "cataclysm", {"secs_every": 20.0, "r": 18.0, "dmg": 70.0})])),
		_spec("illusionist", "Illusionist", "They never hit the real you", Color(0.5, 0.26, 0.62),
			a("illusionist", "Illusionist", "Unlocks Mirror Swap: vanish and reappear 9 m ahead. A decoy stays behind, draws enemies, then bursts", "mirror+blink", {}, [], "art_swap"),
			[[a("twin_decoy", "Twin Image", "Each swap leaves two decoys", "mirror+star", {"swap_decoys": 1.0}),
			a("long_step", "Long Step", "Swap reaches 6 m further", "blink+up", {"swap_range": 6.0})],
			[a("bigger_burst", "Bigger Burst", "Decoys burst for 60 more, and further", "flame+mirror", {"swap_burst": 60.0, "swap_radius": 1.5}),
			a("lasting_image", "Lasting Image", "Decoys last 3 s longer, and take twice as much to break", "mirror+clock", {"swap_decoy_time": 3.0, "ally_hp": 1.0})],
			[a("quick_mirror", "Quick Mirror", "Swap is ready 35% sooner", "mirror+wind", {"art_cd": -0.35}),
			a("fade", "Fade", "After a swap, nothing sees you for 2.5 s", "ghost+eye_closed", {}, [], "swap_fade")],
			[a("stunning_burst", "Stunning Burst", "Bursts stun what they hit for 1.5 s", "star+mirror", {}, [], "swap_stun"),
			a("dazzle", "Dazzle", "Each swap makes enemies within 10 m forget you", "star+spiral", {}, [], "swap_forget")]],
			a("mirror_legion", "Mirror Legion", "Each swap also calls 3 mirror images that cast bolts at enemies for 8 s", "mirror+crown", {"ally_cap": 3}, [], "swap_legion")),
	]}
