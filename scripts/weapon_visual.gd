class_name WeaponVisual
extends MeshInstance3D
## Shared held-weapon presentation. The flail uses a bounded pendulum, never a rigid-body simulation.

var weapon := ""
var arrow: MeshInstance3D
var chain: MeshInstance3D
var reload_left := 0.0
var swing_left := 0.0
var body_owner: Node3D
var body_plus_z := false
var body_size := 1.0
var _chain_direction := Vector3.DOWN


func _init() -> void:
	cast_shadow = SHADOW_CASTING_SETTING_OFF


func equip(id: String, view_model := false) -> void:
	weapon = id
	mesh = WeaponDefs.mesh(id) if id != "" and (id != "fists" or view_model) else null
	reload_left = 0.0
	swing_left = 0.0
	body_owner = null
	if arrow:
		arrow.free()
		arrow = null
	if chain:
		chain.free()
		chain = null
	if id == "flail":
		chain = MeshInstance3D.new()
		chain.mesh = WeaponDefs.flail_chain()
		chain.position.y = 0.36
		chain.layers = layers
		chain.cast_shadow = SHADOW_CASTING_SETTING_OFF
		add_child(chain)
		_chain_direction = Vector3.DOWN
	if not view_model and id in ["bow", "longbow", "crossbow"]:
		arrow = MeshInstance3D.new()
		arrow.mesh = WeaponAnim.nocked_arrow()
		arrow.layers = layers
		arrow.cast_shadow = SHADOW_CASTING_SETTING_OFF
		arrow.position = Vector3(0, 0, -0.05) if id != "crossbow" else Vector3(0, 0.2, -0.1)
		arrow.scale = Vector3.ONE * (1.0 if id != "crossbow" else 2.5)
		add_child(arrow)
	set_process(chain != null or arrow != null)


func attack() -> void:
	swing_left = 0.6
	reload_left = float(WeaponDefs.ALL.get(weapon, {}).get("rate", 0.5))
	if arrow:
		arrow.visible = false


func hold(owner_body: Node3D, plus_z: bool, size: float) -> void:
	body_owner = owner_body
	body_plus_z = plus_z
	body_size = size
	set_process(true)


func _process(delta: float) -> void:
	reload_left = maxf(0.0, reload_left - delta)
	swing_left = maxf(0.0, swing_left - delta)
	if arrow:
		var duration := float(WeaponDefs.ALL[weapon]["rate"])
		arrow.visible = reload_left <= duration * 0.25
	if is_instance_valid(body_owner) and is_visible_in_tree():
		# Procedural weapons use the same authored axes and attack orientation as the view model.
		# Only the grip origin comes from the animated hand; the sword socket cannot turn the blade over.
		var forward := body_owner.global_basis.z.normalized() * (1.0 if body_plus_z else -1.0)
		var grip := (get_parent() as Node3D).global_position
		var d: Dictionary = WeaponDefs.ALL[weapon]
		var swing: String = d.get("swing", "")
		var turn := WeaponAnim.rest_rotation(swing, float(d.get("tilt", 0.0)))
		if swing_left > 0.0 and swing != "":
			var pose := WeaponAnim.sample(WeaponAnim.keys_for(swing, true), (0.6 - swing_left) / 0.6, 1.0)
			if pose[1] != null:
				turn = pose[1]
		elif reload_left > 0.0 and arrow:
			var recoil := sin(clampf(reload_left / float(d["rate"]), 0.0, 1.0) * PI)
			turn = turn * Quaternion(Vector3.RIGHT, recoil * 0.18)
		global_transform = Transform3D((Basis.looking_at(forward) * Basis(turn)).scaled(Vector3.ONE * body_size), grip)
	if chain and is_visible_in_tree():
		var down := global_basis.inverse() * Vector3.DOWN
		var strike := sin(clampf((0.6 - swing_left) / 0.6, 0.0, 1.0) * PI) if swing_left > 0.0 else 0.0
		var target := (down.normalized() + Vector3(0.2, 1.1, -2.5) * strike).normalized()
		_chain_direction = _chain_direction.lerp(target, 1.0 - exp(-delta * 18.0)).normalized()
		chain.quaternion = Quaternion(Vector3.DOWN, _chain_direction)
