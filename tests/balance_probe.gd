extends Node
## Exhaustive static loadout probe: all 128 binary builds per profession, plus base loadouts.
## This is a screening metric, not a prediction of multiplayer win rate.

func _ready() -> void:
	Game.quality = 0
	Game.force_weather = Weather.Kind.CLEAR
	Game.mode = Game.Mode.NIGHT
	var w := World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	w.director.set_process(false)
	w.players.clear()
	w.player.free()
	w.player = null
	w.set_process(false)
	for z: Zombie in w.zombies.duplicate():
		z.release()
	for cls: String in ClassDefs.ALL:
		var base := _pawn(w, cls)
		print("BALANCE_BASE ", JSON.stringify(_metrics(base)))
		base.free()
		for spec in 3:
			var values: Array[Dictionary] = []
			for bits in 128:
				var p := _pawn(w, cls)
				p.points = 9
				p.level = 10
				var bit := 0
				for step in 9:
					var option := spec if step == 3 else (bits >> bit) & 1
					if step != 3:
						bit += 1
					p.choose_ability(step, mini(option, p.steps()[step].size() - 1))
				values.append(_metrics(p))
				p.free()
			var row := {"class": cls, "profession": AbilityData.tree(cls)["specs"][spec]["id"], "builds": values.size()}
			for key: String in ["direct_dps", "ehp", "speed", "art_cd"]:
				var numbers := values.map(func(v: Dictionary) -> float: return v[key])
				row[key] = {"min": numbers.min(), "max": numbers.max()}
			print("BALANCE ", JSON.stringify(row))
	w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Sfx.stop_all()
	OS.delay_msec(120)
	get_tree().quit()


func _pawn(w: World, cls: String) -> Player:
	Game.player_class = cls
	var p := Player.new(w)
	# _ready is sufficient for pure loadout metrics; avoid thousands of viewmodel scene attachments.
	w.player = p
	w.add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	return p


func _metrics(p: Player) -> Dictionary:
	var d := p.weapon_def()
	var damage := WeaponDefs.DAMAGE * float(d.get("power", 1.0))
	if d["kind"] == WeaponDefs.Kind.MELEE:
		damage = p.melee_stats(d)["damage"]
		if p.stance == "wind":
			damage *= 1.5
	elif d["kind"] == WeaponDefs.Kind.SPELL:
		damage *= p.m("spell_damage")
	else:
		damage *= p.m("ranged_damage")
	var art := p.art_def()
	return {"class": p.class_id, "direct_dps": snappedf(damage / p.attack_interval(d), 0.1),
		"ehp": snappedf(p.max_hp() / maxf(0.05, p.m("damage_taken") * (1.0 - p.m("dodge"))), 0.1),
		"speed": snappedf(p.m("speed"), 0.01), "art_cd": snappedf(float(art.get("cd", 0)) * p.m("art_cd"), 0.1)}
