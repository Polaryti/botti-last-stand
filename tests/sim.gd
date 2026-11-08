extends Node
## Balance simulator: a bot plays whole nights through the same inputs as a thumb, with
## human-like limits on reaction, turning and aim. It reads no hidden state a player
## could not see, and it changes no game rule. Output: one "SIM {json}" line per night.
##
## godot --headless --path . res://tests/sim.tscn -- class=ranger spec=0 nights=2 skill=good quality=2

const SPEED := 12

## dodge: steps back from a swing it can see coming, as a skilled player does.
const SKILLS := {
	"great": {"reaction": 0.18, "turn": 500.0, "sigma": 0.9, "fov": 95.0, "dodge": true},
	"good": {"reaction": 0.22, "turn": 420.0, "sigma": 1.1, "fov": 85.0, "dodge": false},
	"avg": {"reaction": 0.4, "turn": 260.0, "sigma": 2.4, "fov": 70.0, "dodge": false},
}

var cls := "infantry"
var spec := 0
var nights := 1
var simulation_seed := 731
var _night_seed := 731
var full_build := false
var skill: Dictionary = SKILLS["good"]
var skill_name := "good"
var map_mode: int = Game.Mode.NIGHT
var _heart_fell := false

var w: World
var pl: Player
var _done := false
var _won := false
var _target: Zombie
var _seen_for := 0.0
var _menu_left := 0.0
var _points_wait := 0.0
var _aim_err := Vector2.ZERO
var _aim_timer := 0.0
var _goal := Vector3.INF
var _path := PackedVector3Array()
var _path_i := 0
var _repath := 0.0
var _stuck_at := Vector3.ZERO
var _stuck_time := 0.0
var _unstick_left := 0.0
var _unstick_dir := Vector3.ZERO
var _last_hurt := -10.0
var _think := 0.0
var _near3 := 0
var _near8 := 0
var _closest := INF
var _closest_dir := Vector3.ZERO
var _dodge_left := 0.0
var _dodge_dir := Vector3.ZERO
var _away := Vector3.ZERO
var _sweep := 0.0
var _damage := {}
var _levels := {}
var _heals := 0.0
var _last_hp := 0.0
var _hunters_max := 0
var _alive_sum := 0.0
var _alive_n := 0
var _now := 0.0
var _trace_every := 0.0
var _trace_left := 0.0
var _phys_sum := 0.0
var _proc_sum := 0.0
var _perf_n := 0
var _shots := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"class": cls = kv[1]
			"seed": simulation_seed = int(kv[1])
			"loadout": full_build = kv[1] == "full"
			"spec": spec = int(kv[1])
			"nights": nights = int(kv[1])
			"mode": map_mode = Game.Mode.FORT if kv[1] == "fort" else Game.Mode.NIGHT
			"skill":
				skill_name = kv[1]
				skill = SKILLS[kv[1]]
			"quality": Game.quality = int(kv[1])
			"difficulty": Game.set("difficulty", int(kv[1]))
			"trace": _trace_every = float(kv[1])
	# Keep every physics step at 1/60 of a game second while running it much faster.
	Engine.physics_ticks_per_second = 60 * SPEED
	Engine.time_scale = float(SPEED)
	Engine.max_physics_steps_per_frame = 32
	Engine.max_fps = 0
	Game.player_class = cls
	Game.auto_jump = true
	Game.set("vibration", false)
	for i in nights:
		_night_seed = simulation_seed + i
		seed(_night_seed)
		_rng.seed = _night_seed
		await _night()
	Sfx.stop_all()
	OS.delay_msec(120) # allow the audio mixing thread to release stopped playback
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


func _night() -> void:
	_heart_fell = false
	_seen_for = 0.0
	_aim_timer = 0.0
	_aim_err = Vector2.ZERO
	_near3 = 0
	_near8 = 0
	_closest = INF
	_closest_dir = Vector3.ZERO
	_dodge_dir = Vector3.ZERO
	_sweep = 0.0
	_points_wait = 0.0
	_path_i = 0
	_repath = 0.0
	_stuck_time = 0.0
	_unstick_left = 0.0
	_last_hurt = -10.0
	_think = 0.0
	_dodge_left = 0.0
	_away = Vector3.ZERO
	_shots = 0
	_trace_left = 0.0
	_done = false
	_won = false
	_target = null
	_menu_left = 0.0
	_goal = Vector3.INF
	_path = PackedVector3Array()
	_damage.clear()
	_levels.clear()
	_heals = 0.0
	_hunters_max = 0
	_alive_sum = 0.0
	_alive_n = 0
	_phys_sum = 0.0
	_proc_sum = 0.0
	_perf_n = 0
	Game.mode = map_mode
	w = World.new()
	add_child(w)
	w.setup(map_mode)
	pl = w.player
	if full_build:
		pl.grant_all_points()
		while pl.points > 0:
			var step := pl.next_step()
			pl.choose_ability(step, spec if step == 3 else 0)
		pl.hp = pl.max_hp()
	w.player_died.connect(func() -> void: _done = true)
	w.fort_lost.connect(func() -> void:
		_heart_fell = true
		_done = true)
	w.dawn_reached.connect(func() -> void:
		_won = true
		_done = true)
	if pl.has_signal("damaged"):
		pl.connect("damaged", func(amount: float, source: String) -> void:
			_damage[source] = float(_damage.get(source, 0.0)) + amount)
	_last_hp = pl.hp
	while not _done:
		await get_tree().physics_frame
		_tick(1.0 / 60.0)
	var result := {
		"seed": _night_seed, "loadout": "full" if full_build else "progression", "class": cls, "spec": _spec_name(), "skill": skill_name, "won": _won, "time": snappedf(w.director.elapsed, 0.1),
		"heart_fell": _heart_fell, "heart": snappedf(w.fort.heart_hp, 1.0) if w.fort else 0.0,
		"kills": pl.kills, "level": pl.level, "hp": snappedf(pl.hp, 1.0), "damage": _rounded(_damage), "heal": int(_heals),
		"levels": _levels, "weapons": pl.slots, "by": str(pl.get("hit_by")), "hunters_max": _hunters_max,
		"alive_avg": snappedf(_alive_sum / maxf(1.0, _alive_n), 0.1),
		"physics_ms": snappedf(_phys_sum / maxf(1.0, _perf_n), 0.01), "process_ms": snappedf(_proc_sum / maxf(1.0, _perf_n), 0.01),
		"flags": (pl.get("flags") as Dictionary).keys() if pl.get("flags") != null else [],
	}
	print("SIM ", JSON.stringify(result))
	w.queue_free()
	w = null
	pl = null
	await get_tree().physics_frame
	await get_tree().physics_frame


func _rounded(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = int(d[k])
	return out


func _spec_name() -> String:
	var id: Variant = pl.get("spec_id")
	return id if id != null and id != "" else "-"


func _revenant_arts() -> void:
	if not pl.call("has_burst"):
		# Bombs, inventions and swaps: used as soon as anything is close enough to be worth it.
		var wanted := 3 if pl.get("spec_id") == "guardian" else 1
		if pl.has_art() and pl.art_cd_left <= 0.0 and _near8 >= wanted:
			if cls == "commander" and pl.spec_id == "gunner" and pl.has_flag("last_command"):
				if _target == null or not is_instance_valid(_target):
					return
				pl.set("command_target", _target.position)
				pl.set("command_target_ready", true)
			pl.use_art()
		return
	if _near8 >= 3 and pl.get("burst_cd_left") <= 0.0:
		pl.call("use_burst")
	if pl.get("spec_id") == "":
		return
	if pl.get("art_cd_left") <= 0.0 and (_near8 >= 2 or (pl.get("spec_id") == "summoner" and _near8 >= 1)):
		pl.call("use_art")


func _tick(dt: float) -> void:
	_revenant_arts()
	if pl.dead:
		return
	_now += dt
	if pl.hp > _last_hp:
		_heals += pl.hp - _last_hp
	elif pl.hp < _last_hp:
		_last_hurt = _now
	_last_hp = pl.hp
	_perf_n += 1
	_phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if not _levels.has(str(pl.level)):
		_levels[str(pl.level)] = int(w.director.elapsed)
	_think -= dt
	if _think <= 0.0:
		_think = 0.1
		_scan()
	if _trace_every > 0.0:
		_trace_left -= dt
		if _trace_left <= 0.0:
			_trace_left = _trace_every
			_trace()
	if _menu_left > 0.0:
		# A person needs a moment in the tree. The game keeps running behind it.
		_menu_left -= dt
		pl.input_move = Vector2.ZERO
		pl.input_fire = false
		return
	if pl.points > 0:
		_points_wait += dt
		if _near8 == 0 or _points_wait > 12.0:
			_choose()
			return
	if pl.has_method("horse_ready") and pl.call("horse_ready") and _near8 >= 1:
		pl.call("mount")
	_weapons()
	_pick_up_weapon()
	var flee := (pl.hp < pl.max_hp() * 0.3 and _near8 > 0) or (not _can_attack() and _near8 > 0)
	_fight(dt)
	_walk(dt, flee)


func _trace() -> void:
	var t := "-"
	if _target and is_instance_valid(_target) and _target.is_alive():
		t = "%s@%.1f" % [_target.type_id, _target.position.distance_to(pl.global_position)]
	print("T %5.1f pos(%5.1f,%5.1f) hp=%3d arrows=%d %s near3=%d near8=%d closest=%.1f target=%s move=(%.1f,%.1f) fire=%s goal=%s" % [
		_now, pl.global_position.x, pl.global_position.z, int(pl.hp), pl.arrows, pl.weapon_id(), _near3, _near8, _closest, t,
		pl.input_move.x, pl.input_move.y, pl.input_fire, "-" if _goal == Vector3.INF else "(%.0f,%.0f)" % [_goal.x, _goal.z]])


## What the player can notice: nearby things, and whatever is in view with a clear line.
func _scan() -> void:
	var here := pl.global_position
	var eye := pl.eye_position()
	var forward := -pl.camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var hurt_recently := _now - _last_hurt < 1.5
	var fov_cos := cos(deg_to_rad(float(skill["fov"])))
	var best: Zombie = null
	var best_score := INF
	_near3 = 0
	_near8 = 0
	_closest = INF
	_away = Vector3.ZERO
	var alive := 0
	var hunting := 0
	for z: Zombie in w.zombies:
		if not z.is_alive():
			continue
		alive += 1
		if z.is_hunting():
			hunting += 1
		if z.get("dormant") == true:
			continue
		var flat := Vector3(z.position.x - here.x, 0, z.position.z - here.z)
		var d := flat.length()
		if z.get("flies") == true and z.position.y - w.ground_at(z.position) > 3.0 and not _has_ranged_ready():
			continue
		if d < _closest and z.position.y - w.ground_at(z.position) < 3.0:
			_closest = d
			_closest_dir = -flat / maxf(d, 0.2)
		if skill["dodge"] and d < 2.6 and z.get("_attack_hit_pending") == true:
			_dodge_left = 0.3
			_dodge_dir = -flat / maxf(d, 0.2)
		if d < 3.5:
			_near3 += 1
		if d < 8.0:
			_near8 += 1
			_away -= flat / maxf(d, 0.2)
		if d > 45.0:
			continue
		var in_view := d < 5.0 or hurt_recently or flat.normalized().dot(forward) > fov_cos
		if not in_view:
			continue
		if not w.has_line_of_sight(eye, z.centre()):
			continue
		var score := d
		if z.type_id == "banshee":
			score -= 8.0 # silence her first
		if z == _target:
			score -= 3.0 # keep attacking the same one
		if score < best_score:
			best_score = score
			best = z
	_hunters_max = maxi(_hunters_max, hunting)
	_alive_sum += alive
	_alive_n += 1
	if best != _target:
		_target = best
		_seen_for = 0.0


## Out of arrows with nothing else to hold, the only move is to find something.
func _can_attack() -> bool:
	for slot: Variant in pl.slots:
		if slot == null:
			continue
		var d: Dictionary = WeaponDefs.ALL[slot]
		if d["kind"] == WeaponDefs.Kind.MELEE or not WeaponDefs.uses_arrows(d) or pl.arrows > 0:
			return true
	return false


func _power() -> float:
	return float(pl.call("m", "ranged_power")) if pl.has_method("m") else 1.0


func _has_ranged_ready() -> bool:
	var d := pl.weapon_def()
	if d.is_empty():
		return false
	return d["kind"] != WeaponDefs.Kind.MELEE and (pl.arrows > 0 or not WeaponDefs.uses_arrows(d))


func _choose() -> void:
	_points_wait = 0.0
	_menu_left = 1.5
	if pl.has_method("steps"):
		var step: int = pl.call("next_step")
		var options: Array = pl.call("steps")[step]
		var pick := _rng.randi() % options.size()
		if step == pl.CORE_STEPS:
			pick = spec
		pl.call("choose_ability", step, pick)
	elif pl.has_method("next_tier"):
		pl.call("choose_ability", pl.call("next_tier"), _rng.randi() % 2)


func _weapons() -> void:
	var d := pl.weapon_def()
	var other: Variant = pl.slots[1 - pl.current]
	if other == null or d.is_empty():
		return
	var other_def: Dictionary = WeaponDefs.ALL[other]
	var now_ranged: bool = d["kind"] != WeaponDefs.Kind.MELEE
	var other_ranged: bool = other_def["kind"] != WeaponDefs.Kind.MELEE
	if now_ranged and WeaponDefs.uses_arrows(d) and pl.arrows <= 0:
		if not WeaponDefs.uses_arrows(other_def):
			pl.switch_weapon()
		return
	if now_ranged and d["kind"] == WeaponDefs.Kind.SPELL and pl.mana < 10.0:
		pl.switch_weapon()
		return
	if _target == null or not is_instance_valid(_target):
		return
	var dist := _target.position.distance_to(pl.global_position)
	if now_ranged and not other_ranged and dist < 3.0:
		pl.switch_weapon()
	elif not now_ranged and other_ranged and dist > 7.0 and (not WeaponDefs.uses_arrows(other_def) or pl.arrows > 0):
		pl.switch_weapon()


func _usable(id: String) -> bool:
	return pl.call("can_use", id) if pl.has_method("can_use") else true


func _weapon_value(id: String) -> float:
	var d: Dictionary = WeaponDefs.ALL[id]
	match d["kind"]:
		WeaponDefs.Kind.SPELL: return 9.0
		WeaponDefs.Kind.RANGED:
			var ammo_ok := not WeaponDefs.uses_arrows(d) or pl.arrows > 5
			var liking := 8.0 if cls == "ranger" else 5.0
			return (liking if ammo_ok else 1.0) + (1.0 / float(d["rate"])) * 0.5
	return 3.0 + float(d["max_hits"]) * 0.4 + float(d["range"]) * 0.3 + (1.0 / float(d["rate"])) * 0.5


func _pick_up_weapon() -> void:
	var p := pl.nearby_weapon
	if p == null or not is_instance_valid(p):
		return
	var worst := INF
	for s: Variant in pl.slots:
		if s != null and s != "staff":
			worst = minf(worst, _weapon_value(s))
	if _weapon_value(p.weapon_id) > worst + 0.5:
		pl.take_nearby_weapon()


func _fight(dt: float) -> void:
	_aim_timer -= dt
	if _aim_timer <= 0.0:
		_aim_timer = 0.35
		var s := deg_to_rad(float(skill["sigma"]))
		_aim_err = Vector2(_rng.randfn(0.0, s), _rng.randfn(0.0, s * 0.7))
	var d := pl.weapon_def()
	pl.input_fire = false
	if _target == null or not is_instance_valid(_target) or not _target.is_alive() or d.is_empty():
		_look_around(dt)
		return
	_seen_for += dt
	if _seen_for < float(skill["reaction"]):
		return
	var eye := pl.eye_position()
	var point := _target.centre()
	var melee: bool = d["kind"] == WeaponDefs.Kind.MELEE
	if pl.weapon_id() == "war_staff" and int(pl.get("_war_attacks")) % 5 == 4:
		melee = false
		d = {"range": 34.0, "speed": 34.0, "gravity": 0.0}
	if pl.weapon_id() == "musket" and point.distance_to(eye) < 3.5:
		pl.call("use_bayonet")
		return
	if not melee:
		var flight := eye.distance_to(point) / maxf(float(d["speed"]), 1.0)
		point += _target.velocity * flight
		point.y += 0.5 * float(d.get("gravity", 0.0)) * flight * flight - 0.5 * flight
	var to := point - eye
	var want_yaw := atan2(-to.x, -to.z) + _aim_err.x
	var want_pitch := atan2(to.y, Vector2(to.x, to.z).length()) + _aim_err.y
	var step := deg_to_rad(float(skill["turn"])) * dt
	pl.yaw += clampf(angle_difference(pl.yaw, want_yaw), -step, step)
	pl.pitch = clampf(move_toward(pl.pitch, want_pitch, step), deg_to_rad(-82), deg_to_rad(82))
	pl.rotation.y = pl.yaw
	pl.head.rotation.x = pl.pitch
	var off := absf(angle_difference(pl.yaw, want_yaw))
	var dist := Vector2(to.x, to.z).length()
	if melee:
		var st: Dictionary = pl.call("melee_stats", d) if pl.has_method("melee_stats") else d
		var cone := deg_to_rad(minf(float(st["cone"]), 180.0) * 0.5)
		pl.input_fire = dist < float(st["range"]) + 0.2 and off < maxf(cone, 0.25)
	else:
		var reach: float = float(d["range"]) * _power()
		pl.input_fire = dist < reach and off < deg_to_rad(5.0) and absf(pl.pitch - want_pitch) < deg_to_rad(5.0)


func _look_around(dt: float) -> void:
	# With nothing to shoot, look where you are going and glance around now and then.
	_sweep += dt
	var dir := Vector3(pl.velocity.x, 0, pl.velocity.z)
	if dir.length_squared() < 0.5:
		dir = Vector3(sin(_sweep * 0.9), 0, cos(_sweep * 0.9))
	var want := atan2(-dir.x, -dir.z) + sin(_sweep * 1.7) * 0.7
	var step := deg_to_rad(float(skill["turn"])) * 0.5 * dt
	pl.yaw += clampf(angle_difference(pl.yaw, want), -step, step)
	pl.pitch = move_toward(pl.pitch, 0.0, step)
	pl.rotation.y = pl.yaw
	pl.head.rotation.x = pl.pitch


func _walk(dt: float, flee: bool) -> void:
	var here := pl.global_position
	var want := Vector3.ZERO
	var d := pl.weapon_def()
	var has_target := _target != null and is_instance_valid(_target) and _target.is_alive()
	var melee: bool = d.is_empty() or d["kind"] == WeaponDefs.Kind.MELEE
	var urgent := _urgent_item()
	if urgent != Vector3.INF and _near3 < 3:
		# Food when hurt, or a familiar close by, is worth a detour even with enemies around.
		_set_goal(urgent)
		want = _follow_path()
		flee = true # keeps the path below
	if want != Vector3.ZERO:
		pass
	elif flee or _near3 >= 3:
		want = _open_direction(_away)
		if flee:
			var help := _nearest_help()
			if help != Vector3.INF and help.distance_to(here) < 14.0:
				_set_goal(help)
				var along := _follow_path()
				if along != Vector3.ZERO:
					want = along
	elif has_target and not _can_attack():
		pass # keep going for the arrows or weapon the errand picked
	elif has_target and melee:
		var flat := _target.position - here
		flat.y = 0.0
		var reach: float = float((pl.call("melee_stats", d) if pl.has_method("melee_stats") else d)["range"])
		if pl.has_method("is_riding") and pl.call("is_riding"):
			want = flat.normalized()
		elif flat.length() > reach * 0.9:
			if flat.length() < 7.0:
				want = flat.normalized()
			else:
				_set_goal(_target.position)
		elif flat.length() < reach * 0.7:
			# Hit and step back: most zombies are slower than you on foot.
			want = _open_direction(-flat.normalized())
	elif has_target:
		var flat := _target.position - here
		flat.y = 0.0
		var dist := flat.length()
		var reach: float = float(d["range"]) * 0.8
		if dist < 6.0:
			want = _open_direction(-flat.normalized())
		elif dist > reach:
			_set_goal(_target.position)
		else:
			# Hold the range and step sideways so nothing lines up.
			want = flat.normalized().rotated(Vector3.UP, PI * 0.5) * (0.5 if int(_now) % 6 < 3 else -0.5)
	if want == Vector3.ZERO and (not has_target or not _can_attack()):
		_repath -= dt
		if _goal == Vector3.INF or _repath <= 0.0 or here.distance_to(_goal) < 1.5:
			_repath = 3.0
			_goal = _pick_errand()
			_path = w.grid.path(here, _goal)
			_path_i = 0
	if want == Vector3.ZERO:
		want = _follow_path()
	elif not flee:
		_path = PackedVector3Array()
		_goal = Vector3.INF
	# Getting stuck on something: try somewhere else.
	_stuck_time += dt
	if _stuck_time > 1.5:
		if here.distance_to(_stuck_at) < 0.5 and want != Vector3.ZERO:
			_goal = Vector3.INF
			_repath = 0.0
			_unstick_left = 0.6
			_unstick_dir = _open_direction(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)))
		_stuck_at = here
		_stuck_time = 0.0
	if _unstick_left > 0.0:
		_unstick_left -= dt
		want = _unstick_dir
	if _dodge_left > 0.0:
		_dodge_left -= dt
		want = _open_direction(_dodge_dir)
	var local := pl.global_basis.inverse() * want
	pl.input_move = Vector2(local.x, local.z).limit_length(1.0)


func _set_goal(at: Vector3) -> void:
	if _goal != Vector3.INF and _goal.distance_to(at) < 3.0 and _path_i < _path.size():
		return
	_goal = at
	_path = w.grid.path(pl.global_position, at)
	_path_i = 0


func _follow_path() -> Vector3:
	var here := pl.global_position
	while _path_i < _path.size() and Vector2(_path[_path_i].x - here.x, _path[_path_i].z - here.z).length() < 0.7:
		_path_i += 1
	if _path_i >= _path.size():
		return Vector3.ZERO
	var to := _path[_path_i] - here
	to.y = 0.0
	return to.normalized()


## Whichever of eight directions is free for the next few metres and closest to where we want to go.
func _open_direction(prefer: Vector3) -> Vector3:
	var here := pl.global_position
	var best := prefer.normalized() if prefer.length_squared() > 0.001 else Vector3.FORWARD
	var best_score := -INF
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector3(cos(a), 0, sin(a))
		var free := 0
		for m in range(1, 7):
			if w.grid.is_free(w.grid.to_cell(here + dir * m)):
				free += 1
			else:
				break
		var score := dir.dot(prefer) * 2.0 + free * 0.5
		if score > best_score:
			best_score = score
			best = dir
	return best


func _urgent_item() -> Vector3:
	var here := pl.global_position
	var share := pl.hp / pl.max_hp()
	var best := Vector3.INF
	var best_d := INF
	for p: Pickup in w.pickups:
		var reach := 0.0
		if p.kind == Pickup.Kind.FOOD and share < 0.7:
			reach = 22.0
		elif p.kind == Pickup.Kind.POWER and PowerDefs.ALL[p.item_id]["familiar"]:
			reach = 16.0
		var d := p.global_position.distance_to(here)
		if d < reach and d < best_d:
			best_d = d
			best = p.global_position
	return best


func _nearest_help() -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for p: Pickup in w.pickups:
		var useful: bool = p.kind == Pickup.Kind.FOOD or (p.kind == Pickup.Kind.POWER and PowerDefs.ALL[p.item_id]["familiar"])
		if not useful:
			continue
		var d := p.global_position.distance_to(pl.global_position)
		if d < best_d:
			best_d = d
			best = p.global_position
	return best


## Nothing to fight: fetch what is useful, or go looking for trouble, since kills are progress.
func _pick_errand() -> Vector3:
	var here := pl.global_position
	var best := Vector3.INF
	var best_score := -INF
	var hurt_share := pl.hp / pl.max_hp()
	for p: Pickup in w.pickups:
		var value := 0.0
		match p.kind:
			Pickup.Kind.FOOD:
				value = 40.0 * (1.0 - hurt_share) if hurt_share < 0.85 else 0.0
			Pickup.Kind.ARROWS:
				value = 14.0 if pl.arrows < 25 and _usable("bow") else 0.0
				if not _can_attack():
					value = 60.0
			Pickup.Kind.POWER:
				value = 30.0 if PowerDefs.ALL[p.item_id]["familiar"] else 10.0
			Pickup.Kind.WEAPON:
				if _usable(p.weapon_id) and not pl.carries(p.weapon_id):
					var worst := INF
					for s: Variant in pl.slots:
						worst = minf(worst, 0.0 if s == null else _weapon_value(s))
					value = 6.0 * (_weapon_value(p.weapon_id) - worst)
					if not _can_attack() and WeaponDefs.ALL[p.weapon_id]["kind"] == WeaponDefs.Kind.MELEE:
						value = 80.0
		if value <= 0.0:
			continue
		var score := value - p.global_position.distance_to(here) * 0.5
		if score > best_score:
			best_score = score
			best = p.global_position
	if best != Vector3.INF and best_score > 0.0:
		return best
	# Head for the nearest enemy we know of: the noise and the sensor of a player's ears.
	var nearest := INF
	for z: Zombie in w.zombies:
		if z.is_alive() and z.get("dormant") != true and z.get("flies") != true:
			var d := z.position.distance_to(here)
			if d < nearest:
				nearest = d
				best = z.position
	if best != Vector3.INF and nearest < 45.0:
		return best
	return w.pois[_rng.randi() % w.pois.size()]
