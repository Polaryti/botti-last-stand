class_name ModelView
extends SubViewportContainer
## A small stage with something slowly turning on it, for the Store and the Armory. It has its own
## little world, lit its own way, so it looks the same whatever is behind it.

const TURN_SPEED := 0.7

var _stage: Node3D
var _spin: Node3D
var _camera: Camera3D
var _anim: AnimationPlayer


func _init(size_wanted: Vector2) -> void:
	custom_minimum_size = size_wanted
	stretch = true
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_2X
	view.size = Vector2i(size_wanted)
	add_child(view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.86, 0.8)
	env.ambient_light_energy = 0.75
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)
	_stage = Node3D.new()
	view.add_child(_stage)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-40, 35, 0)
	lamp.light_energy = 1.1
	_stage.add_child(lamp)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_stage.add_child(_camera)
	_camera.current = true


func _process(delta: float) -> void:
	if _spin:
		_spin.rotation.y += delta * TURN_SPEED


func _begin(height: float) -> Node3D:
	if _spin:
		_spin.queue_free()
	_anim = null
	_spin = Node3D.new()
	_stage.add_child(_spin)
	# The camera's angle is measured upward, so a narrow stage has to stand further back.
	var narrow := maxf(1.0, custom_minimum_size.y / maxf(custom_minimum_size.x, 1.0))
	var distance := height / (2.0 * tan(deg_to_rad(_camera.fov * 0.5))) * 1.35 * narrow
	_camera.position = Vector3(0, height * 0.55, distance)
	_camera.rotation = Vector3.ZERO
	return _spin


## A class: its body, standing and breathing.
func show_class(id: String) -> void:
	var root := _begin(2.0)
	var model: String = Avatar.MODELS.get(id, "clever")
	var body: Node3D = (load("res://assets/characters/%s.glb" % model) as PackedScene).instantiate()
	root.add_child(body)
	var top := 0.0
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var part := mi as MeshInstance3D
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top = maxf(top, part.get_aabb().end.y)
		if id == "revenant":
			part.material_override = Ally._ghost()
	body.scale = Vector3.ONE * 1.8 / float(Zombie.BODY_TOP.get(model, maxf(top, 0.5)))
	ClassDefs.dress(body, id)
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players[0]
		if _anim.has_animation("Idle"):
			_anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			_anim.play("Idle")


func show_pet(id: String) -> void:
	var root := _begin(1.3 if id == "raven" else 1.5)
	var holder := Node3D.new()
	holder.position.y = 0.6 if id == "raven" else 0.0
	root.add_child(holder)
	Ally.build_beast_model(id, holder)


## An upgrade: the thing it is about, standing on end.
func show_item(id: String) -> void:
	var d: Dictionary = ShopDefs.ITEMS[id]
	if d.get("pet", false):
		show_pet(id)
		return
	var root := _begin(1.3)
	var piece := MeshInstance3D.new()
	var model: String = d.get("model", "sword")
	if model == "trap":
		piece.mesh = World.trap_mesh()
		piece.position.y = 0.35
		piece.scale = Vector3.ONE * 1.3
	else:
		piece.mesh = WeaponDefs.mesh(model)
		var box := piece.mesh.get_aabb()
		var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
		piece.scale = Vector3.ONE * 1.0 / maxf(longest, 0.01)
		piece.position = Vector3(0, 0.6, 0) - box.get_center() * piece.scale
		if box.size.z > box.size.y:
			piece.rotation.x = PI * 0.5
			piece.position = Vector3(0, 0.6, 0)
	root.add_child(piece)
