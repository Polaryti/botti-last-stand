@tool
class_name MapTree
extends MapPiece
## A tree. Turn it and size it to taste: no two need look alike.

const FILES := {"fir": "res://assets/nature/tree_single_A.gltf", "broad": "res://assets/nature/tree_single_B.gltf"}

@export_enum("fir", "broad", "dead") var kind := "fir":
	set(v):
		kind = v
		refresh()
@export var size := 7.0:
	set(v):
		size = v
		refresh()
@export var tall := 1.0:
	set(v):
		tall = v
		refresh()


func build(b: MapBuilder) -> void:
	if kind == "dead":
		b.dead_tree()
	else:
		b.tree(FILES[kind], size, tall, true)
