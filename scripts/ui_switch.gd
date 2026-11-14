class_name UiSwitch
extends Control
## An on/off switch: a pill that is ember when on and slate when off, with a knob that slides across.
## It only shows the state; the row it sits in is what is tapped.

const W := 64.0
const H := 34.0

var on := false:
	set(v):
		if v == on:
			return
		on = v
		_slide()
var _knob := 0.0 # 0 off, 1 on
var _tween: Tween


func _init(start := false) -> void:
	on = start
	_knob = 1.0 if start else 0.0
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _slide() -> void:
	if not is_inside_tree():
		_knob = 1.0 if on else 0.0
		queue_redraw()
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(f: float) -> void:
		_knob = f
		queue_redraw(), _knob, 1.0 if on else 0.0, 0.14).set_trans(Tween.TRANS_QUAD)


func _draw() -> void:
	var r := Rect2(Vector2(0, (size.y - H) * 0.5), Vector2(W, H))
	var track := UiTheme.flat(UiTheme.STEEL.lerp(UiTheme.EMBER, _knob), Color.TRANSPARENT, int(H * 0.5), 0.0)
	draw_style_box(track, r)
	var knob_r := H * 0.5 - 4.0
	var x := lerpf(r.position.x + H * 0.5, r.end.x - H * 0.5, _knob)
	draw_circle(Vector2(x, r.get_center().y + 1.0), knob_r, Color(0, 0, 0, 0.25), true, -1.0, true)
	draw_circle(Vector2(x, r.get_center().y), knob_r, UiTheme.BONE, true, -1.0, true)
