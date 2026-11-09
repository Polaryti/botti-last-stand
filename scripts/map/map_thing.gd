@tool
class_name MapThing
extends MapPiece
## One small thing drawn by the game itself.

@export_enum("bed", "table", "hay_bale", "bonfire", "torch", "lantern", "well", "small_well", "stall_red", "stall_blue", "scarecrow", "cow", "cart", "grave_slab", "grave_cross", "grave_stone", "tomb", "log_pile", "stump", "rubble", "portcullis", "fallen_log", "dirt", "glow") var kind := "bed":
	set(v):
		kind = v
		refresh()
## For dirt: how much ground it covers. For glow: x is its size, y how high it floats.
@export var size := Vector2(18, 18):
	set(v):
		size = v
		refresh()
## For glow.
@export var color := Color(0.45, 0.9, 0.55):
	set(v):
		color = v
		refresh()


func build(b: MapBuilder) -> void:
	if kind in ["fallen_log", "stump", "rubble"] and b.expedition_lane(b.xf.origin):
		return
	match kind:
		"bed": b.bed()
		"table": b.table()
		"hay_bale": b.hay_bale()
		"bonfire": b.bonfire()
		"torch": b.torch()
		"lantern": b.lantern()
		"well": b.well()
		"small_well": b.small_well()
		"stall_red": b.stall(Color(0.55, 0.14, 0.12))
		"stall_blue": b.stall(Color(0.14, 0.26, 0.5))
		"scarecrow": b.scarecrow()
		"cow": b.cow()
		"cart": b.cart()
		"grave_slab": b.grave(0)
		"grave_cross": b.grave(1)
		"grave_stone": b.grave(2)
		"tomb": b.tomb()
		"log_pile": b.log_pile()
		"stump": b.stump()
		"rubble": b.rubble()
		"portcullis": b.portcullis()
		"fallen_log": b.fallen_log()
		"dirt": b.dirt(size)
		"glow": b.glow(color, size.x, size.y)
