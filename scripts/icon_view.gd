class_name IconView
extends Control
## A medallion icon as a simple control.

var icon := "sword"
var color := Color(0.4, 0.4, 0.45)
var dim := false


func _init(p_icon := "sword", p_color := Color(0.4, 0.4, 0.45), px := 64.0) -> void:
	icon = p_icon
	color = p_color
	custom_minimum_size = Vector2.ONE * px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	Icons.draw(self, Rect2(Vector2.ZERO, size), icon, color, dim)
