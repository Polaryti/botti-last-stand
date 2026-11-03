@tool
class_name MapSpot
extends MapPiece
## A place on the map that nobody sees in the game, but that the game uses.
## loot: where items can appear. poi: where zombies wander to. crop: where a Scarecrow can rise, in a field.
## wood and yard_wood: where wood appears in the fort. start: where players begin, in order.
## rival: where players begin when they fight each other.
## place: a name on the map screen. weapon, item and familiar: the Sandbox's stands.
## dummy: a training dummy in the Sandbox.

@export_enum("loot", "poi", "crop", "wood", "yard_wood", "start", "rival", "place", "weapon", "item", "familiar", "dummy") var kind := "loot":
	set(v):
		kind = v
		refresh()
## For place: the name to show on the map screen.
@export var text := "":
	set(v):
		text = v
		refresh()


func build(b: MapBuilder) -> void:
	var at := b.xf.origin
	match kind:
		"loot": b.w.loot_spots.append(at)
		"poi": b.w.pois.append(at)
		"crop": b.w.crop_spots.append(at)
		"wood": b.w.wood_spots.append(at)
		"yard_wood": b.w.yard_wood_spots.append(at)
		"start": b.w.start_spots.append(at)
		"rival": b.w.rival_spots.append(at)
		"dummy": b.w.dummy_spots.append(at)
		"place": b.w.map_marks.append({"name": text, "at": Vector2(at.x, at.z)})
		"weapon", "item", "familiar": b.w.stands.append({"kind": kind, "at": at, "yaw": b.xf.basis.get_euler().y})
	if b.is_preview:
		b.w.show_spot(kind, text, at)
