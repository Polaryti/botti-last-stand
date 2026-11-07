class_name DragScroll
extends ScrollContainer
## A list that scrolls the way a phone's lists do. Drag anywhere on it, tiles and buttons included, and
## it follows the finger exactly; let go while moving and it glides on and slows down; pull past the
## end and it gives a little, then settles back. A thin bar on the right shows where you are while you
## scroll, and can itself be grabbed and dragged. A mouse wheel scrolls smoothly too.
## A touch that stays still is a tap on whatever is under it. One that moves is a drag, and then the
## button it began on forgets it was pressed.

const DEAD_ZONE := 10.0
const GLIDE_SLOWS := 3.2 # how quickly a fling dies away: higher stops sooner
const STRETCH := 0.4 # how far the list follows a finger past its ends
const SETTLE := 14.0 # how quickly an overstretched list comes back
const WHEEL_STEP := 110.0
const WHEEL_EASE := 16.0
const BAR_WIDTH := 7.0
const BAR_GRAB := 30.0 # how wide the strip on the right that grabs the bar is, while it shows
const BAR_SHOWS := 0.9 # seconds the bar stays after the list stops

var _pos := 0.0 # where the list is, in pixels, possibly a little past either end
var _wheel_to := -1.0
var _held := false
var _touch := -1 # the finger that holds it, or -1 for a mouse
var _dragging := false
var _on_bar := false
var _start := Vector2.ZERO
var _start_pos := 0.0
var _speed := 0.0
var _samples: Array[Vector2] = [] # (milliseconds, y) of the last moments of a drag
var _bar_left := 0.0
var _bar: Control


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	_pos = get_v_scroll_bar().value


func _longest() -> float:
	var bar := get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


## Where the list is, from 0 at the top to the bottom of what there is.
func scroll_to(pixels: float) -> void:
	_pos = clampf(pixels, 0.0, _longest())
	_speed = 0.0
	_wheel_to = -1.0
	_apply()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _touch == -1 and not _held and get_global_rect().has_point(t.position):
				_press(t.position, t.index)
		elif t.index == _touch:
			_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch and _held:
			_move(d.position)
	elif event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		# On a phone, the mouse is the same finger again: the touch already counts.
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			if _dragging and not e.pressed:
				get_viewport().set_input_as_handled()
			return
		if e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if get_global_rect().has_point(e.position):
				var from := _wheel_to if _wheel_to >= 0.0 else _pos
				_wheel_to = clampf(from + WHEEL_STEP * (1.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0) * e.factor, 0.0, _longest())
				_speed = 0.0
				_bar_left = BAR_SHOWS
				get_viewport().set_input_as_handled()
			return
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			if not _held and get_global_rect().has_point(e.position):
				_press(e.position, -1)
		elif _held and _touch == -1:
			var was_drag := _dragging
			_release()
			if was_drag:
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if m.device == InputEvent.DEVICE_ID_EMULATION:
			if _dragging:
				get_viewport().set_input_as_handled()
			return
		if _held and _touch == -1:
			_move(m.position)


func _press(at: Vector2, finger: int) -> void:
	_held = true
	_touch = finger
	_dragging = false
	_start = at
	_start_pos = _pos
	_speed = 0.0
	_wheel_to = -1.0
	_samples.clear()
	_samples.append(Vector2(Time.get_ticks_msec(), at.y))
	# The bar can be taken hold of while it is showing.
	_on_bar = _bar_left > 0.0 and _longest() > 0.0 and at.x > get_global_rect().end.x - BAR_GRAB
	if _on_bar:
		_dragging = true
		_forget_press()
		_bar_left = BAR_SHOWS
		get_viewport().set_input_as_handled()


func _move(at: Vector2) -> void:
	if not _dragging:
		if absf(at.y - _start.y) <= DEAD_ZONE:
			return
		_dragging = true
		_start = at
		_start_pos = _pos
		_forget_press()
	get_viewport().set_input_as_handled()
	_bar_left = BAR_SHOWS
	if _on_bar:
		var track := maxf(size.y - _thumb_length(), 1.0)
		_pos = clampf(_start_pos + (at.y - _start.y) / track * _longest(), 0.0, _longest())
	else:
		var wanted := _start_pos - (at.y - _start.y)
		# Past the ends it gives, but less and less.
		if wanted < 0.0:
			wanted *= STRETCH
		elif wanted > _longest():
			wanted = _longest() + (wanted - _longest()) * STRETCH
		_pos = wanted
	var now := float(Time.get_ticks_msec())
	_samples.append(Vector2(now, at.y))
	while _samples.size() > 2 and now - _samples[0].x > 100.0:
		_samples.pop_front()
	_apply()


func _release() -> void:
	if _dragging and not _on_bar and _samples.size() >= 2:
		var first := _samples[0]
		var last := _samples[_samples.size() - 1]
		var gap := (float(Time.get_ticks_msec()) - first.x)
		# A finger that stopped before letting go means no glide.
		if gap > 0.0 and float(Time.get_ticks_msec()) - last.x < 80.0:
			_speed = -(last.y - first.y) / maxf(gap, 16.0) * 1000.0
	_held = false
	_touch = -1
	_dragging = false
	_on_bar = false


func _process(delta: float) -> void:
	var longest := _longest()
	if not _held:
		if _wheel_to >= 0.0:
			_pos = lerpf(_pos, _wheel_to, 1.0 - exp(-WHEEL_EASE * delta))
			if absf(_pos - _wheel_to) < 0.5:
				_pos = _wheel_to
				_wheel_to = -1.0
		elif _pos < 0.0 or _pos > longest:
			# Settle back from past an end.
			var edge := 0.0 if _pos < 0.0 else longest
			_speed = 0.0
			_pos = lerpf(_pos, edge, 1.0 - exp(-SETTLE * delta))
			if absf(_pos - edge) < 0.5:
				_pos = edge
		elif absf(_speed) > 8.0:
			_pos += _speed * delta
			_speed *= exp(-GLIDE_SLOWS * delta)
			if _pos < 0.0 or _pos > longest:
				# Running into an end stops it, with a little give.
				_pos = clampf(_pos, -18.0, longest + 18.0)
				_speed = 0.0
			_bar_left = BAR_SHOWS
		else:
			_speed = 0.0
			# The content can change size under it.
			_pos = clampf(_pos, 0.0, longest)
	_apply()
	if _bar_left > 0.0:
		_bar_left -= delta
		_bar.queue_redraw()


func _apply() -> void:
	var bar := get_v_scroll_bar()
	var shown := clampf(_pos, 0.0, _longest())
	if not is_equal_approx(bar.value, shown):
		bar.value = shown
	# Past an end, the content itself moves a little further.
	var over := _pos - shown
	var content := _content()
	if content:
		content.position.y = -shown - over
	_bar.position = Vector2.ZERO
	_bar.size = size


func _content() -> Control:
	for c in get_children():
		if c is Control:
			return c as Control
	return null


func _thumb_length() -> float:
	var bar := get_v_scroll_bar()
	if bar.max_value <= 0.0:
		return size.y
	return clampf(size.y * bar.page / bar.max_value, 44.0, size.y)


func _draw_bar() -> void:
	if _longest() <= 0.0 or _bar_left <= 0.0:
		return
	var alpha := clampf(_bar_left / 0.3, 0.0, 1.0) * (0.75 if _on_bar else 0.5)
	var length := _thumb_length()
	var at := clampf(_pos / _longest(), 0.0, 1.0) * (size.y - length)
	var w := BAR_WIDTH * (1.6 if _on_bar else 1.0)
	_bar.draw_rect(Rect2(size.x - w - 3.0, at, w, length), Color(1.0, 0.92, 0.78, alpha))


func _forget_press() -> void:
	for b in find_children("*", "BaseButton", true, false):
		var button := b as BaseButton
		var was := button.disabled
		button.disabled = true
		button.disabled = was
