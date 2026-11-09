extends RefCounted
## Give scene and audio-server resources time to retire before a capture process exits.


static func finish(main: Node) -> void:
	var tree := main.get_tree()
	tree.paused = false
	Net.leave()
	main.queue_free()
	await tree.process_frame
	await tree.process_frame
	Sfx.stop_all()
	await tree.create_timer(0.1, true, false, true).timeout
	tree.quit()
