class_name DirectHost
extends Node
## Playing over the internet with no one in the middle: the host's router has to let the others in.
## This finds out which address the host's friends should use, by asking one public "what is my address"
## service, and at the same time asks the router to open the way (UPnP, which many home routers allow).
## A router can take many seconds to answer, or never answer at all, so nothing here ever waits for it.

signal changed

const WHAT_IS_MY_ADDRESS := "https://api.ipify.org"
const MAPPING_NAME := "Botti's Last Stand"
const ROUTER_PATIENCE := 8.0

var address := "" # the public address friends type in
var ipv6 := ""
var looked_up := false # the address service has answered, or given up
var router_answered := false
var opened := false # the router agreed to let others in
var behind_another := false # the router's own outside address is not public, so nobody can reach it

var _port := 0
var _job: RouterJob
var _patience := ROUTER_PATIENCE
var _ask: HTTPRequest


## What the background thread shares with this node. It outlives the node if the host leaves first.
class RouterJob:
	extends RefCounted
	var port := 0
	var done := false
	var found := false
	var says := ""
	var cancelled := false

	func run() -> void:
		if not ClassDB.can_instantiate("UPNP"):
			done = true
			return
		var upnp: Object = ClassDB.instantiate("UPNP")
		if int(upnp.call("discover", 2000, 2, "InternetGatewayDevice")) == UPNP.UPNP_RESULT_SUCCESS:
			var gateway: Object = upnp.call("get_gateway")
			if gateway and bool(gateway.call("is_valid_gateway")):
				found = int(upnp.call("add_port_mapping", port, port, MAPPING_NAME, "UDP", 0)) == UPNP.UPNP_RESULT_SUCCESS
				says = str(upnp.call("query_external_address"))
				# The host left while the router was thinking, or is leaving later: close it again.
				while found and not cancelled:
					OS.delay_msec(250)
				if found:
					upnp.call("delete_port_mapping", port, "UDP")
		done = true


func start(port: int) -> void:
	_port = port
	ipv6 = _own_ipv6()
	_ask = HTTPRequest.new()
	_ask.timeout = 6.0
	add_child(_ask)
	_ask.request_completed.connect(_on_public_address)
	if _ask.request(WHAT_IS_MY_ADDRESS) != OK:
		looked_up = true
	_job = RouterJob.new()
	_job.port = port
	WorkerThreadPool.add_task(_job.run)


func _exit_tree() -> void:
	if _job:
		_job.cancelled = true


func _process(delta: float) -> void:
	if router_answered or _job == null:
		return
	_patience -= delta
	# "found" is set before the thread stays behind to hold the way open, so it counts as an answer too.
	if _job.done or _job.says != "" or _patience <= 0.0:
		_take_router_answer()


func _take_router_answer() -> void:
	router_answered = true
	opened = _job.found
	var says := _job.says
	if says != "" and _is_public(says):
		if address == "":
			address = says
	elif says != "":
		behind_another = true
	changed.emit()


func _on_public_address(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	looked_up = true
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var text := body.get_string_from_utf8().strip_edges()
		if text.is_valid_ip_address():
			address = text
	changed.emit()


## In words, for the lobby: is this likely to work, and what to do if not.
func status_line() -> String:
	var line := "Give your friends this address."
	if address == "" and ipv6 == "":
		line = "Looking for your address..." if not looked_up else "Could not find your address. Is this phone online?"
	if not router_answered:
		return line + " Asking your router to let them in..."
	if opened and not behind_another:
		return line + " Your router is open."
	if behind_another:
		return line + " Your network sits behind another one, so this will probably not work. Try Online instead."
	return line + " Your router did not open by itself. If they cannot join, forward UDP port %d to this phone, or try Online." % _port


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
