extends Node
## Real input through the engine, under a window: a tap, a drag on a tile with a mouse and with a
## finger, a fling, the bar, and the wheel. Prints one line per check for the shell to read.

var drag: DragScroll
var tapped := [0]


## The checks are written where things are on the screen of the game, and the window may be smaller.
func w(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func press(at: Vector2, down: bool) -> void:
	at = w(at)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)


func move(at: Vector2) -> void:
	at = w(at)
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func touch(at: Vector2, down: bool) -> void:
	at = w(at)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = down
	e.position = at
	Input.parse_input_event(e)


func finger(at: Vector2, rel: Vector2) -> void:
	at = w(at)
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	e.relative = rel
	Input.parse_input_event(e)


func wheel(at: Vector2, down: bool) -> void:
	at = w(at)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.factor = 1.0
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)


func frame() -> void:
	await get_tree().process_frame


func _ready() -> void:
	drag = DragScroll.new()
	drag.size = Vector2(400, 300)
	add_child(drag)
	var list := VBoxContainer.new()
	drag.add_child(list)
	for i in 20:
		var t := Button.new()
		t.custom_minimum_size = Vector2(380, 80)
		t.pressed.connect(func() -> void: tapped[0] += 1)
		list.add_child(t)
	await get_tree().create_timer(0.3).timeout
	var at := Vector2(190, 40)
	move(at)
	await frame()
	press(at, true)
	await frame()
	press(at, false)
	await frame()
	await frame()
	print("TAP ", tapped[0])
	# A slow drag with the mouse, held still before letting go: follows exactly, no glide.
	press(at, true)
	await frame()
	for s in 8:
		move(at + Vector2(0, -20.0 * (s + 1)))
		await frame()
	await get_tree().create_timer(0.15).timeout
	press(at + Vector2(0, -160), false)
	await frame()
	var after_drag := drag.get_v_scroll_bar().value
	await get_tree().create_timer(0.4).timeout
	print("DRAG ", after_drag, " still ", drag.get_v_scroll_bar().value, " tapped ", tapped[0])
	# A quick flick with a finger: it glides on after the finger leaves.
	drag.scroll_to(0.0)
	await frame()
	var start := Vector2(190, 250)
	touch(start, true)
	await frame()
	var p := start
	for s in 6:
		var step := Vector2(0, -30)
		p += step
		finger(p, step)
		await frame()
	touch(p, false)
	await frame()
	var let_go := drag.get_v_scroll_bar().value
	await get_tree().create_timer(0.6).timeout
	print("FLING ", let_go, " glided to ", drag.get_v_scroll_bar().value, " tapped ", tapped[0])
	# Past the top it gives, then comes back.
	drag.scroll_to(0.0)
	await frame()
	touch(Vector2(190, 60), true)
	await frame()
	for s in 5:
		finger(Vector2(190, 60 + 25.0 * (s + 1)), Vector2(0, 25))
		await frame()
	var content: Control = list
	var pulled := content.position.y
	await get_tree().create_timer(0.15).timeout
	touch(Vector2(190, 185), false)
	await get_tree().create_timer(0.6).timeout
	print("STRETCH ", pulled, " back to ", content.position.y)
	# The bar: grabbed at the right edge while it shows, dragged to the bottom.
	drag.scroll_to(0.0)
	drag._bar_left = DragScroll.BAR_SHOWS
	await frame()
	press(Vector2(395, 20), true)
	await frame()
	for s in 10:
		move(Vector2(395, 20 + 28.0 * (s + 1)))
		await frame()
	press(Vector2(395, 300), false)
	await frame()
	print("BAR ", drag.get_v_scroll_bar().value, " of ", drag._longest(), " tapped ", tapped[0])
	# The wheel moves it smoothly, over a few frames.
	drag.scroll_to(0.0)
	await frame()
	wheel(Vector2(190, 150), true)
	await frame()
	var first := drag.get_v_scroll_bar().value
	await get_tree().create_timer(0.4).timeout
	print("WHEEL ", first, " then ", drag.get_v_scroll_bar().value)
	drag.scroll_to(0.0)
	await frame()
	touch(at, true)
	press(at, true)
	await frame()
	touch(at, false)
	press(at, false)
	await frame()
	await frame()
	print("TAP again ", tapped[0])
	get_tree().quit()
