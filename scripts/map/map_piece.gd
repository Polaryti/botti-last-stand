@tool
class_name MapPiece
extends Node3D
## Anything placed on a map. Move, turn, copy or delete it in the editor. Pieces with on_ground on
## stand on the land wherever you drop them, lift above it if you say so. A piece inside another one
## moves with it: furniture in a house, for example, has on_ground off and sits on the house's floor.

@export var on_ground := true:
	set(v):
		on_ground = v
		refresh()
@export var lift := 0.0:
	set(v):
		lift = v
		refresh()


## Draw the piece and make it solid. b.xf says where it stands.
func build(_b: MapBuilder) -> void:
	pass


## Add what this piece does to the shape of the land. at is where it stands.
func land(_t: Terrain, _at: Transform3D) -> void:
	pass


## Whether moving this piece reshapes the land, so the editor knows to redraw the ground.
func shapes_land() -> bool:
	return false


## Whether its parts follow the ground under them, so it has to be drawn again when moved.
func follows_land() -> bool:
	return false


func refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var root := MapRoot.of(self)
		if root:
			root.piece_changed(self)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_inside_tree():
		var root := MapRoot.of(self)
		if root:
			root.piece_moved(self)


## Openings in a wall, written like "door:1, window:-2". Numbers are metres from the wall's centre.
## door:at or door:at:width:top. window:at. slit:at. hole:at:width:sill:top, for a gap with no frame.
static func parse_openings(text: String) -> Array:
	var out: Array = []
	for part: String in text.split(",", false):
		var bits := part.strip_edges().split(":")
		var at := bits[1].to_float() if bits.size() > 1 else 0.0
		match bits[0]:
			"door":
				out.append({"at": at, "width": bits[2].to_float() if bits.size() > 2 else 2.2, "sill": 0.0, "top": bits[3].to_float() if bits.size() > 3 else 2.5})
			"window":
				out.append({"at": at, "width": 1.1, "sill": 1.15, "top": 2.0})
			"slit":
				out.append({"at": at, "width": 0.5, "sill": 1.6, "top": 3.0, "bare": true})
			"hole":
				out.append({"at": at, "width": bits[2].to_float(), "sill": bits[3].to_float(), "top": bits[4].to_float(), "bare": true})
			"tall":
				out.append({"at": at, "width": bits[2].to_float(), "sill": bits[3].to_float(), "top": bits[4].to_float()})
	return out


## Gaps in a fence, written like "-2..2, 6..9". Numbers are metres from the fence's centre.
static func parse_gaps(text: String) -> Array:
	var out: Array = []
	for part: String in text.split(",", false):
		var bits := part.strip_edges().split("..")
		if bits.size() == 2:
			out.append(Vector2(bits[0].to_float(), bits[1].to_float()))
	return out
