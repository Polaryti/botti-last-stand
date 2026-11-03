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


func _draw() -> void:
	Icons.draw(self, Rect2(Vector2.ZERO, size), icon, color, dim)
