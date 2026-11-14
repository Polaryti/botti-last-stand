extends RefCounted
## Every number a class, a path, an ability or a Class Upgrade quotes on a screen (Store, Armory, Codex,
## class screens, skill tree) has to be what the game uses. A number in the words must be found in the
## thing's own data (its modifiers and triggers, its ability's cost and cooldown, the class's health,
## weapon and arrows), or in FACTS below, which read the constants the code itself plays by. A new
## number in a description with nothing behind it fails the check: the rule holds for every update.

var failures: Array[String] = []

static func pct(x: float) -> float:
	return roundf(absf(x) * 100.0)


## For abilities and items whose effect is written in code: the numbers their words may quote, read
## from the same constants the code uses.
static func facts() -> Dictionary:
	var N := AbilityNumbers
	return {
		# Classes (ClassDefs descriptions)
		"class:adept": [WorldLight.ARTS["stance"]["cd"], pct(N.STANCE_MASTERY), 3.0, pct(Player.STANCE_ADDS["wind"]["speed"]), pct(Player.STANCE_ADDS["stone"]["damage_taken"]), pct(Player.STANCE_ADDS["flame"]["damage_taken"])],
		"class:plague_doctor": [pct(1.0 - ClassDefs.ALL["plague_doctor"]["damage_taken"])],
		"class:commander": [float(ClassDefs.MAX_LEVEL)],
		# Infantry
		"coup_de_grace": [pct(N.EXECUTE_BELOW)],
		"perfect_riposte": [N.RIPOSTE_EVERY],
		"berserker": [pct(N.RAGE_MAX)],
		"blood_frenzy": [pct(N.FRENZY_BELOW), pct(N.FRENZY_RATE - 1.0)],
		"death_dark": [N.ASSASSIN_HIDE],
		# Ranger
		"still_aim": [pct(N.STILL_AIM - 1.0)],
		"overdraw": [float(N.OVERDRAW_EVERY)],
		"killing_shot": [N.KILLING_SHOT_EVERY, N.KILLING_SHOT_DAMAGE],
		"trapper": [Player.BASE_MODS["trap_damage"] + 20.0, 2.0],
		"barbed": [N.TRAP_BLEED, N.TRAP_BLEED_TIME],
		"field_snares": [Player.BASE_MODS["trap_cap"] + 5.0, Player.TRAPS_CARRIED + 3.0],
		"beastmaster": [15.0],
		"savage_bite": [N.SAVAGE_BITE_STUN],
		"scent": [N.SCENT_REACH],
		"pack_tactics": [pct(N.PACK_TACTICS - 1.0)],
		"bond": [N.BOND_HEAL],
		# Heavy Infantry
		"guardian": [pct(WorldLight.DOME_REDUCTION), Player.BASE_MODS["dome_time"]],
		"aegis": [N.AEGIS_HEAL],
		"shield_faith": [pct(Player.LOW_HEALTH)],
		# Chivalry
		"run_down": [N.RUN_DOWN_TIME],
		"spirit_knight": [pct(Player.LOW_HEALTH)],
		"sacred_steed": [N.SACRED_STEED_REST],
		# Magician
		"army_dead": [Player.BASE_MODS["ally_cap"] + 2.0],
		"meteor": [float(N.METEOR_EVERY)],
		"illusionist": [Player.BASE_MODS["swap_range"]],
		"fade": [N.FADE_TIME],
		"stunning_burst": [N.BURST_STUN],
		"dazzle": [N.DAZZLE_REACH, SurveyNet.STAR_SLOW], # the Illusionist's Dazzle and the Star Reader's share a name
		"mirror_legion": [float(N.LEGION_IMAGES), N.LEGION_TIME],
		# Revenant
		"thick_mist": [15.0],
		"deep_breath": [60.0],
		"mist_leaper": [Player.BASE_MODS["leap_range"], N.LEAP_HEAL, Player.BASE_MODS["leap_damage"] + 20.0],
		"mist_landing": [N.LEAP_MEND_HEAL - N.LEAP_HEAL, N.LEAP_MEND_MIST],
		"rift_traveller": [Player.BASE_MODS["rift_hops"], Player.BASE_MODS["rift_damage"]],
		"rift_feast": [N.RIFT_FEAST_HEAL],
		"mist_thief": [N.RIFT_MIST],
		"summoner_entry": [Player.BASE_MODS["summon_time"]],
		# Monk
		"bo_master": [Player.VAULT_REACH],
		"wide_sweep": [N.WIDE_SWEEP],
		"stun_sweep": [N.STUN_SWEEP],
		"high_vault": [pct(N.HIGH_VAULT - 1.0)],
		"crushing": [N.CRUSHING_STUN],
		"spirit_walker": [Player.SPIRIT_TIME, Player.SPIRIT_HEAL, 2.0],
		"longer_journey": [N.LONGER_JOURNEY],
		"swift_spirit": [pct(Player.SPIRIT_SPEED - 1.0)],
		"mended": [N.MENDED_HEAL],
		"haunting": [N.HAUNTING_SLOW],
		"enlightenment": [N.ENLIGHTENED_DAMAGE, N.ENLIGHTENED_STUN, N.ENLIGHTENED_REACH],
		"iron_mountain": [pct(Player.SKIN_MAX)],
		"recoil": [pct(Player.SKIN_STRONG), N.RECOIL_DAMAGE],
		"aftershock": [N.AFTERSHOCK_SLOW],
		"rooted": [pct(N.ROOTED - 1.0), pct(Player.SKIN_STRONG)],
		"unmoved": [pct(Player.SKIN_UNMOVED)],
		# Adept
		"quick_change": [3.5],
		"quick_feet": [3.5],
		"blade_dancer": [Player.SWEEP_REACH, N.DANCE_HEAL_EACH, N.DANCE_HEAL_MAX, pct(N.DANCE_POWER - 1.0)],
		"wide_arc": [N.WIDE_SWEEP],
		"dance_on": [pct(N.DANCE_ON), N.DANCE_ON_TIME, float(N.DANCE_ON_STACKS)],
		"flowing_health": [N.FLOWING_HEAL],
		"whirl": [pct(N.WHIRL - 1.0)],
		"mirror_step": [Player.MIRROR_WINDOW, N.UNDO_HEAL, pct(N.MIRROR_GUARD), N.MIRROR_GUARD_TIME, pct(N.MIRROR_NEXT_BLOW - 1.0), N.MIRROR_GUARD_LONG],
		"long_mirror": [N.LONG_MIRROR],
		"still_water": [N.STILL_REFLECTION],
		"blinding_step": [N.BLINDING_STEP_REACH, N.BLINDING_STEP_STUN],
		"patient_blade": [pct(N.PATIENT_BLADE), N.PATIENT_BLADE_TIME],
		"perfect_reflection": [N.PERFECT_REFLECTION_REACH],
		"void_walker": [N.VOID_HEAL, Player.VOID_TIME],
		"deeper_void": [N.DEEPER_VOID],
		"hungry_void": [N.HUNGRY_VOID],
		"aftermath": [N.AFTERMATH_REACH, N.AFTERMATH_STUN],
		"walker_between": [N.WALKER_BETWEEN],
		# Plague Doctor
		"apothecary": [N.TONIC_HEAL, N.TONIC_FRIEND_HEAL],
		"strong_tonic": [N.STRONG_TONIC],
		"miracle_cure": [N.MIRACLE_CURE],
		"black_death": [N.BLACK_DEATH_REACH],
		"fleas": [N.BOND_HEAL],
		# Artificer
		"shrapnel": [N.BOMB_STUN],
		"chaotic": [float(N.BOMBLETS)],
		"mechanic": [6.0, 2.0],
		"sentry_plans": [WorldLight.SENTRY_TIME],
		"boots_plans": [2.0],
		"magnet_plans": [3.0],
		# Bandit
		"thief_entry": [BanditKit.STEAL_RANGE],
		"pocket_sand": [N.STEAL_STUN],
		"slip_away": [pct(N.SLIP_AWAY), N.SLIP_AWAY_TIME],
		"grand_larceny": [BanditKit.STEAL_SPLASH],
		"mercenary_entry": [BanditKit.NIGHT_TIME, BanditKit.NIGHT_LINGER],
		"paid_in_full": [pct(N.NIGHT_DAMAGE)],
		"hired_blades": [pct(N.NIGHT_GUARD)],
		"night_watch": [N.NIGHT_HEAL],
		"stand_deliver": [N.FAN_SLOW],
		"point_blank": [pct(N.FAN_CLOSE - 1.0), N.FAN_CLOSE_REACH],
		"highwayman_entry": [float(BanditKit.FAN_KNIVES)],
		# Cartographer
		"star_reader_entry": [pct(CartographerKit.STAR_BONUS), SurveyNet.STAR_EVERY, CartographerKit.STAR_DAMAGE],
		"quick_stars": [SurveyNet.QUICK_STAR_EVERY],
		"guiding_star": [pct(SurveyNet.STAR_GUARD)],
		"north_star": [SurveyNet.STAR_HEAL],
		"dazzle_star": [SurveyNet.STAR_SLOW],
		"falling_star": [SurveyNet.FALL_EVERY, SurveyNet.FALL_DAMAGE, SurveyNet.FALL_RADIUS, SurveyNet.FALL_STUN],
		"worlds_traveler_entry": [pct(CartographerKit.GATE_SPEED), 2.0, CartographerKit.GATE_REST],
		"light_luggage": [pct(CartographerKit.GATE_SPEED + 0.2)],
		"grand_arrival": [SurveyNet.GATE_BURST, SurveyNet.GATE_BURST_RADIUS],
		"veiled_passage": [SurveyNet.GATE_HIDE],
		"rift_road": [SurveyNet.RIFT_STUN],
		"pathfinder_entry": [CartographerKit.FIND_GAP, CartographerKit.FIND_REST],
		"keen_eye": [CartographerKit.FIND_REST - 8.0],
		"wanderer": [CartographerKit.FIND_GAP - 7.0],
		# Commander
		"composure": [pct(1.0 - CommanderKit.TRAINED_COMMAND_CD / CommanderKit.COMMAND_CD)],
		"warlock": [WeaponDefs.DAMAGE * 1.8, 0.8, 16.0],
		"storm_training": [70.0],
		"last_command_warlock": [CommanderKit.STORM_TIME, CommanderKit.STORM_RADIUS, 16.0, CommanderKit.LAST_CD],
		"gunner": [16.0],
		"bayonet_drill": [N.BAYONET_STAGGER],
		"last_command_gunner": [CommanderKit.BARRAGE_RADIUS, CommanderKit.BARRAGE_DELAY, CommanderKit.BARRAGE_TIME, CommanderKit.FIRE_TIME, CommanderKit.FIRE_DPS, 16.0, CommanderKit.LAST_CD],
		"vanguard": [pct(CommanderKit.RALLY_SPEED), CommanderKit.RALLY_TIME, 16.0],
		"banner_reach": [N.BANNER_REACH, CommanderKit.RALLY_RADIUS],
		"rally_recovery": [N.RALLY_HEAL],
		"last_command_vanguard": [35.0, pct(CommanderKit.LAST_RALLY_DAMAGE), CommanderKit.LAST_RALLY_TIME, 20.0, CommanderKit.LAST_CD],
		# Class Upgrades
		"item:oathkeeper": [4.0, 20.0],
		"item:rain_of_arrows": [Player.RAIN_ARROWS, 2.0],
		"item:trap_satchel": [float(Player.TRAPS_CARRIED), Player.TRAP_ARMING],
		"item:blade_flurry": [Player.FLURRY_TIME, pct(Player.FLURRY_RATE - 1.0)],
		"item:undying_rage": [Player.RAGE_TIME, pct(Player.RAGE_SPEED - 1.0), 30.0, Player.RAGE_COOLDOWN],
		"item:shadow_shroud": [float(Player.SHROUD_KILLS), Player.SHROUD_TIME],
		"item:snake": [5.0],
		"item:last_rites": [HeavyArts.RITES_REACH, HeavyArts.RITES_HEAL, HeavyArts.RITES_BURN],
		"item:faultline": [HeavyArts.FAULT_REACH, HeavyArts.FAULT_DAMAGE, HeavyArts.FAULT_SLOW],
		"item:lance_charge": [UpgradeKit.CHARGE_REACH, UpgradeKit.CHARGE_DAMAGE],
		"item:consecration": [UpgradeKit.CONSECRATE_TIME, UpgradeKit.CONSECRATE_RADIUS, UpgradeKit.CONSECRATE_HEAL],
		"item:grave_call": [float(UpgradeKit.GRAVE_RAISED), UpgradeKit.GRAVE_REACH, UpgradeKit.GRAVE_RECENT, UpgradeKit.GRAVE_TIME],
		"item:frost_nova": [UpgradeKit.NOVA_RADIUS, UpgradeKit.NOVA_DAMAGE, UpgradeKit.NOVA_FREEZE],
		"item:hall_of_mirrors": [UpgradeKit.MIRROR_REST],
	}


## Numbers found in data: as they are, and as the percentages they read as.
static func _collect(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k: Variant in v:
			_collect(v[k], out)
	elif v is Array:
		for x: Variant in v:
			_collect(x, out)
	elif v is float or v is int:
		var f := absf(float(v))
		out.append(f)
		out.append(roundf(f * 100.0))
		if f > 1.0 and f < 3.0:
			out.append(roundf((f - 1.0) * 100.0)) # a multiplier, read as "+35%"


func _audit(key: String, words: String, data: Array) -> void:
	var allowed: Array = []
	for d: Variant in data:
		_collect(d, allowed)
	for f: float in facts().get(key, []):
		allowed.append(f)
	var re := RegEx.new()
	re.compile("(?<![A-Za-z])(\\d+(?:\\.\\d+)?)")
	var wrong := PackedStringArray()
	for m in re.search_all(words):
		var n := float(m.get_string(1))
		if not allowed.any(func(a: float) -> bool: return absf(a - n) < 0.011):
			wrong.append(m.get_string(1))
	if not wrong.is_empty():
		failures.append("%s says %s, which nothing in the game backs: \"%s\"" % [key, ", ".join(wrong), words])


func run() -> Array[String]:
	failures.clear()
	for cls: String in ClassDefs.ALL:
		var d: Dictionary = ClassDefs.ALL[cls]
		var tree := AbilityData.tree(cls)
		var core_kill: Array = []
		for row: Array in tree["core"]:
			for ab: Dictionary in row:
				core_kill.append(ab)
		var start := RegEx.new()
		start.compile("Starts with an? ([A-Z][A-Za-z ]+?)(?: and| powered|,|\\.)")
		var said := start.search(str(d["desc"]))
		if said and said.get_string(1) != str(WeaponDefs.ALL[d["weapon"]]["name"]):
			failures.append("class:%s says it starts with a %s, but it starts with the %s" % [cls, said.get_string(1), WeaponDefs.ALL[d["weapon"]]["name"]])
		_audit("class:" + cls, str(d["desc"]) + " " + ClassPresentation.description(cls), [d.get("hp", 0), d.get("speed", 0), d.get("arrows", 0), d.get("kill_heal", 0), d.get("kill_arrows", 0)])
		var all: Array = core_kill.duplicate()
		for spec: Dictionary in tree["specs"]:
			all.append(spec["entry"])
			for row: Array in spec["path"]:
				all.append_array(row)
			all.append(spec["final"])
			_audit("spec:" + str(spec["id"]), str(spec["desc"]), [spec["entry"]["add"], spec["entry"]["on"]])
		for ab: Dictionary in all:
			_audit(str(ab["id"]), str(ab["desc"]), [ab["add"], ab["on"], WorldLight.ARTS.get(ab["id"], {}), BanditKit.ARTS.get(ab["id"], {})])
	for id: String in ShopDefs.ITEMS:
		var item: Dictionary = ShopDefs.ITEMS[id]
		_audit("item:" + id, str(item["desc"]), [item.get("art", {}), item.get("effect", {})])
	return failures
