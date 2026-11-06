class_name DragScroll
extends ScrollContainer
## A list you move by dragging anywhere on it, tiles and buttons included, and with no bar at the side.
## A touch that stays still is a tap on whatever is under it. One that moves is a drag, and then the
## button it began on forgets it was pressed.

const DEAD_ZONE := 12.0
const FRICTION := 5.0

var _held := false
var _dragging := false
var _start := Vector2.ZERO
var _start_scroll := 0.0
var _speed := 0.0
var _last_y := 0.0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			if get_global_rect().has_point(e.position):
				_held = true
				_dragging = false
				_start = e.position
				_start_scroll = float(scroll_vertical)
				_last_y = e.position.y
				_speed = 0.0
		else:
			_held = false
			_dragging = false
	elif event is InputEventMouseMotion and _held:
		var m := event as InputEventMouseMotion
		if not _dragging and absf(m.position.y - _start.y) > DEAD_ZONE:
			_dragging = true
			_start = m.position
			_start_scroll = float(scroll_vertical)
			_forget_press()
		if _dragging:
			scroll_vertical = int(_start_scroll - (m.position.y - _start.y))
			var dt := maxf(get_process_delta_time(), 0.001)
			_speed = lerpf(_speed, -(m.position.y - _last_y) / dt, 0.4)
			_last_y = m.position.y


func _process(delta: float) -> void:
	if _held or absf(_speed) < 12.0:
		if not _held:
			_speed = 0.0
		return
	scroll_vertical = int(float(scroll_vertical) + _speed * delta)
	_speed = move_toward(_speed, 0.0, absf(_speed) * FRICTION * delta + 40.0 * delta)


func _forget_press() -> void:
	for b in find_children("*", "BaseButton", true, false):
		var button := b as BaseButton
		var was := button.disabled
		button.disabled = true
		button.disabled = was
