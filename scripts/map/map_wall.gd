@tool
class_name MapWall
extends MapPiece
## A straight wall along the piece's X axis, for castles and ruins.

@export var length := 10.0:
	set(v):
		length = v
		refresh()
@export var height := 5.6:
	set(v):
		height = v
		refresh()
@export var color := MapBuilder.CASTLE_STONE:
	set(v):
		color = v
		refresh()
@export var thickness := 0.3:
	set(v):
		thickness = v
		refresh()
## Openings, like "hole:0:5:0:4.1, slit:-10". See MapHouse.
@export var openings := "":
	set(v):
		openings = v
		refresh()
@export var merlons := true:
	set(v):
		merlons = v
		refresh()


func build(b: MapBuilder) -> void:
	b.long_wall(length, height, color, parse_openings(openings), merlons, false, thickness)
