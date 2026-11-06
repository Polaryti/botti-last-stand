extends Node
func press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
func move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
func _ready() -> void:
	var drag := DragScroll.new()
	drag.size = Vector2(400, 300)
	add_child(drag)
	var list := VBoxContainer.new()
	drag.add_child(list)
	var tapped := [0]
	for i in 20:
		var t := Button.new()
		t.custom_minimum_size = Vector2(380, 80)
		t.pressed.connect(func() -> void: tapped[0] += 1)
		list.add_child(t)
	await get_tree().create_timer(0.3).timeout
	var at := Vector2(190, 40)
	move(at); await get_tree().process_frame
	press(at, true); await get_tree().process_frame
	press(at, false); await get_tree().process_frame; await get_tree().process_frame
	print("TAP ", tapped[0], " max ", drag.get_v_scroll_bar().max_value, " list ", list.size)
	press(at, true); await get_tree().process_frame
	for s in 8:
		move(at + Vector2(0, -20.0 * (s + 1))); await get_tree().process_frame
	press(at + Vector2(0, -160), false); await get_tree().process_frame
	await get_tree().process_frame
	print("DRAG scroll ", drag.scroll_vertical, " tapped ", tapped[0])
	await get_tree().create_timer(0.5).timeout
	print("AFTER fling ", drag.scroll_vertical)
	drag.scroll_vertical = 0
	await get_tree().process_frame
	press(at, true); await get_tree().process_frame
	press(at, false); await get_tree().process_frame; await get_tree().process_frame
	print("TAP again ", tapped[0])
	get_tree().quit()
