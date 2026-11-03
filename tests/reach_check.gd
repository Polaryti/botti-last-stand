extends Node
## Lists the places on each map that nobody can walk to: a yard closed in by fences, a corner behind
## a building. A few single cells are normal. Run it after moving things around:
##     godot --headless --path . res://tests/reach_check.tscn


func _ready() -> void:
	# In the fort the gates start closed, so its yard and the land outside each count as walkable.
	await _check("village", Game.Mode.NIGHT, [Vector3(0, 0, 4.5)])
	await _check("fort", Game.Mode.FORT, [Vector3(0, 0, 20), Vector3(0, 0, 60)])
	await _check("sandbox", Game.Mode.SANDBOX, [Vector3.ZERO])
	get_tree().quit()


func _check(map_name: String, mode: int, starts: Array[Vector3]) -> void:
	Game.mode = mode
	var world := World.new()
	add_child(world)
	world.setup(mode)
	await get_tree().process_frame
	var grid: PathGrid = world.grid
	var seen := {}
	for from: Vector3 in starts:
		seen.merge(grid.flood(from))
	var done := {}
	var groups: Array = []
	for y in grid.size:
		for x in grid.size:
			var start := Vector2i(x, y)
			if done.has(start) or seen.has(start) or not grid.is_free(start):
				continue
			var cells: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			done[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				cells.append(c)
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n := c + d
					if grid.is_free(n) and not seen.has(n) and not done.has(n):
						done[n] = true
						stack.append(n)
			groups.append(cells)
	var cut_off := 0
	for g: Array in groups:
		cut_off += g.size()
	print("%s: %d open cells can be walked to, %d cannot, in %d places" % [map_name, seen.size(), cut_off, groups.size()])
	groups.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	for g: Array in groups.slice(0, 20):
		var at: Vector3 = grid.to_world(g[0])
		print("  %d cells around (%.0f, %.0f)" % [g.size(), at.x, at.z])
	world.queue_free()
	await get_tree().process_frame
