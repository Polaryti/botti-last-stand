extends Node
## Signs in to Epic with the real keys and opens and finds a room. Needs the plugin: see docs/BUILDING.md.
func _ready() -> void:
	print("available: ", EpicNet.available())
	var e := EpicNet.new()
	add_child(e)
	Engine.get_singleton("IEOS").connect("logging_interface_callback", func(m: Dictionary) -> void:
		if int(m["level"]) <= 300:
			print("EOS: ", m["category"], " ", str(m["message"]).substr(0, 160)))
	var t := get_tree().create_timer(50.0)
	t.timeout.connect(func() -> void:
		print("TIMED OUT")
		get_tree().quit(1))
	var ok := await e.sign_in()
	print("signed in: ", ok, " ", e.last_error, " user ", e._user)
	if ok and not OS.get_cmdline_user_args().has("signin"):
		var code := await e.open_room()
		print("room: ", code, " ", e.last_error)
		if code != "":
			var host := await e.find_room(code)
			print("found host: ", host, " same=", host == e._user, " ", e.last_error)
			e.close_room()
	await get_tree().process_frame
	e.queue_free()
	await get_tree().process_frame
	print("shut down cleanly")
	get_tree().quit()
