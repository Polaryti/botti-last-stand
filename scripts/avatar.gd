class_name Avatar
extends Target
## Another player, as seen on this phone. Their phone decides what they do. Here they are a
## body that zombies can hunt and that shots can hit, and anything that hurts them is sent over.

const LAYER_AVATAR := 64
const MODELS := {"commander": "clever", "monk": "clever", "adept": "clever", "plague_doctor": "magic", "infantry": "clever", "ranger": "clever", "heavy": "beast", "chivalry": "beast", "magician": "magic", "revenant": "clever", "artificer": "clever", "bandit": "clever", "cartographer": "clever"}

var world: World
var peer := 0
var team := 0
var display := ""
var hp_fraction := 1.0
var level := 1 # as their own phone last said
var down_since := -1.0 # world.now when this player fell, for the countdown beside their name
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
var _hand: WeaponVisual
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
var _ice_left := 0.0
var bar_time := 0.0 # seconds left of the health bar shown over the head after a hit
var _flash := 0.0
var _flames: CPUParticles3D
var _debuff_fx: CPUParticles3D
var _stun_fx: CPUParticles3D
var _statuses := 0
var _banner: MeshInstance3D
static var _ice_material: StandardMaterial3D
static var _flash_material: StandardMaterial3D


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
	ClassDefs.dress(_visual, str(info.get("class", "")))
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
	BodyAnim.install(_anim, _skeleton)
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
	_hand = WeaponVisual.new()
	_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(_hand)
	_play("Idle")


## Riding: the horse under them if it is theirs, and either way they sit higher.
func _show_seat() -> void:
	var up := _riding or _seated
	_visual.position.y = (0.5 if in_chariot else HorseModel.SADDLE) if up else 0.0
	if _riding and not in_chariot and _horse == null:
		_horse = HorseModel.make()
		_horse.scale = Vector3.ONE * HorseModel.RIDDEN_SIZE
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
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = speed
	if _current == anim_name:
		return
	_current = anim_name
	_anim.play(anim_name, 0.15)


func apply_pose(at: Vector3, yaw: float, pitch: float, vel: Vector3, sight: float, flags: int, attacks: int, weapon: String, hp_left: float) -> void:
	var first_pose := not _got_pose
	if first_pose: _attack_seen = attacks
	# Far in one step: a gate. No gliding across the sky.
	if not _got_pose or at.distance_to(_target) > 12.0:
		global_position = at
	_got_pose = true
	_target = at
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
	# Health that drops, from whatever did it, shows over the head for everyone.
	if hp_left < hp_fraction - 0.004 and not dead:
		bar_time = 2.5
	hp_fraction = hp_left
	set_fallen(flags & 1 != 0)
	var attacked := not first_pose and attacks != _attack_seen
	if attacked:
		_attack_seen = attacks
		if not dead:
			_attack_left = 0.5
			_current = ""
			_play(BodyAnim.attack_for(weapon, attacks), 1.6)
			Sfx.play_at("swing", global_position, world.player.global_position if world.player else global_position, -4.0)
	if weapon != _weapon:
		_weapon = weapon
		_hand.equip(weapon)
		if weapon != "":
			_hand.scale = Vector3.ONE * float(WeaponDefs.ALL[weapon]["scale"]) * (0.8 if WeaponDefs.ALL[weapon]["kind"] == WeaponDefs.Kind.RANGED or WeaponDefs.ALL[weapon].get("swing", "") == "thrust" else 1.6) / _fit
			_hand.rotation = WeaponDefs.hand_rotation(weapon)
			if weapon in WeaponDefs.ALIGNED_HELD:
				_hand.hold(self, false, WeaponDefs.held_size(weapon))

	if attacked:
		_hand.attack()


## They used an ability: everyone can see them raise a hand.
func play_cast(anim_name := "") -> void:
	if dead:
		return
	_attack_left = 0.6
	_current = ""
	_play(anim_name if anim_name != "" else "Spellcast_Shoot", 1.4)


## They go down where they stood, and lie there until they come back.
func set_fallen(on: bool) -> void:
	if on == dead:
		return
	_flash = 0.0
	_ice_left = 0.0
	_set_flash(false)
	_show_ice(false)
	dead = on
	down_since = world.now if dead and world else -1.0
	collision_layer = 0 if dead else LAYER_AVATAR
	if dead:
		bar_time = 0.0
		show_statuses(0)
	_attack_left = 0.0
	_current = ""
	_play("Death_A" if dead else "Idle")


## Straight there, without gliding across the map on the way.
func teleport(at: Vector3) -> void:
	_target = at
	global_position = at


## A blow from this phone landed: the body flashes, bleeds and shows its health, right away.
func show_hit(amount: float) -> void:
	if dead:
		return
	bar_time = 2.5
	hp_fraction = maxf(0.0, hp_fraction - amount / 140.0)
	_flash = 0.09
	_set_flash(true)
	world.fx_gore(global_position + Vector3.UP * 1.1, Color(0.6, 0.1, 0.08))
	Sfx.play_at("hurt", global_position, world._player_camera_position(), -6.0)


func _set_flash(on: bool) -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color(1, 0.88, 0.82)
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		if on:
			if not part.has_meta("status_base"):
				part.set_meta("status_base", part.material_override)
			part.material_override = _flash_material
		elif part.has_meta("status_base"):
			part.material_override = _ice_look() if _ice_left > 0.0 else part.get_meta("status_base")


## What is happening to this player, as their own phone or the host says: flames when burning,
## green bubbles when poisoned, red drops when bleeding, stars when stunned, ice when frozen.
func show_statuses(bits: int) -> void:
	if bits == _statuses:
		return
	_statuses = bits
	_show_banner(bits & 128 != 0)
	if dead:
		bits = 0
	var burning := bits & 1 != 0
	if burning and _flames == null:
		_flames = World.make_flames()
		_flames.position = Vector3.UP * 0.9
		add_child(_flames)
	if _flames:
		_flames.emitting = burning
	var poisoned := bits & 2 != 0
	var bleeding := bits & 4 != 0
	var slowed := bits & 8 != 0
	if (poisoned or bleeding or slowed) and _debuff_fx == null:
		_debuff_fx = CPUParticles3D.new()
		_debuff_fx.amount = 10
		_debuff_fx.lifetime = 0.8
		_debuff_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_debuff_fx.emission_sphere_radius = 0.35
		_debuff_fx.position = Vector3.UP * 1.0
		var dot := QuadMesh.new()
		dot.size = Vector2(0.11, 0.11)
		var look := StandardMaterial3D.new()
		look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		look.vertex_color_use_as_albedo = true
		dot.material = look
		_debuff_fx.mesh = dot
		add_child(_debuff_fx)
	if _debuff_fx:
		_debuff_fx.emitting = poisoned or bleeding or slowed
		_debuff_fx.color = Color(0.35, 0.95, 0.25) if poisoned else (Color(0.85, 0.08, 0.06) if bleeding else Color(0.6, 0.85, 1.0))
		_debuff_fx.gravity = Vector3.UP * (1.0 if poisoned else (-3.0 if bleeding else -0.5))
	var stunned := bits & 16 != 0
	if stunned and _stun_fx == null:
		_stun_fx = CPUParticles3D.new()
		_stun_fx.amount = 5
		_stun_fx.lifetime = 0.7
		_stun_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_stun_fx.emission_sphere_radius = 0.3
		_stun_fx.gravity = Vector3.ZERO
		_stun_fx.local_coords = true
		_stun_fx.orbit_velocity_min = 1.0
		_stun_fx.orbit_velocity_max = 1.4
		_stun_fx.position = Vector3.UP * 2.0
		var star := BoxMesh.new()
		star.size = Vector3(0.09, 0.09, 0.09)
		var star_look := StandardMaterial3D.new()
		star_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star_look.albedo_color = Color(1.0, 0.92, 0.4)
		star.material = star_look
		_stun_fx.mesh = star
		add_child(_stun_fx)
	if _stun_fx:
		_stun_fx.emitting = stunned
	var frozen := bits & 32 != 0
	if frozen and _ice_left <= 0.0:
		_ice_left = 0.4
		_show_ice(true)
	elif frozen:
		_ice_left = maxf(_ice_left, 0.4)


func _process(delta: float) -> void:
	bar_time = maxf(0.0, bar_time - delta)
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_flash(false)
	global_position = global_position.lerp(_target, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _yaw, minf(1.0, delta * 14.0))
	_attack_left -= delta
	# A name over someone's head gives them away, so only friends have one.
	_label.visible = not _watched and not Net.is_foe(peer)
	if _statuses & 32 != 0 and not dead:
		_ice_left = maxf(_ice_left, 0.2)
	if _ice_left > 0.0:
		_ice_left -= delta
		if _ice_left <= 0.0:
			_show_ice(false)
	_visual.visible = not _watched and not (_unseen and Net.is_foe(peer))
	if _chariot and _chariot.visible:
		_chariot.roll(velocity.length() * delta)
	if _horse and _horse.visible:
		HorseModel.set_gait(_horse, clampf(velocity.length() / 8.0, 0.0, 1.0))
	if _banner and _banner.visible:
		var wave := sin(world.now * (10.0 if _attack_left > 0.0 else 2.0)) * (0.18 if _attack_left > 0.0 else 0.035)
		_banner.global_transform = Transform3D(global_basis * Basis.from_euler(Vector3(0, PI - 0.4, wave)), (_banner.get_parent() as Node3D).global_position)
	if not dead and _attack_left <= 0.0:
		_play("Running_A" if velocity.length_squared() > 0.5 else "Idle", maxf(0.8, velocity.length() / 5.0))


func is_unseen() -> bool:
	return _unseen


## Someone froze this player. Their own phone does the rest, but everyone can see it here.
func show_status(kind: int, seconds: float) -> void:
	if kind != Net.Status.FREEZE or dead:
		return
	_ice_left = seconds * Player.PVP_STATUS
	_show_ice(true)


func _show_ice(on: bool) -> void:
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		if on:
			if not part.has_meta("status_base"):
				part.set_meta("status_base", part.material_override)
			part.material_override = _flash_material if _flash > 0.0 else _ice_look()
		elif part.has_meta("status_base"):
			part.material_override = _flash_material if _flash > 0.0 else part.get_meta("status_base")


static func _ice_look() -> StandardMaterial3D:
	if _ice_material == null:
		_ice_material = StandardMaterial3D.new()
		_ice_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ice_material.albedo_color = Color(0.62, 0.86, 0.96)
	return _ice_material


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


func _show_banner(on: bool) -> void:
	if on and _banner == null:
		var attach := BoneAttachment3D.new()
		attach.bone_name = "handslot.l"
		_skeleton.add_child(attach)
		_banner = MeshInstance3D.new()
		_banner.mesh = WeaponDefs.banner_mesh()
		_banner.scale = Vector3.ONE / _fit
		_banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach.add_child(_banner)
	if _banner:
		_banner.visible = on and not dead
