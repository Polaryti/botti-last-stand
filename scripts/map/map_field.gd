@tool
class_name MapField
extends MapPiece
## A fenced plot: wheat, barley, corn or vegetables. Also an orchard, vines, or just a fence.
## Tall crops hide you. The land is levelled under it.

@export var size := Vector2(30, 24):
	set(v):
		size = v
		refresh()
@export_enum("wheat", "barley", "corn", "garden", "orchard", "vines", "graveyard") var crop := "wheat":
	set(v):
		crop = v
		refresh()
## Gaps in the fence, like "-2..2, 6..9". Metres from the centre of that side.
@export var north_gaps := "":
	set(v):
		north_gaps = v
		refresh()
@export var south_gaps := "":
	set(v):
		south_gaps = v
		refresh()
@export var east_gaps := "":
	set(v):
		east_gaps = v
		refresh()
@export var west_gaps := "":
	set(v):
		west_gaps = v
		refresh()
@export var level_ground := true:
	set(v):
		level_ground = v
		refresh()


func build(b: MapBuilder) -> void:
	b.field(size, crop, {"n": parse_gaps(north_gaps), "s": parse_gaps(south_gaps), "e": parse_gaps(east_gaps), "w": parse_gaps(west_gaps)})


func land(t: Terrain, at: Transform3D) -> void:
	if level_ground and on_ground:
		t.level_auto(Vector2(at.origin.x, at.origin.z), size * 0.5 + Vector2(2.0, 2.0), at.basis.get_euler().y, 5.0)


func shapes_land() -> bool:
	return level_ground and on_ground


func follows_land() -> bool:
	return true
