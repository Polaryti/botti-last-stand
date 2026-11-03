class_name Avatar
extends Target
## Another player, as seen on this phone. Their phone decides what they do. Here they are a
## body that zombies can hunt and that shots can hit, and anything that hurts them is sent over.

const LAYER_AVATAR := 64
const MODELS := {"infantry": "clever", "ranger": "clever", "heavy": "beast", "chivalry": "beast", "magician": "magic", "revenant": "clever", "artificer": "clever"}

var world: World
var peer := 0
var team := 0
var display := ""
var hp_fraction := 1.0
var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _sight := 1.0
var _unseen := false
var _riding := false
var _attack_seen := 0
var _attack_left := 0.0
var _weapon := ""
var _visual: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _hand: MeshInstance3D
var _label: Label3D
var _current := ""
var _fit := 1.0
var _got_pose := false
var cover_pct := 0.0
var cover_radius := 0.0
var rescues := false
var has_passenger := false
var _seated := false
var _horse: MeshInstance3D
var _chariot: ChariotModel
var in_chariot := false
var _has_turret := false
var _watched := false
var _view_pitch := 0.0


func _init(owner_world: World, peer_id: int, info: Dictionary) -> void:
	world = owner_world
	peer = peer_id
	team = int(info.get("team", 0))
	display = str(info.get("name", "Player"))
	collision_layer = LAYER_AVATAR
	collision_mask = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	_build_body(str(MODELS.get(str(info.get("class", "infantry")), "clever")))
	if str(info.get("class", "")) == "revenant":
		for mi in _visual.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = Ally._ghost()
	add_child(World.make_blob_shadow(1.0))
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0018
	_label.font_size = 28
	_label.outline_size = 8
	_label.position.y = 2.15
	_label.text = display
	_label.modulate = Net.team_colour(team) if Net.rules == Net.Rules.TEAMS else Color(0.86, 0.9, 1.0)
	add_child(_label)


func _build_body(model: String) -> void:
	_visual = (load("res://assets/characters/%s.glb" % model) as PackedScene).instantiate()
	add_child(_visual)
	_visual.rotation.y = PI
	_anim = _visual.find_children("*", "AnimationPlayer", true, false)[0]
	for n: String in ["Idle", "Running_A"]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_skeleton = _visual.find_children("*", "Skeleton3D", true, false)[0]
	var top := 0.0
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.extra_cull_margin = 1.0
		top = maxf(top, part.get_aabb().end.y)
	_fit = 1.8 / float(Zombie.BODY_TOP.get(model, maxf(top, 0.5)))
	_visual.scale = Vector3.ONE * _fit
	var a := BoneAttachment3D.new()
	a.bone_name = "handslot.r"
	_skeleton.add_child(a)
	_hand = MeshInstance3D.new()
	_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(_hand)
	_play("Idle")


## Riding: the horse under them if it is theirs, and either way they sit higher.
func _show_seat() -> void:
	var up := _riding or _seated
	_visual.position.y = (0.5 if in_chariot else 0.85) if up else 0.0
	if _riding and not in_chariot and _horse == null:
		_horse = MeshInstance3D.new()
		_horse.mesh = HorseModel.mesh()
		_horse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_horse)
	if _horse:
		_horse.visible = _riding and not in_chariot and not _watched
	if _riding and in_chariot and _chariot == null:
		_chariot = ChariotModel.new()
		add_child(_chariot)
	if _chariot:
		_chariot.visible = _riding and in_chariot and not _watched
		_chariot.show_upgrades(_has_turret, false)


func is_mounted() -> bool:
	return _riding and not dead


## Whoever is watching through this player's eyes should not see the inside of their head.
func set_watched(on: bool) -> void:
	_watched = on
	_label.visible = not on
	_show_seat()


func view_transform() -> Transform3D:
	_view_pitch = lerpf(_view_pitch, _pitch, 0.25)
	var eye := global_position + Vector3.UP * ((2.0 if in_chariot else 2.35) if _riding or _seated else 1.58)
	return Transform3D(Basis.from_euler(Vector3(_view_pitch, rotation.y, 0.0)), eye)


func _play(anim_name: String, speed := 1.0) -> void:
	if _current == anim_name or not _anim.has_animation(anim_name):
		return
	_current = anim_name
	_anim.speed_scale = speed
	_anim.play(anim_name, 0.15)


func apply_pose(at: Vector3, yaw: float, pitch: float, vel: Vector3, sight: float, flags: int, attacks: int, weapon: String, hp_left: float) -> void:
	_target = at
	if not _got_pose:
		_got_pose = true
		global_position = at
	_yaw = yaw
	_pitch = pitch
	velocity = vel
	_sight = sight
	_unseen = flags & 2 != 0
	_riding = flags & 4 != 0
	_seated = flags & 8 != 0
	rescues = flags & 16 != 0
	has_passenger = flags & 32 != 0
	in_chariot = flags & 64 != 0 or (_seated and in_chariot)
	_has_turret = flags & 128 != 0
	_show_seat()
	hp_fraction = hp_left
	var fell := flags & 1 != 0
	if fell != dead:
		dead = fell
		collision_layer = 0 if dead else LAYER_AVATAR
		_current = ""
		if dead:
			_play("Death_A")
		else:
			_play("Idle")
	if attacks != _attack_seen:
		_attack_seen = attacks
		if not dead:
			_attack_left = 0.5
			_current = ""
			_play("1H_Melee_Attack_Chop" if weapon == "" or not WeaponDefs.is_ranged(weapon) else "2H_Ranged_Shoot", 1.6)
			Sfx.play_at("swing", global_position, world.player.global_position if world.player else global_position, -4.0)
	if weapon != _weapon:
		_weapon = weapon
		_hand.mesh = WeaponDefs.mesh(weapon) if weapon != "" else null
		if weapon != "":
			_hand.scale = Vector3.ONE * float(WeaponDefs.ALL[weapon]["scale"]) * 1.6 / _fit


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _yaw, minf(1.0, delta * 14.0))
	_attack_left -= delta
	_label.visible = not _watched and (not _unseen or not Net.is_foe(peer))
	_visual.visible = not _watched and not (_unseen and Net.is_foe(peer))
	if _chariot and _chariot.visible:
		_chariot.roll(velocity.length() * delta)
	if not dead and _attack_left <= 0.0:
		_play("Running_A" if velocity.length_squared() > 0.5 else "Idle", maxf(0.8, velocity.length() / 5.0))


func is_unseen() -> bool:
	return _unseen


func sight_factor() -> float:
	return _sight


func look_direction() -> Vector3:
	return Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Vector3.FORWARD


func eye_position() -> Vector3:
	return global_position + Vector3.UP * 1.58


func hurt(amount: float, from: Vector3, attacker: Zombie = null) -> void:
	if not dead:
		Net.hurt_peer(peer, amount, from, attacker)


func ignite(seconds: float) -> void:
	if not dead:
		Net.ignite_peer(peer, seconds)
