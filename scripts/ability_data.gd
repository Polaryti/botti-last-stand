class_name AbilityData
## Every class's tree: 4 shared tiers, then 1 of 3 specializations, then that branch to a final
## ability. "add" changes a stat, "on" reacts to events through Player._act, and "flag" switches
## on a rule coded elsewhere. Icons are "shape" or "shape+corner badge".

static var _cache := {}


static func a(id: String, name: String, desc: String, icon: String, add := {}, on := [], flag := "") -> Dictionary:
	return {"id": id, "name": name, "desc": desc, "icon": icon, "add": add, "on": on, "flag": flag}


static func t(when: String, action: String, params := {}) -> Dictionary:
	var d := {"when": when, "do": action}
	d.merge(params)
	return d


static func _spec(id: String, name: String, desc: String, color: Color, entry: Dictionary, choices: Array, mastery: Dictionary, final: Dictionary) -> Dictionary:
	var path: Array = []
	var rank := 1
	for i in choices.size():
		path.append(choices[i])
		path.append([_rank(mastery, rank)])
		rank += 1
	while rank <= 7:
		path.append([_rank(mastery, rank)])
		rank += 1
	final["final"] = true
	return {"id": id, "name": name, "desc": desc, "color": color, "entry": entry, "path": path, "final": final}


static func _rank(m: Dictionary, rank: int) -> Dictionary:
	var c := m.duplicate(true)
	c["id"] = "%s_%d" % [m["id"], rank]
	c["name"] = "%s %s" % [m["name"], ["I", "II", "III", "IV", "V", "VI", "VII"][rank - 1]]
	c["mastery"] = true
	return c


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
	return _cache[class_id]


## Unlike the others, each step here has one gift and it arrives by itself. Only the path is a choice.
static func _revenant() -> Dictionary:
	var teal := Color(0.16, 0.48, 0.5)
	return {"core": [
		[a("cold_hands", "Cold Hands", "+15% claw damage", "claw+up", {"melee_damage": 0.15})],
		[a("thick_mist", "Thick Mist", "+25 max Mist", "mist+plus", {"mana": 25.0})],
		[a("drifting", "Drifting", "+8% move speed, quieter steps", "wind+boot", {"speed": 0.08, "noise": -0.25})],
		[a("hungry_dead", "Hungry Dead", "Kills give 6 more Mist", "skull+mist", {}, [t("kill", "mana", {"n": 6.0})])],
	], "specs": [
		_spec("leaper", "Mist Leaper", "Crosses the map in bounds.", teal,
			a("mist_leaper", "Mist Leaper", "Unlocks Mist Leap: bound 9 m forward, untouchable in the air", "leap+mist", {}, [], "art_leaper"),
			[[a("long_stride", "Long Stride", "Leap 3 m further", "leap+up", {"leap_range": 3.0})],
			[a("hard_landing", "Hard Landing", "Landing deals 30 damage around you", "quake+leap", {"leap_damage": 30.0})],
			[a("light_feet", "Light Feet", "Leap comes back 20% sooner", "boot+clock", {"art_cd": -0.2})],
			[a("stunning_fall", "Stunning Fall", "Landing stuns what is close", "star+leap", {}, [], "leap_stun")],
			[a("thin_air", "Thin Air", "Leap costs 20% less Mist", "wind+mist", {"art_cost": -0.2})]],
			a("leaper_m", "Leaper Mastery", "Leap +0.5 m, claws +3%, Mist Burst +6 damage", "leap+crown", {"leap_range": 0.5, "melee_damage": 0.03, "burst_damage": 6.0}),
			a("sky_rend", "Sky Rend", "Landing freezes everything close, and deals 40 more", "snow+leap", {"leap_damage": 40.0}, [], "leap_freeze")),
		_spec("rift", "Rift Traveller", "Hops between enemies, untouchable.", teal,
			a("rift_traveller", "Rift Traveller", "Unlocks Rift Jump: hop between 3 enemies, untouchable, dealing 40 to each", "rift+mist", {}, [], "art_rift"),
			[[a("long_chain", "Long Chain", "One more hop", "chain+rift", {"rift_hops": 1.0})],
			[a("cutting", "Cutting Through", "+15 damage per hop", "claw+rift", {"rift_damage": 15.0})],
			[a("mist_thief", "Mist Thief", "Each hop gives 4 Mist", "mist+rift", {}, [], "rift_mist")],
			[a("swift_rift", "Swift Rift", "Rift Jump comes back 20% sooner", "rift+clock", {"art_cd": -0.2})],
			[a("wide_chain", "Wide Chain", "One more hop, and 20% less Mist", "spiral+rift", {"rift_hops": 1.0, "art_cost": -0.2})]],
			a("rift_m", "Rift Mastery", "+4 damage per hop, claws +3%, Mist Burst +6 damage", "rift+crown", {"rift_damage": 4.0, "melee_damage": 0.03, "burst_damage": 6.0}),
			a("between_worlds", "Between Worlds", "3 more hops, and each one leaves the enemy frozen", "snow+rift", {"rift_hops": 3.0}, [], "rift_freeze")),
		_spec("summoner", "Summoner", "Calls other Revenants out of the mist.", teal,
			a("summoner_entry", "Summoner", "Unlocks Call Revenant: another Revenant fights by your side for 10 s", "ghost+mist", {}, [], "art_summoner"),
			[[a("long_stay", "Long Stay", "Revenants stay 4 s longer", "ghost+clock", {"summon_time": 4.0})],
			[a("two_from_mist", "Two from the Mist", "Call one more", "ghost+plus", {"summon_n": 1.0})],
			[a("dead_claws", "Claws of the Dead", "Revenants hit 15% harder", "claw+ghost", {"ally_damage": 0.15})],
			[a("thick_shroud", "Thick Shroud", "Revenants have 20% more health", "heart+ghost", {"ally_hp": 0.2})],
			[a("swift_call", "Swift Call", "Call comes back 20% sooner", "horn+clock", {"art_cd": -0.2})]],
			a("summoner_m", "Summoner Mastery", "Revenants stay +0.5 s and hit +2%, claws +3%, Mist Burst +6 damage", "ghost+crown", {"summon_time": 0.5, "ally_damage": 0.02, "melee_damage": 0.03, "burst_damage": 6.0}),
			a("the_host", "The Host", "Each Revenant lets go a weak Mist Burst when it falls", "burst+ghost", {"summon_time": 2.0}, [], "host_burst")),
	]}


## One weapon at a time, and everything else is built. Each path adds something to make, and the tree
## improves it. The Inventor's steps mostly add new devices to the bag, or improve ones already in it.
static func _artificer() -> Dictionary:
	var copper := Color(0.62, 0.34, 0.16)
	var iron := Color(0.34, 0.38, 0.44)
	var brass := Color(0.6, 0.48, 0.14)
	return {"core": [
		[a("steady_hands", "Steady Hands", "+15% damage with any weapon", "hand+up", {"melee_damage": 0.15, "ranged_damage": 0.15}),
		a("greased_boots", "Greased Boots", "+10% move speed", "boot+up", {"speed": 0.1})],
		[a("leather_apron", "Leather Apron", "+20 max health", "heart+plus", {"max_hp": 20.0}),
		a("soot_and_ash", "Soot and Ash", "Fire cannot set you alight", "flame+shield_round", {}, [], "fire_proof")],
		[a("scavenger", "Scavenger", "Heal 2 per kill", "drop+heart", {}, [t("kill", "heal", {"n": 2.0})]),
		a("tool_belt", "Tool Belt", "Potions last 30% longer", "potion+clock", {"potion_time": 0.3})],
		[a("whetstone", "Whetstone", "+0.4 m melee reach", "spear+up", {"melee_reach": 0.4}),
		a("quick_fingers", "Quick Fingers", "+15% attack speed with any weapon", "hand+clock", {"melee_rate": 0.15, "ranged_rate": 0.15})],
	], "specs": [
		_spec("pyromaniac", "Pyromaniac", "Throws bombs that leave the ground burning.", copper,
			a("pyromaniac", "Pyromaniac", "Unlocks Incendiary Bomb: throw a bomb that bursts into flame and sets the ground alight", "bomb+flame"),
			[[a("bigger_charge", "Bigger Charge", "Bombs reach 1.5 m further", "bomb+up", {"bomb_radius": 1.5}),
			a("pitch_mix", "Pitch Mix", "The ground burns 3 s longer", "flame+clock", {"bomb_fire": 3.0})],
			[a("quick_fuse", "Quick Fuse", "The next bomb is ready 20% sooner", "bomb+clock", {"art_cd": -0.2}),
			a("heavy_powder", "Heavy Powder", "+40 bomb damage", "bomb+plus", {"bomb_damage": 40.0})],
			[a("two_in_hand", "Two in Hand", "Throw two bombs at once", "bomb+swap", {"bomb_count": 1.0}),
			a("shrapnel", "Shrapnel", "Bombs stun what they hit for 1 s", "star+flame", {}, [], "bomb_stun")],
			[a("long_arm", "Long Arm", "Throw 30% further", "hand+wind", {"bomb_throw": 0.3}),
			a("fire_feeds", "Fire Feeds Fire", "Each kill takes 0.5 s off the wait for the next bomb", "flame+skull", {}, [], "bomb_refund")],
			[a("white_fire", "White Fire", "Burning enemies take 50% more", "flame+up", {"burn_damage": 0.5}),
			a("blast_shield", "Blast Shield", "Take 25% less damage for 3 s after a throw", "shield_round+flame", {}, [t("throw", "buff", {"stat": "damage_taken", "val": -0.25, "secs": 3.0, "key": "blast_shield"})])]],
			a("pyro_m", "Pyromaniac Mastery", "+8 bomb damage, +0.1 m reach", "bomb+crown", {"bomb_damage": 8.0, "bomb_radius": 0.1}),
			a("chaotic", "Chaotic", "Every bomb throws off 6 bomblets that bounce away at random, each with its own effect: fire, frost, thunder or poison", "spiral+flame", {}, [], "chaotic")),
		_spec("mechanic", "Mechanic", "Builds a war chariot with room for a friend.", iron,
			a("mechanic", "Mechanic", "Kills build the War Chariot: slower than a horse, it takes 35% of each hit off you, and a friend can ride along", "chariot+plus", {"riding_armor": -0.35}),
			[[a("mounted_ballista", "Mounted Ballista", "A turret on the chariot shoots the nearest enemy", "turret+plus", {}, [], "chariot_turret")],
			[a("better_axles", "Better Axles", "The chariot is 20% faster", "chariot+up", {"horse_speed": 0.2}),
			a("long_haul", "Long Haul", "The chariot lasts 10 s longer", "chariot+clock", {"horse_time": 10.0})],
			[a("scythed_wheels", "Scythed Wheels", "Spikes on the wheels cut whatever comes close", "spikes+plus", {}, [], "chariot_spikes")],
			[a("iron_plates", "Iron Plates", "The chariot takes 15% more of each hit", "shield_rect+chariot", {"riding_armor": -0.15}),
			a("repair_kit", "Repair Kit", "Heal 4 health a second while riding", "heart+chariot", {"riding_regen": 4.0})],
			[a("twin_bolts", "Twin Bolts", "The turret shoots twice as fast", "turret+up", {"turret_rate": 1.0}),
			a("caltrops", "Caltrops", "Drops a trap behind the chariot every 5 s", "trap+chariot", {}, [t("every", "trap", {"secs_every": 5.0, "riding": true})])]],
			a("mechanic_m", "Mechanic Mastery", "+1 s riding, turret and spikes +6% damage", "chariot+crown", {"horse_time": 1.0, "turret_damage": 0.06}),
			a("war_machine", "War Machine", "Turret bolts burst into flame, and the chariot lasts 15 s longer", "turret+flame", {"horse_time": 15.0}, [], "war_machine")),
		_spec("inventor", "Inventor", "A different device every time, and the button shows which is next.", brass,
			a("inventor", "Inventor", "Unlocks Invention: a random device each use, and the button shows the next one. Starts with Electric Volley and Cryo Flask", "gear+star"),
			[[a("sentry_plans", "Clockwork Sentry", "New invention: a turret that shoots for 12 s", "turret+gear", {}, [], "inv_sentry"),
			a("overcharge", "Overcharge", "Electric Volley: 2 more darts, and each spark jumps once more", "dart+up", {"volley_darts": 2.0, "volley_jumps": 1.0})],
			[a("boots_plans", "Steam Boots", "New invention: a burst of speed, untouchable for 1.5 s", "steam+plus", {}, [], "inv_boots"),
			a("deep_freeze", "Deep Freeze", "Cryo Flask: freezes 1 s longer and reaches 1.5 m further", "flask+up", {"flask_time": 1.0, "flask_radius": 1.5})],
			[a("noise_plans", "Noise Box", "New invention: draws everything close to it, then bursts", "noisebox+plus", {}, [], "inv_noise"),
			a("better_bench", "Better Workbench", "Invention is ready 20% sooner", "gear+clock", {"art_cd": -0.2})],
			[a("magnet_plans", "Lodestone", "New invention: drags enemies together and holds them for 3 s", "magnet+plus", {}, [], "inv_magnet"),
			a("fine_gears", "Fine Gears", "Inventions do 25% more damage", "gear+up", {"inv_damage": 0.25})],
			[a("spare_parts", "Spare Parts", "Each invention also heals you 8", "heart+gear", {"inv_heal": 8.0}),
			a("prototype", "Prototype", "20% chance that Invention is ready again at once", "gear+swap", {"inv_repeat": 0.2})]],
			a("inventor_m", "Inventor Mastery", "Inventions do 5% more damage and are ready 2% sooner", "gear+crown", {"inv_damage": 0.05, "art_cd": -0.02}),
			a("eureka", "Eureka!", "Every invention goes off twice", "bolt+gear", {}, [], "eureka")),
	]}


static func _infantry() -> Dictionary:
	return {"core": [
		[a("keen_edge", "Keen Edge", "+15% melee damage", "sword+up", {"melee_damage": 0.15}),
		a("quick_hands", "Quick Hands", "+15% melee speed", "hand+clock", {"melee_rate": 0.15})],
		[a("sprinter", "Sprinter", "+10% move speed", "boot+up", {"speed": 0.1}),
		a("thick_skin", "Thick Skin", "+20 max health", "heart+plus", {"max_hp": 20.0})],
		[a("bloodlust", "Bloodlust", "Heal 2 per kill", "drop+heart", {}, [t("kill", "heal", {"n": 2.0})]),
		a("whirl", "Whirl", "Wider swings that hit 2 more", "spiral+sword", {"melee_cone": 40.0, "melee_hits": 2})],
		[a("long_reach", "Long Reach", "+0.5 m melee reach", "spear+up", {"melee_reach": 0.5}),
		a("riposte", "Riposte", "15% chance to stun on hit", "dagger+star", {}, [t("hit", "stun", {"chance": 0.15, "secs": 1.0})])],
	], "specs": [
		_spec("duelist", "Duelist", "Precise strikes and perfect defence", Color(0.2, 0.42, 0.72),
			a("duelist", "Duelist", "15% crit chance, and crits do double", "sword+star", {"crit_chance": 0.15}),
			[[a("footwork", "Footwork", "Each hit: +15% speed for 2 s", "boot+wind", {}, [t("hit", "buff", {"stat": "speed", "val": 0.15, "secs": 2.0, "key": "footwork"})]),
			a("measure", "Measure", "+0.6 m melee reach", "target+up", {"melee_reach": 0.6})],
			[a("bleeding_cut", "Bleeding Cut", "Hits bleed for 8 per second, 3 s", "drop+dagger", {}, [t("hit", "dot", {"dps": 8.0, "secs": 3.0})]),
			a("feint", "Feint", "Crits stun for 0.8 s", "mask+star", {}, [t("crit", "stun", {"secs": 0.8})])],
			[a("parry", "Parry Stance", "20% chance to avoid any hit", "shield_round+sword", {"dodge": 0.2}),
			a("counterstroke", "Counterstroke", "When hit: +40% damage for 3 s", "swap+sword", {}, [t("hurt", "buff", {"stat": "melee_damage", "val": 0.4, "secs": 3.0, "key": "counter"})])],
			[a("flurry", "Flurry", "Every 4th hit strikes twice", "sword+plus", {}, [t("hit", "extra", {"nth": 4, "mult": 1.0})]),
			a("momentum", "Momentum", "Kills: +8% attack speed for 5 s, up to 5", "wind+up", {}, [t("kill", "buff", {"stat": "melee_rate", "val": 0.08, "secs": 5.0, "max": 5, "key": "momentum"})])],
			[a("blade_dance", "Blade Dance", "+15% crit chance", "star+sword", {"crit_chance": 0.15}),
			a("coup_de_grace", "Coup de Grace", "Melee kills enemies under 25% health", "skull+dagger", {}, [], "execution")]],
			a("duelist_m", "Duelist Mastery", "+3% melee damage, +1% crit", "sword+crown", {"melee_damage": 0.03, "crit_chance": 0.01}),
			a("perfect_riposte", "Perfect Riposte", "Every 8 s, the next blow is blocked and stuns all around you", "shield_round+crown", {}, [], "perfect_riposte")),
		_spec("berserker", "Berserker", "Pain becomes power", Color(0.68, 0.14, 0.1),
			a("berserker", "Berserker", "Up to +60% damage as your health falls", "axe+drop", {}, [], "rage"),
			[[a("thirst", "Thirst", "Heal 4 per kill", "drop+plus", {}, [t("kill", "heal", {"n": 4.0})]),
			a("thick_blood", "Thick Blood", "+30 max health", "heart+drop", {"max_hp": 30.0})],
			[a("savage", "Savage", "+25% melee damage, take 10% more", "claw+up", {"melee_damage": 0.25, "damage_taken": 0.1}),
			a("reckless", "Reckless Swing", "Wider swings that hit 3 more", "axe+spiral", {"melee_cone": 60.0, "melee_hits": 3})],
			[a("frenzy", "Frenzy", "Kills: +10% attack speed for 6 s, up to 5", "flame+wind", {}, [t("kill", "buff", {"stat": "melee_rate", "val": 0.1, "secs": 6.0, "max": 5, "key": "frenzy"})]),
			a("terrify", "Terrify", "Kills may stun enemies around you", "skull+shout", {}, [t("kill", "stun_around", {"chance": 0.3, "r": 4.0, "secs": 0.8})])],
			[a("undying", "Undying", "Under 30% health: heal 30, once per 30 s", "cross+heart", {}, [t("low", "heal", {"n": 30.0, "cd": 30.0})]),
			a("pain_feeds", "Pain Feeds", "When hit: +30% speed for 3 s", "boot+drop", {}, [t("hurt", "buff", {"stat": "speed", "val": 0.3, "secs": 3.0, "key": "pain"})])],
			[a("cleaver", "Cleaver", "Every 5th hit makes a small blast", "axe+flame", {}, [t("hit", "blast", {"nth": 5, "r": 3.0, "dmg": 35.0})]),
			a("war_cry", "War Cry", "Every 20 s, stun everything near you", "shout+up", {}, [t("every", "stun_around", {"secs_every": 20.0, "r": 7.0, "secs": 1.0, "sound": "attack"})])]],
			a("berserker_m", "Berserker Mastery", "+3% melee damage, +4 health", "axe+crown", {"melee_damage": 0.03, "max_hp": 4.0}),
			a("blood_frenzy", "Blood Frenzy", "Under 50% health: +50% attack speed and heal from every hit", "drop+crown", {}, [], "blood_frenzy")),
		_spec("shadow", "Shadow Blade", "Kill before they know you are there", Color(0.3, 0.2, 0.5),
			a("shadow", "Shadow Blade", "+60% damage on unaware enemies or from behind, 30% less noise", "dagger+eye_closed", {"backstab": 0.6, "noise": -0.3}),
			[[a("soft_steps", "Soft Steps", "30% less noise", "boot+eye_closed", {"noise": -0.3}),
			a("cloak", "Cloak", "Zombies see you 25% less far", "mask+eye_closed", {"sight": -0.25})],
			[a("venom_blade", "Venom Blade", "Hits poison for 8 per second, 4 s", "poison+dagger", {}, [t("hit", "dot", {"dps": 8.0, "secs": 4.0})]),
			a("ambush", "Ambush", "+40% more backstab damage", "eye_closed+dagger", {"backstab": 0.4})],
			[a("smoke", "Smoke", "When hit: vanish for 3 s, every 25 s", "wind+eye_closed", {}, [t("hurt", "invis", {"secs": 3.0, "cd": 25.0})]),
			a("slip_away", "Slip Away", "+12% move speed", "wind+boot", {"speed": 0.12})],
			[a("throat_cut", "Throat Cut", "Backstabs stun for 1 s", "dagger+tooth", {}, [t("backstab", "stun", {"secs": 1.0})]),
			a("vanish", "Vanish", "Kills have a 15% chance to hide you for 3 s", "moon+skull", {}, [t("kill", "invis", {"chance": 0.15, "secs": 3.0})])],
			[a("deep_shadows", "Deep Shadows", "Zombies see you 20% less far", "moon+eye_closed", {"sight": -0.2}),
			a("predator", "Predator", "+25% backstab damage, +8% speed", "claw+eye", {"backstab": 0.25, "speed": 0.08})]],
			a("shadow_m", "Shadow Mastery", "+6% backstab damage, 2% less noise", "dagger+crown", {"backstab": 0.06, "noise": -0.02}),
			a("death_dark", "Death from the Dark", "Unaware enemies die in one hit, and those kills hide you for 3 s", "skull+crown", {}, [], "assassin")),
	]}


static func _ranger() -> Dictionary:
	return {"core": [
		[a("steady_aim", "Steady Aim", "+15% ranged damage", "arrow+up", {"ranged_damage": 0.15}),
		a("quick_draw", "Quick Draw", "+15% firing speed", "bow+clock", {"ranged_rate": 0.15})],
		[a("deep_quiver", "Deep Quiver", "Carry 30 more arrows, and get 15 now", "arrows+plus", {"max_arrows": 30}, [t("take", "arrows", {"n": 15})]),
		a("light_feet", "Light Feet", "+10% move speed", "boot+feather", {"speed": 0.1})],
		[a("recover", "Recover Arrows", "25% of shots use no arrow", "arrows+swap", {"arrow_save": 0.25}),
		a("far_sight", "Far Sight", "+25% arrow range and speed", "eye+arrow", {"ranged_power": 0.25})],
		[a("piercing", "Piercing", "Arrows pass through 1 enemy", "arrow+plus", {"pierce": 1}),
		a("twin_shot", "Twin Shot", "Each shot fires a second arrow", "arrows+star", {}, [], "twin_shot")],
	], "specs": [
		_spec("sharpshooter", "Sharpshooter", "One arrow, one kill", Color(0.18, 0.46, 0.34),
			a("sharpshooter", "Sharpshooter", "Headshots do double damage, +10% crit", "target+arrow", {"crit_chance": 0.1}, [], "sharpshooter"),
			[[a("eagle_eye", "Eagle Eye", "+25% arrow range and speed", "eye+up", {"ranged_power": 0.25}),
			a("still_aim", "Still Aim", "+30% ranged damage while standing still", "target+clock", {}, [], "still_aim")],
			[a("stopping_power", "Stopping Power", "Arrows may stun for 0.6 s", "arrow+star", {}, [t("shot", "stun", {"chance": 0.3, "secs": 0.6})]),
			a("marked", "Marked Prey", "Arrows mark enemies: +25% damage for 4 s", "target+eye", {}, [t("shot", "mark", {"mult": 1.25, "secs": 4.0})])],
			[a("rapid_fire", "Rapid Fire", "+18% firing speed", "bow+wind", {"ranged_rate": 0.18}),
			a("long_breath", "Long Breath", "+12% crit chance", "wind+star", {"crit_chance": 0.12})],
			[a("ricochet", "Ricochet", "Arrows bounce to 1 more enemy", "swap+arrow", {"bounces": 1}),
			a("overdraw", "Overdraw", "Every 4th arrow does double damage", "bow+up", {}, [], "overdraw")],
			[a("deadeye", "Deadeye", "Crits do triple damage", "skull+target", {"crit_mult": 1.0}),
			a("hunters_eye", "Hunter's Eye", "Enemies you hit are marked through walls for 6 s", "eye+claw", {}, [t("shot", "reveal", {"secs": 6.0})])]],
			a("sharp_m", "Sharpshooter Mastery", "+3% ranged damage, +1% crit", "target+crown", {"ranged_damage": 0.03, "crit_chance": 0.01}),
			a("killing_shot", "Killing Shot", "Every 6 s, your next arrow does 300 damage", "arrow+crown", {}, [], "killing_shot")),
		_spec("trapper", "Trapper", "The field itself fights for you", Color(0.5, 0.36, 0.14),
			a("trapper", "Trapper", "Every 12 s a trap drops at your feet: 50 damage and a 2 s stun", "trap+plus", {}, [t("every", "trap", {"secs_every": 12.0})]),
			[[a("barbed", "Barbed Traps", "Traps bleed 10 per second for 4 s", "trap+drop", {}, [], "trap_bleed"),
			a("burning_tar", "Burning Tar", "Traps set enemies on fire", "trap+flame", {}, [], "trap_fire")],
			[a("spare_parts", "Spare Parts", "Carry 2 more traps on the ground", "trap+up", {"trap_cap": 2}),
			a("quick_setup", "Quick Setup", "Traps come 3 s sooner", "trap+clock", {"trap_cd": -3.0})],
			[a("snare_net", "Snare Net", "Traps hold enemies 1.5 s longer", "net+trap", {"trap_stun": 1.5}),
			a("powder_keg", "Powder Keg", "Traps also explode in a small blast", "flame+trap", {}, [], "trap_blast")],
			[a("scavenger", "Scavenger", "Kills may give back an arrow", "arrows+skull", {}, [t("kill", "arrows", {"chance": 0.5, "n": 1})]),
			a("woodsman", "Woodsman", "+25 max health", "heart+feather", {"max_hp": 25.0})],
			[a("lure", "Lure", "Every trap also pulls roaming zombies to it", "horn+trap", {}, [], "trap_lure"),
			a("ghillie", "Ghillie Suit", "Zombies see you 30% less far", "mask+feather", {"sight": -0.3})]],
			a("trapper_m", "Trapper Mastery", "+8 trap damage, traps 0.3 s sooner", "trap+crown", {"trap_damage": 8.0, "trap_cd": -0.3}),
			a("field_snares", "Field of Snares", "Up to 8 traps, and each trap kill drops a new one", "net+crown", {"trap_cap": 5}, [], "field_snares")),
		_spec("beastmaster", "Beastmaster", "You never hunt alone", Color(0.34, 0.5, 0.2),
			a("beastmaster", "Beastmaster", "A wolf fights beside you, and returns 15 s after falling", "wolf+plus", {"wolves": 1}),
			[[a("alpha", "Alpha", "Allies do 25% more damage", "wolf+up", {"ally_damage": 0.25}),
			a("thick_fur", "Thick Fur", "Allies have 50% more health", "wolf+heart", {"ally_hp": 0.5})],
			[a("savage_bite", "Savage Bite", "Wolf bites stun for 0.7 s", "tooth+star", {}, [], "wolf_stun"),
			a("scent", "Scent", "Enemies within 15 m are always marked", "wolf+eye", {}, [], "scent")],
			[a("second_wolf", "Second Wolf", "One more wolf at your side", "wolf+star", {"wolves": 1}),
			a("hawk", "Hunting Hawk", "Every 3 s a hawk strikes a nearby enemy", "feather+arrow", {}, [t("every", "hawk", {"secs_every": 3.0})])],
			[a("pack_tactics", "Pack Tactics", "+25% damage to enemies near your allies", "claw+plus", {}, [], "pack_tactics"),
			a("bond", "Blood Bond", "Heal 3 whenever one of your allies kills", "heart+wolf", {}, [], "bond")],
			[a("feral", "Feral", "+12% move speed", "boot+claw", {"speed": 0.12}),
			a("fetch", "Fetch", "Every 6 s, a nearby item is brought to you", "wolf+grab", {}, [t("every", "fetch", {"secs_every": 6.0})])]],
			a("beast_m", "Beastmaster Mastery", "Allies +5% damage and +5% health", "wolf+crown", {"ally_damage": 0.05, "ally_hp": 0.05}),
			a("wolf_pack", "Wolf Pack", "4 wolves, and a howl every 20 s stuns all around you", "moon+crown", {"wolves": 3}, [t("every", "stun_around", {"secs_every": 20.0, "r": 9.0, "secs": 1.2, "sound": "howl"})])),
	]}


static func _heavy() -> Dictionary:
	return {"core": [
		[a("banded", "Banded Shield", "Iron bands: blocks 15% more", "shield_round+up", {"shield": 0.15}, [t("take", "shield_up")]),
		a("heavy_swing", "Heavy Swing", "+15% melee damage", "mace+up", {"melee_damage": 0.15})],
		[a("thick_hide", "Thick Hide", "+25 max health", "heart+shield", {"max_hp": 25.0}),
		a("shockwave", "Shockwave", "Double knockback, 10% stun", "quake+mace", {"knock": 1.0}, [t("hit", "stun", {"chance": 0.1, "secs": 1.0})])],
		[a("iron_round", "Iron Round Shield", "Blocks 15% more, and fireballs no longer burn you", "shield_round+plus", {"shield": 0.15}, [t("take", "shield_up")], "fire_proof"),
		a("cleave", "Cleave", "Wider swings that hit 2 more", "axe+plus", {"melee_cone": 30.0, "melee_hits": 2})],
		[a("thorns", "Thorns", "Melee attackers take 12 damage", "claw+shield", {"thorns": 12.0}),
		a("second_wind", "Second Wind", "Heal 3 per kill", "wind+heart", {}, [t("kill", "heal", {"n": 3.0})])],
	], "specs": [
		_spec("guardian", "Guardian", "Stands between the others and the dark", Color(0.34, 0.38, 0.46),
			a("guardian", "Guardian", "Iron shield. Unlocks Shield Dome: nobody inside can be hurt for 3 s. Friends and summons near you take 25% less damage, and you bear part of it", "shield_rect+up", {"shield": 0.2, "cover": 0.25, "cover_radius": 8.0}, [t("take", "shield_max")]),
			[[a("take_the_blow", "Take the Blow", "Friends near you take 10% less", "shield_rect+heart", {"cover": 0.1}),
			a("wide_cover", "Wide Cover", "You cover friends 4 m further away", "banner+shield", {"cover_radius": 4.0})],
			[a("long_dome", "Long Dome", "The dome lasts 2 s longer", "shield_rect+clock", {"dome_time": 2.0}),
			a("wide_dome", "Wide Dome", "The dome reaches 3 m further", "shield_rect+plus", {"dome_radius": 3.0})],
			[a("challenge", "Challenge", "Raising the dome draws every enemy around to you", "shout+shield", {}, [], "dome_taunt"),
			a("hold_line", "Hold the Line", "Take 15% less damage, -5% speed", "banner+helm", {"damage_taken": -0.15, "speed": -0.05})],
			[a("rescuer", "Rescuer", "Fallen friends near you get back up twice as fast", "cross+shield", {}, [], "rescuer"),
			a("second_skin", "Second Skin", "+40 max health", "helm+heart", {"max_hp": 40.0})],
			[a("block_stuns", "Crushing Block", "Blocking stuns the attacker for 0.5 s", "shield+star", {}, [t("block", "stun_attacker", {"secs": 0.5})]),
			a("block_heals", "Faith in Iron", "Blocking heals 2", "shield+heart", {}, [t("block", "heal", {"n": 2.0})])]],
			a("guardian_m", "Guardian Mastery", "+1% cover, +1% block, +5 health", "shield_rect+crown", {"cover": 0.01, "shield": 0.01, "max_hp": 5.0}),
			a("aegis", "Aegis", "The dome also heals everyone inside by 30, and comes back 25% sooner", "helm+crown", {"art_cd": -0.25}, [], "aegis")),
		_spec("warpriest", "Warpriest", "Holy fire and endless faith", Color(0.76, 0.6, 0.2),
			a("warpriest", "Warpriest", "Heal 1 health per second", "cross+heart", {"regen": 1.0}),
			[[a("blessing", "Blessing", "Heal 1 more per second", "sun+heart", {"regen": 1.0}),
			a("healing_hands", "Healing Hands", "Heal 3 per kill", "hand+heart", {}, [t("kill", "heal", {"n": 3.0})])],
			[a("holy_fire", "Holy Fire", "Melee sets enemies on fire", "flame+cross", {}, [t("hit", "ignite")]),
			a("smite", "Smite", "Every 6th hit calls lightning", "bolt+cross", {}, [t("hit", "thunder", {"nth": 6})])],
			[a("consecrate", "Consecrate", "Every 8 s, burn enemies within 4 m", "sun+flame", {}, [t("every", "burn_around", {"secs_every": 8.0, "r": 4.0})]),
			a("shield_faith", "Shield of Faith", "Under 30% health: no damage for 3 s, every 40 s", "shield+cross", {}, [t("low", "guard", {"secs": 3.0, "cd": 40.0})])],
			[a("prayer", "Prayer", "Every 40 s, an Angel joins you for 10 s", "wings+cross", {}, [t("every", "power", {"secs_every": 40.0, "id": "angel", "time": 10.0})]),
			a("last_rites", "Last Rites", "Kills have a 25% chance to heal 8", "book+heart", {}, [t("kill", "heal", {"chance": 0.25, "n": 8.0})])],
			[a("devotion", "Devotion", "Familiars last 50% longer", "wings+clock", {"familiar_time": 0.5}),
			a("zeal", "Zeal", "+15% melee speed", "cross+wind", {"melee_rate": 0.15})]],
			a("priest_m", "Warpriest Mastery", "+0.2 health per second, +2% melee damage", "cross+crown", {"regen": 0.2, "melee_damage": 0.02}),
			a("divine_wrath", "Divine Wrath", "Every 15 s, lightning strikes all enemies within 12 m", "bolt+crown", {}, [t("every", "thunder_all", {"secs_every": 15.0, "r": 12.0})])),
		_spec("warlord", "Warlord", "Break whole crowds at once", Color(0.56, 0.24, 0.14),
			a("warlord", "Warlord", "Swings are much wider and hit 2 more", "mace+spiral", {"melee_cone": 40.0, "melee_hits": 2, "knock": 0.5}),
			[[a("great_swing", "Great Swing", "+20% melee damage", "hammer+up", {"melee_damage": 0.2}),
			a("swift_arm", "Swift Arm", "+15% melee speed", "hammer+clock", {"melee_rate": 0.15})],
			[a("aftershock", "Aftershock", "Every 4th hit makes a shockwave", "quake+plus", {}, [t("hit", "blast", {"nth": 4, "r": 3.0, "dmg": 30.0})]),
			a("stomp", "Stomp", "Every 12 s, slow all around you for 3 s", "boot+quake", {}, [t("every", "slow_around", {"secs_every": 12.0, "r": 6.0, "secs": 3.0})])],
			[a("war_horn", "War Horn", "Every 18 s, stun enemies within 6 m", "horn+up", {}, [t("every", "stun_around", {"secs_every": 18.0, "r": 6.0, "secs": 1.2, "sound": "hammer"})]),
			a("intimidate", "Intimidate", "Every 5 s, slow enemies within 5 m", "skull+shout", {}, [t("every", "slow_around", {"secs_every": 5.0, "r": 5.0, "secs": 2.0})])],
			[a("war_banner", "War Banner", "Every 40 s, a spirit soldier fights with you for 15 s", "banner+ghost", {}, [t("every", "summon", {"secs_every": 40.0, "kind": "ghost", "n": 1, "secs": 15.0})]),
			a("rally_troops", "Rally", "Allies do 40% more damage", "banner+up", {"ally_damage": 0.4})],
			[a("crush", "Crush", "25% chance to stun on hit", "hammer+star", {}, [t("hit", "stun", {"chance": 0.25, "secs": 1.0})]),
			a("sunder", "Sunder", "Hits mark enemies: +20% damage for 4 s", "axe+target", {}, [t("hit", "mark", {"mult": 1.2, "secs": 4.0})])]],
			a("warlord_m", "Warlord Mastery", "+3% melee damage, +3 degrees of swing", "mace+crown", {"melee_damage": 0.03, "melee_cone": 3.0}),
			a("earthbreaker", "Earthbreaker", "Every 5th attack shakes the ground: 60 damage and stun in 7 m", "quake+crown", {}, [t("hit", "quake", {"nth": 5, "r": 7.0, "dmg": 60.0})])),
	]}


static func _chivalry() -> Dictionary:
	return {"core": [
		[a("lance_mastery", "Lance Mastery", "+15% melee damage", "lance+up", {"melee_damage": 0.15}),
		a("swift_steed", "Swift Steed", "+15% riding speed", "horse+wind", {"horse_speed": 0.15})],
		[a("stable_bond", "Stable Bond", "Horse needs 3 fewer kills", "horseshoe+skull", {"horse_kills": -3}),
		a("long_ride", "Long Ride", "+8 s of riding", "horseshoe+clock", {"horse_time": 8.0})],
		[a("trample", "Trample", "+60% trample damage", "boot+horse", {"trample": 0.6}),
		a("couched", "Couched Lance", "Double melee damage while riding", "lance+horse", {}, [], "couched")],
		[a("barding", "Armored Barding", "Take 40% less damage while riding", "horse+shield", {"riding_armor": -0.4}),
		a("thick_armor", "Thick Armor", "+25 max health", "helm+heart", {"max_hp": 25.0})],
	], "specs": [
		_spec("lancer", "Lancer", "A charge nothing survives", Color(0.6, 0.16, 0.14),
			a("lancer", "Lancer", "+1 m lance reach, +25% melee damage while riding", "lance+star", {"melee_reach": 1.0, "riding_damage": 0.25}),
			[[a("spur", "Spur", "+15% riding speed", "horse+up", {"horse_speed": 0.15}),
			a("long_lance", "Long Lance", "+0.6 m melee reach", "lance+plus", {"melee_reach": 0.6})],
			[a("impale", "Impale", "Thrusts hit 2 more enemies", "lance+skull", {"melee_hits": 2}),
			a("joust", "Joust", "+25% crit chance while riding", "target+lance", {"riding_crit": 0.25})],
			[a("bowl_over", "Bowl Over", "Trampled enemies are stunned for 1 s", "horseshoe+star", {}, [t("trample", "stun", {"secs": 1.0})]),
			a("heavy_hooves", "Heavy Hooves", "+60% trample damage", "horseshoe+up", {"trample": 0.6})],
			[a("charge", "Charge", "Mounting: +40% speed for 3 s", "wind+horse", {}, [t("mount", "buff", {"stat": "horse_speed", "val": 0.4, "secs": 3.0, "key": "charge"})]),
			a("remount", "Remount", "Each kill while riding adds 1 s", "clock+horse", {}, [], "ride_on_kill")],
			[a("iron_tip", "Iron Tip", "+12% crit chance", "spear+star", {"crit_chance": 0.12}),
			a("run_down", "Run Them Down", "Riding kills normal zombies outright", "skull+horse", {}, [], "war_horse")]],
			a("lancer_m", "Lancer Mastery", "+3% melee damage, +1% riding speed", "lance+crown", {"melee_damage": 0.03, "horse_speed": 0.01}),
			a("unstoppable", "Unstoppable Charge", "While riding you take no damage, and trampling kills anything but Beasts", "horse+crown", {}, [], "unstoppable")),
		_spec("paladin", "Paladin", "A holy knight who keeps riding", Color(0.8, 0.66, 0.26),
			a("paladin", "Paladin", "Heal 15 on mounting, and 1 per second while riding", "sun+horse", {"riding_regen": 1.0}, [t("mount", "heal", {"n": 15.0})]),
			[[a("lay_hands", "Lay on Hands", "Heal 3 per kill", "hand+cross", {}, [t("kill", "heal", {"n": 3.0})]),
			a("holy_armor", "Holy Armor", "Take 10% less damage", "helm+cross", {"damage_taken": -0.1})],
			[a("smite_undead", "Smite the Undead", "Melee sets enemies on fire", "flame+lance", {}, [t("hit", "ignite")]),
			a("aura", "Aura of Dread", "Every 8 s, slow enemies within 6 m", "sun+skull", {}, [t("every", "slow_around", {"secs_every": 8.0, "r": 6.0, "secs": 3.0})])],
			[a("sacred_mount", "Sacred Mount", "Horse needs 3 fewer kills", "horse+cross", {"horse_kills": -3}),
			a("endurance", "Endurance", "+10 s of riding", "horse+clock", {"horse_time": 10.0})],
			[a("blessed_rally", "Blessed Rally", "Mounting and dismounting stun all around you", "horn+cross", {}, [t("mount", "stun_around", {"r": 7.0, "secs": 1.5}), t("dismount", "stun_around", {"r": 7.0, "secs": 1.5})]),
			a("flaming_trail", "Flaming Trail", "While riding, you leave burning ground", "flame+horseshoe", {}, [t("every", "poison", {"secs_every": 0.7, "riding": true})])],
			[a("guardian", "Guardian", "Under 30% health: a spirit knight fights for you, every 45 s", "ghost+cross", {}, [t("low", "summon", {"kind": "ghost", "n": 1, "secs": 15.0, "cd": 45.0})]),
			a("oath", "Oath", "Fire and burning no longer hurt", "book+flame", {}, [], "fire_proof")]],
			a("paladin_m", "Paladin Mastery", "+5 health, +0.2 riding heal", "cross+crown", {"max_hp": 5.0, "riding_regen": 0.2}),
			a("sacred_steed", "Sacred Steed", "The horse comes every 60 s without kills, heals 3 per second, and burns what it passes", "sun+crown", {"riding_regen": 3.0}, [], "sacred_steed")),
		_spec("horse_archer", "Horse Archer", "Strike from the saddle and be gone", Color(0.22, 0.46, 0.3),
			a("horse_archer", "Horse Archer", "Unlocks ranged weapons: a Short Bow, 30 arrows, an arrow back per kill, and +20% ranged damage while riding", "bow+horse", {"riding_ranged": 0.2}, [t("take", "arrows", {"n": 30}), t("take", "weapon", {"id": "bow"}), t("kill", "arrows", {"n": 1})], "ranged_ok"),
			[[a("swift_quiver", "Swift Quiver", "+18% firing speed", "arrows+clock", {"ranged_rate": 0.18}),
			a("saddle_bags", "Saddle Bags", "Carry 30 more arrows, and get 15 now", "arrows+horseshoe", {"max_arrows": 30}, [t("take", "arrows", {"n": 15})])],
			[a("mounted_aim", "Mounted Aim", "+30% ranged damage while riding", "target+horse", {"riding_ranged": 0.3}),
			a("dismounted", "Skirmisher", "+15% ranged damage", "bow+up", {"ranged_damage": 0.15})],
			[a("horse_pierce", "Piercing Bolts", "Arrows pass through 1 enemy", "arrow+horse", {"pierce": 1}),
			a("horse_twin", "Double Nock", "Each shot fires a second arrow", "arrows+star", {}, [], "twin_shot")],
			[a("retrieve", "Retrieve", "Kills may give back an arrow", "arrows+skull", {}, [t("kill", "arrows", {"chance": 0.5, "n": 1})]),
			a("scout", "Scout", "Zombies see you 25% less far", "eye_closed+horse", {"sight": -0.25})],
			[a("fire_quiver", "Fire Quiver", "Arrows shot while riding set enemies on fire", "flame+arrow", {}, [], "riding_fire"),
			a("skip_shot", "Skip Shot", "Arrows bounce to 1 more enemy", "swap+horse", {"bounces": 1})]],
			a("harcher_m", "Horse Archer Mastery", "+3% ranged damage, +1% riding speed", "bow+crown", {"ranged_damage": 0.03, "horse_speed": 0.01}),
			a("parthian", "Parthian Volley", "While riding, every 3 s a volley of 5 arrows hits nearby enemies", "arrows+crown", {}, [t("every", "volley", {"secs_every": 3.0, "n": 5, "riding": true})])),
	]}


static func _magician() -> Dictionary:
	return {"core": [
		[a("deep_well", "Deep Well", "+40 max mana", "orb+plus", {"mana": 40.0}),
		a("flow", "Flow", "Mana refills 35% faster", "drop+clock", {"mana_regen": 0.35})],
		[a("arcane_focus", "Arcane Focus", "+15% spell damage", "staff+up", {"spell_damage": 0.15}),
		a("quick_cast", "Quick Cast", "+15% casting speed", "staff+clock", {"spell_rate": 0.15})],
		[a("mana_shield", "Mana Shield", "Half of the damage drains mana instead", "orb+shield", {}, [], "mana_shield"),
		a("blink_step", "Light Step", "+10% move speed", "blink+boot", {"speed": 0.1})],
		[a("familiar_bond", "Familiar Bond", "Familiars last 50% longer", "wings+plus", {"familiar_time": 0.5}),
		a("potion_lore", "Potion Lore", "Potions last 50% longer", "potion+clock", {"potion_time": 0.5})],
	], "specs": [
		_spec("necromancer", "Necromancer", "The dead fight for you", Color(0.26, 0.42, 0.22),
			a("necromancer", "Necromancer", "Every 25 s, a skeleton fights for you", "skull+plus", {}, [t("every", "summon", {"secs_every": 25.0, "kind": "skeleton", "n": 1, "secs": 22.0, "soon": true})]),
			[[a("bone_armor", "Bone Armor", "+20 health, and allies have 30% more", "bones+shield", {"max_hp": 20.0, "ally_hp": 0.3}),
			a("reanimate", "Reanimate", "25% of your kills rise as skeletons", "skull+up", {}, [t("kill", "raise", {"chance": 0.25, "secs": 15.0})])],
			[a("legion", "Bone Legion", "Skeletons come in pairs", "bones+plus", {"summon_extra": 1}),
			a("long_unlife", "Long Unlife", "Allies last 50% longer", "skull+clock", {"ally_time": 0.5})],
			[a("death_bolt", "Death Bolt", "Bolts poison for 8 per second, 4 s", "poison+staff", {}, [t("shot", "dot", {"dps": 8.0, "secs": 4.0})]),
			a("life_tap", "Life Tap", "Kills give 4 health and 6 mana", "drop+orb", {}, [t("kill", "heal", {"n": 4.0}), t("kill", "mana", {"n": 6.0})])],
			[a("corpse_blast", "Corpse Blast", "Your fallen allies explode", "flame+bones", {}, [], "corpse_blast"),
			a("dark_pact", "Dark Pact", "Allies do 40% more damage", "book+skull", {"ally_damage": 0.4})],
			[a("bone_cage", "Bone Cage", "Every 15 s, stun enemies within 5 m", "bones+net", {}, [t("every", "stun_around", {"secs_every": 15.0, "r": 5.0, "secs": 1.0})]),
			a("soul_harvest", "Soul Harvest", "Kills: +5% spell damage for 8 s, up to 6", "ghost+staff", {}, [t("kill", "buff", {"stat": "spell_damage", "val": 0.05, "secs": 8.0, "max": 6, "key": "soul"})])]],
			a("necro_m", "Necromancy", "Allies +5% damage, +3 mana", "skull+crown", {"ally_damage": 0.05, "mana": 3.0}),
			a("army_dead", "Army of the Dead", "Every 30 s, 4 skeletons rise around you. Up to 8 allies", "bones+crown", {"ally_cap": 4}, [t("every", "summon", {"secs_every": 30.0, "kind": "skeleton", "n": 4, "secs": 22.0})])),
		_spec("elementalist", "Elementalist", "Fire, frost and storm", Color(0.2, 0.42, 0.74),
			a("elementalist", "Elementalist", "Bolts cycle through fire, frost and lightning", "flame+snow", {}, [], "elements"),
			[[a("scorch", "Scorch", "Burns do double damage", "flame+up", {"burn_damage": 1.0}),
			a("deep_freeze", "Deep Freeze", "Bolts may freeze for 1 s", "snow+star", {}, [t("shot", "stun", {"chance": 0.2, "secs": 1.0})])],
			[a("meteor", "Meteor", "Every 5th bolt is a large blast", "orb+flame", {}, [], "meteor"),
			a("chain", "Chain Lightning", "All bolts jump to 2 more enemies", "bolt+chain", {"bounces": 2})],
			[a("surge", "Mana Surge", "Kills give 6 mana", "orb+skull", {}, [t("kill", "mana", {"n": 6.0})]),
			a("focus_lens", "Focus Lens", "Bolts cost 25% less", "eye+orb", {"spell_cost": -0.25})],
			[a("frost_nova", "Frost Nova", "Every 10 s, slow enemies within 6 m", "snow+up", {}, [t("every", "slow_around", {"secs_every": 10.0, "r": 6.0, "secs": 3.0})]),
			a("storm_caller", "Storm Caller", "Every 8 s, lightning strikes near you", "bolt+clock", {}, [t("every", "thunder", {"secs_every": 8.0})])],
			[a("ward", "Elemental Ward", "Take 15% less damage, and burning no longer hurts", "shield+flame", {"damage_taken": -0.15}, [], "fire_proof"),
			a("overload", "Overload", "+30% spell damage, bolts cost 20% more", "bolt+up", {"spell_damage": 0.3, "spell_cost": 0.2})]],
			a("element_m", "Elemental Mastery", "+3% spell damage, +2 mana", "orb+crown", {"spell_damage": 0.03, "mana": 2.0}),
			a("cataclysm", "Cataclysm", "Every 20 s, a firestorm hits all enemies within 18 m", "sun+crown", {}, [t("every", "cataclysm", {"secs_every": 20.0, "r": 18.0, "dmg": 70.0})])),
		_spec("illusionist", "Illusionist", "They never hit the real you", Color(0.5, 0.26, 0.62),
			a("illusionist", "Illusionist", "Every 15 s, a decoy of you draws enemies for 6 s", "mirror+plus", {}, [t("every", "summon", {"secs_every": 15.0, "kind": "decoy", "n": 1, "secs": 6.0, "soon": true})]),
			[[a("twin_decoy", "Twin Image", "Decoys come in pairs", "mirror+star", {"summon_extra": 1}),
			a("lasting_image", "Lasting Image", "Decoys last 50% longer", "mirror+clock", {"ally_time": 0.5, "ally_hp": 0.5})],
			[a("confuse", "Confuse", "Bolts may stun for 0.7 s", "spiral+staff", {}, [t("shot", "stun", {"chance": 0.3, "secs": 0.7})]),
			a("mesmer", "Mesmer", "Bolts mark enemies: +25% damage for 4 s", "eye+spiral", {}, [t("shot", "mark", {"mult": 1.25, "secs": 4.0})])],
			[a("fade", "Fade", "When hit: vanish for 2 s, every 20 s", "ghost+eye_closed", {}, [t("hurt", "invis", {"secs": 2.0, "cd": 20.0})]),
			a("mirror_step", "Mirror Step", "+12% move speed", "blink+mirror", {"speed": 0.12})],
			[a("escape", "Grand Escape", "Under 30% health: vanish for 4 s and leave a decoy, every 40 s", "mask+blink", {}, [t("low", "invis", {"secs": 4.0, "cd": 40.0}), t("low", "summon", {"kind": "decoy", "n": 1, "secs": 6.0, "cd": 40.0})]),
			a("burst_decoy", "Bursting Decoys", "Decoys explode when they end", "flame+mirror", {}, [], "corpse_blast")],
			[a("mind_trick", "Mind Trick", "Zombies see you 30% less far", "mask+eye_closed", {"sight": -0.3}),
			a("dazzle", "Dazzle", "Every 12 s, enemies within 8 m forget you", "star+spiral", {}, [t("every", "forget", {"secs_every": 12.0, "r": 8.0})])]],
			a("illusion_m", "Illusion Mastery", "+4% mana refill, +3 mana", "mask+crown", {"mana_regen": 0.04, "mana": 3.0}),
			a("mirror_legion", "Mirror Legion", "Every 25 s, 4 mirror images cast bolts at enemies for 10 s", "mirror+crown", {"ally_cap": 4}, [t("every", "summon", {"secs_every": 25.0, "kind": "mirror", "n": 4, "secs": 10.0})])),
	]}
