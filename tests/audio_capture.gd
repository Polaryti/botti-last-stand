extends Node
## Plays the menu, a quiet night and a hunted night, for recording the real sound mix with --write-movie.
func _ready() -> void:
	Game.quality = 0
	Game.player_class = "infantry"
	Game.music_volume = 0.8
	Game.sound_volume = 1.0
	Sfx.apply_volumes()
	var m: Node = load("res://scripts/main.gd").new()
	add_child(m)
	await get_tree().create_timer(12.0).timeout
	await m.start_game(Game.Mode.NIGHT)
	print("night at ", Time.get_ticks_msec())
	var w: World = m.world
	w.player.hurt_flash = 0.0
	w.player.guard_left = 9999.0
	for z: Zombie in w.zombies.duplicate():
		z.release()
	w.director.running = false
	await get_tree().create_timer(14.0).timeout
	print("hunted")
	w.director.running = true
	w.spawn_zombie("normal", w.player.global_position + Vector3(0, 0, -9))
	var z: Zombie = w.zombies[-1]
	z.state = Zombie.State.CHASE
	z._start_chase(w.player.global_position)
	z._damage = 0.0
	await get_tree().create_timer(14.0).timeout
	get_tree().quit()
