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
		# Harpooner
		"class:harpooner": [HarpoonerKit.RETURN],
		"reaver_entry": [HarpoonerKit.BLOOD_TIME, HarpoonerKit.BLOOD_HEAL, pct(HarpoonerKit.BLOOD_SPEED), pct(HarpoonerKit.HAUL_MARK - 1.0), HarpoonerKit.HAUL_MARK_TIME],
		"sea_dog": [pct(HarpoonerKit.BLOOD_GUARD)],
		"grapple_slam": [HarpoonerKit.SLAM_DAMAGE, HarpoonerKit.SLAM_RADIUS],
		"no_quarter": [HarpoonerKit.REFUND],
		"red_tide": [HarpoonerKit.RED_TIDE_REACH],
		"rigger_entry": [HarpoonerKit.RIG_REACH, HarpoonerKit.RIG_TIME, HarpoonerKit.TRIP_STUN, HarpoonerKit.TRIP_SLOW, float(HarpoonerKit.RIG_LINES)],
		"barbed_line": [HarpoonerKit.BARB_DAMAGE],
		"snare_knot": [HarpoonerKit.SNARE],
		"lifeline": [pct(HarpoonerKit.LIFELINE_SPEED), HarpoonerKit.LIFELINE_TIME],
		"crows_nest": [pct(HarpoonerKit.CROWS_NEST), HarpoonerKit.CROWS_REACH],
		"leviathan_hunter_entry": [HarpoonerKit.GREAT_DAMAGE, HarpoonerKit.GREAT_PIN, HarpoonerKit.MARK_TIME, pct(HarpoonerKit.MARK - 1.0)],
		"whale_oil": [pct(HarpoonerKit.BIG_GAME)],
		"flensing": [HarpoonerKit.FLENSE_HEAL],
		"leviathans_bane": [pct(HarpoonerKit.BANE - 1.0)],
		# Tidecaller
		"class:tidecaller": [TidecallerKit.TRIDENT_TIDE],
		"long_haft": [TidecallerKit.LONG_HAFT_REACH, TidecallerKit.LONG_HAFT_HITS],
		"skewer": [TidecallerKit.SKEWER_HOLD, TidecallerKit.SKEWER_TIDE],
		"tide_deep_breath": [TidecallerKit.DEEP_BREATH_TIDE],
		"brine": [TidecallerKit.BRINE_SLOW, pct(TidecallerKit.BRINE_HARD)],
		"tidewarden_entry": [TidecallerKit.SHELL_TIME, TidecallerKit.SHELL_BASE, TidecallerKit.SHELL_REFILL, TidecallerKit.BURST_RADIUS, TidecallerKit.BURST_DAMAGE],
		"thick_shell": [TidecallerKit.SHELL_THICK],
		"coral_barbs": [TidecallerKit.CORAL_DAMAGE],
		"salt_mend": [TidecallerKit.SALT_MEND],
		"breakwater": [TidecallerKit.BREAKWATER_STUN],
		"high_surge": [TidecallerKit.SURGE_REACH, pct(TidecallerKit.SURGE_HARD)],
		"tidal_ward": [TidecallerKit.WARD_REACH],
		"unbroken_sea": [TidecallerKit.UNBROKEN_TIME, pct(TidecallerKit.UNBROKEN_HEAL)],
		"stormcaller_entry": [TidecallerKit.SOAK_TIME, TidecallerKit.SPEAR_RANGE, TidecallerKit.SPEAR_DAMAGE, TidecallerKit.CHAINS, TidecallerKit.CHAIN_REACH, TidecallerKit.CHAIN_DAMAGE, TidecallerKit.CHAIN_JOLT],
		"charged_tines": [pct(TidecallerKit.CHARGED_TINES)],
		"long_throw": [TidecallerKit.LONG_THROW],
		"conductor": [TidecallerKit.CONDUCTOR],
		"static_charge": [TidecallerKit.STATIC_SLOW],
		"squall_step": [TidecallerKit.SQUALL_STEP],
		"rain_cloak": [TidecallerKit.RAIN_COUNT, TidecallerKit.RAIN_REACH, pct(TidecallerKit.RAIN_CLOAK)],
		"downpour": [TidecallerKit.DOWNPOUR],
		"maelstrom": [TidecallerKit.MAELSTROM_TIME, TidecallerKit.MAELSTROM_GAP, TidecallerKit.MAELSTROM_REACH, TidecallerKit.MAELSTROM_DAMAGE],
		"deepcaller_entry": [TidecallerKit.SERPENT_HP, TidecallerKit.SERPENT_TIME, TidecallerKit.SERPENT_TAUNT],
		"thick_scales": [pct(TidecallerKit.THICK_SCALES)],
		"long_tide": [TidecallerKit.LONG_TIDE],
		"pack_hunter": [pct(TidecallerKit.PACK_HUNTER)],
		"venom_of_the_deep": [TidecallerKit.VENOM.x, TidecallerKit.VENOM.y],
		"coil": [TidecallerKit.COIL_HOLD],
		"shed_skin": [TidecallerKit.SHED_HEAL, pct(TidecallerKit.SHED_REST)],
		"leviathans_child": [pct(TidecallerKit.CHILD_HP), TidecallerKit.CHILD_REACH],
		# Ferryman
		"class:ferryman": [FerrymanKit.CROSS_REACH, FerrymanKit.CROSS_HEAL],
		"toll_bell": [FerrymanKit.TOLL_BELL],
		"ferrymans_due": [FerrymanKit.DUE_HEAL],
		"tollkeeper_entry": [FerrymanKit.TOLL_REACH, FerrymanKit.DEBT_TIME + 1.0, pct(FerrymanKit.DEBT - 1.0), FerrymanKit.OBOL_HEAL, pct(FerrymanKit.OBOL_DAMAGE), float(FerrymanKit.OBOLS)],
		"interest": [FerrymanKit.INTEREST],
		"all_must_pay": [FerrymanKit.TOLL_WIDE],
		"silver_tongue": [pct(FerrymanKit.OBOL_SPEED)],
		"debt_collector": [pct(FerrymanKit.COLLECT_BELOW)],
		"boatman_entry": [FerrymanKit.CARRY_REACH, FerrymanKit.BOAT_STUN],
		"black_water": [FerrymanKit.WAKE_TIME],
		"ferry_fare": [FerrymanKit.LEECH],
		"safe_passage": [pct(FerrymanKit.SAFE_PASSAGE), FerrymanKit.SAFE_TIME],
		"the_last_ferry": [FerrymanKit.SECOND_TRIP],
		"psychopomp_entry": [FerrymanKit.SOUL_REACH, float(FerrymanKit.SOULS), FerrymanKit.SOUL_CAST_REACH + 2.0, FerrymanKit.SOUL_DAMAGE, FerrymanKit.SOUL_HEAL],
		"soul_ward": [pct(FerrymanKit.SOUL_WARD)],
		"restless_dead": [FerrymanKit.SOUL_AURA_REACH, FerrymanKit.SOUL_AURA],
		"reaping": [2.0],
		"gate_of_the_dead": [float(FerrymanKit.GATE_SOULS)],
		# Commander
		"composure": [pct(1.0 - CommanderKit.TRAINED_COMMAND_CD / CommanderKit.COMMAND_CD)],
		"warlock": [WeaponDefs.DAMAGE * 1.8, 0.8, 16.0],
		"storm_training": [70.0],
		"last_command_warlock": [CommanderKit.STORM_TIME, CommanderKit.STORM_RADIUS, CommanderKit.STORM_DPS, 1.0 / CommanderKit.STORM_STRIKE_EVERY, CommanderKit.STORM_STRIKE_DAMAGE, 16.0, CommanderKit.LAST_CD],
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
		"item:mist_reinforcements": [pct(Garrison.REINFORCED - 1.0), Ally.PERCH_REACH] + range(1, ShopDefs.MAP_LEVELS + 1).map(func(n: int) -> float: return float(n)),
		"item:wild_hunt": [UpgradeKit.HUNT_TIME, UpgradeKit.HUNT_EVERY, UpgradeKit.HUNT_REACH],
		"item:mist_wake": [PathUpgrades.MIST_WAKE_RADIUS * 2.0, PathUpgrades.MIST_WAKE_TIME, PathUpgrades.MIST_WAKE_DPS],
		"item:torn_rifts": [PathUpgrades.TORN_RIFT_DAMAGE, PathUpgrades.TORN_RIFT_RADIUS],
		"item:soul_link": [PathUpgrades.SOUL_LINK_HEAL],
		"item:dragon_spin": [PathUpgrades.DRAGON_SPIN_TIME, float(PathUpgrades.DRAGON_SPIN_HITS), PathUpgrades.DRAGON_SPIN_DAMAGE, PathUpgrades.DRAGON_SPIN_REACH],
		"item:fighting_body": [PathUpgrades.FIGHTING_BODY_REACH, PathUpgrades.FIGHTING_BODY_DAMAGE, pct(PathUpgrades.FIGHTING_BODY_GUARD)],
		"item:avalanche": [PathUpgrades.AVALANCHE_DELAY, PathUpgrades.AVALANCHE_STUN],
		"item:healing_mist": [PathUpgrades.HEALING_MIST_RADIUS, PathUpgrades.HEALING_MIST_TIME, PathUpgrades.HEALING_MIST_HEAL],
		"item:plague_censer": [PathUpgrades.CENSER_TIME, PathUpgrades.CENSER_RADIUS, PathUpgrades.CENSER_DPS],
		"item:rat_tide": [float(PathUpgrades.RAT_TIDE_RATS), PathUpgrades.RAT_TIDE_REACH, PathUpgrades.RAT_TIDE_DAMAGE, PathUpgrades.RAT_TIDE_STUN, PathUpgrades.RAT_TIDE_POISON.x, PathUpgrades.RAT_TIDE_POISON.y],
		"item:field_turret": [PathUpgrades.FIELD_TURRET_TIME],
		"item:tesla_coil": [float(PathUpgrades.TESLA_TARGETS), PathUpgrades.TESLA_REACH, PathUpgrades.TESLA_EVERY, PathUpgrades.TESLA_TIME, PathUpgrades.TESLA_DAMAGE],
		"item:grapeshot": [float(PathUpgrades.GRAPESHOT_PELLETS), PathUpgrades.GRAPESHOT_DAMAGE],
		"item:shield_wall": [PathUpgrades.SHIELD_WALL_RADIUS, PathUpgrades.SHIELD_WALL_AMOUNT, PathUpgrades.SHIELD_WALL_TIME],
		"item:encore": [float(CrownUpgrades.ENCORE_EVERY), CrownUpgrades.ENCORE_REACH, pct(CrownUpgrades.ENCORE_POWER - 1.0), CrownUpgrades.ENCORE_DOWN],
		"item:shattered_mirror": [float(CrownUpgrades.SHARDS), CrownUpgrades.SHARD_REACH, CrownUpgrades.SHARD_DAMAGE, CrownUpgrades.SHARD_BLEED.x, CrownUpgrades.SHARD_BLEED.y],
		"item:event_horizon": [CrownUpgrades.HORIZON_TIME, CrownUpgrades.HORIZON_REACH, CrownUpgrades.HORIZON_DPS, CrownUpgrades.HORIZON_COLLAPSE, CrownUpgrades.HORIZON_COLLAPSE_REACH],
		"item:star_shower": [float(CrownUpgrades.SHOWER_STARS), CrownUpgrades.SHOWER_DAMAGE, CrownUpgrades.SHOWER_RADIUS, CrownUpgrades.SHOWER_STUN],
		"item:open_door": [pct(CrownUpgrades.DOOR_BELOW), CrownUpgrades.DOOR_HEAL, CrownUpgrades.DOOR_GUARD, CrownUpgrades.DOOR_REST, CrownUpgrades.DOOR_MIN],
		"item:trailblazer": [CrownUpgrades.BLAZE_GAP, CrownUpgrades.BLAZE_TIME, pct(CrownUpgrades.BLAZE_SPEED)],
		"item:lucky_fingers": [float(CrownUpgrades.LUCKY_ONE_IN)],
		"item:contract": [pct(CrownUpgrades.CONTRACT_MARK - 1.0), CrownUpgrades.CONTRACT_HEAL, CrownUpgrades.CONTRACT_REFUND],
		"item:toll_road": [float(CrownUpgrades.TOLL_EVERY), CrownUpgrades.TOLL_PIN],
		"item:trappers_guild": [TrappersGuild.SNARE_HOLD, TrappersGuild.SNARE_DAMAGE, TrappersGuild.SNARE_REARM, TrappersGuild.CACHE_EVERY, TrappersGuild.FIRE_REACH, TrappersGuild.FIRE_HEAL] + range(1, ShopDefs.MAP_LEVELS + 1).map(func(n: int) -> float: return float(n)),
		# Weapons whose rules are written in code
		"weapon:flare_pistol": [Flare.BURN_RADIUS, Flare.TIME, Flare.REVEAL_RADIUS],
		"weapon:blowgun": [pct(Player.POISON_HURT - 1.0)],
		# Port Vael's foes (their special moves are VaelMind's), and the clock times they come at,
		# read as minutes and seconds ("around 3:00").
		"enemy:siren": [VaelMind.SONG_REACH, VaelMind.SONG_PULL],
		"enemy:kraken": [VaelMind.KRAKEN_SWEEP_REACH, VaelMind.KRAKEN_INK_BLIND, VaelMind.KRAKEN_PULL_REACH, VaelMind.KRAKEN_PULL_TIME, VaelMind.KRAKEN_BROOD],
		"enemy:press_gang": [VaelMind.NET_HOLD],
		"enemy:mutant_bee": [FontaMind.STING_POISON],
		"enemy:beehive": [float(FontaMind.HIVE_RELEASE), float(FontaMind.HIVE_BEES), float(FontaMind.HIVE_HONEY)],
		"enemy:mutant_wasp": [FontaMind.WASP_POISON],
		"enemy:mutant_snail": [FontaTrails.TRAIL_LIFE],
		"enemy:wasp_hive_snail": [FontaMind.NEST_EVERY, float(FontaMind.NEST_WASPS)],
		"enemy:mutant_spider": [FontaMind.PERCH_WAKE, FontaMind.WEB_ROOT, FontaMind.WEB_POISON],
		"enemy:ember_moth": [FontaMind.MOTH_TELL, FontaMind.DUST_BLIND],
		"enemy:cult_worshipper": [CultMind.FERVOUR_REACH, CultMind.FERVOUR_TIME],
		"enemy:cult_priest": [CultMind.PRIEST_RANGE.x, CultMind.PRIEST_RANGE.y, CultMind.ELIXIR_POISON, CultMind.ELIXIR_SLOW, CultMind.ANOINT_EVERY, CultMind.ANOINT_REACH, CultMind.ANOINT_HASTE],
		"enemy:cult_guardian": [CultMind.BASH_STUN],
		"enemy:tide_witch": [float(VaelMind.WAVES), VaelMind.WAVE_SLOW, float(VaelMind.RAISE_COUNT)],
		"enemy:harbourmaster": _clock(Director.HARBOURMASTER_AT),
		"enemy:lighthouse_keeper": [VaelMind.FLASH_REACH, VaelMind.FLASH_STUN, 2.0] + _clock(Director.KEEPER_AT),
		"enemy:kraken_arm": _clock(MistTide.TURN * 3.0),
		"enemy:hollow_sovereign": [float(VaelMind.UNDERTOW_WAVES), VaelMind.SURGE, float(VaelMind.COURT)] + _clock(510.0),
		"power:sunken_crown": [PowerDefs.CROWN_REGEN] + _clock(Director.CROWN_AT),
		# Last Light
		"enemy:leviathan": [float(VaelMind.TIDAL_WAVES), LastLight.DIM_RADIUS, LastLight.DIM_TIME, float(VaelMind.DIVE_RAISES)],
		"boon:deep_lungs": [Boons.DEEP_GRACE],
		"boon:lantern_bearer": [Boons.BEARER_REACH],
	}


## A time on the night's clock, as the words write it ("4:30"): its minutes and its seconds.
static func _clock(seconds: float) -> Array:
	return [floorf(seconds / 60.0), fmod(seconds, 60.0)]


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
		if d.has("second") and not str(d["desc"]).contains(str(WeaponDefs.ALL[d["second"]]["name"])):
			failures.append("class:%s starts with a %s as well, but does not say so" % [cls, WeaponDefs.ALL[d["second"]]["name"]])
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
		# A Map Upgrade's levels, as the Armory lists them, are held to the same numbers.
		_audit("item:" + id, str(item["desc"]) + " " + " ".join(PackedStringArray(item.get("levels", []))), [item.get("art", {}), item.get("effect", {})])
	# Port Vael's foes and the Sunken Crown: what the Codex says of them is what they do.
	for zid: String in ZombieDefs.ALL:
		if SpawnRules.is_vael(ZombieDefs.ALL[zid]):
			_audit("enemy:" + zid, str(ZombieDefs.ALL[zid]["desc"]), [ZombieDefs.ALL[zid], [VaelSkyMind.REACH, VaelSkyMind.RECOVERY, 1.5, 2.0]] if zid in VaelSkyMind.KINDS else [ZombieDefs.ALL[zid]])
	_audit("power:sunken_crown", str(PowerDefs.ALL[PowerDefs.CROWN]["desc"]), [PowerDefs.CROWN_DAMAGE])
	_audit("power:oracle_eye", str(PowerDefs.ALL[PowerDefs.EYE]["desc"]), [PowerDefs.EYE_RANGE, roundf((PowerDefs.EYE_DAMAGE - 1.0) * 100.0)])
	for bid: String in Boons.ALL:
		_audit("boon:" + bid, str(Boons.ALL[bid]["desc"]), [Boons.ALL[bid].get("add", {})])
	# Weapons: every number a weapon's words quote (Codex, Armory) is one of its own, or a fact.
	for wid: String in WeaponDefs.ALL:
		var wd: Dictionary = WeaponDefs.ALL[wid]
		_audit("weapon:" + wid, str(wd.get("desc", "")), [wd])
	return failures
