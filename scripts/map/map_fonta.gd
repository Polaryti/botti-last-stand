@tool
class_name MapFonta
extends MapPiece
## A piece of Fontanova, the first island of the Archipelagos of the Forgotten Gods, drawn by code
## (scripts/map/fonta_builder.gd and fonta_flora.gd).
##   isle: makes the map an island (Terrain.set_isle): the shore size metres from the middle, wobbling
##     in and out by wide of that; the open sea beyond, deepening to the horizon.
##   The flora of the Mediterranean, all moving in the wind: olive, holm_oak, madrono (strawberry tree),
##     carob, cypress, wildflowers (a meadow size metres across), maquis (a thicket of shrubs).
##   The forgotten gods: god_statue (standing), fallen_god (toppled), god_head, god_hand, column,
##     broken_column, ruin_wall, temple (the god's house on the height), altar, cauldron (the alchemist
##     god's), stele, amphorae, terrace_wall (dry stone holding up the olive groves).
##   The landing: sailboat (the ship that brought you, run up on the beach), shore_crates.
##   Crossings: rope_bridge (a plank bridge on ropes over a ravine, size long, along +Z), grotto (a
##     cave passage through rock, size long along +Z, wide across).
##   Far away: horizon_isle (another island of the archipelago, out past the edge of the map).
## Which god a statue shows is its variant (FontaBuilder.GODS).

@export_enum("isle", "olive", "holm_oak", "madrono", "carob", "cypress", "wildflowers", "maquis", "god_statue", "fallen_god", "god_head", "god_hand", "column", "broken_column", "ruin_wall", "temple", "altar", "cauldron", "stele", "amphorae", "terrace_wall", "sailboat", "shore_crates", "rope_bridge", "grotto", "horizon_isle", "sea_stack", "limestone", "mesa", "terraces", "flora", "sacred_stair", "god_altar") var kind := "olive":
	set(v):
		kind = v
		refresh()
## How big it is: the island's radius; a tree's height; a meadow's or a thicket's breadth; a statue's
## height; a wall's, a bridge's, a grotto's or a boat's length; a far island's breadth.
@export var size := 6.0:
	set(v):
		size = v
		refresh()
## The island's wobble; a grotto's width; a wall's height; a temple's depth.
@export var wide := 0.0:
	set(v):
		wide = v
		refresh()
## The island's shore: how far out it lies at bearings evenly spaced round from the east towards the
## south (Terrain.set_isle).
@export var shore := PackedFloat32Array():
	set(v):
		shore = v
		refresh()
## A mesa's length along its +X over its breadth (a ridge is long).
@export var stretch := 1.0:
	set(v):
		stretch = v
		refresh()
## Which god a statue, head or stele shows (FontaBuilder.GODS), or 0.
@export var variant := 0:
	set(v):
		variant = v
		refresh()


func build(b: MapBuilder) -> void:
	# Nothing grows inside the grotto, on the temple's floor, at an altar or where the night begins.
	if kind == "sacred_stair":
		# The stair climbs from where it stands towards -Z.
		b._plant_rooms.append({"inverse": b.xf.translated_local(Vector3(0, 0, -size * 0.5)).affine_inverse(), "half": Vector2(wide * 0.5 + 0.8, size * 0.5 + 0.5)})
	if kind == "grotto":
		b._plant_rooms.append({"inverse": b.xf.affine_inverse(), "half": Vector2(wide * 1.05 + 1.2, size * 0.5 + 1.2)})
		# No tree stands in front of its mouth (the -Z end); grass and flowers still grow there.
		var mouth := b.xf * Vector3(0, 0, -size * 0.5 - 4.0)
		b.tree_clearings.append(Vector3(mouth.x, mouth.z, 6.0))
	var clear: float = {"temple": size * 0.7, "god_altar": 3.5, "altar": 2.0, "sailboat": size * 0.45, "god_statue": size * 0.3}.get(kind, 0.0)
	if clear > 0.0:
		b._plant_clearings.append(Vector3(b.xf.origin.x, b.xf.origin.z, clear))
	match kind:
		"isle":
			pass
		"olive", "holm_oak", "madrono", "carob", "cypress":
			FontaFlora.tree(b, kind, size)
		"wildflowers": FontaFlora.wildflowers(b, size)
		"maquis": FontaFlora.maquis(b, size)
		"god_statue": FontaBuilder.god_statue(b, size, variant, false)
		"fallen_god": FontaBuilder.god_statue(b, size, variant, true)
		"god_head": FontaBuilder.god_head(b, size, variant)
		"god_hand": FontaBuilder.god_hand(b, size)
		"column": FontaBuilder.column(b, size, false)
		"broken_column": FontaBuilder.column(b, size, true)
		"ruin_wall": FontaBuilder.ruin_wall(b, size, wide)
		"temple": FontaBuilder.temple(b, size, wide)
		"altar": FontaBuilder.altar(b)
		"cauldron": FontaBuilder.cauldron(b, size)
		"stele": FontaBuilder.stele(b, size, variant)
		"amphorae": FontaBuilder.amphorae(b)
		"terrace_wall": FontaBuilder.terrace_wall(b, size, wide)
		"sailboat": FontaBuilder.sailboat(b, size)
		"shore_crates": FontaBuilder.shore_crates(b)
		"rope_bridge": FontaBuilder.rope_bridge(b, self)
		"grotto": FontaBuilder.grotto(b, size, wide)
		"horizon_isle": FontaBuilder.horizon_isle(b, size)
		"sea_stack": FontaBuilder.sea_stack(b, size)
		"limestone": FontaBuilder.limestone(b, size)
		"sacred_stair": FontaBuilder.sacred_stair(b, size, wide)
		"god_altar":
			# A lesser god's altar, which wakes now and then in the night (FontaRites); variant is the god.
			FontaBuilder.altar(b)
			if not b.is_preview:
				b.w.altar_spots.append({"god": variant, "at": b.xf.origin})
		"flora":
			# The whole island planted from its land (FontaFlora.field), size metres round the middle.
			if not b.is_preview:
				FontaBuilder.cliff_faces(b, size)
				FontaFlora.field(b, size)
		"mesa", "terraces":
			if b.is_preview:
				b.w.show_spot("hill", kind, b.xf.origin)


## Half its extent along its own X and Z, where it meets the ground (MapBuilder.settle).
func footprint() -> Vector2:
	match kind:
		"god_statue": return Vector2(size * 0.22, size * 0.22)
		"fallen_god": return Vector2(size * 0.25, size * 0.55)
		"god_head": return Vector2(size * 0.45, size * 0.45)
		"god_hand": return Vector2(size * 0.35, size * 0.45)
		"column", "broken_column": return Vector2(size * 0.12, size * 0.12)
		"ruin_wall": return Vector2(size * 0.5, 0.4)
		"terrace_wall": return Vector2(size * 0.5, 0.5)
		"altar", "god_altar": return Vector2(1.2, 0.8)
		"cauldron": return Vector2(size * 0.6, size * 0.6)
		"stele": return Vector2(size * 0.25, 0.3)
		"amphorae", "shore_crates": return Vector2(1.4, 1.4)
		"limestone": return Vector2(size * 0.4, size * 0.4)
		"olive", "holm_oak", "madrono", "carob", "cypress": return Vector2(0.5, 0.5)
	return Vector2.ZERO


func land(t: Terrain, at: Transform3D) -> void:
	var c := Vector2(at.origin.x, at.origin.z)
	var yaw := at.basis.get_euler().y
	match kind:
		"isle":
			t.set_isle(shore if not shore.is_empty() else PackedFloat32Array([size]), wide)
		"rope_bridge":
			var a := at * Vector3(0, 0, -size * 0.5)
			var e := at * Vector3(0, 0, size * 0.5)
			t.bridge(Vector2(a.x, a.z), Vector2(e.x, e.z), -minf(size * 0.06, 1.4), FontaBuilder.BRIDGE_HALF)
		"temple":
			t.level_auto(c, Vector2(size * 0.5 + 2.0, wide * 0.5 + 2.0), yaw, 4.0)
		"mesa":
			# A height with cliffs all round: its top at this piece's height, size its radius, wide its
			# cliffs' width from rim to foot.
			t.mesa(c.x, c.y, size, at.origin.y, maxf(wide, 1.0), 0.2, Vector2(stretch, 1.0), yaw)
		"terraces":
			t.shelves(c.x, c.y, size, wide if wide > 0.0 else 2.4)
		"grotto":
			# The passage's floor: a level way through the rock, its walls and roof drawn over it.
			var down := at.basis.z.normalized()
			down.y = 0.0
			down = down.normalized()
			var pts: Array[Vector3] = [at.origin - down * (size * 0.5 + 3.0), at.origin + down * (size * 0.5 + 1.0)]
			t.cut(pts, wide * 1.05, 1.5) # wide enough for the chamber; the walls are drawn inside it


func shapes_land() -> bool:
	return kind in ["isle", "rope_bridge", "temple", "grotto", "mesa", "terraces"]


func follows_land() -> bool:
	return kind in ["fallen_god", "god_head", "god_hand", "broken_column", "amphorae", "shore_crates", "limestone", "sailboat"]
