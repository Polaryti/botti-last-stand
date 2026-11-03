@tool
class_name MapTower
extends MapPiece
## A round tower. It stands clear of the fog, so it can be seen from far off.

@export var radius := 3.2:
	set(v):
		radius = v
		refresh()
@export var height := 9.6:
	set(v):
		height = v
		refresh()


func build(b: MapBuilder) -> void:
	b.tower(radius, height, true)
