extends Node
## Inspect every house interior and the photographed watermill and vineyard clearings.
var out := ""
var w: World
var cam: Camera3D

func shot(label: String, from: Vector3, toward: Vector3) -> void:
	w.player.position = from - Vector3.UP * 1.6
	cam.global_position = from
	cam.look_at(toward)
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Game.night_map = "village"
	Game.quality = 1
	Game.force_weather = Weather.Kind.CLEAR
	Game.player_class = "infantry"
	Game.mode = Game.Mode.NIGHT
	w = World.new()
	add_child(w)
	w.setup(Game.Mode.NIGHT)
	w.director.running = false
	for mob: Zombie in w.zombies.duplicate(): mob.release()
	w.player.set_physics_process(false)
	w.player.set_process(false)
	cam = w.player.camera
	cam.cull_mask = 5
	var map := (load("res://maps/village.tscn") as PackedScene).instantiate()
	await rooms(map, Transform3D.IDENTITY)
	map.free()
	await shot("watermill_repaired", Vector3(18, 5, 58), Vector3(28, 1.4, 70))
	var y := w.ground_at(Vector3(-68, 0, 24))
	await shot("vineyard_fire_clearing", Vector3(-68, y + 4.0, 19), Vector3(-68, y, 24))
	await preload("res://tests/scene_cleanup.gd").finish(w)

func rooms(node: Node, parent: Transform3D) -> void:
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var at := parent * (child as Node3D).transform
		if child is MapHouse:
			var house := child as MapHouse
			if house.on_ground: at.origin.y = w.terrain.height(at.origin.x, at.origin.z) + house.lift
			await shot("interior_" + str(child.name), at * Vector3(0, 1.7, minf(house.depth * 0.5 - 0.8, 4)), at * Vector3(-house.width * 0.3, 0.2, -house.depth * 0.3))
		await rooms(child, at)
