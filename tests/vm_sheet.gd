extends Node
## Draws each weapon at moments of its attack, so the animation can be checked by eye.
## Args after --: output folder, then optionally weapon ids.

const MOMENTS := [0.0, 0.17, 0.3, 0.45, 0.7]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var ids: Array = args.slice(1) if args.size() > 1 else WeaponDefs.ALL.keys()
	Game.quality = 2
	Game.apply_quality()
	Game.mode = Game.Mode.SANDBOX
	Game.player_class = "ranger"
	var w := World.new()
	add_child(w)
	w.setup(Game.Mode.SANDBOX)
	w.director.set_process(false)
	var p := w.player
	p.set_process(false)
	p.set_physics_process(false)
	p.global_position = Vector3(-4, w.ground_at(Vector3(-4, 0, 3)), 3)
	p.apply_look(0, 0)
	var img_size := Vector2i(320, 180)
	get_window().size = img_size
	for id: String in ids:
		p.slots = [id, null]
		p.current = 0
		p._equip()
		p._switch_anim = 0.0
		var d: Dictionary = WeaponDefs.ALL[id]
		var row := 0
		for side: bool in [true, false]:
			var i := 0
			for t: float in MOMENTS:
				match d["kind"]:
					WeaponDefs.Kind.MELEE:
						p._swing_keys = WeaponAnim.keys_for(str(d.get("swing", "")), side)
					WeaponDefs.Kind.SPELL:
						p._swing_keys = "cast"
						p._reload = t
					_:
						p._swing_keys = "throw" if d.get("returning", false) else ""
						p._reload = t * 1.42
				p._axe_out = false
				p._smear.visible = false
				var roll := WeaponAnim.smear_roll(p._swing_keys)
				if absf(t - 0.3) < 0.01 and not is_nan(roll):
					p._smear.visible = true
					p._smear.position = Vector3(0, -0.12, -0.25)
					p._smear.rotation = Vector3(0.5, 0, roll)
				p.pose_weapon(d, t)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%d_%d.png" % [out, id, row, i])
				i += 1
			row += 1
	get_tree().quit()
