@tool
class_name MapTree
extends MapPiece
## A tree. Turn it and size it to taste: no two need look alike. The fir and broadleaf come from
## files; the giant fir, tall pine and mossy oak of the Valleys of Mesenlla are drawn by code.

const FILES := {"fir": "res://assets/nature/tree_single_A.gltf", "broad": "res://assets/nature/tree_single_B.gltf"}

@export_enum("fir", "broad", "dead", "giant_fir", "tall_pine", "mossy_oak") var kind := "fir":
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
	elif kind in ["giant_fir", "tall_pine", "mossy_oak"]:
		# The valley's own, drawn by code; an old fir's trunk is too thick to slip past.
		b.tree("proc:" + kind, size, tall, true)
		if kind == "giant_fir" and not b.is_preview:
			b.w.add_solid(b.xf.origin + Vector3.UP, Vector3(size * 0.16, 2.0, size * 0.16))
	else:
		b.tree(FILES[kind], size, tall, true)
