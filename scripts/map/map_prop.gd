@tool
class_name MapProp
extends MapPiece
## One thing from the free model packs. Each kind knows its own size and how solid it is.

const KINDS := {
	"barrel": ["props/barrel", 4.2, Vector3(0.85, 0.9, 0.85)],
	"crate_big": ["props/crate_A_big", 4.0, Vector3(0.9, 0.85, 0.9)],
	"crate_small": ["props/crate_B_small", 4.0, Vector3(0.6, 0.6, 0.6)],
	"crate_long": ["props/crate_long_A", 3.6, Vector3(1.5, 0.6, 1.5)],
	"lumber": ["props/resource_lumber", 3.0, Vector3(2.2, 0.7, 1.1)],
	"lumber_small": ["props/resource_lumber", 2.6, Vector3(1.9, 0.6, 0.9)],
	"sack": ["props/sack", 5.0, Vector3.ZERO],
	"bucket": ["props/bucket_water", 3.5, Vector3.ZERO],
	"wheelbarrow": ["props/wheelbarrow", 4.0, Vector3(1.3, 0.8, 1.9)],
	"target": ["props/target", 5.0, Vector3(1.2, 1.5, 0.5)],
	"weapon_rack": ["props/weaponrack", 5.0, Vector3(1.0, 1.2, 0.7)],
	"rock": ["nature/rock_single_C", 5.0, Vector3(1.2, 0.7, 1.2)],
}

@export_enum("barrel", "crate_big", "crate_small", "crate_long", "lumber", "lumber_small", "sack", "bucket", "wheelbarrow", "target", "weapon_rack", "rock") var kind := "barrel":
	set(v):
		kind = v
		refresh()
## Bigger or smaller than usual.
@export var grow := 1.0:
	set(v):
		grow = v
		refresh()


func build(b: MapBuilder) -> void:
	var k: Array = KINDS[kind]
	var solid_size: Vector3 = k[2]
	b.prop(k[0], float(k[1]) * grow, solid_size if kind != "rock" else solid_size * grow / 1.0)
