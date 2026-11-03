@tool
class_name MapPreview
extends RefCounted
## Stands in for the World while a map is open in the Godot editor. It takes the same calls, keeps the
## meshes under the piece that made them, and ignores everything to do with collision.

var terrain: Terrain
var target: Node3D
var mode := 1
var grid := PreviewGrid.new()
var fort: Variant = null
var bell: Node3D
var play_half := 110.0
var church_door := Vector3.ZERO
var perches: Array[Vector3] = []
var pois: Array[Vector3] = []
var loot_spots: Array[Vector3] = []
var crop_spots: Array[Vector3] = []
var wood_spots: Array[Vector3] = []
var yard_wood_spots: Array[Vector3] = []
var start_spots: Array[Vector3] = []
var rival_spots: Array[Vector3] = []
var stands: Array[Dictionary] = []
var map_marks: Array[Dictionary] = []
var map_roads: Array = []
var indoors: Array[Rect2] = []
var _marker_material: StandardMaterial3D


func _init(p_terrain: Terrain) -> void:
	terrain = p_terrain


func add_child(n: Node) -> void:
	n.set_meta("map_preview", true)
	var world_xf := Transform3D.IDENTITY
	if n is Node3D:
		world_xf = (n as Node3D).transform
	target.add_child(n, false, Node.INTERNAL_MODE_BACK)
	if n is Node3D:
		(n as Node3D).global_transform = world_xf


func add_solid(_at: Vector3, _size: Vector3) -> void: pass
func add_solid_xf(_t: Transform3D, _size: Vector3) -> void: pass
func add_collider(_at: Vector3, _size: Vector3) -> void: pass
func add_collider_xf(_t: Transform3D, _size: Vector3) -> void: pass
func add_barrier(_at: Vector3, _size: Vector3) -> void: pass
func add_barrier_xf(_t: Transform3D, _size: Vector3) -> void: pass
func add_enemy_block(_at: Vector3, _size: Vector3) -> void: pass
func add_wedge(_t: Transform3D, _points: PackedVector3Array) -> void: pass
func grid_block_turned(_t: Transform3D, _size: Vector3) -> void: pass
func grid_mark_crops(_t: Transform3D, _size: Vector2) -> void: pass
func set_water(_m: ShaderMaterial) -> void: pass
func add_fire(_at: Vector3, _radius: float, _light: OmniLight3D = null, _heals := false) -> void: pass
func add_lantern_light(_l: OmniLight3D) -> void: pass
func add_spinner(_n: Node3D, _axis: Vector3, _speed: float) -> void: pass


func add_glow(_at: Vector3, _col: Color, _size: float, _fade_at := 0.0) -> void:
	pass


func start_fort() -> void:
	fort = PreviewFort.new()


## A small marker for things nobody sees in the game, so they can be found and picked here.
func show_spot(kind: String, text: String, at: Vector3) -> void:
	var col: Color = {"loot": Color(1.0, 0.8, 0.2), "poi": Color(0.9, 0.3, 0.3), "crop": Color(0.5, 0.8, 0.3), "wood": Color(0.7, 0.45, 0.2),
		"yard_wood": Color(0.7, 0.45, 0.2), "start": Color(0.3, 0.9, 1.0), "rival": Color(0.9, 0.5, 1.0), "place": Color(1, 1, 1), "hill": Color(0.5, 0.75, 0.4),
		"weapon": Color(0.9, 0.9, 1.0), "item": Color(0.5, 0.9, 0.6), "familiar": Color(0.8, 0.6, 1.0)}.get(kind, Color.WHITE)
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.9 if kind == "hill" else 0.3
	m.height = 2.0 if kind == "hill" else 0.8
	m.radial_segments = 6
	m.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (m.height * 0.5 + 0.05))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if text != "":
		var label := Label3D.new()
		label.text = text
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.pixel_size = 0.03
		label.no_depth_test = true
		label.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 3.0)
		add_child(label)


## A faint outline of a levelled area.
func show_area(size: Vector2) -> void:
	var m := BoxMesh.new()
	m.size = Vector3(size.x, 0.05, size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 1.0, 0.12)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = target.global_transform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


class PreviewGrid:
	extends RefCounted

	func block_box(_at: Vector3, _size: Vector3) -> void: pass
	func is_free(_c: Vector2i) -> bool: return true
	func to_cell(_p: Vector3) -> Vector2i: return Vector2i.ZERO


class PreviewFort:
	extends RefCounted

	func add_gate(_i: int, _node: Node3D, _rows: Array[Node3D]) -> void: pass
	func set_heart(_at: Vector3, _mesh: Node3D) -> void: pass
