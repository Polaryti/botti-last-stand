@tool
class_name MapRamp
extends MapPiece
## Stairs that climb toward the piece's -Z, for getting up a wall. You stand on the steps and cannot
## walk underneath.

@export var length := 15.0:
	set(v):
		length = v
		refresh()
@export var height := 6.5:
	set(v):
		height = v
		refresh()
@export var width := 2.6:
	set(v):
		width = v
		refresh()


func build(b: MapBuilder) -> void:
	b.stairs(length, height, width)
