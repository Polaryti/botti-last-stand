extends Node
## Saves each map as an ordinary scene, so it can be looked at in the Godot editor. The game does
## not use these files: it builds its maps from code when it starts. Run again after map changes:
## Not headless: without a real renderer the trees and crops save empty.
##   godot --path . res://tools/make_previews.tscn
const OUT := "res://map_previews/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Game.quality = 1
	Game.player_class = "infantry"
	await _save(Game.Mode.ROAM, "village")
	await _save(Game.Mode.FORT, "fort")
	get_tree().quit()


## Every mesh on the map keeps its place, however deep it sits. People and things to pick up stay out.
func _copy_meshes(w: World, from: Node, root: Node3D, n: int) -> int:
	for c in from.get_children():
		if c == w.player or c == w._sky_root or c is Zombie or c is Pickup or c is CharacterBody3D or c is Camera3D:
			continue
		if c is MeshInstance3D or c is MultiMeshInstance3D:
			var g := c as GeometryInstance3D
			if g.is_visible_in_tree() and (g is MultiMeshInstance3D or (g as MeshInstance3D).mesh != null):
				var copy := g.duplicate(0) as GeometryInstance3D
				for kid in copy.get_children():
					copy.remove_child(kid)
					kid.free()
				copy.name = "Piece_%d" % n
				copy.set_script(null)
				copy.visibility_range_end = 0.0
				root.add_child(copy)
				copy.owner = root
				copy.global_transform = g.global_transform
				n += 1
		n = _copy_meshes(w, c, root, n)
	return n


func _save(mode: int, file: String) -> void:
	Game.mode = mode
	var w := World.new()
	add_child(w)
	w.setup(mode)
	await get_tree().process_frame
	var root := Node3D.new()
	root.name = "Map_" + file
	var sun := DirectionalLight3D.new()
	sun.name = "Light"
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var n := _copy_meshes(w, w, root, 0)
	sun.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	var path := OUT + file + ".scn"
	var err := ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS)
	print(path, " pieces=", n, " err=", err)
	root.free()
	w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
