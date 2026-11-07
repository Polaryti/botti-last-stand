class_name FakeEpic
extends Node
## Stands in for Epic's plugin in the tests: the same calls and signals, with rooms kept here. What the
## game writes on a room and what it searches for are kept, to check.

signal lobby_interface_create_lobby_callback(data: Dictionary)
signal lobby_interface_update_lobby_callback(data: Dictionary)
signal lobby_search_find_callback(data: Dictionary)

var rooms: Array = [] # {owner, attrs}
var written := {}
var searched := {}


class Modification:
	extends RefCounted
	var fake: FakeEpic

	func add_attribute(key: String, value: Variant, _visibility: int) -> int:
		fake.written[key] = value
		return 0


class Search:
	extends RefCounted
	var fake: FakeEpic

	func set_parameter(key: String, value: Variant, _op: int) -> int:
		fake.searched[key] = value
		return 0

	func find(_user: String) -> void:
		fake.call_deferred("emit_signal", "lobby_search_find_callback", {"result_code": 0})

	func get_search_result_count() -> int:
		return fake.rooms.size()

	func copy_search_result_by_index(i: int) -> Dictionary:
		var d := Details.new()
		d.room = fake.rooms[i]
		return {"result_code": 0, "lobby_details": d}


class Details:
	extends RefCounted
	var room: Dictionary

	func get_lobby_owner() -> String:
		return room["owner"]

	func get_attribute_count() -> int:
		return (room["attrs"] as Dictionary).size()

	func copy_attribute_by_index(i: int) -> Dictionary:
		var key: String = (room["attrs"] as Dictionary).keys()[i]
		return {"result_code": 0, "attribute": {"data": {"key": key, "value": room["attrs"][key]}, "visibility": 0}}


func lobby_interface_create_lobby(_options: Object) -> void:
	call_deferred("emit_signal", "lobby_interface_create_lobby_callback", {"result_code": 0, "lobby_id": "room1"})


func lobby_interface_update_lobby_modification(_options: Object) -> Dictionary:
	var m := Modification.new()
	m.fake = self
	return {"result_code": 0, "lobby_modification": m}


func lobby_interface_update_lobby(_options: Object) -> void:
	call_deferred("emit_signal", "lobby_interface_update_lobby_callback", {"result_code": 0})


func lobby_interface_create_lobby_search(_options: Object) -> Dictionary:
	var s := Search.new()
	s.fake = self
	return {"result_code": 0, "lobby_search": s}


func lobby_interface_destroy_lobby(_options: Object) -> void:
	pass


func platform_interface_release() -> void:
	pass


func platform_interface_shutdown() -> void:
	pass


func tick() -> void:
	pass
