@tool
class_name MapRoot
extends Node3D
## The top of a map scene. In the game, the World reads the pieces under it and builds them. In the
## Godot editor, this draws them all, so you can move things and see the result straight away.
## Press F6 on a map scene to walk around in it.

## How far from the centre players can go.
@export var play_half := 110.0
## A wall of trees just outside that edge.
@export var forest_wall := true
## How rough the land is away from the centre, in metres.
@export var roughness := 5.5
## Inside this distance from the centre the land is smooth.
@export var calm_radius := 30.0
## Redraw the land by itself after a hill, a road or a building moves. Turn off if it gets in the way.
@export var auto_redraw := true
@export_tool_button("Redraw the whole map") var redraw_button := rebuild_preview

var terrain: Terrain
var _preview: MapPreview
var _builder: MapBuilder
var _land_holder: Node3D
var _wait := 0.0
var _land_dirty := false
var _dirty_pieces := {}
var _snapping := false


static func of(node: Node) -> MapRoot:
	var n := node.get_parent()
	while n:
		if n is MapRoot:
			return n
		n = n.get_parent()
	return null


## The land, from all the pieces that shape it.
func plan_land(t: Terrain) -> void:
	t.roughness = roughness
	t.calm_radius = calm_radius
	_plan(self, Transform3D.IDENTITY, t)
	t.bake()


func _plan(node: Node, parent: Transform3D, t: Terrain) -> void:
	for c: Node in node.get_children():
		if c is Node3D:
			var at := parent * (c as Node3D).transform
			if c.has_method("land"):
				c.call("land", t, at)
			_plan(c, at, t)


func _ready() -> void:
	if Engine.is_editor_hint():
		rebuild_preview.call_deferred()
	elif get_tree().current_scene == self:
		# F6 in the editor: play this map.
		var game := get_node("/root/Game")
		game.set("test_map", scene_file_path)
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or (not _land_dirty and _dirty_pieces.is_empty()):
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if _land_dirty:
		_land_dirty = false
		_redraw_land()
	for p: Node in _dirty_pieces.keys():
		if is_instance_valid(p) and p.is_inside_tree():
			_redraw_piece(p)
	_dirty_pieces.clear()


func rebuild_preview() -> void:
	if not is_inside_tree():
		return
	var began := Time.get_ticks_msec()
	_land_dirty = false
	_dirty_pieces.clear()
	terrain = Terrain.new()
	plan_land(terrain)
	_preview = MapPreview.new(terrain)
	_builder = MapBuilder.new(_preview, terrain)
	_builder.is_preview = true
	_builder.quality = 1
	_builder.grass_tufts = 150
	_draw_ground()
	_each_piece(self, func(p: Node) -> void:
		_snap(p)
		_redraw_piece(p))
	if not terrain.river.is_empty():
		pass
	print("Map drawn in %d ms" % (Time.get_ticks_msec() - began))


func _each_piece(node: Node, action: Callable) -> void:
	for c: Node in node.get_children():
		if c.has_method("build"):
			action.call(c)
		_each_piece(c, action)


func _draw_ground() -> void:
	if is_instance_valid(_land_holder):
		_land_holder.free()
	_land_holder = Node3D.new()
	_land_holder.name = "LandPreview"
	add_child(_land_holder, false, Node.INTERNAL_MODE_BACK)
	_preview.target = _land_holder
	_builder.ground()
	if forest_wall:
		_builder.forest_wall(play_half)
	_builder.flush()


func _clear_piece(p: Node) -> void:
	for c: Node in p.get_children(true):
		if c.has_meta("map_preview"):
			c.free()


func _redraw_piece(p: Node) -> void:
	_clear_piece(p)
	_preview.target = p
	var at: Transform3D = (p as Node3D).global_transform
	_builder.stand_at(at)
	p.call("build", _builder)
	_builder.flush()


func _snap(p: Node) -> void:
	if p is MapPiece and (p as MapPiece).on_ground and terrain:
		var piece := p as MapPiece
		var g := piece.global_position
		var y := terrain.height(g.x, g.z) + piece.lift
		if absf(g.y - y) > 0.001:
			_snapping = true
			piece.global_position = Vector3(g.x, y, g.z)
			_snapping = false


func _redraw_land() -> void:
	terrain = Terrain.new()
	plan_land(terrain)
	_preview.terrain = terrain
	_builder.terrain = terrain
	_draw_ground()
	_each_piece(self, func(p: Node) -> void:
		_snap(p)
		if p.has_method("follows_land") and p.call("follows_land"):
			_redraw_piece(p))


## Called by a piece when it has been moved in the editor.
func piece_moved(p: Node) -> void:
	if _snapping or _preview == null:
		return
	_snap(p)
	_schedule(p, not p is MapHouse)


## Called by a piece when one of its settings changes.
func piece_changed(p: Node) -> void:
	if _preview == null:
		return
	_schedule(p, true)


func _schedule(p: Node, redraw: bool) -> void:
	_wait = 0.6
	if redraw or (p.has_method("follows_land") and p.call("follows_land")):
		_dirty_pieces[p] = true
	if auto_redraw and p.has_method("shapes_land") and p.call("shapes_land"):
		_land_dirty = true
