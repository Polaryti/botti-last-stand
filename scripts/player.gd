class_name Player
extends Target
## First-person player. All input goes through plain variables, so touch, keyboard
## and (later) network input can drive the same code.

const WALK_SPEED := 5.6
const JUMP_SPEED := 7.0
const GRAVITY := 20.0
const BASE_FOV := 72.0
const BASE_ARROWS := 60
const BURN_DPS := 5.0
const BASE_MANA := 100.0
const MANA_REGEN := 8.0
const BRIDGE_KNOCK := 13.0
# The Monk.
const KI_PER_HIT := 5.0 # the first thing each blow lands on
const KI_PER_EXTRA := 1.0 # each other thing the same blow lands on
const KI_PER_SHOT := 2.5
const SWEEP_REACH := 3.4
const VAULT_REACH := 9.0
const VAULT_POWER := 1.4
const SPIRIT_TIME := 4.0
const SPIRIT_HEAL := 10.0
const SPIRIT_SPEED := 1.3
const SKIN_MAX := 0.6
const SKIN_UNMOVED := 0.8
const SKIN_GROWS := 0.1 # a second
const SKIN_WEARS := 0.3 # a second
const SKIN_STRONG := 0.3 # from here Recoil and Rooted Blows work
const SKIN_WAITS := 0.4 # standing still this long before it starts
# The Adept.
const STANCES: Array[String] = ["wind", "stone", "flame"]
const STANCE_ADDS := {"wind": {"speed": 0.25, "melee_damage": -0.3}, "stone": {"damage_taken": -0.3, "knock": 1.5}, "flame": {"damage_taken": 0.15}, "void": {}}
const STANCE_NAMES := {"wind": "Wind", "stone": "Stone", "flame": "Flame", "void": "Void"}
const STANCE_ICONS := {"wind": "wind", "stone": "mountain", "flame": "flame", "void": "moon"}
const STANCE_COLOURS := {"wind": Color(0.75, 0.95, 1.0), "stone": Color(0.72, 0.68, 0.6), "flame": Color(1.0, 0.55, 0.15), "void": Color(0.62, 0.36, 0.95)}
const ECHO_POWER := 0.5
const ECHO_AFTER := 0.13
const VOID_TIME := 5.0
const MIRROR_WINDOW := 1.0
const SHIELD_BASE := 0.3
const HORSE_KILLS := 10
const HORSE_TIME := 15.0
const HORSE_SPEED := 1.9
const CHARIOT_SPEED := 0.8 # slower than walking: you ride it to fight, not to get away
const CHARIOT_TIME := 30.0
const TRAMPLE_DAMAGE := 40.0
const CORE_STEPS := 3
const LEVEL_UP_GUARD := 3.0 # seconds nothing can hurt you after gaining a level
const PVP_STATUS := 0.6 # a freeze or a stun lasts this much as long on a player
const PVP_STATUS_GAP := 1.5
const FOG_XP := 0.5
const WADE_SPEED := 0.7
const RAIN_REACH := 30.0
const RAIN_RADIUS := 5.0
const RAIN_ARROWS := 8
const RAIN_POWER := 0.8 # each of the eight strikes in the volley
const TRAPS_CARRIED := 5
const TRAP_ARMING := 3.0
const FLURRY_TIME := 4.0
const FLURRY_RATE := 1.6
const RAGE_TIME := 5.0
const RAGE_COOLDOWN := 60.0
const RAGE_SPEED := 1.3
const SHROUD_KILLS := 8
const SHROUD_TIME := 3.0
const POISON_HURT := 1.05 # poisoned: everything hurts this much more
const BLEED_SPEED := 0.9 # bleeding: this much of your speed is left
const DEBUFF_DPS := 3.0
const SWING_HIT := 0.3 # how far through a swing the blow lands
const BASH := {"kind": WeaponDefs.Kind.MELEE, "rate": 0.8, "range": 2.3, "cone": 110.0, "max_hits": 1, "knock": 3.5, "power": 0.6}

signal damaged(amount: float, source: String)
signal command_target_requested

var world: World
var class_id := "infantry"
## A bot on the host is a Player too, with a BotPlayer steering it. Then these are set.
var bot: BotPlayer
var bot_peer := 0
var bot_class := "infantry"
var bot_pet := "wolf"
var shun_weapon := "" # a weapon you just put down is not picked up again until you walk away
var shun_at := Vector3.INF
var _ki_swing := -1
var hp := 100.0
var kills := 0
var arrows := 0
var slots: Array = [null, null]
var current := 0
var yaw := 0.0
var pitch := 0.0
var powers := {} # power id -> seconds left

# Progress and abilities.
var level := 1
var xp := 0
var points := 0
var chosen := {} # step index -> ability id
var mods := {"melee_damage": 1.0, "melee_rate": 1.0, "melee_reach": 0.0, "melee_cone": 0.0, "melee_hits": 0.0,
	"knock": 1.0, "ranged_damage": 1.0, "ranged_rate": 1.0, "ranged_power": 1.0, "speed": 1.0, "max_hp": 0.0,
	"damage_taken": 1.0, "ki_gain": 1.0, "noise": 1.0, "sight": 1.0, "arrow_save": 0.0, "max_arrows": 0.0, "pierce": 0.0, "bounces": 0.0,
	"shield": 0.0, "thorns": 0.0, "mana": 0.0, "mana_regen": 1.0, "spell_damage": 1.0, "spell_rate": 1.0, "spell_cost": 1.0,
	"horse_speed": 1.0, "horse_time": 0.0, "horse_kills": 0.0, "trample": 1.0, "riding_armor": 1.0, "riding_damage": 1.0,
	"riding_crit": 0.0, "riding_ranged": 1.0, "riding_regen": 0.0, "familiar_time": 1.0, "potion_time": 1.0,
	"crit_chance": 0.0, "crit_mult": 2.0, "backstab": 0.0, "dodge": 0.0, "regen": 0.0, "burn_damage": 1.0,
	"ally_damage": 1.0, "ally_hp": 1.0, "ally_time": 1.0, "ally_cap": 4.0, "summon_extra": 0.0, "wolves": 0.0,
	"trap_damage": 50.0, "trap_cd": 0.0, "trap_cap": 3.0, "trap_carry": 0.0, "trap_stun": 0.0,
	"burst_damage": 45.0, "burst_radius": 6.0, "burst_cost": 35.0, "burst_cd": 7.0, "art_cost": 1.0, "art_cd": 1.0,
	"leap_range": 9.0, "leap_damage": 0.0, "rift_hops": 3.0, "rift_damage": 40.0, "summon_n": 1.0, "summon_time": 10.0,
	"cover": 0.0, "cover_radius": 0.0, "dome_time": 3.0, "dome_radius": 6.0,
	"bomb_damage": 70.0, "bomb_radius": 4.5, "bomb_fire": 4.0, "bomb_count": 1.0, "bomb_throw": 1.0,
	"turret_rate": 1.0, "turret_damage": 1.0,
	"volley_darts": 7.0, "volley_jumps": 3.0, "flask_time": 3.0, "flask_radius": 6.0, "inv_damage": 1.0, "inv_heal": 0.0,
	"swap_range": 9.0, "swap_burst": 50.0, "swap_radius": 4.0, "swap_decoys": 1.0, "swap_decoy_time": 5.0}
var flags := {}
var spec_id := ""
var _buffs := {} # key -> {stat, val, left, stacks}
var _triggers := {} # event -> list of effect dictionaries with runtime counters
var invis_left := 0.0
var guard_left := 0.0
var dome_left := 0.0
var oath_reserve := 0.0
var _riposte_cd := 0.0
var _kill_shot_cd := 0.0
var _sacred_cd := 0.0
var aiming_art := false
var _gate_wait := 0.0
var _safe_spot := Vector3.ZERO
var trap_charges := 0
var shadow_kills := 0
var flurry_left := 0.0
var rage_left := 0.0
var _rage_cd := 0.0
var _rain_spot := Vector3.ZERO
var _rain_wait := 0.0
var _wolf_timer := 0.0
var _low_armed := true
var _assassin_kill := false
var mana := 0.0
var spirit_left := 0.0
var _spirit_home := Vector3.ZERO
var _spirit_taken := 0.0
var _bo_hits := 0
var _sweep_now := false
var _vaulting := false
var _next_hit_mult := 1.0
var stone_skin := 0.0
var _still_for := 0.0
var _skin_step := 0
var command_target := Vector3.ZERO
var command_target_ready := false
var _banner: MeshInstance3D
var _war_attacks := 0
var _bayonet_pending := false
var _stance_mastered := false
var stance_hits := 0
var _transition_power := 1.0
var mirror_guard_left := 0.0
var _void_extensions := 0
var stance := ""
var void_left := 0.0
var _void_hits := {}
var _echo_left := -1.0
var _second_sweep := -1.0
var _last_hit := 0.0
var _last_hit_left := 0.0
var shield_tier := 0
var horse_progress := 0
var riding_left := 0.0
var _shot_count := 0
var _flail_stacks := 0
var _flail_idle := 0.0
var _axe_out := false
var _trampled := {}

var input_move := Vector2.ZERO
var input_fire := false
var input_jump := false
var zoomed := false
var nearby_weapon: Pickup = null
var named_item: Pickup = null # the closest item, whose name the HUD shows
var hurt_flash := 0.0
var heal_flash := 0.0
var hit_by := "" # whoever hurt the player last, for the end screen
var last_foe := 0 # the other player who hurt this one last, if any
var attack_count := 0
var burst_cd_left := 0.0
var art_cd_left := 0.0
var _cast_kind := ""
var _cast_left := 0.0
var _leap_t := -1.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _rift_targets: Array = [] # enemies and, in a fight, other players
var _rift_timer := 0.0
var _lit := false
var _lit_timer := 0.0
var _warm := false
var _vm_left: MeshInstance3D
var _mist_trail := 0.0
var fog_flash := 0.0
var passenger := 0 # who is riding behind you
var ride_behind := 0 # whose horse you are on
var wood := 0
var hurt_from := Vector3.ZERO
var hurt_dir_time := 0.0
var level_flash := 0.0
const LEVEL_GOLD := Color(1.0, 0.8, 0.36)
var _shake := 0.0
var _buzz_at := -10.0
var _dawn_bright := 0.0
var hit_marker := 0.0
var hit_head := false
var burn_time := 0.0
var poison_left := 0.0
var bleed_left := 0.0
var _debuff_tick := 0.0
var frozen_left := 0.0 # frozen or stunned by another player: you can look around, and that is all
var is_iced := false
var _status_immune := 0.0 # just after a freeze or stun nobody can start another, or it never ends
var slowed_left := 0.0
var toast := ""
var toast_time := 0.0

var head: Node3D
var camera: Camera3D
var _vm_root: Node3D
var _vm_mesh: WeaponVisual
var _shield_node: MeshInstance3D
var _horse: Node3D
var _horse_legs: Array[Node3D] = []
var _chariot: ChariotModel
var _turret_timer := 0.0
var _spike_timer := 0.0
var _next_invention := ""
var _last_invention := ""
var _volley_left := 0
var _volley_timer := 0.0
var _later: Array[Dictionary] = []
var _light: OmniLight3D
var _familiars := {} # id -> MeshInstance3D
var _cooldown := 0.0
var _kick := 0.0
var _swing := 1.0
var _melee_pending := -1.0
var _swing_time := 0.4
var _swing_keys := ""
var _swing_side := false
var _sway := Vector2.ZERO
var _bash_anim := 0.0
var _land_dip := 0.0
var _smear: MeshInstance3D
var _smear_left := 0.0
var _smear_roll := 0.0
var _vm_arrow: MeshInstance3D
var _vm_orb: MeshInstance3D
var _reload := 1.0
var _bashing := false
var _bob := 0.0
var _switch_anim := 0.0
var _step_timer := 0.0
var _noise_timer := 0.0
var _was_on_floor := true
var _keyboard_moving := false
var _auto_jump_cd := 0.0
var _angel_timer := 0.0
var _archer_timer := 0.0
var _thunder_timer := 0.0
var _imp_timer := 0.0
var _bell_timer := 0.0
var _rat_timer := 0.0


func _init(owner_world: World, as_bot := 0) -> void:
	world = owner_world
	bot_peer = as_bot
	collision_layer = LAYER if as_bot == 0 else 0 # a bot is hit through the body everyone sees
	collision_mask = 1 | Terrain.LAYER | Terrain.BARRIER
	floor_snap_length = 0.55
	floor_constant_speed = true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.75
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	head = Node3D.new()
	head.position.y = 1.58
	add_child(head)
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.near = 0.06
	camera.far = 460.0 if owner_world.terrain.has_islands() else 100.0
	head.add_child(camera)
	_vm_root = Node3D.new()
	camera.add_child(_vm_root)
	_vm_mesh = WeaponVisual.new()
	_vm_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vm_mesh.layers = 2
	_vm_root.add_child(_vm_mesh)
	if as_bot != 0:
		set_process_unhandled_input(false)
		visible = false
	_add_lights(as_bot == 0)
	_smear = MeshInstance3D.new()
	_smear.mesh = WeaponAnim.smear_mesh()
	_smear.layers = 2
	_smear.visible = false
	_smear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(_smear)
	_vm_arrow = MeshInstance3D.new()
	_vm_arrow.layers = 2
	_vm_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vm_arrow.visible = false
	_vm_root.add_child(_vm_arrow)
	_vm_left = MeshInstance3D.new()
	_vm_left.layers = 2
	_vm_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vm_left.visible = false
	camera.add_child(_vm_left)
	_vm_orb = MeshInstance3D.new()
	_vm_orb.mesh = WeaponAnim.orb_mesh()
	_vm_orb.layers = 2
	_vm_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vm_orb.visible = false
	_vm_root.add_child(_vm_orb)


func _ready() -> void:
	setup_class(bot_class if bot_peer != 0 else Game.player_class)


## A small warm glow so the night stays dark without hiding what is close. A bot carries none:
## lights cost a phone a lot, and nobody looks through a bot's eyes.
func _add_lights(on: bool) -> void:
	if not on:
		return
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.55)
	_light.light_energy = 0.9
	_light.omni_range = 11.0
	_light.omni_attenuation = 1.2
	_light.position = Vector3(0.2, -0.1, 0.1)
	_light.light_cull_mask = 5 # world and terrain; the held weapon would look burnt out this close
	head.add_child(_light)
	var hand_light := OmniLight3D.new()
	hand_light.light_color = Color(1.0, 0.82, 0.6)
	hand_light.light_energy = 0.55
	hand_light.omni_range = 2.5
	hand_light.light_cull_mask = 2
	hand_light.position = Vector3(0.05, 0.1, 0.1)
	head.add_child(hand_light)



func setup_class(id: String) -> void:
	if bot_peer != 0 and ClassDefs.ALL.get(id, {}).get("no_bots", false):
		id = "infantry"
	class_id = id
	var c: Dictionary = ClassDefs.ALL[id]
	slots = [c["weapon"], null]
	current = 0
	arrows = int(c["arrows"])
	mods["speed"] = float(c["speed"])
	mods["damage_taken"] = float(c.get("damage_taken", 1.0))
	mods["mana_regen"] = float(c.get("mana_regen", 1.0))
	hp = max_hp()
	mana = 0.0 if c.get("ki", false) else max_mana()
	if id == "adept":
		_enter_stance("wind")
	if c.get("shield", false):
		_refresh_shield()
	if c.get("horse", false):
		_build_horse() # ready now, not in the middle of the fight that earned it
		_horse.visible = false
	_equip()


func class_def() -> Dictionary:
	return ClassDefs.ALL[class_id]


func is_bot() -> bool:
	return bot_peer != 0


## Who this is on the network: this phone's own id, or the bot's.
func net_id() -> int:
	return bot_peer if bot_peer != 0 else Net.my_id()


func is_foe_peer(peer: int) -> bool:
	return Net.bots_foes(net_id(), peer)


## A sound of this player's: in your ears if it is you, from where they stand if it is a bot.
func sfx(sound: String, volume_db := 0.0, pitch := 1.0, min_gap := 0.03) -> void:
	if bot_peer == 0:
		Sfx.play(sound, volume_db, pitch, min_gap)
	else:
		Sfx.play_at(sound, global_position, world._player_camera_position(), volume_db - 3.0)


## Another player's status, from one of this player's blows or abilities.
func status_on(peer: int, kind: int, seconds: float) -> void:
	Net.status_peer(peer, kind, seconds, net_id())


## What is happening to this player, for everyone else to see on their body.
func status_bits() -> int:
	return (1 if burn_time > 0.0 else 0) | (2 if poison_left > 0.0 else 0) | (4 if bleed_left > 0.0 else 0) \
		| (8 if slowed_left > 0.0 else 0) | (16 if frozen_left > 0.0 and not is_iced else 0) | (32 if frozen_left > 0.0 and is_iced else 0) \
		| (64 if guard_left > 0.0 and guard_left < 900.0 else 0) | (128 if spec_id == "vanguard" else 0)


func _cast_anim(anim_name := "") -> void:
	if bot_peer != 0:
		Net.bot_cast(bot_peer, anim_name)
	else:
		Net.cast_anim(anim_name)


func max_hp() -> float:
	return float(class_def()["hp"]) + m("max_hp")


func max_mana() -> float:
	return BASE_MANA + m("mana") if class_def().get("mana", false) else 0.0


func max_arrows() -> int:
	return BASE_ARROWS + int(m("max_arrows"))


func eye_position() -> Vector3:
	return head.global_position


func weapon_id() -> String:
	var w: Variant = slots[current]
	return w if w else ""


func weapon_def() -> Dictionary:
	var w: Variant = slots[current]
	return WeaponDefs.ALL[w] if w else {}


func has_power(id: String) -> bool:
	return float(powers.get(id, 0.0)) > 0.0


func has_flag(f: String) -> bool:
	return flags.has(f)


## A stat including temporary buffs.
func m(stat: String) -> float:
	var v: float = mods[stat]
	if _buffs.is_empty():
		return v
	for b: Dictionary in _buffs.values():
		if b["stat"] == stat:
			v += float(b["val"]) * int(b["stacks"])
	return v


func is_riding() -> bool:
	return riding_left > 0.0


## Chivalry rides a horse. A Mechanic builds a war chariot, which works much the same.
func has_mount() -> bool:
	return class_def().get("horse", false) or spec_id == "mechanic"


func mount_kind() -> String:
	return "chariot" if spec_id == "mechanic" else "horse"


func mount_name() -> String:
	return "Chariot" if spec_id == "mechanic" else "Horse"


func carries(id: String) -> bool:
	return slots.has(id)


## An empty hand is an empty slot, even when it is the Monk's and can punch.
func _slot_free(i: int) -> bool:
	return slots[i] == null or slots[i] == "fists"


func has_empty_slot() -> bool:
	if class_def().get("one_weapon", false):
		return _slot_free(0)
	return _slot_free(0) or _slot_free(1)


## Class rule: Heavy Infantry and Chivalry cannot use ranged weapons, unless unlocked.
func can_use(id: String) -> bool:
	if not WeaponDefs.ALL.has(id):
		return false
	var exclusive: String = WeaponDefs.ALL[id].get("only", "")
	if exclusive != "" and exclusive != class_id:
		return false
	if class_id == "commander" and spec_id in ["warlock", "gunner"]:
		return id == ("war_staff" if spec_id == "warlock" else "musket")
	if class_def().get("no_weapons", false):
		return false
	if has_flag("bo_master"):
		return id == "bo"
	if id == "bo":
		return class_id == "monk"
	if WeaponDefs.is_ranged(id):
		return bool(class_def()["ranged"]) or has_flag("ranged_ok")
	return true


func give_weapon(id: String) -> void:
	if class_def().get("one_weapon", false):
		current = 0
		slots[0] = id
		_equip()
		return
	if _slot_free(current):
		slots[current] = id
	elif _slot_free(1 - current):
		current = 1 - current
		slots[current] = id
	else:
		_swap_slot_index()
		slots[current] = id
	_equip()


## A Magician never loses the staff, so swaps replace the other slot.
func _swap_slot_index() -> void:
	if slots[current] == "staff":
		current = 1 - current


func add_arrows(n: int) -> void:
	arrows = mini(max_arrows(), arrows + n)


func heal(amount: float) -> void:
	hp = minf(max_hp(), hp + amount)
	heal_flash = 1.0


func say(text: String) -> void:
	toast = text
	toast_time = 2.0


func take_nearby_weapon() -> void:
	var p := nearby_weapon
	if p == null or not is_instance_valid(p) or not can_use(p.weapon_id):
		return
	if not has_empty_slot():
		_swap_slot_index()
		var old: Variant = slots[current]
		if old and old != "fists":
			world.drop_weapon(global_position - camera.global_basis.z * 1.2, old)
	world.collect_weapon(self, p)
	nearby_weapon = null


## You can put down what you hold, as long as it can lie on the ground and you are left with
## something to fight with. A class's own weapon stays with it.
func can_drop_weapon() -> bool:
	var id: Variant = slots[current]
	if id == null or dead or spirit_left > 0.0 or is_riding():
		return false
	if not WeaponDefs.lies_around(id):
		return false
	return class_id == "monk" or slots[1 - current] != null


func drop_current_weapon() -> void:
	if not can_drop_weapon():
		return
	var spot := global_position - camera.global_basis.z * 1.6
	world.drop_weapon(spot, slots[current])
	# It lies where it fell until you have walked away from it, or it would be back in your hand.
	shun_weapon = slots[current]
	shun_at = spot
	sfx("weapon_change", -3.0, 0.8)
	if class_id == "monk":
		slots[current] = "fists"
	else:
		slots[current] = null
		current = 1 - current
	_equip()


func switch_weapon() -> void:
	if slots[1 - current] == null:
		return
	current = 1 - current
	sfx("weapon_change")
	_equip()


func _equip() -> void:
	for i in slots.size():
		if slots[i] != null and not WeaponDefs.ALL.has(str(slots[i])):
			slots[i] = null
	if slots[current] == null and slots[1 - current] != null:
		current = 1 - current
	var d := weapon_def()
	_melee_pending = -1.0
	_bashing = false
	_swing = 1.0
	_swing_keys = ""
	_bash_anim = 0.0
	_smear_left = 0.0
	_smear.visible = false
	_reload = 1.0
	zoomed = false
	_switch_anim = 0.25
	_cooldown = 0.2
	_flail_stacks = 0
	_vm_arrow.visible = false
	_vm_orb.visible = false
	if d.is_empty():
		_vm_mesh.equip("", true)
		return
	_vm_mesh.equip(weapon_id(), true)
	_vm_mesh.rotation.y = float(d.get("mesh_yaw", 0.0))
	_vm_mesh.visible = not (d.get("returning", false) and _axe_out)
	_vm_root.scale = Vector3.ONE * float(d["scale"])
	_vm_left.visible = WeaponAnim.both_hands(d)
	if _vm_left.visible:
		_vm_left.mesh = _vm_mesh.mesh
	if WeaponDefs.uses_arrows(d):
		_vm_arrow.mesh = WeaponAnim.nocked_arrow()
		_vm_arrow.scale = Vector3.ONE * (0.34 / float(d["scale"]))
		_vm_arrow.position = Vector3(d.get("nock", Vector3.ZERO)) / float(d["scale"])
		_vm_arrow.rotation.z = -float(d.get("tilt", 0.0))
	elif d["kind"] == WeaponDefs.Kind.SPELL:
		_vm_orb.position = Vector3(0, 0.86, 0)
		_vm_orb.visible = true
	if _light:
		_light.light_energy = lerpf(1.7 if d.get("burns", false) else 0.9, 0.15, _dawn_bright)
		_light.omni_range = 16.0 if d.get("burns", false) else 11.0


func toggle_zoom() -> void:
	if weapon_def().has("zoom_fov"):
		zoomed = not zoomed


func apply_look(dx: float, dy: float) -> void:
	var fov_scale := camera.fov / BASE_FOV
	_sway += Vector2(dx, dy) * 0.0042 * Game.sensitivity * fov_scale
	yaw -= dx * 0.0042 * Game.sensitivity * fov_scale
	pitch = clampf(pitch - dy * 0.0042 * Game.sensitivity * fov_scale, deg_to_rad(-82), deg_to_rad(82))
	rotation.y = yaw
	head.rotation.x = pitch


# --- Taking damage -----------------------------------------------------------

## Whatever happens because of it, a riposte or a thorn, is this player's doing.
func hurt(amount: float, from: Vector3, attacker: Zombie = null) -> void:
	var was := world.begin_act(self)
	_take_hurt(amount, from, attacker)
	world.end_act(was)


func _take_hurt(amount: float, from: Vector3, attacker: Zombie = null) -> void:
	if dead or guard_left > 0.0 or (is_riding() and has_flag("unstoppable")):
		return
	if m("dodge") > 0.0 and randf() < m("dodge"):
		say("Dodged")
		return
	if has_flag("perfect_riposte") and _riposte_cd <= 0.0:
		_riposte_cd = 8.0
		world.stun_around(global_position, 6.0, 1.5)
		sfx("block", 0.0)
		say("Perfect Riposte!")
		return
	var dmg := amount * (1.0 - WorldLight.DOME_REDUCTION if dome_left > 0.0 else 1.0) * m("damage_taken") * (0.3 if mirror_guard_left > 0.0 else 1.0) * (POISON_HURT if poison_left > 0.0 else 1.0)
	if Net.active():
		# A Guardian nearby takes part of it.
		var cover: Target = world.best_cover(global_position)
		if cover:
			var pct := world.cover_of(cover)
			if cover is Player:
				(cover as Player).take_shared(dmg * pct * 0.6)
			else:
				Net.share_hit(world.peer_of(cover), dmg * pct * 0.6)
			dmg *= 1.0 - pct
	if is_riding():
		dmg *= m("riding_armor")
	if _shield_blocks(from):
		dmg *= 1.0 - minf(0.88, SHIELD_BASE + m("shield"))
		sfx("block", -6.0, 1.0, 0.1)
		if has_item("oathkeeper") and amount > 0.0:
			oath_reserve = minf(20.0, oath_reserve + 4.0)
		fire("block", {"attacker": attacker})
	if has_flag("mana_shield") and mana > 0.0:
		var drained := minf(mana, dmg * 0.5)
		mana -= drained
		dmg -= drained
	if stone_skin > 0.0:
		dmg *= 1.0 - stone_skin
		if attacker and has_flag("recoil") and stone_skin >= SKIN_STRONG:
			attacker.take_damage(15.0, attacker.position - global_position, 1.0, attacker.centre())
	if has_flag("mirror_step"):
		_last_hit = dmg
		_last_hit_left = 1.5 if has_flag("long_mirror") else MIRROR_WINDOW
	if attacker and m("thorns") > 0.0:
		attacker.take_damage(m("thorns"), attacker.position - global_position, 1.0, attacker.centre())
	hp -= dmg
	hurt_flash = 1.0
	hurt_from = from
	hurt_dir_time = 1.0
	_shake = 1.0
	if attacker:
		hit_by = attacker.display_name()
	damaged.emit(dmg, hit_by)
	var push := global_position - from
	push.y = 0
	if push.length_squared() > 0.001:
		# A bridge has no sides, and a good blow can put you over the edge.
		var on_bridge := world.terrain.has_islands() and world.terrain.on_deck(global_position.x, global_position.z)
		var thrown: bool = on_bridge or (attacker != null and attacker.def.get("shoves", false))
		velocity += push.normalized() * (BRIDGE_KNOCK if thrown else 2.5)
		if thrown:
			velocity.y = maxf(velocity.y, 3.5)
	sfx("hurt", -3.0, 1.0, 0.2)
	if bot_peer == 0 and Game.vibration and world.now - _buzz_at > 0.3:
		_buzz_at = world.now
		Input.vibrate_handheld(45)
	if hp <= 0.0:
		_on_fatal()
		if dead:
			return
	fire("hurt", {"attacker": attacker})
	_check_low()


func _shield_blocks(from: Vector3) -> bool:
	if not class_def().get("shield", false):
		return false
	var to := from - global_position
	to.y = 0.0
	if to.length_squared() < 0.001:
		return true
	var limit := -0.1 if shield_tier >= 3 else 0.3
	return to.normalized().dot(-global_basis.z) > limit


func ignite(seconds: float) -> void:
	if has_flag("fire_proof") or guard_left > 0.0:
		return
	burn_time = maxf(burn_time, seconds)


## Another player's ability. It does not last as long on a person as on the undead.
func apply_status(kind: int, seconds: float) -> void:
	if dead or guard_left > 0.0:
		return
	var secs := seconds * PVP_STATUS
	if (kind == Net.Status.FREEZE or kind == Net.Status.STUN) and (frozen_left > 0.0 or _status_immune > 0.0):
		return
	match kind:
		Net.Status.FREEZE:
			frozen_left = secs
			is_iced = true
			say("Frozen!")
		Net.Status.STUN:
			frozen_left = secs
			is_iced = false
			say("Stunned!")
		Net.Status.SLOW:
			slowed_left = maxf(slowed_left, secs)
		Net.Status.POISON:
			if not has_flag("antidote"):
				poison_left = maxf(poison_left, seconds)
				say("Poisoned")
		Net.Status.BLEED:
			if not has_flag("antidote"):
				bleed_left = maxf(bleed_left, seconds)
				say("Bleeding")
		Net.Status.BURN:
			ignite(secs)


## The deadly fog: no armour or dodge helps against it, though a moment of invincibility does.
func fog_hurt(amount: float) -> void:
	if dead or guard_left > 0.0:
		return
	hp -= amount
	hurt_flash = maxf(hurt_flash, 0.35)
	hit_by = "the fog"
	last_foe = 0
	damaged.emit(amount, hit_by)
	if hp <= 0.0:
		_on_fatal()


func _on_fatal() -> void:
	_kill()


func _check_low() -> void:
	if hp < max_hp() * 0.3:
		if _low_armed:
			_low_armed = false
			fire("low", {})
	elif hp > max_hp() * 0.45:
		_low_armed = true


## Standing up again, in a multiplayer game.
func respawn(at: Vector3) -> void:
	dead = false
	hp = max_hp()
	mana = 0.0 if class_def().get("ki", false) else max_mana()
	stone_skin = 0.0
	spirit_left = 0.0
	_vm_root.visible = true
	burn_time = 0.0
	poison_left = 0.0
	bleed_left = 0.0
	frozen_left = 0.0
	slowed_left = 0.0
	_status_immune = 0.0
	guard_left = 2.5
	last_foe = 0
	velocity = Vector3.ZERO
	input_move = Vector2.ZERO
	input_fire = false
	input_jump = false
	_leap_t = -1.0
	_rift_targets.clear()
	_cast_kind = ""
	ride_behind = 0
	passenger = 0
	if bot_peer == 0:
		camera.current = true
	global_position = Vector3(at.x, world.ground_at(at) + 0.05, at.z)
	head.position.y = 1.58
	_equip()


func is_unseen() -> bool:
	return invis_left > 0.0 or spirit_left > 0.0


## Firelight shows you to everything out in the dark, and so does a torch in your hand.
func sight_factor() -> float:
	return maxf(0.15, m("sight")) * (WorldLight.SEEN_IN_LIGHT if is_lit() else 1.0)


## Burning counts: you are your own torch.
func is_lit() -> bool:
	return _lit or burn_time > 0.0


func look_direction() -> Vector3:
	return -camera.global_basis.z


func _kill() -> void:
	if has_item("undying_rage") and _rage_cd <= 0.0:
		_rage_cd = RAGE_COOLDOWN
		rage_left = RAGE_TIME
		hp = max_hp() * 0.3
		burn_time = 0.0
		say("Undying Rage!")
		hurt_flash = 1.0
		world.fx_ring(global_position, 6.0, Color(1.0, 0.25, 0.1))
		sfx("blast", -2.0, 0.8)
		return
	hp = 0.0
	dead = true
	input_fire = false
	if is_riding():
		dismount()
	world.on_player_died(self)


# --- Levels and abilities ----------------------------------------------------

func xp_needed() -> int:
	var needed := ClassDefs.xp_for_level(level)
	# All vs All is short, and has fewer enemies in it.
	return ceili(needed * FOG_XP) if Net.fog_rules() else needed


func add_xp(n: int) -> void:
	if level >= ClassDefs.MAX_LEVEL:
		return
	xp += n
	while xp >= xp_needed() and level < ClassDefs.MAX_LEVEL:
		xp -= xp_needed()
		level += 1
		points += 1
		level_flash = 1.0
		guard_left = maxf(guard_left, LEVEL_UP_GUARD)
		sfx("level", -2.0)
		# Everyone sees someone grow stronger: a golden ring, and motes rising around them.
		world.fx_ring(global_position, 3.4, LEVEL_GOLD)
		world.fx_rise(global_position, LEVEL_GOLD)
		say("Level %d! Choose an ability" % level)
	if level >= ClassDefs.MAX_LEVEL:
		xp = 0


## In the Sandbox the whole tree is yours from the start.
func grant_all_points() -> void:
	level = ClassDefs.MAX_LEVEL
	xp = 0
	points = ClassDefs.MAX_LEVEL - 1 - chosen.size()


func tree_data() -> Dictionary:
	return AbilityData.tree(class_id)


func next_step() -> int:
	return chosen.size()


## The options of each step of this character's path, in order. After the shared steps comes the
## choice of specialization, and its branch only appears here once one has been taken.
func steps() -> Array:
	var t := tree_data()
	var out: Array = (t["core"] as Array).duplicate()
	var entries: Array = []
	for spec: Dictionary in t["specs"]:
		entries.append(spec["entry"])
	out.append(entries)
	if spec_id != "":
		var spec := spec_def()
		out.append_array(spec["path"])
		out.append([spec["final"]])
	return out


func spec_def() -> Dictionary:
	for spec: Dictionary in tree_data()["specs"]:
		if spec["id"] == spec_id:
			return spec
	return {}


## One step at a time. Taking an option locks the others, and picking a specialization
## locks the other two branches for this game.
func choose_ability(step: int, index: int) -> bool:
	var all := steps()
	if points <= 0 or step != next_step() or step >= all.size():
		return false
	var options: Array = all[step]
	if index < 0 or index >= options.size():
		return false
	var a: Dictionary = options[index]
	chosen[step] = a["id"]
	points -= 1
	if step == CORE_STEPS:
		spec_id = (tree_data()["specs"] as Array)[index]["id"]
	_apply_ability(a)
	if step == CORE_STEPS:
		spec_chosen()
		for item: String in ShopDefs.for_class(class_id):
			if has_item(item) and ShopDefs.ITEMS[item].has("effect"):
				_apply_ability({"on": [ShopDefs.ITEMS[item]["effect"].duplicate(true)]})
	sfx("ui_choose", -3.0)
	return true


func _apply_ability(a: Dictionary) -> void:
	var was_hp := max_hp()
	var add: Dictionary = a.get("add", {})
	for k: String in add:
		mods[k] = float(mods[k]) + float(add[k])
	if a.get("flag", "") != "":
		flags[a["flag"]] = true
		if a["flag"] == "art_summoner":
			world.prepare_allies("revenant", 3)
		elif a["flag"] == "art_swap":
			world.prepare_allies("decoy", 3)
		elif a["flag"] == "swap_legion":
			world.prepare_allies("mirror", 3)
		elif a["flag"] == "spirit_walker":
			world.prepare_allies("body", 1)
	if max_hp() > was_hp:
		hp += max_hp() - was_hp
	hp = minf(hp, max_hp())
	if add.has("mana"):
		mana += float(add["mana"])
	if add.has("wolves"):
		world.prepare_allies(pet_kind(), int(m("wolves")))
	for e: Dictionary in a.get("on", []):
		if e["do"] == "summon":
			world.prepare_allies(e["kind"], int(e["n"]) + int(m("summon_extra")))
		elif e["do"] == "raise":
			world.prepare_allies("skeleton", 3)
		var entry := e.duplicate()
		entry["cd_left"] = 0.0
		entry["count"] = 0
		entry["timer"] = 1.0 if e.get("soon", false) else float(e.get("secs_every", 0.0))
		if e["when"] == "take":
			_act(entry, {})
			continue
		if not _triggers.has(e["when"]):
			_triggers[e["when"]] = []
		_triggers[e["when"]].append(entry)


func fire(event: String, ctx: Dictionary) -> void:
	if not _triggers.has(event):
		return
	for e: Dictionary in _triggers[event]:
		if float(e["cd_left"]) > 0.0:
			continue
		if e.has("nth"):
			e["count"] = int(e["count"]) + 1
			if int(e["count"]) % int(e["nth"]) != 0:
				continue
		if e.has("chance") and randf() >= float(e["chance"]):
			continue
		e["cd_left"] = float(e.get("cd", 0.0))
		_act(e, ctx)


func _tick_triggers(delta: float) -> void:
	for event: String in _triggers:
		for e: Dictionary in _triggers[event]:
			if float(e["cd_left"]) > 0.0:
				e["cd_left"] = float(e["cd_left"]) - delta
			if event == "every":
				e["timer"] = float(e["timer"]) - delta
				if float(e["timer"]) <= 0.0:
					if e.get("riding", false) and not is_riding():
						continue
					if _act(e, {}) == false:
						e["timer"] = 0.4 # nothing to act on yet, so look again soon
					elif e["do"] == "trap":
						e["timer"] = maxf(2.0, float(e["secs_every"]) + m("trap_cd"))
					else:
						e["timer"] = float(e["secs_every"])


## Runs one ability effect. Returns false when there was nothing to do, so timers retry soon.
func _act(e: Dictionary, ctx: Dictionary) -> Variant:
	var z: Zombie = ctx.get("z")
	var here := global_position
	match e["do"]:
		"heal":
			if hp < max_hp():
				heal(float(e["n"]))
		"mana":
			mana = minf(max_mana(), mana + float(e["n"]))
		"arrows":
			add_arrows(int(e["n"]))
		"buff":
			var key: String = e["key"]
			if not _buffs.has(key):
				_buffs[key] = {"stat": e["stat"], "val": e["val"], "left": 0.0, "stacks": 0}
			_buffs[key]["stacks"] = mini(int(e.get("max", 1)), int(_buffs[key]["stacks"]) + 1)
			_buffs[key]["left"] = e["secs"]
		"stun":
			if z:
				z.stun(float(e["secs"]))
			elif ctx.has("rival"):
				status_on(ctx["rival"], Net.Status.STUN, float(e["secs"]))
		"stun_attacker":
			var at: Zombie = ctx.get("attacker")
			if at:
				at.stun(float(e["secs"]))
		"mark":
			if z:
				z.mark(float(e["mult"]), float(e["secs"]))
		"reveal":
			if z:
				z.reveal_left = float(e["secs"])
		"dot":
			if z:
				z.add_dot(float(e["dps"]), float(e["secs"]), e.get("bleed", false))
				if not e.get("bleed", false):
					_note_poison(float(e["dps"]) * float(e["secs"]))
			elif ctx.has("rival"):
				status_on(ctx["rival"], Net.Status.BLEED if e.get("bleed", false) else Net.Status.POISON, float(e["secs"]))
		"ignite":
			if z:
				z.ignite(ZombieDefs.BURN_SECONDS)
			elif ctx.has("rival"):
				status_on(ctx["rival"], Net.Status.BURN, ZombieDefs.BURN_SECONDS)
		"extra":
			if z and z.is_alive():
				z.take_damage(WeaponDefs.DAMAGE * float(e["mult"]) * m("melee_damage"), Vector3.ZERO, 0.0, z.centre())
		"stun_around":
			var n := world.stun_around(here, float(e["r"]), float(e["secs"]))
			if e.has("secs_every") and n == 0:
				return false
			if e.has("sound"):
				sfx(e["sound"], -3.0, 1.0, 0.2)
		"slow_around":
			var n := world.slow_around(here, float(e["r"]), float(e["secs"]))
			if n == 0:
				return false
			world.fx_blast(here + Vector3.UP * 0.2, float(e["r"]) * 0.7, Color(0.6, 0.85, 1.0, 0.3))
		"burn_around":
			if world.burn_around(here, float(e["r"])) == 0:
				return false
			world.fx_blast(here + Vector3.UP * 0.3, float(e["r"]) * 0.7, Color(1.0, 0.7, 0.25, 0.3))
		"blast":
			var at: Vector3 = z.centre() if z else here
			world.blast(at, float(e["r"]), float(e["dmg"]))
		"last_rites":
			if z: HeavyArts.last_rites(self, z.position)
		"faultline":
			HeavyArts.faultline(self)
		"quake":
			world.blast(here + Vector3.UP * 0.2, float(e["r"]), float(e["dmg"]) * damage_multiplier())
			world.stun_around(here, float(e["r"]), 1.2)
		"thunder":
			var t := world.nearest_zombie(eye_position(), PowerDefs.THUNDER_RANGE, false)
			var foe := world.nearest_rival(eye_position(), PowerDefs.THUNDER_RANGE)
			if t == null and foe == null:
				return false
			world.thunder_strike(self, foe.global_position if foe else t.position)
		"thunder_all":
			var any := false
			for t: Zombie in world.zombies.duplicate():
				if t.is_alive() and t.position.distance_to(here) <= float(e["r"]):
					t.take_damage(PowerDefs.THUNDER_DAMAGE, t.position - here, 3.0, t.centre())
					any = true
			for r: Target in world.rivals_near(here, float(e["r"])):
				world.hit_rival(r, PowerDefs.THUNDER_DAMAGE, here)
				any = true
			if not any:
				return false
			sfx("thunder", -3.0, 1.0, 0.2)
			world.flash_bolt(here + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
		"cataclysm":
			var any := false
			for t: Zombie in world.zombies.duplicate():
				if t.is_alive() and t.position.distance_to(here) <= float(e["r"]):
					t.take_damage(float(e["dmg"]), t.position - here, 3.0, t.centre())
					t.ignite(ZombieDefs.BURN_SECONDS)
					any = true
			for r: Target in world.rivals_near(here, float(e["r"])):
				world.hit_rival(r, float(e["dmg"]), here)
				world.status_rival(r, Net.Status.BURN, ZombieDefs.BURN_SECONDS)
				any = true
			if not any:
				return false
			world.fx_blast(here + Vector3.UP, float(e["r"]) * 0.45, Color(1.0, 0.45, 0.1, 0.4))
			sfx("blast", 0.0, 1.0, 0.2)
		"summon":
			var count := int(e["n"]) + int(m("summon_extra"))
			for i in count:
				world.spawn_ally(e["kind"], here + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)), float(e["secs"]) * m("ally_time"))
		"raise":
			if z:
				world.spawn_ally("skeleton", z.position, float(e["secs"]) * m("ally_time"))
		"invis":
			invis_left = maxf(invis_left, float(e["secs"]))
			say("Invisible")
		"guard":
			guard_left = maxf(guard_left, float(e["secs"]))
			sfx("block", -6.0, 1.3, 0.2)
		"forget":
			if world.forget_around(here, float(e["r"])) == 0:
				return false
		"give_weapon":
			slots[0] = e["id"]
			slots[1] = null
			current = 0
			_equip()
		"miasma":
			world.drop_poison(here)
		"trap":
			if has_item("trap_satchel"):
				trap_charges = mini(traps_carried(), trap_charges + 1)
			else:
				world.place_trap(self, here)
		"poison":
			world.drop_poison(here, true)
		"hawk":
			var t: Node3D = world.nearest_rival(eye_position(), 18.0)
			if t == null:
				t = world.nearest_zombie(eye_position(), 18.0, true)
			if t == null:
				return false
			world.familiar_arrow(self, t)
		"fetch":
			world.imp_steal(self)
		"pack_call":
			return _pack_call()
		"volley":
			var targets: Array = world.zombies_near(here, 18.0, int(e["n"]))
			targets.append_array(world.rivals_near(here, 18.0))
			if targets.is_empty():
				return false
			for t: Node3D in targets:
				world.familiar_arrow(self, t)
		"power":
			activate_power(e["id"], float(e["time"]))
		"shield_up":
			shield_tier = mini(2, shield_tier + 1)
			_refresh_shield()
		"shield_max":
			shield_tier = 3
			_refresh_shield()
		"weapon":
			if not carries(e["id"]):
				if has_empty_slot():
					give_weapon(e["id"])
				else:
					world.drop_weapon(global_position - global_basis.z * 1.5, e["id"])
	return true


func set_dawn_light(bright: float) -> void:
	_dawn_bright = bright
	if _light == null:
		return
	_light.light_energy = lerpf(1.7 if weapon_def().get("burns", false) else 0.9, 0.15, bright)


func _refresh_shield() -> void:
	if _shield_node == null:
		_shield_node = MeshInstance3D.new()
		_shield_node.layers = 2
		_shield_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield_node.position = Vector3(-0.47, -0.36, -0.62)
		_shield_node.rotation = Vector3(0, 0.5, 0.05)
		_shield_node.scale = Vector3.ONE * 0.42
		camera.add_child(_shield_node)
	_shield_node.mesh = WeaponDefs.shield_mesh(shield_tier)


func on_kill(z: Zombie) -> void:
	var was := world.begin_act(self)
	_on_kill(z)
	world.end_act(was)


func _on_kill(z: Zombie) -> void:
	kills += 1
	if z.poison_left > 0.0 and has_flag("plague_burst"):
		world.drop_poison(z.position)
	if z.poison_left > 0.0 and has_flag("black_death"):
		world.fx_ring(z.position, 6.0, Color(0.5, 0.95, 0.25))
		for near: Zombie in world.zombies_near(z.position, 6.0, 8):
			near.add_dot(14.0, 5.0)
			_note_poison(70.0)
	if has_item("shadow_shroud"):
		shadow_kills = mini(SHROUD_KILLS, shadow_kills + 1)
	if bot_peer == 0 and z.type_id == "rider" and not Game.unlocked.has("chivalry"):
		Game.note_rider_killed()
		if Game.unlocked.has("chivalry"):
			say("Chivalry unlocked!")
	add_xp(z.xp_value)
	mana = minf(max_mana(), mana + float(class_def().get("kill_mist", 0.0)))
	if class_def().has("kill_heal") and hp < max_hp():
		heal(float(class_def()["kill_heal"]))
	if void_left > 0.0:
		if has_flag("hungry_void"):
			heal(12.0)
		if has_flag("walker_between") and _void_extensions < 6:
			_void_extensions += 1
			void_left += 1.0
			invis_left = maxf(invis_left, void_left)
	add_arrows(int(class_def().get("kill_arrows", 0)))
	fire("kill", {"z": z})
	if _assassin_kill:
		_assassin_kill = false
		invis_left = maxf(invis_left, 3.0)
	if has_mount() and not is_riding():
		horse_progress = mini(horses_needed(), horse_progress + 1)
		if horse_progress == horses_needed():
			say("Your %s is ready!" % mount_name().to_lower())
	if has_flag("bomb_refund"):
		art_cd_left = maxf(0.0, art_cd_left - 0.5)
	if is_riding() and (has_flag("ride_on_kill") or has_flag("war_horse")):
		riding_left += 1.0


func on_ally_kill() -> void:
	if has_flag("bond"):
		heal(5.0)


## Crits, backstabs and other per-target rules for anything the player deals.
func modify_damage(z: Zombie, base: float) -> float:
	var dmg := base
	var unaware := z.is_unaware()
	if has_flag("assassin") and unaware and z.type_id != "beast" and not z.hero:
		_assassin_kill = true
		return 99999.0
	var crit := m("crit_chance") + (m("riding_crit") if is_riding() else 0.0)
	if flurry_left > 0.0:
		crit = 1.0
	if crit > 0.0 and randf() < crit:
		dmg *= m("crit_mult")
		fire("crit", {"z": z})
	if m("backstab") > 0.0 and (unaware or z.is_behind(global_position)):
		dmg *= 1.0 + m("backstab")
		fire("backstab", {"z": z})
	if has_flag("pack_tactics") and world.ally_near(z.position, 5.0):
		dmg *= 1.3
	return dmg


func horses_needed() -> int:
	return HORSE_KILLS + int(m("horse_kills"))


func horse_ready() -> bool:
	if not has_mount() or is_riding():
		return false
	return horse_progress >= horses_needed() or (has_flag("sacred_steed") and _sacred_cd <= 0.0)


func mount() -> void:
	if not horse_ready():
		return
	horse_progress = 0
	_sacred_cd = 60.0
	_trampled.clear()
	if mount_kind() == "chariot":
		riding_left = CHARIOT_TIME + m("horse_time")
		if _chariot == null:
			_chariot = ChariotModel.new(2)
			add_child(_chariot)
		_chariot.show_upgrades(has_turret(), has_spikes())
		_chariot.visible = true
		sfx("creak", 0.0)
	else:
		riding_left = HORSE_TIME + m("horse_time")
		if _horse == null:
			_build_horse()
		_horse.visible = true
		sfx("gallop", 0.0)
	fire("mount", {})


func dismount() -> void:
	riding_left = 0.0
	_sacred_cd = 60.0
	if passenger != 0:
		Net.drop_passenger(passenger)
		passenger = 0
	if _horse:
		_horse.visible = false
	if _chariot:
		_chariot.visible = false
	if not dead:
		fire("dismount", {})


func _build_horse() -> void:
	_horse = Node3D.new()
	add_child(_horse)
	var coat := Color(0.3, 0.19, 0.12)
	var mane := Color(0.1, 0.07, 0.06)
	var cloth := Color(0.55, 0.13, 0.12)
	var l := LowPoly.new()
	l.box(Vector3(0, 1.15, 0.15), Vector3(0.75, 0.75, 2.0), coat)
	l.box(Vector3(0, 1.37, 0.15), Vector3(0.82, 0.32, 1.2), cloth)
	l.box(Vector3(0, 1.62, -0.92), Vector3(0.36, 1.0, 0.45), coat, Vector3(-30, 0, 0))
	l.box(Vector3(0, 2.05, -1.32), Vector3(0.3, 0.32, 0.78), coat)
	l.box(Vector3(0, 1.96, -1.74), Vector3(0.24, 0.2, 0.2), Color(0.16, 0.1, 0.07))
	l.box(Vector3(0, 1.9, -0.72), Vector3(0.08, 1.05, 0.14), mane, Vector3(-30, 0, 0))
	l.box(Vector3(-0.1, 2.27, -1.03), Vector3(0.07, 0.16, 0.05), coat)
	l.box(Vector3(0.1, 2.27, -1.03), Vector3(0.07, 0.16, 0.05), coat)
	var body := MeshInstance3D.new()
	body.mesh = l.commit()
	body.layers = 2
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_horse.add_child(body)
	var leg := LowPoly.new().box(Vector3(0, -0.4, 0), Vector3(0.17, 0.85, 0.17), coat).box(Vector3(0, -0.8, 0), Vector3(0.2, 0.1, 0.2), mane).commit()
	for s: Vector3 in [Vector3(-0.27, 0.9, -0.65), Vector3(0.27, 0.9, -0.65), Vector3(-0.27, 0.9, 0.95), Vector3(0.27, 0.9, 0.95)]:
		var mi := MeshInstance3D.new()
		mi.mesh = leg
		mi.layers = 2
		mi.position = s
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_horse.add_child(mi)
		_horse_legs.append(mi)


func _tick_riding(delta: float) -> void:
	var target_y := 1.58
	if is_riding():
		target_y = 2.0 if mount_kind() == "chariot" else 2.35
	elif ride_behind != 0:
		var carrier: Avatar = Net.avatar(ride_behind)
		target_y = 2.0 if carrier and carrier.in_chariot else 2.35
	head.position.y = lerpf(head.position.y, target_y, min(1.0, delta * 7.0))
	if not is_riding():
		return
	riding_left -= delta
	var horiz := Vector2(velocity.x, velocity.z).length()
	if mount_kind() == "chariot":
		_chariot.roll(horiz * delta)
		_tick_chariot(delta)
		if horiz > 3.0:
			_trample(horiz)
			sfx("creak", -14.0, 1.0, 0.9)
	else:
		var t := Time.get_ticks_msec() * 0.016
		for i in _horse_legs.size():
			var swing := sin(t + (0.0 if i % 3 == 0 else PI)) * 0.7 * clampf(horiz / 6.0, 0.05, 1.0)
			_horse_legs[i].rotation.x = swing
		if horiz > 3.0:
			_trample(horiz)
			sfx("gallop", -9.0, 1.0, 0.32)
	if riding_left <= 0.0:
		dismount()
		say("Your %s is gone" % mount_name().to_lower())


## What a Mechanic's upgrades do while the chariot is out.
func has_turret() -> bool:
	return has_flag("chariot_turret") or has_flag("war_machine")


func has_spikes() -> bool:
	return has_flag("chariot_spikes") or has_flag("war_machine")


func _tick_chariot(delta: float) -> void:
	if has_turret():
		_turret_timer -= delta
		if _turret_timer <= 0.0:
			var from := global_position + global_basis * Vector3(0.6, 1.6, -1.0)
			var aim_at := world.aim_point(from, WorldLight.TURRET_REACH)
			if aim_at == Vector3.INF:
				_turret_timer = 0.25
			else:
				_turret_timer = WorldLight.TURRET_EVERY / m("turret_rate")
				_chariot.aim_turret(aim_at)
				var dir := (aim_at - from).normalized()
				world.spawn_player_arrow(self, from, dir * 45.0, 0.0, WorldLight.TURRET_REACH + 6.0, 1.5, WeaponDefs.DAMAGE * 1.2 * m("turret_damage") * damage_multiplier(), false)
				sfx("crossbow", -8.0, 1.1, 0.1)
	if has_spikes():
		_spike_timer -= delta
		if _spike_timer <= 0.0:
			_spike_timer = 0.45 / m("turret_rate")
			for z: Zombie in world.zombies_near(global_position, 2.5, 8):
				z.take_damage(26.0 * m("turret_damage") * damage_multiplier(), z.position - global_position, 2.0, z.centre())
				on_hit(false)
			for r: Target in world.rivals_near(global_position, 2.5):
				world.hit_rival(r, 26.0 * m("turret_damage") * damage_multiplier(), global_position)


func _trample(horiz: float) -> void:
	var now := world.now
	var ahead := Vector3(velocity.x, 0, velocity.z) / maxf(horiz, 0.01)
	for r: Target in world.rivals_near(global_position, 2.3):
		if now - float(_trampled.get(r.get_instance_id(), -10.0)) >= 0.8:
			_trampled[r.get_instance_id()] = now
			world.hit_rival(r, TRAMPLE_DAMAGE * m("trample") * damage_multiplier(), global_position)
			world.status_rival(r, Net.Status.STUN, 0.8)
	for z: Zombie in world.zombies:
		if not z.is_alive():
			continue
		var to := z.position - global_position
		to.y = 0.0
		if to.length() > 2.3 or (to.length() > 0.5 and to.normalized().dot(ahead) < 0.1):
			continue
		if now - float(_trampled.get(z.get_instance_id(), -10.0)) < 0.8:
			continue
		_trampled[z.get_instance_id()] = now
		var dmg := TRAMPLE_DAMAGE * m("trample") * damage_multiplier()
		if has_flag("war_horse") and z.type_id == "normal":
			dmg = 9999.0
		if has_flag("unstoppable") and z.type_id != "beast":
			dmg = 9999.0
		z.take_damage(dmg, ahead, 9.0, z.centre())
		fire("trample", {"z": z})
		on_hit(false)
		sfx("clang", -9.0, 0.6, 0.15)


# --- Powers ------------------------------------------------------------------

func activate_power(id: String, forced_time := 0.0) -> void:
	var d: Dictionary = PowerDefs.ALL[id]
	var time: float = d["time"]
	time *= m("familiar_time") if d["familiar"] else m("potion_time")
	if forced_time > 0.0:
		time = forced_time
	powers[id] = maxf(time, float(powers.get(id, 0.0)))
	if d["familiar"]:
		sfx("chime", -2.0)
		match id:
			"angel": _angel_timer = PowerDefs.ANGEL_INTERVAL
			"archer": _archer_timer = 0.3
			"thunder": _thunder_timer = 1.0
			"imp": _imp_timer = 0.3
			"bell_spirit": _bell_timer = 1.0
			"rat": _rat_timer = 0.0
			"ghost":
				var previous := world.begin_act(self)
				world.spawn_ally("ghost", global_position - global_basis.z * 1.5, time)
				world.end_act(previous)
		if not _familiars.has(id):
			var mi := MeshInstance3D.new()
			mi.mesh = PowerDefs.mesh(id)
			mi.material_override = PowerDefs.familiar_material(id)
			mi.scale = Vector3.ONE * 0.22
			mi.layers = 2
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			camera.add_child(mi)
			_familiars[id] = mi
			_arrange_familiars()
	else:
		sfx("potion", -2.0)
	say(str(d["name"]) + "!")


func _arrange_familiars() -> void:
	var i := 0
	for id: String in _familiars:
		(_familiars[id] as Node3D).position = Vector3(-0.56 + i * 0.12, 0.3, -0.72)
		i += 1


func _tick_powers(delta: float) -> void:
	for id: String in powers.keys():
		powers[id] = float(powers[id]) - delta
		if float(powers[id]) <= 0.0:
			powers.erase(id)
			if _familiars.has(id):
				(_familiars[id] as Node).queue_free()
				_familiars.erase(id)
				_arrange_familiars()
	var t := Time.get_ticks_msec() * 0.003
	for id: String in _familiars:
		var f := _familiars[id] as Node3D
		f.rotation.y = sin(t) * 0.5
		f.position.y = 0.3 + sin(t * 1.4) * 0.012
	if has_power("angel"):
		_angel_timer -= delta
		if _angel_timer <= 0.0:
			_angel_timer = PowerDefs.ANGEL_INTERVAL
			if hp < max_hp():
				heal(PowerDefs.ANGEL_HEAL)
				sfx("chime", -10.0, 1.3)
	if has_power("archer"):
		_archer_timer -= delta
		if _archer_timer <= 0.0:
			var shot_at := _familiar_mark(PowerDefs.ARCHER_RANGE, true)
			if shot_at:
				_archer_timer = PowerDefs.ARCHER_INTERVAL
				world.familiar_arrow(self, shot_at)
	if has_power("thunder"):
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			var struck := _familiar_mark(PowerDefs.THUNDER_RANGE, false)
			if struck:
				_thunder_timer = PowerDefs.THUNDER_INTERVAL
				world.thunder_strike(self, struck.global_position)
	if has_power("imp"):
		_imp_timer -= delta
		if _imp_timer <= 0.0:
			_imp_timer = PowerDefs.IMP_INTERVAL
			world.imp_steal(self)
	if has_power("bell_spirit"):
		_bell_timer -= delta
		if _bell_timer <= 0.0:
			_bell_timer = PowerDefs.BELL_INTERVAL
			if world.stun_around(global_position, PowerDefs.BELL_RADIUS, PowerDefs.BELL_STUN) > 0:
				sfx("hammer", -4.0, 1.3, 0.2)
	if has_power("rat"):
		_rat_timer -= delta
		if _rat_timer <= 0.0:
			_rat_timer = PowerDefs.RAT_INTERVAL
			world.drop_poison(global_position)
	_tick_ability_timers(delta)


## The Pack's call, every 20 s. What it does depends on the beast: a wolf's howl stuns all around,
## ravens mark every enemy near you, snakes poison them, and a fox brings you food or arrows.
func _pack_call() -> bool:
	var here := global_position
	match pet_kind():
		"raven":
			var marked := world.zombies_near(here, 15.0, 24)
			for z: Zombie in marked:
				z.mark(1.35, 6.0)
				z.reveal_left = maxf(z.reveal_left, 6.0)
			if marked.is_empty():
				return false
			world.fx_ring(here, 15.0, Color(0.45, 0.4, 0.75))
			sfx("crow", -2.0)
		"snake":
			var bitten := world.zombies_near(here, 9.0, 24)
			for z: Zombie in bitten:
				z.add_dot(12.0, 5.0)
				_note_poison(60.0)
			var rivals := world.rivals_near(here, 9.0)
			for r: Target in rivals:
				world.status_rival(r, Net.Status.POISON, 5.0)
			if bitten.is_empty() and rivals.is_empty():
				return false
			world.fx_ring(here, 9.0, Color(0.4, 0.9, 0.3))
			sfx("thunk", -4.0, 0.7)
		"fox":
			var spot := here - global_basis.z * 1.5
			var wants_food: bool = hp < max_hp() * 0.7 or not (class_def().get("ranged", false) or WeaponDefs.uses_arrows(weapon_def()))
			if wants_food:
				world.spawn_pickup_at(spot, Pickup.Kind.FOOD, PowerDefs.FOODS.keys().pick_random())
			else:
				world.spawn_pickup_at(spot, Pickup.Kind.ARROWS, "arrows")
			sfx("wolf", -6.0, 1.3)
		_:
			if world.stun_around(here, 9.0, 1.2) == 0:
				return false
			sfx("howl", -3.0, 1.0, 0.2)
	return true


## What a familiar goes for: the nearest enemy, or the nearest player or bot on the other side.
func _familiar_mark(reach: float, need_sight: bool) -> Node3D:
	var z := world.nearest_zombie(eye_position(), reach, need_sight)
	var r := world.nearest_rival(eye_position(), reach)
	if r and (z == null or r.global_position.distance_to(global_position) < z.position.distance_to(global_position)):
		return r
	return z


func _tick_ability_timers(delta: float) -> void:
	if _banner != null:
		_banner.rotation.z = sin(world.now * (12.0 if _cast_kind == "command" else 2.0)) * (0.18 if _cast_kind == "command" else 0.025)
	for key: String in _buffs.keys():
		_buffs[key]["left"] = float(_buffs[key]["left"]) - delta
		if float(_buffs[key]["left"]) <= 0.0:
			_buffs.erase(key)
	_tick_triggers(delta)
	invis_left = maxf(0.0, invis_left - delta)
	guard_left = maxf(0.0, guard_left - delta)
	dome_left = maxf(0.0, dome_left - delta)
	_riposte_cd -= delta
	_kill_shot_cd -= delta
	flurry_left -= delta
	rage_left -= delta
	_rage_cd -= delta
	_tick_monk(delta)
	_tick_adept(delta)
	_tick_art_aim()
	if not is_riding():
		_sacred_cd -= delta
	var regen := m("regen") + (m("riding_regen") if is_riding() else 0.0)
	if regen > 0.0 and hp < max_hp():
		hp = minf(max_hp(), hp + regen * delta)
	if class_def().get("mana", false):
		mana = minf(max_mana(), mana + MANA_REGEN * m("mana_regen") * delta)
	if m("wolves") > 0.0:
		_wolf_timer -= delta
		if _wolf_timer <= 0.0:
			# The pack comes back at the same pace however large it is.
			_wolf_timer = 15.0 / maxf(1.0, m("wolves"))
			if world.count_allies(pet_kind()) < int(m("wolves")):
				world.spawn_ally(pet_kind(), global_position + Vector3(1.5, 0, 1.5), INF)
				sfx("wolf" if pet_kind() in ["wolf", "fox"] else "thunk", -5.0)
	_check_low()


# --- The Revenant ------------------------------------------------------------

## The second ability of a path. Most belong to the Revenant, one to the Guardian.
func has_art() -> bool:
	return not art_def().is_empty()


func has_burst() -> bool:
	return class_def().get("mist", false)


func art_def() -> Dictionary:
	if class_id == "commander":
		return CommanderKit.art(self)
	if class_id == "adept":
		return WorldLight.ARTS["stance"]
	if class_id == "monk" and spec_id == "":
		return WorldLight.ARTS["ki_blast"]
	var item := ShopDefs.art_item(spec_id)
	if item != "" and _item_on(item):
		return ShopDefs.ITEMS[item]["art"]
	return WorldLight.ARTS.get(spec_id, {})


func has_item(id: String) -> bool:
	return _item_on(id) and spec_id == str(ShopDefs.ITEMS[id]["spec"])


## A bot has everything in the Store, like a player who bought it all.
func _item_on(id: String) -> bool:
	return true if bot_peer != 0 else Game.item_active(id)


func _note_poison(amount: float) -> void:
	if bot_peer == 0:
		Game.note_poison(amount)


## How many traps the Trap Satchel holds.
func traps_carried() -> int:
	return TRAPS_CARRIED + int(m("trap_carry"))


func pet_kind() -> String:
	return bot_pet if bot_peer != 0 else Game.pet


## Some abilities are aimed first: the button goes down, a circle shows where, and letting go does it.
func art_is_held() -> bool:
	return art_def().get("hold", false)


func art_aim() -> void:
	if art_cd_left > 0.0 or _cast_kind != "":
		return
	aiming_art = true


func art_release() -> void:
	if not aiming_art:
		return
	aiming_art = false
	if bot_peer == 0:
		world.show_aim(Vector3.ZERO, 0.0)
	use_art()


func _tick_art_aim() -> void:
	if not aiming_art:
		return
	if dead or _cast_kind != "":
		aiming_art = false
		if bot_peer == 0:
			world.show_aim(Vector3.ZERO, 0.0)
		return
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var reach := RAIN_REACH
	if dir.y < -0.02:
		reach = minf(RAIN_REACH, (from.y - world.ground_at(from)) / -dir.y)
	var spot := from + dir * reach
	spot.y = world.ground_at(spot)
	_rain_spot = spot
	if bot_peer == 0:
		world.show_aim(spot, RAIN_RADIUS)


func _rain_tick(delta: float) -> void:
	_rain_wait -= delta
	if _rain_wait > 0.0:
		return
	_rain_wait = 0.25
	for i in 3:
		var a := randf() * TAU
		var fall := _rain_spot + Vector3(cos(a), 0.0, sin(a)) * randf() * RAIN_RADIUS
		var from := fall + Vector3(0.0, 16.0, 0.0)
		world.net_visual_shot(0, from, Vector3.DOWN * 45.0, 0.0, 16.0, false, Color.WHITE)
		Net.shot(0, from, Vector3.DOWN * 45.0, 0.0, 16.0, false, Color.WHITE)
	var dmg := WeaponDefs.DAMAGE * RAIN_POWER * _ranged_mult()
	for z: Zombie in world.zombies_near(_rain_spot, RAIN_RADIUS, 14):
		z.take_damage(dmg, Vector3.ZERO, 0.5, z.centre())
		on_hit(false)
	for r: Target in world.rivals_near(_rain_spot, RAIN_RADIUS):
		world.hit_rival(r, dmg, _rain_spot)
	sfx("bow", -8.0, 1.2, 0.2)


## The picture on the ability's button. For an Inventor, that is what will come out next.
func art_glyph() -> String:
	if class_id == "adept":
		return "moon" if _void_is_ready() else str(STANCE_ICONS.get(stance, "wind"))
	if spec_id == "inventor" and _next_invention != "":
		return WorldLight.INVENTIONS[_next_invention]["icon"]
	return str(art_def().get("icon", "mist"))


func art_label() -> String:
	if spec_id == "guardian" and has_item("oathkeeper"):
		return "Oath %d / 20" % int(oath_reserve)
	if class_id == "commander":
		return "Last Command" if has_flag("last_command") else "Command"
	if class_id == "adept":
		return "Void is open" if _void_is_ready() else "%s stance" % STANCE_NAMES.get(stance, "")
	if spirit_left > 0.0:
		return "Come back"
	if spec_id == "inventor" and _next_invention != "":
		return WorldLight.INVENTIONS[_next_invention]["name"]
	if has_item("trap_satchel"):
		return "%d of %d" % [trap_charges, traps_carried()]
	if has_item("shadow_shroud"):
		return "%d of %d" % [shadow_kills, SHROUD_KILLS]
	return ""


func burst_cost() -> float:
	return m("burst_cost")


func art_cost() -> float:
	if spirit_left > 0.0 or (has_flag("unmoved") and stone_skin >= SKIN_UNMOVED - 0.001):
		return 0.0
	return float(art_def().get("cost", 0.0)) * m("art_cost")


## What the bar is full of, for "Not enough...".
func _art_fuel() -> String:
	return "Ki" if class_def().get("ki", false) else "mist"


## Mist Burst: gather the mist for a moment, then let it go.
func use_burst() -> void:
	if not has_burst() or _cast_kind != "" or _is_moved_by_mist() or frozen_left > 0.0:
		return
	if burst_cd_left > 0.0:
		return
	if mana < burst_cost():
		say("Not enough mist")
		return
	mana -= burst_cost()
	burst_cd_left = m("burst_cd")
	_cast_kind = "burst"
	_cast_left = 0.45
	_cast_anim()
	sfx("spell", -3.0, 0.55)


## The second ability, from the chosen path.
func use_art() -> void:
	if spirit_left > 0.0:
		_come_back()
		return
	var d := art_def()
	if d.is_empty() or _cast_kind != "" or _is_moved_by_mist() or art_cd_left > 0.0 or frozen_left > 0.0:
		return
	if mana < art_cost():
		say("Not enough %s" % _art_fuel())
		return
	if spec_id == "rift" and _rift_candidates().is_empty():
		say("Nothing to jump to")
		return
	if has_item("trap_satchel") and trap_charges <= 0:
		say("No traps ready")
		return
	if has_item("shadow_shroud") and shadow_kills < SHROUD_KILLS:
		say("%d more kills" % (SHROUD_KILLS - shadow_kills))
		return
	if has_item("rain_of_arrows"):
		if arrows < RAIN_ARROWS:
			say("Needs %d arrows" % RAIN_ARROWS)
			return
		arrows -= RAIN_ARROWS
		_rain_wait = 0.0
	if class_id == "commander" and spec_id == "gunner" and has_flag("last_command") and not command_target_ready:
		command_target_requested.emit()
		return
	mana -= art_cost()
	art_cd_left = maxf(3.5 if class_id == "adept" else 0.5, float(d["cd"]) * m("art_cd"))
	_cast_kind = "command" if class_id == "commander" else "stance" if class_id == "adept" else "ki_blast" if d == WorldLight.ARTS["ki_blast"] else spec_id
	_cast_left = float(d["cast"])
	_cast_anim(str(d.get("anim", "")))
	sfx("spell", -5.0, 1.3)
	# The class's colour flares at the caster's feet, so friends and foes can read what happened.
	world.fx_ring(global_position, 2.2, ClassDefs.color(class_id).lightened(0.4))


# --- The Monk ----------------------------------------------------------------

## A blow that lands gives Ki once, and a little more for each other enemy it catches.
func _ki_from_blow() -> void:
	if _ki_swing == attack_count:
		gain_ki(KI_PER_EXTRA)
	else:
		_ki_swing = attack_count
		gain_ki(KI_PER_HIT)


func gain_ki(amount: float) -> void:
	if class_def().get("ki", false):
		mana = minf(max_mana(), mana + amount * m("ki_gain"))


func _tick_monk(delta: float) -> void:
	if spirit_left > 0.0:
		spirit_left -= delta
		guard_left = maxf(guard_left, 0.15)
		if has_flag("haunting"):
			for z: Zombie in world.zombies_near(global_position, 2.0, 8):
				z.slow(3.0)
		if spirit_left <= 0.0:
			_come_back()
	if has_flag("iron_mountain"):
		_tick_stone_skin(delta)


## Stand still and it grows. Walk and it wears away.
func _tick_stone_skin(delta: float) -> void:
	if Vector2(velocity.x, velocity.z).length() < 0.5 and is_on_floor():
		_still_for += delta
		if _still_for >= SKIN_WAITS:
			var top := SKIN_UNMOVED if has_flag("unmoved") else SKIN_MAX
			stone_skin = minf(top, stone_skin + SKIN_GROWS * (2.0 if has_flag("deep_roots") else 1.0) * delta)
			var step := int(stone_skin / 0.2 + 0.001)
			if step > _skin_step:
				_skin_step = step
				world.fx_ring(global_position, 1.4 + step * 0.4, STANCE_COLOURS["stone"])
				sfx("thunk", -8.0, 0.7)
	else:
		_still_for = 0.0
		stone_skin = maxf(0.0, stone_skin - SKIN_WEARS * (0.5 if has_flag("walking_mountain") else 1.0) * delta)
		_skin_step = int(stone_skin / 0.2 + 0.001)


## All around at once: the Bo's third hit, a change of stance, a landing.
func _sweep(radius: float, power: float, stun_secs := 0.0, col := Color(0.95, 0.85, 0.6)) -> int:
	var d := weapon_def()
	var stats := melee_stats(d) if not d.is_empty() and d["kind"] == WeaponDefs.Kind.MELEE else {"damage": WeaponDefs.DAMAGE * m("melee_damage") * damage_multiplier(), "knock": 3.0}
	var dmg: float = float(stats["damage"]) * power
	world.fx_ring(global_position, radius, col)
	if Net.active():
		Net.blast_fx(global_position + Vector3.UP * 0.8, radius * 0.5, Color(col, 0.3))
	var hits := 0
	for z: Zombie in world.zombies_near(global_position, radius, 16):
		z.take_damage(dmg, z.position - global_position, float(stats["knock"]), z.centre())
		if stun_secs > 0.0:
			z.stun(stun_secs)
		if not d.is_empty() and d["kind"] == WeaponDefs.Kind.MELEE:
			on_melee_connect(z, d)
		on_hit(false)
		hits += 1
	for r: Target in world.rivals_near(global_position, radius):
		world.hit_rival(r, dmg, global_position)
		if stun_secs > 0.0:
			world.status_rival(r, Net.Status.STUN, stun_secs)
		hits += 1
	sfx("swing", -2.0, 0.7)
	if hits > 0:
		shake(0.3)
		sfx("hit", -3.0)
	return hits


func _bo_sweep() -> void:
	_sweep(SWEEP_REACH + (1.5 if has_flag("wide_sweep") else 0.0), 1.0, 0.8 if has_flag("stun_sweep") else 0.0)


func _ki_blast() -> void:
	const REACH := 4.5
	heal(10.0)
	var col := Color(1.0, 0.8, 0.3)
	world.fx_blast(global_position + Vector3.UP * 0.8, REACH * 0.7, Color(col, 0.45))
	world.fx_ring(global_position, REACH, col)
	if Net.active():
		Net.blast_fx(global_position + Vector3.UP * 0.8, REACH * 0.7, Color(col, 0.45))
	var dmg := 30.0 * m("melee_damage") * damage_multiplier()
	for z: Zombie in world.zombies_near(global_position, REACH, 16):
		z.take_damage(dmg, z.position - global_position, 6.0, z.centre())
		on_hit(false)
	for r: Target in world.rivals_near(global_position, REACH):
		world.hit_rival(r, dmg, global_position)
	sfx("blast", -6.0, 1.4)
	shake(0.4)


func _pole_vault() -> void:
	_vaulting = true
	_start_leap(VAULT_REACH * (1.5 if has_flag("high_vault") else 1.0))


func _vault_landing() -> void:
	_vaulting = false
	var crushing := has_flag("crushing")
	_sweep(SWEEP_REACH + (1.5 if has_flag("wide_sweep") else 0.0), VAULT_POWER * (2.0 if crushing else 1.0), 1.5 if crushing else (0.8 if has_flag("stun_sweep") else 0.0))


## The body stays and draws everything. The spirit walks away from it.
func _leave_body() -> void:
	spirit_left = SPIRIT_TIME + (2.0 if has_flag("longer_journey") else 0.0)
	_spirit_home = global_position
	_spirit_taken = 0.0
	world.spawn_ally("body", global_position, spirit_left + 1.0)
	for z: Zombie in world.zombies_near(global_position, 14.0, 16):
		z.taunted_by(_spirit_home)
	_fog_at(global_position + Vector3.UP, 1.4)
	fog_flash = 1.0
	_vm_root.visible = false
	_vm_left.visible = false
	sfx("wraith", -6.0, 1.3)


func body_hit(amount: float) -> void:
	_spirit_taken += amount


## Called when the body falls before the spirit is back: it returns at once, to what is left.
func body_lost() -> void:
	if spirit_left > 0.0:
		_come_back()


func _come_back() -> void:
	spirit_left = 0.0
	world.dismiss_ally("body")
	global_position = _spirit_home + Vector3.UP * 0.04
	velocity = Vector3.ZERO
	_vm_root.visible = true
	_equip()
	heal(SPIRIT_HEAL + _spirit_taken + (20.0 if has_flag("mended") else 0.0))
	_fog_at(global_position + Vector3.UP, 1.4)
	fog_flash = 0.6
	guard_left = maxf(guard_left, 0.3)
	sfx("bell", -6.0, 1.3)
	if has_flag("spirit_strike"):
		_next_hit_mult = 3.0
	if has_flag("enlightened"):
		const REACH := 6.0
		var dmg := 80.0 * damage_multiplier()
		world.fx_blast(global_position + Vector3.UP, REACH * 0.7, Color(0.7, 0.95, 1.0, 0.45))
		world.fx_ring(global_position, REACH, Color(0.7, 0.95, 1.0))
		if Net.active():
			Net.blast_fx(global_position + Vector3.UP, REACH * 0.7, Color(0.7, 0.95, 1.0, 0.45))
		for z: Zombie in world.zombies_near(global_position, REACH, 16):
			z.take_damage(dmg, z.position - global_position, 3.0, z.centre())
			z.stun(1.5)
			on_hit(false)
		for r: Target in world.rivals_near(global_position, REACH):
			world.hit_rival(r, dmg, global_position)
			world.status_rival(r, Net.Status.STUN, 1.5)


func _mountain_stomp() -> void:
	var top := SKIN_UNMOVED if has_flag("unmoved") else SKIN_MAX
	var built := clampf(stone_skin / top, 0.0, 1.0)
	var radius := 4.0 + 5.0 * built
	var dmg := (25.0 + 75.0 * built) * m("melee_damage") * damage_multiplier()
	var throw_power := (6.0 + 6.0 * built) * (2.0 if has_flag("landslide") else 1.0)
	var col := Color(0.8, 0.72, 0.55)
	world.fx_blast(global_position + Vector3.UP * 0.2, radius * 0.6, Color(col, 0.45))
	world.fx_ring(global_position, radius, col)
	if Net.active():
		Net.blast_fx(global_position + Vector3.UP * 0.2, radius * 0.6, Color(col, 0.45))
	for z: Zombie in world.zombies_near(global_position, radius, 18):
		z.take_damage(dmg, z.position - global_position, throw_power, z.centre())
		if built >= 0.5:
			z.stun(0.8)
		if has_flag("aftershock"):
			z.slow(3.0)
		on_hit(false)
	for r: Target in world.rivals_near(global_position, radius):
		world.hit_rival(r, dmg, global_position)
		if has_flag("aftershock"):
			world.status_rival(r, Net.Status.SLOW, 3.0)
	stone_skin = 0.0
	_skin_step = 0
	_still_for = 0.0
	_land_dip = 1.0
	shake(1.0)
	sfx("blast", -2.0, 0.7)
	_noise(12.0)


# --- The Adept ---------------------------------------------------------------

func _enter_stance(next: String) -> void:
	if _stance_mastered:
		mods["melee_damage"] -= 0.15
		_stance_mastered = false
	stance_hits = 0
	if stance != "":
		var leaving: Dictionary = STANCE_ADDS[stance]
		for k: String in leaving:
			mods[k] = float(mods[k]) - float(leaving[k])
	stance = next
	var coming: Dictionary = STANCE_ADDS[next]
	for k: String in coming:
		mods[k] = float(mods[k]) + float(coming[k])


func _void_is_ready() -> bool:
	return has_flag("void_walker") and void_left <= 0.0 and _void_hits.size() >= (2 if has_flag("quick_emptiness") else 3)


func _change_stance() -> void:
	_transition_power = 1.6 if stance_hits >= 3 else 1.0
	stance_hits = 0
	var next: String = STANCES[(STANCES.find(stance) + 1) % STANCES.size()]
	if _void_is_ready():
		next = "void"
		_void_hits = {}
		_void_extensions = 0
		void_left = VOID_TIME + (2.0 if has_flag("deeper_void") else 0.0)
		invis_left = maxf(invis_left, void_left)
		heal(15.0)
		_fog_at(global_position + Vector3.UP, 1.5)
		sfx("wraith", -4.0, 0.8)
	elif void_left > 0.0:
		void_left = 0.0
		_left_void()
	_enter_stance(next)
	var col: Color = STANCE_COLOURS[next]
	world.fx_ring(global_position, 2.2, col)
	sfx("weapon_change", -3.0, 0.8)
	say("%s stance" % STANCE_NAMES[next])
	if has_flag("mirror_step"):
		mirror_guard_left = 1.2 + (0.6 if _transition_power > 1.0 else 0.0)
		_next_hit_mult = maxf(_next_hit_mult, 1.5)
		_undo_hit()
	if has_flag("blade_dancer"):
		_dance_sweep()
		if has_flag("storm_of_steel"):
			_second_sweep = 0.25


func _dance_sweep() -> void:
	var hits := _sweep(SWEEP_REACH + (1.5 if has_flag("wide_sweep") else 0.0), (1.5 if has_flag("whirl") else 1.0) * _transition_power, 1.0 if has_flag("stance_echo") and stance == "stone" else 0.0, STANCE_COLOURS[stance])
	if hits <= 0:
		return
	if hp < max_hp():
		heal(minf(10.0, 2.0 * hits))
	if has_flag("stance_echo"):
		for z: Zombie in world.zombies_near(global_position, SWEEP_REACH + 1.5, 16):
			if stance == "wind":
				z.slow(3.0)
			elif stance == "flame":
				z.ignite(ZombieDefs.BURN_SECONDS)
	if has_flag("flowing_health"):
		heal(6.0)
	if has_flag("dance_on"):
		_act({"do": "buff", "key": "dance_on", "stat": "melee_rate", "val": 0.15, "secs": 4.0, "max": 3}, {})


## Mirror Step: the hit that just landed never happened.
func _undo_hit() -> void:
	if _last_hit_left <= 0.0 or dead:
		return
	var taken := _last_hit
	_last_hit_left = 0.0
	heal(taken + 10.0 + (10.0 if has_flag("still_reflection") else 0.0))
	hurt_flash = 0.0
	_fog_at(global_position + Vector3.UP, 1.1)
	say("Stepped aside")
	sfx("wraith", -7.0, 1.8)
	if has_flag("counterstep"):
		_next_hit_mult = 2.0
	if has_flag("blinding_step"):
		world.stun_around(global_position, 4.0, 1.0)
	if has_flag("patient_blade"):
		_act({"do": "buff", "key": "patient_blade", "stat": "melee_damage", "val": 0.25, "secs": 4.0}, {})
	if has_flag("perfect_reflection"):
		const REACH := 5.0
		world.fx_ring(global_position, REACH, Color(0.7, 0.85, 1.0))
		for z: Zombie in world.zombies_near(global_position, REACH, 16):
			z.take_damage(taken * 3.0, z.position - global_position, 3.0, z.centre())
			on_hit(false)
		for r: Target in world.rivals_near(global_position, REACH):
			world.hit_rival(r, taken * 3.0, global_position)


func _left_void() -> void:
	if has_flag("aftermath"):
		world.stun_around(global_position, 6.0, 1.5)
	invis_left = 0.0


func _tick_adept(delta: float) -> void:
	if class_id != "adept":
		return
	_last_hit_left = maxf(0.0, _last_hit_left - delta)
	mirror_guard_left = maxf(0.0, mirror_guard_left - delta)
	if void_left > 0.0:
		void_left -= delta
		if void_left <= 0.0:
			_left_void()
			_enter_stance("wind")
			say("Wind stance")
	if _echo_left >= 0.0:
		_echo_left -= delta
		if _echo_left < 0.0:
			_echo_blow()
	if _second_sweep >= 0.0:
		_second_sweep -= delta
		if _second_sweep < 0.0:
			_dance_sweep()


## In Wind stance each blow strikes twice, the second a moment later and weaker.
func _echo_blow() -> void:
	var d := weapon_def()
	if d.is_empty() or d["kind"] != WeaponDefs.Kind.MELEE or dead:
		return
	var stats := melee_stats(d)
	stats["damage"] = float(stats["damage"]) * ECHO_POWER
	var hits := world.melee_hit(self, d, stats)
	_show_smear(d)
	if hits > 0:
		sfx("hit", -7.0, 1.3)


func _healing_tonic() -> void:
	const FRIEND_REACH := 8.0
	var strong := 15.0 if has_flag("strong_tonic") else 0.0
	var untouchable := 2.0 if has_flag("miracle_cure") else 0.0
	heal(30.0 + strong)
	guard_left = maxf(guard_left, untouchable)
	poison_left = 0.0
	bleed_left = 0.0
	world.fx_ring(global_position, FRIEND_REACH, Color(0.4, 0.95, 0.5))
	sfx("eat", -2.0, 0.8)
	for t: Target in world.friends_near(global_position, FRIEND_REACH):
		Net.guard_peer(world.peer_of(t), untouchable, 25.0 + strong)


func cast_progress() -> float:
	return _cast_left if _cast_kind != "" else 0.0


func _is_moved_by_mist() -> bool:
	return _leap_t >= 0.0 or not _rift_targets.is_empty()


func _tick_mist(delta: float) -> void:
	burst_cd_left = maxf(0.0, burst_cd_left - delta)
	art_cd_left = maxf(0.0, art_cd_left - delta)
	if _cast_kind == "":
		return
	if _cast_kind == "sharpshooter":
		_rain_tick(delta)
	_cast_left -= delta
	if _cast_left > 0.0:
		return
	var what := _cast_kind
	_cast_kind = ""
	match what:
		"burst": mist_burst_at(global_position + Vector3.UP, 1.0)
		"leaper": _start_leap()
		"rift": _start_rift()
		"summoner": _summon_revenants()
		"guardian": raise_dome()
		"pyromaniac": _throw_bombs()
		"inventor": _invent()
		"illusionist": _mirror_swap()
		"ki_blast": _ki_blast()
		"bo_master": _pole_vault()
		"spirit_walker": _leave_body()
		"iron_mountain": _mountain_stomp()
		"stance": _change_stance()
		"command": CommanderKit.cast(self)
		"apothecary": _healing_tonic()
		"trapper":
			trap_charges -= 1
			world.place_trap(self, global_position, TRAP_ARMING)
		"duelist":
			flurry_left = FLURRY_TIME
			say("Blade Flurry!")
			world.fx_blast(global_position + Vector3.UP, 1.6, Color(0.5, 0.75, 1.0, 0.4))
		"shadow":
			shadow_kills = 0
			invis_left = maxf(invis_left, SHROUD_TIME)
			say("Invisible")
			world.fx_mist(global_position + Vector3.UP, 1.0)


func mist_burst_at(at: Vector3, power: float) -> void:
	var radius := m("burst_radius") * (0.8 if power < 1.0 else 1.0)
	var dmg := m("burst_damage") * power * damage_multiplier()
	var col := Color(0.62, 0.92, 0.95, 0.5)
	world.fx_blast(at, radius * 0.7, col)
	if Net.active():
		Net.blast_fx(at, radius * 0.7, col)
	sfx("blast", -4.0, 1.5, 0.1)
	_noise(10.0)
	for z: Zombie in world.zombies.duplicate():
		if z.is_alive() and z.position.distance_to(at) <= radius:
			z.take_damage(dmg, z.position - at, 2.0, z.centre())
			z.freeze(WorldLight.BURST_FREEZE)
			on_hit(false)
	for r: Target in world.rivals_near(at, radius):
		world.hit_rival(r, dmg, at)
		world.status_rival(r, Net.Status.FREEZE, WorldLight.BURST_FREEZE)


## A timed damage reduction for the Guardian and nearby allies, including summons.
func raise_dome() -> void:
	var r := m("dome_radius")
	var secs := m("dome_time")
	world.fx_dome(global_position + Vector3.UP * 0.5, r, secs)
	sfx("block", 0.0, 0.7, 0.1)
	dome_left = maxf(dome_left, secs)
	var healing := (30.0 if has_flag("aegis") else 0.0) + oath_reserve
	oath_reserve = 0.0
	if healing > 0.0:
		HeavyArts.heal_party(self, global_position, r, healing)
	for a in world.allies:
		if a.remote_owner == 0 and not a.dead and a.global_position.distance_to(global_position) <= r:
			a.guarded = maxf(a.guarded, secs)
	if Net.active():
		Net.dome(global_position + Vector3.UP * 0.5, r, secs)
		for t: Target in world.friends_near(global_position, r):
			Net.protect_peer(world.peer_of(t), secs, 0.0)
	if has_flag("dome_taunt"):
		for z: Zombie in world.zombies:
			if z.is_alive() and z.position.distance_to(global_position) < 22.0:
				z.taunted_by(global_position)


# --- The Artificer -----------------------------------------------------------

## Where something leaves the hand, and which way it goes: up a little, to carry it.
func _throw_start() -> Vector3:
	return camera.global_position + camera.global_basis.x * 0.2 + Vector3.DOWN * 0.1 - camera.global_basis.z * 0.5


func _throw_velocity(speed: float, spread := 0.0) -> Vector3:
	var dir := (-camera.global_basis.z + Vector3.UP * 0.2).normalized()
	if spread != 0.0:
		dir = dir.rotated(Vector3.UP, spread)
	return dir * speed


func _throw_anim() -> void:
	_swing_time = 0.3
	_swing = 0.0
	_swing_keys = "throw"
	sfx("swing", -3.0, 0.8)


func _throw_bombs() -> void:
	var n := int(m("bomb_count"))
	for i in n:
		var spread := 0.0 if n == 1 else (float(i) / (n - 1) - 0.5) * 0.3
		world.spawn_thrown(_throw_start(), _throw_velocity(17.0 * m("bomb_throw"), spread), Color(0.1, 0.1, 0.12), bomb_burst, true, 1.3)
	_throw_anim()
	fire("throw", {})


func bomb_burst(at: Vector3) -> void:
	var radius := m("bomb_radius")
	var dmg := m("bomb_damage") * damage_multiplier()
	var col := Color(1.0, 0.55, 0.15, 0.55)
	world.fx_blast(at, radius * 0.8, col)
	sfx("blast", -2.0, 1.0, 0.1)
	world.make_noise(at, 16.0)
	for z: Zombie in world.zombies.duplicate():
		if z.is_alive() and z.centre().distance_to(at) <= radius:
			z.take_damage(dmg, z.position - at, 5.0, z.centre())
			z.ignite(ZombieDefs.BURN_SECONDS)
			if has_flag("bomb_stun"):
				z.stun(1.5)
			on_hit(false)
	for r: Target in world.rivals_near(at, radius):
		world.hit_rival(r, dmg, at)
		world.status_rival(r, Net.Status.BURN, ZombieDefs.BURN_SECONDS)
		if has_flag("bomb_stun"):
			world.status_rival(r, Net.Status.STUN, 1.5)
	var patch := minf(radius * 0.6, 3.6)
	world.drop_poison(at, true, m("bomb_fire"), patch)
	if Net.active():
		Net.blast_fx(at, radius * 0.8, col)
		Net.world_fx(Net.Fx.FIRE_PATCH, at, Vector3(m("bomb_fire"), patch, 0))
	if has_flag("chaotic"):
		_scatter_bomblets(at)


## The Pyromaniac's last step: every bomb throws off bomblets, and nobody knows what each will do.
func _scatter_bomblets(at: Vector3) -> void:
	var kinds: Array = WorldLight.BOMBLET_COLOURS.keys()
	for i in 6:
		var kind: String = kinds[randi() % kinds.size()]
		var a := randf() * TAU
		var vel := Vector3(cos(a), randf_range(0.9, 1.4), sin(a)).normalized() * randf_range(8.0, 12.0)
		var shot := world.spawn_thrown(at + Vector3.UP * 0.5, vel, WorldLight.BOMBLET_COLOURS[kind], func(p: Vector3) -> void: _bomblet_burst(p, kind), kind == "fire", 0.7)
		if shot:
			shot.chaos_left = 2


func _bomblet_burst(at: Vector3, kind: String) -> void:
	const REACH := 3.2
	var col: Color = WorldLight.BOMBLET_COLOURS[kind]
	world.fx_blast(at, REACH * 0.6, Color(col, 0.45))
	if Net.active():
		Net.blast_fx(at, REACH * 0.6, Color(col, 0.45))
	sfx("blast", -9.0, 1.4, 0.08)
	var dmg := m("bomb_damage") * 0.3 * damage_multiplier()
	for z: Zombie in world.zombies_near(at, REACH, 8):
		z.take_damage(dmg, z.position - at, 2.0, z.centre())
		on_hit(false)
		match kind:
			"fire": z.ignite(ZombieDefs.BURN_SECONDS)
			"frost": z.freeze(1.5)
			"thunder": z.stun(0.8)
			"poison":
				z.add_dot(10.0, 4.0)
				_note_poison(40.0)
	for r: Target in world.rivals_near(at, REACH):
		world.hit_rival(r, dmg, at)
		match kind:
			"fire": world.status_rival(r, Net.Status.BURN, 2.0)
			"poison": world.status_rival(r, Net.Status.POISON, 4.0)
			"frost": world.status_rival(r, Net.Status.FREEZE, 1.5)
			"thunder": world.status_rival(r, Net.Status.STUN, 0.8)
	match kind:
		"fire": world.drop_poison(at, true, 2.5, 1.6)
		"poison": world.drop_poison(at)
		"thunder": world.flash_bolt(at)


func spec_chosen() -> void:
	if class_id == "commander":
		CommanderKit.equip(self)
	if spec_id == "inventor":
		_roll_invention()


## What is in the Inventor's bag right now.
func _inventions() -> Array[String]:
	var bag: Array[String] = ["volley", "flask"]
	if has_flag("inv_sentry"):
		bag.append("sentry")
	if has_flag("inv_boots"):
		bag.append("boots")
	if has_flag("inv_noise"):
		bag.append("noise")
	if has_flag("inv_magnet"):
		bag.append("magnet")
	return bag


func _roll_invention() -> void:
	var bag := _inventions()
	if bag.size() > 1:
		bag.erase(_last_invention)
	_next_invention = bag[randi() % bag.size()]


func _invent() -> void:
	var what := _next_invention
	if what == "":
		_roll_invention()
		what = _next_invention
	_run_invention(what)
	if has_flag("eureka"):
		_later.append({"left": 0.5, "do": func() -> void: _run_invention(what)})
	if m("inv_heal") > 0.0:
		heal(m("inv_heal"))
	_last_invention = what
	_roll_invention()


func _run_invention(what: String) -> void:
	match what:
		"volley":
			_volley_left += int(m("volley_darts"))
			_volley_timer = 0.0
			sfx("spell", -3.0, 1.6)
		"flask":
			world.spawn_thrown(_throw_start(), _throw_velocity(17.0), Color(0.65, 0.95, 1.0), _flask_burst, false, 1.2)
			_throw_anim()
		"sentry":
			var at := global_position - global_basis.z * 2.0
			var cell := world.grid.to_cell(at)
			if not world.grid.is_free(cell):
				at = world.grid.to_world(world.grid.nearest_free(cell))
			world.place_sentry(self, at, WorldLight.SENTRY_TIME)
			sfx("creak", -2.0, 1.2)
		"boots":
			_act({"do": "buff", "key": "steam_boots", "stat": "speed", "val": 0.8, "secs": 4.0}, {})
			guard_left = maxf(guard_left, 2.0)
			_fog_at(global_position + Vector3.UP * 0.5, 1.2)
			sfx("wraith", -9.0, 1.6, 0.2)
		"noise":
			world.spawn_thrown(_throw_start(), _throw_velocity(17.0), Color(0.78, 0.6, 0.24), _noise_burst, false, 1.3)
			_throw_anim()
		"magnet":
			world.spawn_thrown(_throw_start(), _throw_velocity(17.0), Color(0.75, 0.2, 0.2), _magnet_burst, false, 1.3)
			_throw_anim()


func _tick_artificer(delta: float) -> void:
	if _volley_left > 0:
		_volley_timer -= delta
		if _volley_timer <= 0.0:
			_volley_timer = 0.09
			_volley_left -= 1
			var dir := world.assist_aim(camera.global_position, -camera.global_basis.z, 40.0)
			dir = dir.rotated(Vector3.UP, randf_range(-0.03, 0.03))
			world.spawn_dart(_throw_start(), dir * 55.0, WeaponDefs.DAMAGE * m("inv_damage") * damage_multiplier(), int(m("volley_jumps")))
			sfx("crossbow", -7.0, 1.5, 0.04)
	for i in range(_later.size() - 1, -1, -1):
		_later[i]["left"] = float(_later[i]["left"]) - delta
		if float(_later[i]["left"]) <= 0.0:
			var job: Callable = _later[i]["do"]
			_later.remove_at(i)
			job.call()


## The spark from a dart: on to whatever is close, and from there to the next.
func spark_from(first: Zombie, jumps: int, damage: float) -> void:
	var hit: Array[RID] = [first.get_rid()]
	var from := first.centre()
	first.stun(0.25)
	for i in jumps:
		var next := world.nearest_zombie_excluding(from, WorldLight.SPARK_REACH, hit)
		if next == null:
			return
		hit.append(next.get_rid())
		var to := next.centre()
		world.fx_spark(from, to)
		if Net.active():
			Net.world_fx(Net.Fx.SPARK, from, to)
		next.take_damage(damage * 0.7, to - from, 1.0, to)
		next.stun(0.25)
		on_hit(false)
		sfx("thunder", -16.0, 1.8, 0.08)
		from = to


func _flask_burst(at: Vector3) -> void:
	var radius := m("flask_radius")
	var col := Color(0.65, 0.95, 1.0, 0.5)
	world.fx_blast(at, radius * 0.8, col)
	if Net.active():
		Net.blast_fx(at, radius * 0.8, col)
	sfx("blast", -4.0, 1.6, 0.1)
	for z: Zombie in world.zombies_near(at, radius, 14):
		z.take_damage(40.0 * m("inv_damage") * damage_multiplier(), z.position - at, 0.5, z.centre())
		z.freeze(m("flask_time"))
		on_hit(false)
	for r: Target in world.rivals_near(at, radius):
		world.hit_rival(r, 40.0 * m("inv_damage") * damage_multiplier(), at)
		world.status_rival(r, Net.Status.FREEZE, m("flask_time"))


## Everything close comes to see, and then it goes off.
func _noise_burst(at: Vector3) -> void:
	world.sfx_at("bell", at, -4.0)
	world.fx_blast(at + Vector3.UP * 0.5, 1.2, Color(0.9, 0.75, 0.3, 0.4))
	for z: Zombie in world.zombies_near(at, 24.0, 16):
		z.taunted_by(at)
	_later.append({"left": 3.0, "do": func() -> void:
		var col := Color(1.0, 0.75, 0.3, 0.55)
		world.fx_blast(at, 4.5, col)
		if Net.active():
			Net.blast_fx(at, 4.5, col)
		sfx("blast", -2.0, 0.9, 0.1)
		for z: Zombie in world.zombies_near(at, 6.0, 16):
			z.take_damage(130.0 * m("inv_damage") * damage_multiplier(), z.position - at, 6.0, z.centre())
			on_hit(false)
		for r: Target in world.rivals_near(at, 6.0):
			world.hit_rival(r, 130.0 * m("inv_damage") * damage_multiplier(), at)})


func _magnet_burst(at: Vector3) -> void:
	var col := Color(0.85, 0.3, 0.3, 0.4)
	world.fx_blast(at, 3.0, col)
	if Net.active():
		Net.blast_fx(at, 3.0, col)
	sfx("blast", -6.0, 0.6, 0.1)
	for z: Zombie in world.zombies_near(at, 10.0, 16):
		z.pull_to(at)
		z.stun(3.0)
		z.take_damage(30.0 * m("inv_damage") * damage_multiplier(), Vector3.ZERO, 0.0, z.centre())
		on_hit(false)
	for r: Target in world.rivals_near(at, 10.0):
		world.hit_rival(r, 30.0 * m("inv_damage") * damage_multiplier(), at)
		world.status_rival(r, Net.Status.STUN, 3.0)


## The Illusionist's trick: gone from here and there already, with something left behind to look at.
func _mirror_swap() -> void:
	var dir := global_basis * Vector3(input_move.x, 0, input_move.y)
	if dir.length_squared() < 0.04:
		dir = -global_basis.z
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var from := global_position
	var to := leap_landing(from, dir, m("swap_range"))
	var side := Vector3(-dir.z, 0, dir.x)
	for i in int(m("swap_decoys")):
		world.spawn_ally("decoy", from + side * (i * 1.6), m("swap_decoy_time") * m("ally_time"))
	# Everything close turns to look at what is still standing there.
	for z: Zombie in world.zombies_near(from, 14.0, 16):
		z.taunted_by(from)
	_fog_at(from + Vector3.UP, 1.2)
	global_position = to + Vector3.UP * 0.04
	velocity = Vector3.ZERO
	_fog_at(to + Vector3.UP, 0.9)
	fog_flash = 0.6
	guard_left = maxf(guard_left, 0.3)
	sfx("wraith", -8.0, 1.7, 0.2)
	if has_flag("swap_fade"):
		invis_left = maxf(invis_left, 2.5)
	if has_flag("swap_forget"):
		world.forget_around(to, 10.0)
	if has_flag("swap_legion"):
		for i in 3:
			var a := TAU * i / 3.0 + rotation.y
			world.spawn_ally("mirror", to + Vector3(sin(a), 0, cos(a)) * 1.8, 8.0 * m("ally_time"))
	_noise(4.0)


## What a decoy does when it ends, whether it was broken or simply ran out.
func decoy_burst(at: Vector3) -> void:
	var radius := m("swap_radius")
	var dmg := m("swap_burst") * damage_multiplier()
	var col := Color(0.72, 0.4, 0.95, 0.5)
	world.fx_blast(at, radius * 0.8, col)
	if Net.active():
		Net.blast_fx(at, radius * 0.8, col)
	world.sfx_at("blast", at, -5.0)
	for z: Zombie in world.zombies_near(at, radius, 16):
		z.take_damage(dmg, z.position - at, 3.0, z.centre())
		if has_flag("swap_stun"):
			z.stun(1.5)
		on_hit(false)
	for r: Target in world.rivals_near(at, radius):
		world.hit_rival(r, dmg, at)
		if has_flag("swap_stun"):
			world.status_rival(r, Net.Status.STUN, 1.5)


## A hit a friend's Guardian took for them.
func take_shared(amount: float) -> void:
	if dead or guard_left > 0.0:
		return
	var dmg := amount * (1.0 - WorldLight.DOME_REDUCTION if dome_left > 0.0 else 1.0) * m("damage_taken") * (1.0 - minf(0.6, m("shield")))
	hp -= dmg
	hurt_flash = maxf(hurt_flash, 0.4)
	sfx("block", -8.0, 1.0, 0.15)
	if hp <= 0.0:
		_on_fatal()


## Forward, or the way the stick points. Over low things and water, up or down the land, and never
## through a wall or further uphill than a leap can carry you.
func _start_leap(reach := -1.0) -> void:
	var dir := global_basis * Vector3(input_move.x, 0, input_move.y)
	if dir.length_squared() < 0.04:
		dir = -global_basis.z
	dir = Vector3(dir.x, 0, dir.z).normalized()
	_leap_from = global_position
	_leap_to = leap_landing(global_position, dir, m("leap_range") if reach < 0.0 else reach)
	_leap_t = 0.0
	guard_left = maxf(guard_left, 0.55)
	sfx("jump_a", -2.0, 0.8)
	_mist_trail = 0.0
	if _vaulting:
		return
	sfx("wraith", -9.0, 1.4, 0.3)
	fog_flash = 1.0
	_fog_at(global_position + Vector3.UP * 0.5, 1.5)


func leap_landing(from: Vector3, dir: Vector3, reach: float) -> Vector3:
	var best := from
	var space := get_world_3d().direct_space_state
	var prev := from
	var d := 0.5
	while d <= reach:
		var p := from + dir * d
		p.y = world.ground_at(p)
		if p.y - from.y > WorldLight.LEAP_CLIMB:
			break
		var q := PhysicsRayQueryParameters3D.create(prev + Vector3.UP * 1.25, p + Vector3.UP * 1.25, 1 | Terrain.LAYER)
		if not space.intersect_ray(q).is_empty():
			break
		if world.grid.is_free(world.grid.to_cell(p)):
			best = p
		prev = p
		d += 0.5
	return best


func _fog_at(at: Vector3, size: float) -> void:
	world.fx_mist(at, size)
	if Net.active():
		Net.mist(at, size)


func _tick_leap(delta: float) -> void:
	_leap_t += delta / 0.42
	_mist_trail -= delta
	if _mist_trail <= 0.0 and not _vaulting:
		_mist_trail = 0.07
		_fog_at(global_position + Vector3.UP * 0.7, 0.8)
	var f := minf(_leap_t, 1.0)
	var pos := _leap_from.lerp(_leap_to, f)
	pos.y += sin(f * PI) * (1.6 + _leap_from.distance_to(_leap_to) * 0.12)
	global_position = pos
	velocity = Vector3.ZERO
	if _leap_t >= 1.0:
		_leap_t = -1.0
		global_position = _leap_to + Vector3.UP * 0.04
		_was_on_floor = true
		_land_dip = 1.0
		sfx("land", -3.0, 0.8)
		_noise(8.0)
		if _vaulting:
			_vault_landing()
			return
		_fog_at(global_position + Vector3.UP * 0.4, 1.9)
		fog_flash = 1.0
		if has_flag("art_leaper") and hp < max_hp():
			heal(15.0 if has_flag("leap_mend") else 5.0)
		if has_flag("leap_mend"):
			mana = minf(max_mana(), mana + 8.0)
		var hit := m("leap_damage")
		var stuns := has_flag("leap_stun")
		var freezes := has_flag("leap_freeze")
		if hit > 0.0 or stuns or freezes:
			var col := Color(0.62, 0.92, 0.95, 0.4)
			world.fx_blast(global_position + Vector3.UP * 0.2, 2.6, col)
			for z: Zombie in world.zombies_near(global_position, 4.0, 12):
				if hit > 0.0:
					z.take_damage(hit * damage_multiplier(), z.position - global_position, 2.0, z.centre())
					on_hit(false)
				if freezes:
					z.freeze(WorldLight.BURST_FREEZE)
				elif stuns:
					z.stun(1.0)
			for r: Target in world.rivals_near(global_position, 4.0):
				if hit > 0.0:
					world.hit_rival(r, hit * damage_multiplier(), global_position)
				if freezes:
					world.status_rival(r, Net.Status.FREEZE, WorldLight.BURST_FREEZE)
				elif stuns:
					world.status_rival(r, Net.Status.STUN, 1.0)


func _rift_candidates() -> Array:
	var out: Array = []
	var eye := eye_position()
	for z in world.zombies:
		if z.is_alive() and not z.dormant and z.position.distance_to(global_position) <= WorldLight.RIFT_REACH and world.has_line_of_sight(eye, z.centre()):
			out.append(z)
	for r: Target in world.rivals_near(global_position, WorldLight.RIFT_REACH):
		if world.has_line_of_sight(eye, r.eye_position()):
			out.append(r)
	var here := global_position
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(here) < b.global_position.distance_squared_to(here))
	return out


func _start_rift() -> void:
	var all := _rift_candidates()
	_rift_targets.clear()
	for i in mini(int(m("rift_hops")), all.size()):
		_rift_targets.append(all[i])
	_rift_timer = 0.0
	if _rift_targets.is_empty():
		mana = minf(max_mana(), mana + art_cost())
		art_cd_left = 0.0


## From one to the next, untouchable, cutting each on the way through.
func _tick_rift(delta: float) -> void:
	velocity = Vector3.ZERO
	guard_left = maxf(guard_left, 0.35)
	_rift_timer -= delta
	if _rift_timer > 0.0:
		return
	_rift_timer = 0.17
	var z: Variant = null
	while z == null and not _rift_targets.is_empty():
		var next: Variant = _rift_targets.pop_front()
		if is_instance_valid(next) and ((next is Zombie and next.is_alive()) or (next is Target and not (next as Target).dead)):
			z = next
	if z == null:
		return
	var there: Vector3 = (z as Node3D).global_position
	var away := global_position - there
	away.y = 0.0
	var spot := there + (away.normalized() if away.length_squared() > 0.01 else Vector3.FORWARD) * 1.1
	var cell := world.grid.to_cell(spot)
	if not world.grid.is_free(cell):
		spot = world.grid.to_world(world.grid.nearest_free(cell))
	spot.y = world.ground_at(spot) + 0.05
	world.fx_blast(global_position + Vector3.UP, 0.8, Color(0.62, 0.92, 0.95, 0.35))
	global_position = spot
	if z is Target:
		world.hit_rival(z, m("rift_damage") * damage_multiplier(), spot)
		if has_flag("rift_freeze"):
			world.status_rival(z, Net.Status.FREEZE, 0.8)
	else:
		z.take_damage(m("rift_damage") * damage_multiplier(), there - spot, 1.5, z.centre())
		if has_flag("rift_freeze") and z.is_alive():
			z.freeze(0.8)
	on_hit(false)
	if has_flag("rift_mist"):
		mana = minf(max_mana(), mana + 6.0)
	if has_flag("rift_feast") and hp < max_hp():
		heal(5.0)
	_swing_side = not _swing_side
	_swing_keys = WeaponAnim.keys_for("claw", _swing_side)
	_swing_time = 0.2
	_swing = WeaponAnim.HIT_MOMENT_START
	sfx("hit", -4.0, 1.3, 0.05)


func _summon_revenants() -> void:
	for i in int(m("summon_n")):
		var a := TAU * float(i) / maxf(m("summon_n"), 1.0) + rotation.y
		world.spawn_ally("revenant", global_position + Vector3(sin(a), 0, cos(a)) * 1.8, m("summon_time") * m("ally_time"))
	world.fx_blast(global_position + Vector3.UP, 2.0, Color(0.62, 0.92, 0.95, 0.35))


func damage_multiplier() -> float:
	var mult := PowerDefs.DAEMON_MULTIPLIER if has_power("daemon") else 1.0
	if void_left > 0.0:
		mult *= 2.0
	if has_flag("rage"):
		mult *= 1.0 + 0.6 * (1.0 - clampf(hp / max_hp(), 0.0, 1.0))
	return mult


# --- Movement ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var was := world.begin_act(self)
	_physics_step(delta)
	world.end_act(was)


func _physics_step(delta: float) -> void:
	if dead:
		head.position.y = lerp(head.position.y, 0.3, delta * 4.0)
		return
	slowed_left = maxf(0.0, slowed_left - delta)
	_status_immune = maxf(0.0, _status_immune - delta)
	if frozen_left > 0.0:
		frozen_left -= delta
		if frozen_left <= 0.0:
			_status_immune = PVP_STATUS_GAP
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		input_jump = false
		move_and_slide()
		_tick_riding(delta)
		return
	if ride_behind != 0:
		_tick_seat(delta)
		return
	if _leap_t >= 0.0:
		_tick_leap(delta)
		return
	if not _rift_targets.is_empty():
		_tick_rift(delta)
		return
	var dir := global_basis * Vector3(input_move.x, 0, input_move.y)
	if _cast_kind == "sharpshooter":
		dir = Vector3.ZERO
	var speed := WALK_SPEED * m("speed") * (1.4 if has_power("speed") else 1.0) * (0.5 if zoomed else 1.0) * (RAGE_SPEED if rage_left > 0.0 else 1.0)
	if is_riding():
		speed = WALK_SPEED * (CHARIOT_SPEED if mount_kind() == "chariot" else HORSE_SPEED) * m("horse_speed")
	if spirit_left > 0.0:
		speed *= SPIRIT_SPEED * (SPIRIT_SPEED if has_flag("swift_spirit") else 1.0)
	if slowed_left > 0.0:
		speed *= 0.6
	if bleed_left > 0.0:
		speed *= BLEED_SPEED
	var wading := world.terrain.in_water(global_position.x, global_position.z)
	if wading:
		speed *= WADE_SPEED
	var accel := 14.0 if is_on_floor() else 5.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * speed * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * speed * delta)
	_auto_jump_cd -= delta
	if (Game.auto_jump or bot_peer != 0) and is_on_floor() and _auto_jump_cd <= 0.0 and input_move.length() > 0.25 and _should_auto_jump(dir):
		input_jump = true
		_auto_jump_cd = 0.4
	if is_on_floor():
		if input_jump:
			velocity.y = JUMP_SPEED * (1.2 if is_riding() else 1.0)
			sfx("jump_a", -6.0)
	else:
		velocity.y -= GRAVITY * delta
	input_jump = false
	move_and_slide()
	if world.portals:
		_tick_islands(delta)
	if wading and global_position.y < Terrain.WATER_Y + 0.6:
		var flow := world.terrain.river_flow(global_position.x, global_position.z)
		move_and_collide(Vector3(flow.x, 0, flow.y) * Terrain.CURRENT * delta)
	# However it happened, nobody stays under the ground.
	var floor_y := world.terrain.ground_height(global_position.x, global_position.z) if world.terrain.has_islands() else world.terrain.height(global_position.x, global_position.z)
	if global_position.y < floor_y - 1.0:
		global_position.y = floor_y + 0.1
		velocity.y = 0.0
	if is_on_floor() and not _was_on_floor:
		sfx("land", -8.0)
		_noise(5.0)
		_land_dip = 1.0
	_was_on_floor = is_on_floor()
	_footsteps(delta)
	_tick_riding(delta)


## On the floating islands: gates to step through, and a long way down.
func _tick_islands(delta: float) -> void:
	_gate_wait -= delta
	if is_on_floor() and world.terrain.height(global_position.x, global_position.z) > 0.0:
		_safe_spot = global_position
	if global_position.y < World.FALL_DEATH and spirit_left > 0.0:
		_come_back()
		return
	if global_position.y < World.FALL_DEATH:
		hit_by = "the fall"
		guard_left = 0.0
		_kill()
		if not dead:
			# Undying Rage brings you back up.
			global_position = _safe_spot
			velocity = Vector3.ZERO
		return
	if _gate_wait > 0.0:
		return
	var out := world.portals.exit_from(global_position)
	if out != Vector3.INF:
		global_position = out
		velocity = Vector3.ZERO
		_gate_wait = 1.5
		sfx("spell", -4.0, 1.5)
		hurt_flash = 0.0
		world.fx_ring(out, 3.0, Color(0.45, 0.98, 0.92))


## Riding behind a friend: their horse goes where they go. You can look around and fight.
func _tick_seat(delta: float) -> void:
	var a: Avatar = Net.avatar(ride_behind)
	if a == null or a.dead or not a.is_mounted():
		leave_horse()
		return
	var behind := Vector3(sin(a.rotation.y), 0, cos(a.rotation.y)) * 0.85
	global_position = a.global_position + behind
	velocity = a.velocity
	_tick_riding(delta)


func can_board() -> bool:
	return Net.active() and not dead and ride_behind == 0 and not is_riding() and Net.nearby_horse(global_position) != 0


func board() -> void:
	var peer: int = Net.nearby_horse(global_position)
	if peer != 0:
		Net.ask_to_ride(peer)


func leave_horse() -> void:
	if ride_behind != 0:
		Net.stop_riding(ride_behind)
	ride_behind = 0
	velocity = Vector3.ZERO
	global_position.y = maxf(global_position.y, world.ground_at(global_position) + 0.05)
	say("You climb down")


func _noise(radius: float) -> void:
	world.make_noise(global_position, radius * maxf(0.15, m("noise")))


## Something low ahead with free space above it, like a fence or a crate.
func _should_auto_jump(dir: Vector3) -> bool:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length_squared() < 0.01:
		return false
	flat = flat.normalized()
	var space := get_world_3d().direct_space_state
	var from := global_position
	var reach := 1.5 if is_riding() else 0.95
	var low := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.35, from + Vector3.UP * 0.35 + flat * reach, 1)
	var ahead := space.intersect_ray(low)
	if ahead.is_empty():
		return false
	# Stairs and slopes are walked up, not jumped at.
	if (ahead["normal"] as Vector3).y > 0.5:
		return false
	var high := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.25, from + Vector3.UP * 1.25 + flat * (reach + 0.35), 1)
	if not space.intersect_ray(high).is_empty():
		return false
	var overhead := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.7, from + Vector3.UP * 2.9, 1)
	return space.intersect_ray(overhead).is_empty()


## Walking with the stick pushed halfway is quiet. Running is heard from further away.
func _footsteps(delta: float) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horiz < 1.0:
		return
	_step_timer -= delta * horiz
	if _step_timer <= 0.0:
		_step_timer = 2.3
		if not is_riding():
			sfx("step", -15.0, 1.0, 0.1)
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = 0.5
		var loud := 11.0 if horiz > WALK_SPEED * 0.65 else 3.0
		_noise(16.0 if is_riding() else loud)


func _process(delta: float) -> void:
	var was := world.begin_act(self)
	_process_step(delta)
	world.end_act(was)


func _process_step(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.2)
	heal_flash = maxf(0.0, heal_flash - delta * 2.2)
	hurt_dir_time = maxf(0.0, hurt_dir_time - delta * 1.4)
	level_flash = maxf(0.0, level_flash - delta * 1.2)
	hit_marker = maxf(0.0, hit_marker - delta * 4.0)
	toast_time = maxf(0.0, toast_time - delta)
	_cooldown -= delta
	if dead:
		return
	if poison_left > 0.0 or bleed_left > 0.0:
		poison_left -= delta
		bleed_left -= delta
		_debuff_tick -= delta
		if _debuff_tick <= 0.0:
			_debuff_tick = 1.0
			hit_by = "poison" if poison_left > 0.0 else "bleeding"
			hurt(DEBUFF_DPS, global_position)
			if dead:
				return
	if burn_time > 0.0:
		burn_time -= delta
		if guard_left <= 0.0:
			hp -= BURN_DPS * delta
			damaged.emit(BURN_DPS * delta, "flames")
			hurt_flash = maxf(hurt_flash, 0.3)
			sfx("burn", -14.0, 1.0, 0.5)
			if hp <= 0.0:
				hit_by = "flames"
				_on_fatal()
				if dead:
					return
	_tick_powers(delta)
	_tick_mist(delta)
	_tick_artificer(delta)
	_lit_timer -= delta
	if _lit_timer <= 0.0:
		_lit_timer = 0.25
		_lit = weapon_def().get("burns", false) or world.in_firelight(global_position)
		_warm = world.beside_bonfire(global_position)
	fog_flash = maxf(0.0, fog_flash - delta * 2.6)
	if _warm and hp < max_hp():
		hp = minf(max_hp(), hp + WorldLight.WARMTH * delta)
	if _melee_pending >= 0.0:
		_melee_pending -= delta
		if _melee_pending < 0.0:
			_do_melee_hit()
	_flail_idle += delta
	if _flail_idle > 1.4:
		_flail_stacks = 0
	_handle_fire()
	if bot_peer == 0:
		_animate_view(delta)
	else:
		# Nobody sees a bot's hands, but its swings still need their timing.
		if _swing < 1.0:
			_swing = minf(1.0, _swing + delta / _swing_time)


func attack_interval(d: Dictionary) -> float:
	var rate: float = d["rate"]
	if rage_left > 0.0:
		rate /= RAGE_SPEED
	if flurry_left > 0.0:
		rate /= FLURRY_RATE
	if d["kind"] == WeaponDefs.Kind.MELEE:
		rate /= m("melee_rate")
		if d.get("momentum", false):
			rate /= 1.0 + _flail_stacks * 0.35
		if has_flag("blood_frenzy") and hp < max_hp() * 0.5:
			rate /= 1.5
	elif d["kind"] == WeaponDefs.Kind.SPELL:
		rate /= m("spell_rate")
	else:
		rate /= m("ranged_rate")
	return rate


func _handle_fire() -> void:
	var d := weapon_def()
	if d.is_empty() or not input_fire or _cooldown > 0.0 or _is_moved_by_mist() or frozen_left > 0.0 or spirit_left > 0.0:
		return
	if WeaponDefs.uses_arrows(d) and arrows <= 0:
		_bash("No arrows")
		return
	if d["kind"] == WeaponDefs.Kind.SPELL and mana < float(d["cost"]) * m("spell_cost"):
		_bash("No mana")
		return
	if d["kind"] == WeaponDefs.Kind.MELEE and d.has("cost"):
		if mana < float(d["cost"]):
			_bash("No mist")
			return
		mana -= float(d["cost"])
	if d.get("returning", false) and _axe_out:
		return
	_cooldown = attack_interval(d)
	attack_count += 1
	_vm_mesh.attack()
	match d["kind"]:
		WeaponDefs.Kind.MELEE:
			if weapon_id() == "war_staff":
				_war_attacks += 1
				if _war_attacks % 5 == 0:
					_cast_bolt(CommanderKit.STAFF_BOLT)
					return
			_start_swing(d)
			_flail_idle = 0.0
			if d.get("momentum", false):
				_flail_stacks = mini(3, _flail_stacks + 1)
			sfx("swing", -3.0, 1.15 if weapon_id() == "dagger" else 1.0)
		WeaponDefs.Kind.RANGED:
			if d.get("returning", false):
				_throw_axe(d)
			else:
				if WeaponDefs.uses_arrows(d) and randf() >= m("arrow_save"):
					arrows -= 1
				_fire_arrow(d)
		WeaponDefs.Kind.SPELL:
			mana -= float(d["cost"]) * m("spell_cost")
			_cast_bolt(d)


## With nothing left to shoot you can still hit with what you hold: weak, but never helpless.
func _bash(reason: String) -> void:
	say(reason)
	sfx("empty", -6.0, 1.0, 0.3)
	sfx("swing", -5.0, 0.8)
	_cooldown = BASH["rate"]
	_bash_anim = 1.0
	_bashing = true
	_melee_pending = 0.14


## Each blow starts where the last one ended, so a run of attacks reads as a real combination.
func _start_swing(d: Dictionary) -> void:
	_swing_time = clampf(_cooldown * 0.85, 0.2, 0.85)
	_swing = 0.0
	_swing_side = not _swing_side
	_swing_keys = WeaponAnim.keys_for(str(d.get("swing", "")), _swing_side)
	if has_flag("bo_master") and d.get("swing", "") == "bo":
		_bo_hits += 1
		if _bo_hits % (2 if has_flag("hundred_hands") else 3) == 0:
			_sweep_now = true
			_swing_keys = "bo_spin"
			_swing_time = maxf(_swing_time, 0.5)
	_melee_pending = minf(_swing_time * SWING_HIT, 0.24)
	_smear_left = 0.0


func _ranged_mult() -> float:
	var mult := m("ranged_damage") * damage_multiplier()
	if is_riding():
		mult *= m("riding_ranged")
	if has_flag("still_aim") and Vector2(velocity.x, velocity.z).length() < 0.5:
		mult *= 1.5
	return mult


func _show_smear(d: Dictionary) -> void:
	var roll := WeaponAnim.smear_roll(_swing_keys)
	if is_nan(roll):
		return
	_smear_left = WeaponAnim.SMEAR_TIME
	_smear_roll = roll
	_smear.scale = Vector3.ONE * clampf(float(d.get("range", 2.5)) / 2.6, 0.75, 1.3)
	_smear.material_override = WeaponAnim.mist_smear() if d.get("swing", "") == "claw" else null
	_smear.visible = true


func _fire_arrow(d: Dictionary) -> void:
	var dir := world.assist_aim(camera.global_position, -camera.global_basis.z, float(d["range"]))
	var start := camera.global_position + dir * 0.5 + camera.global_basis.x * 0.08 + Vector3.DOWN * 0.06
	var power := m("ranged_power")
	var speed: float = float(d["speed"]) * power
	var max_range: float = float(d["range"]) * power
	var dmg := WeaponDefs.DAMAGE * float(d.get("power", 1.0)) * _ranged_mult()
	_shot_count += 1
	if has_flag("overdraw") and _shot_count % 3 == 0:
		dmg *= 2.0
	if has_flag("killing_shot") and _kill_shot_cd <= 0.0:
		_kill_shot_cd = 6.0
		dmg = 300.0
		say("Killing Shot!")
	world.spawn_player_arrow(self, start, dir * speed + Vector3.UP * 0.5, float(d["gravity"]), max_range, float(d["knock"]), dmg)
	if has_flag("twin_shot"):
		var side := dir.rotated(Vector3.UP, deg_to_rad(4.0))
		world.spawn_player_arrow(self, start, side * speed + Vector3.UP * 0.5, float(d["gravity"]), max_range, float(d["knock"]), dmg)
	_kick = 1.0
	if d.get("silent", false):
		sfx("bow", -16.0, 1.6)
		return
	if d.has("shot"):
		_swing_time = 0.3
		_swing = 0.0
		_swing_keys = "throw"
		sfx("swing", -3.0, 0.75)
	else:
		sfx("crossbow" if weapon_id() == "crossbow" else "bow", -2.0, 0.85 if weapon_id() == "longbow" else 1.0)
	_noise(4.0)


func _throw_axe(d: Dictionary) -> void:
	var dir := world.assist_aim(camera.global_position, -camera.global_basis.z, float(d["range"]))
	var start := camera.global_position + dir * 0.5 + camera.global_basis.x * 0.08
	_axe_out = true
	_swing_time = 0.3
	_swing = 0.0
	_swing_keys = "throw"
	var dmg := WeaponDefs.DAMAGE * float(d.get("power", 1.0)) * _ranged_mult()
	world.spawn_axe(self, start, dir * float(d["speed"]) * m("ranged_power"), float(d["range"]) * m("ranged_power"), float(d["knock"]), dmg)
	sfx("swing", -3.0, 0.8)
	_noise(3.0)


func axe_returned() -> void:
	_axe_out = false
	_vm_mesh.visible = true
	_switch_anim = 0.18
	sfx("weapon_change", -8.0, 1.2)


func _cast_bolt(d: Dictionary) -> void:
	var dir := world.assist_aim(camera.global_position, -camera.global_basis.z, float(d["range"]))
	var start := camera.global_position + dir * 0.6 + camera.global_basis.x * 0.12 + Vector3.DOWN * 0.02
	_shot_count += 1
	var meteor := has_flag("meteor") and _shot_count % 4 == 0
	var dmg := WeaponDefs.DAMAGE * m("spell_damage") * damage_multiplier() * (1.8 if weapon_id() == "war_staff" else 1.0)
	var element := ""
	if has_flag("elements"):
		element = ["fire", "frost", "storm"][_shot_count % 3]
	world.spawn_bolt(self, start, dir * float(d["speed"]), float(d["range"]), float(d["knock"]), dmg, meteor, element, weapon_id() == "war_staff")
	_swing_time = clampf(_cooldown * 0.85, 0.2, 0.6)
	_swing = 0.0
	_swing_keys = "cast"
	sfx("spell", -3.0, 0.7 if meteor else 1.0)
	_noise(4.0)


func melee_stats(d: Dictionary) -> Dictionary:
	var mult := m("melee_damage") * damage_multiplier() * _next_hit_mult
	if has_flag("rooted") and stone_skin >= SKIN_STRONG:
		mult *= 1.35
	if is_riding():
		mult *= m("riding_damage") * (2.0 if has_flag("couched") else 1.0)
	if d.get("charge", false) and (is_riding() or Vector2(velocity.x, velocity.z).length() > WALK_SPEED * 0.8):
		mult *= 1.5
	return {
		"damage": WeaponDefs.DAMAGE * mult * float(d.get("power", 1.0)),
		"range": float(d["range"]) + m("melee_reach"),
		"cone": float(d["cone"]) + m("melee_cone"),
		"hits": int(d["max_hits"]) + int(m("melee_hits")),
		"knock": float(d["knock"]) * m("knock"),
	}


func _do_melee_hit() -> void:
	var d := weapon_def()
	if _bayonet_pending:
		d = musket_bayonet()
		_bayonet_pending = false
	if _bashing:
		d = BASH
		_bashing = false
	if d.is_empty() or d["kind"] != WeaponDefs.Kind.MELEE:
		return
	var hits := world.melee_hit(self, d, melee_stats(d))
	if hits > 0 and d != BASH:
		fire("melee_swing", {})
	_next_hit_mult = 1.0
	if d != BASH:
		_show_smear(d)
	if _sweep_now:
		_sweep_now = false
		_bo_sweep()
	if class_id == "adept" and hits > 0 and d != BASH and STANCES.has(stance):
		stance_hits = mini(3, stance_hits + 1)
		if stance_hits == 3 and not _stance_mastered:
			mods["melee_damage"] += 0.15
			_stance_mastered = true
	if stance == "wind" and hits > 0 and d != BASH:
		_echo_left = ECHO_AFTER
	if hits > 0:
		_shake = maxf(_shake, 0.1 + float(d.get("knock", 1.0)) * 0.05)
		sfx("hammer" if d.has("stun") else "hit", -3.0 if not d.has("stun") else -1.0)
		sfx("clang", -14.0, 1.0, 0.1)
		_noise(float(d.get("loud", 9.0)))


## Rules applied to every zombie a melee swing connects with.
func on_melee_connect(z: Zombie, d: Dictionary) -> void:
	_ki_from_blow()
	if stance == "flame":
		z.ignite(ZombieDefs.BURN_SECONDS)
	if has_flag("void_walker") and STANCES.has(stance):
		_void_hits[stance] = true
	if has_flag("execution") and z.is_alive() and z.hp < z.max_hp * 0.3:
		z.take_damage(9999.0, Vector3.FORWARD, 0.0, z.centre())
		return
	if has_flag("blood_frenzy") and hp < max_hp() * 0.5:
		hp = minf(max_hp(), hp + 3.0)
	if weapon_id() == "musket" and has_flag("bayonet_stagger"):
		z.stun(0.6)
	if d.get("burns", false):
		z.ignite(ZombieDefs.BURN_SECONDS)
	if d.has("stun"):
		z.stun(float(d["stun"]))
	if d.get("bleed", false):
		z.add_dot(8.0, 3.0, true)
	if rage_left > 0.0:
		z.ignite(ZombieDefs.BURN_SECONDS)
	if d.get("backstab", false) and z.is_alive():
		var facing := Vector3(sin(z.rotation.y), 0, cos(z.rotation.y))
		if facing.dot(global_position - z.position) < 0.0:
			z.take_damage(melee_stats(d)["damage"], Vector3.ZERO, 0.0, z.centre())
			say("Backstab!")
	fire("hit", {"z": z})


## A melee blow that lands on another player brings its rules along.
func on_melee_rival(peer: int, d: Dictionary) -> void:
	_ki_from_blow()
	if stance == "flame":
		status_on(peer, Net.Status.BURN, ZombieDefs.BURN_SECONDS)
	if has_flag("void_walker") and STANCES.has(stance):
		_void_hits[stance] = true
	if d.get("burns", false):
		status_on(peer, Net.Status.BURN, ZombieDefs.BURN_SECONDS)
	if d.has("stun"):
		status_on(peer, Net.Status.STUN, float(d["stun"]))
	if d.get("bleed", false):
		status_on(peer, Net.Status.BLEED, 3.0)
	fire("hit", {"rival": peer})


## Arrows and bolts likewise.
func on_shot_rival(peer: int, fire_shot: bool, frost_shot: bool) -> void:
	gain_ki(KI_PER_SHOT)
	if fire_shot:
		status_on(peer, Net.Status.BURN, ZombieDefs.BURN_SECONDS)
	if frost_shot:
		status_on(peer, Net.Status.SLOW, ZombieDefs.BURN_SECONDS)
	fire("shot", {"rival": peer})


## Rules for arrows and bolts that reach a zombie.
func on_shot_connect(z: Zombie) -> void:
	gain_ki(KI_PER_SHOT)
	fire("shot", {"z": z})


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func on_hit(head_shot: bool) -> void:
	hit_marker = 1.0
	hit_head = head_shot


func _animate_view(delta: float) -> void:
	var d := weapon_def()
	var target_fov := BASE_FOV
	if zoomed and d.has("zoom_fov"):
		target_fov = float(d["zoom_fov"])
	camera.fov = lerpf(camera.fov, target_fov, min(1.0, delta * 12.0))
	_shake = maxf(0.0, _shake - delta * 3.5)
	camera.rotation.z = sin(Time.get_ticks_msec() * 0.045) * _shake * 0.03
	if d.is_empty():
		return
	var horiz := Vector2(velocity.x, velocity.z).length()
	_bob += delta * horiz * 1.7
	_kick = lerpf(_kick, 0.0, min(1.0, delta * 11.0))
	if _swing < 1.0:
		_swing = minf(1.0, _swing + delta / _swing_time)
	_switch_anim = maxf(0.0, _switch_anim - delta)
	_bash_anim = maxf(0.0, _bash_anim - delta * 2.6)
	_land_dip = maxf(0.0, _land_dip - delta * 5.0)
	_sway = _sway.lerp(Vector2.ZERO, min(1.0, delta * 9.0))
	if _cooldown > 0.0:
		_reload = 1.0 - _cooldown / maxf(attack_interval(d), 0.01)
	else:
		_reload = 1.0
	if _smear_left > 0.0:
		_smear_left -= delta
		var fade := clampf(_smear_left / WeaponAnim.SMEAR_TIME, 0.0, 1.0)
		_smear.visible = _smear_left > 0.0
		_smear.position = Vector3(0, -0.12, -0.25)
		_smear.rotation = Vector3(0.5, (0.5 - fade) * WeaponAnim.smear_turn(_swing_keys), _smear_roll)
	pose_weapon(d, _swing)


## Places the held weapon for a moment of its attack. Split out so a test can draw any moment.
func pose_weapon(d: Dictionary, t: float) -> void:
	var pos: Vector3 = d["pos"]
	# Walking, looking around and landing all move the hands a little, and a beat behind the head.
	pos += Vector3(sin(_bob) * 0.008, absf(cos(_bob)) * 0.01 - _land_dip * 0.05, 0.0)
	pos.y -= _switch_anim * 0.6
	pos.x -= clampf(_sway.x * 0.35, -0.05, 0.05)
	pos.y += clampf(_sway.y * 0.35, -0.05, 0.05)
	var rest := WeaponAnim.rest_rotation(str(d.get("swing", "")), float(d.get("tilt", 0.0)))
	var pose := WeaponAnim.sample(_swing_keys, t, float(d.get("arc", 1.0)))
	pos += pose[0]
	var q: Quaternion = rest if pose[1] == null else pose[1]
	if _bash_anim > 0.0:
		var s := sin(_bash_anim * PI)
		pos += Vector3(-0.1 * s, 0.02 * s, -0.3 * s)
		q = q * Quaternion(Vector3(0, 0, 1), s * 0.7) * Quaternion(Vector3(1, 0, 0), -s * 0.35)
	if d["kind"] == WeaponDefs.Kind.RANGED and not d.get("returning", false):
		_pose_shot(d, pos, q)
		return
	if d["kind"] == WeaponDefs.Kind.SPELL:
		var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.006) * 0.12
		var charge := 1.0 - clampf(_reload * 2.5, 0.0, 1.0)
		_vm_orb.scale = Vector3.ONE * (pulse + charge * 0.5)
	if WeaponAnim.both_hands(d):
		_pose_claws(d, pos, q, rest)
		return
	if d.get("returning", false) and _axe_out:
		# The throw leaves the hand at the moment the arm comes through.
		_vm_mesh.visible = t < SWING_HIT + 0.08
	_vm_root.position = pos
	_vm_root.basis = Basis(q).scaled(Vector3.ONE * float(d["scale"]))


## Two hands of mist, one striking at a time. While gathering mist, both come up.
func _pose_claws(d: Dictionary, pos: Vector3, q: Quaternion, rest: Quaternion) -> void:
	var base: Vector3 = d["pos"]
	var scale_basis := Vector3.ONE * float(d["scale"])
	var cast := 0.12 if _cast_kind != "" else 0.0
	var idle := base + Vector3(0, absf(cos(_bob)) * 0.01 + cast, 0)
	if _swing_side or _swing >= 1.0:
		_vm_root.position = pos + Vector3.UP * cast
		_vm_root.basis = Basis(q).scaled(scale_basis)
		_vm_left.position = Vector3(-idle.x, idle.y, idle.z)
		_vm_left.basis = Basis(_mirror(rest)).scaled(scale_basis)
	else:
		_vm_root.position = idle
		_vm_root.basis = Basis(rest).scaled(scale_basis)
		_vm_left.position = Vector3(-pos.x, pos.y + cast, pos.z)
		_vm_left.basis = Basis(_mirror(q)).scaled(scale_basis)


func _mirror(q: Quaternion) -> Quaternion:
	return Quaternion(q.x, -q.y, -q.z, q.w)


## Bows jump forward when they loose and come back as the next arrow is drawn. A crossbow
## kicks up and dips to be spanned. The arrow on the string shows when you can shoot again.
func _pose_shot(d: Dictionary, pos: Vector3, q: Quaternion) -> void:
	var r := clampf(_reload, 0.0, 1.0)
	var loosed := 1.0 - smoothstep(0.0, 0.32, r)
	var drawing := smoothstep(0.3, 0.72, r) * (1.0 - smoothstep(0.8, 1.0, r))
	var aim := Quaternion.IDENTITY
	if weapon_id() in ["crossbow", "musket"]:
		pos += Vector3(0, loosed * 0.03 - drawing * 0.14, loosed * 0.09 + drawing * 0.06)
		aim = Quaternion(Vector3(1, 0, 0), loosed * 0.32 - drawing * 0.55)
	else:
		pos += Vector3(0, loosed * 0.01, -loosed * 0.07 + drawing * 0.05)
		aim = Quaternion(Vector3(0, 0, 1), -loosed * 0.14) * Quaternion(Vector3(1, 0, 0), loosed * 0.1)
	_vm_root.position = pos
	_vm_root.basis = Basis(q * aim).scaled(Vector3.ONE * float(d["scale"]))
	_vm_arrow.visible = weapon_id() in ["bow", "longbow", "crossbow"] and r >= 0.55 and arrows > 0
	if _vm_arrow.visible:
		var nock: Vector3 = d.get("nock", Vector3.ZERO)
		var slide := 1.0 - smoothstep(0.55, 0.85, r)
		_vm_arrow.position = (nock + Vector3(0, -slide * 0.14, slide * 0.1)) / float(d["scale"])


func _unhandled_input(event: InputEvent) -> void:
	# Desktop controls, handy for testing without a phone.
	if dead or DisplayServer.is_touchscreen_available():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		apply_look(motion.relative.x * 0.45, motion.relative.y * 0.45)
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			input_fire = b.pressed
		elif b.button_index == MOUSE_BUTTON_RIGHT and b.pressed:
			toggle_zoom()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_Q: switch_weapon()
			KEY_E: take_nearby_weapon()
			KEY_F: mount()
			KEY_R: use_burst()
			KEY_T: use_art()
			KEY_V: use_bayonet()
			KEY_SPACE: input_jump = true


func poll_keyboard() -> void:
	if DisplayServer.is_touchscreen_available():
		return
	var kb := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).limit_length(1.0)
	# Only take over while keys are in use, so touch input still works on a laptop.
	if kb != Vector2.ZERO or _keyboard_moving:
		input_move = kb
	_keyboard_moving = kb != Vector2.ZERO


static func musket_bayonet() -> Dictionary:
	var d: Dictionary = WeaponDefs.ALL["spear"].duplicate()
	d["power"] = 0.95
	d["range"] = 3.8
	d["rate"] = 0.65
	return d


func use_bayonet() -> void:
	if weapon_id() != "musket" or dead or _cooldown > 0.0 or _cast_kind != "" or frozen_left > 0.0:
		return
	var d := musket_bayonet()
	_cooldown = attack_interval(d)
	_bayonet_pending = true
	attack_count += 1
	_start_swing(d)
	sfx("swing", -4.0)


func _refresh_banner() -> void:
	if _banner != null:
		return
	_banner = MeshInstance3D.new()
	_banner.mesh = WeaponDefs.banner_mesh()
	_banner.layers = 2
	_banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_banner.position = Vector3(-0.52, -0.68, -0.72)
	_banner.rotation.y = PI - 0.2
	_banner.scale = Vector3.ONE * 0.4
	camera.add_child(_banner)
