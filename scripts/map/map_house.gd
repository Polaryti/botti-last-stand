@tool
class_name MapHouse
extends MapPiece
## A building you can walk into. The ground under it is levelled for you, wherever you put it.
## Put its furniture in as children, with on_ground off.

@export var width := 8.0:
	set(v):
		width = v
		refresh()
@export var depth := 8.0:
	set(v):
		depth = v
		refresh()
@export var height := 3.0:
	set(v):
		height = v
		refresh()
@export_enum("x", "z") var ridge := "x":
	set(v):
		ridge = v
		refresh()
@export var roof_rise := 2.1:
	set(v):
		roof_rise = v
		refresh()
@export var walls := MapBuilder.PLASTER:
	set(v):
		walls = v
		refresh()
@export var roof := MapBuilder.THATCH:
	set(v):
		roof = v
		refresh()
@export var beams := true:
	set(v):
		beams = v
		refresh()
## Openings, like "door:1, window:-2". door:at or door:at:width:top, window:at, slit:at, hole:at:width:sill:top.
@export var north := "":
	set(v):
		north = v
		refresh()
@export var south := "":
	set(v):
		south = v
		refresh()
@export var east := "":
	set(v):
		east = v
		refresh()
@export var west := "":
	set(v):
		west = v
		refresh()
## Flatten the land under it, at about the height it stands on.
@export var level_ground := true:
	set(v):
		level_ground = v
		refresh()


func build(b: MapBuilder) -> void:
	b.house(width, depth, height, ridge, {"plaster": walls, "roof": roof, "beams": beams},
		{"n": parse_openings(north), "s": parse_openings(south), "e": parse_openings(east), "w": parse_openings(west)}, roof_rise)


func land(t: Terrain, at: Transform3D) -> void:
	if level_ground and on_ground:
		t.level_auto(Vector2(at.origin.x, at.origin.z), Vector2(width, depth) * 0.5 + Vector2(1.0, 1.0), at.basis.get_euler().y, 3.0)


func shapes_land() -> bool:
	return level_ground and on_ground
