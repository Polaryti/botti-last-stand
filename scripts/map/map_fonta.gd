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

@export_enum("isle", "olive", "holm_oak", "madrono", "carob", "cypress", "wildflowers", "maquis", "god_statue", "fallen_god", "god_head", "god_hand", "column", "broken_column", "ruin_wall", "temple", "altar", "cauldron", "stele", "amphorae", "terrace_wall", "sailboat", "shore_crates", "rope_bridge", "grotto", "horizon_isle", "sea_stack", "limestone") var kind := "olive":
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
## Which god a statue, head or stele shows (FontaBuilder.GODS), or 0.
@export var variant := 0:
	set(v):
		variant = v
		refresh()


func build(b: MapBuilder) -> void:
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
		"grotto":
			# The passage's floor: a level way through the rock, its walls and roof drawn over it.
			var down := at.basis.z.normalized()
			down.y = 0.0
			down = down.normalized()
			var pts: Array[Vector3] = [at.origin - down * (size * 0.5 + 3.0), at.origin + down * (size * 0.5 + 3.0)]
			t.cut(pts, wide * 0.5, 2.0)


func shapes_land() -> bool:
	return kind in ["isle", "rope_bridge", "temple", "grotto"]


func follows_land() -> bool:
	return kind in ["fallen_god", "god_head", "god_hand", "broken_column", "amphorae", "shore_crates", "limestone", "sailboat"]
