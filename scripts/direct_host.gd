class_name DirectHost
extends Node
## Playing over the internet with no one in the middle: the host's router has to let the others in.
## This asks the router to open the way (UPnP, which many home routers allow) and finds out which
## address the host's friends should use. Nothing here needs a server of ours. To learn the public
## address when the router will not say, it asks one public "what is my address" service.

signal changed

const WHAT_IS_MY_ADDRESS := "https://api.ipify.org"
const MAPPING_NAME := "Botti's Last Stand"

var finished := false
var opened := false # the router agreed to let others in
var address := "" # the public address friends type in
var ipv6 := ""
var behind_another := false # the router's own outside address is not public, so nobody can reach it

var _port := 0
var _thread: Thread
var _upnp: Object
var _router_says := ""
var _ask: HTTPRequest


func start(port: int) -> void:
	_port = port
	ipv6 = _own_ipv6()
	_thread = Thread.new()
	_thread.start(_ask_router)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	if opened and _upnp:
		# It can take a moment, and nobody is waiting for the answer.
		var router := _upnp
		var port := _port
		WorkerThreadPool.add_task(func() -> void: router.call("delete_port_mapping", port, "UDP"))


## Runs on its own thread, because a router can take seconds to answer.
func _ask_router() -> void:
	var found := false
	var says := ""
	if ClassDB.can_instantiate("UPNP"):
		var upnp: Object = ClassDB.instantiate("UPNP")
		if int(upnp.call("discover", 2000, 2, "InternetGatewayDevice")) == UPNP.UPNP_RESULT_SUCCESS:
			var gateway: Object = upnp.call("get_gateway")
			if gateway and bool(gateway.call("is_valid_gateway")):
				found = int(upnp.call("add_port_mapping", _port, _port, MAPPING_NAME, "UDP", 0)) == UPNP.UPNP_RESULT_SUCCESS
				says = str(upnp.call("query_external_address"))
		_upnp = upnp
	_router_answered.call_deferred(found, says)


func _router_answered(found: bool, says: String) -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	opened = found
	_router_says = says
	if says != "" and _is_public(says):
		address = says
		finished = true
		changed.emit()
		return
	behind_another = says != ""
	_ask = HTTPRequest.new()
	_ask.timeout = 6.0
	add_child(_ask)
	_ask.request_completed.connect(_on_public_address)
	if _ask.request(WHAT_IS_MY_ADDRESS) != OK:
		finished = true
		changed.emit()


func _on_public_address(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var text := body.get_string_from_utf8().strip_edges()
		if text.is_valid_ip_address():
			address = text
	finished = true
	changed.emit()


## In words, for the lobby: is this likely to work, and what to do if not.
func status_line() -> String:
	if not finished:
		return "Asking your router to let your friends in..."
	if opened and not behind_another:
		return "Your router is open. Give your friends this address."
	if behind_another:
		return "Your network sits behind another one, so this will probably not work. Try Online instead."
	if ipv6 != "":
		return "Your router did not open by itself. If this does not work, forward UDP port %d to this phone, or try Online." % _port
	return "Your router did not open by itself. Forward UDP port %d to this phone, or try Online." % _port


static func _is_public(a: String) -> bool:
	if not a.is_valid_ip_address() or a.contains(":"):
		return false
	var p := a.split(".")
	var first := p[0].to_int()
	var second := p[1].to_int()
	return not (first == 10 or first == 127 or (first == 192 and second == 168) \
		or (first == 172 and second >= 16 and second < 32) or (first == 100 and second >= 64 and second < 128) \
		or (first == 169 and second == 254))


static func _own_ipv6() -> String:
	for a: String in IP.get_local_addresses():
		# Worldwide addresses start with 2 or 3. The rest only work nearby.
		if a.contains(":") and (a.begins_with("2") or a.begins_with("3")):
			return a
	return ""
