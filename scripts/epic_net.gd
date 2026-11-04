class_name EpicNet
extends Node
## Online play through Epic Online Services: free relays that work from almost any network. Epic signs each
## phone in anonymously, a room code finds the host, and from there the game talks through Epic's
## EOSGMultiplayerPeer just as it talks over Wi-Fi.
## The plugin and the keys are not in the repository (see docs/BUILDING.md), so this asks the engine for
## everything by name, and a build without them simply offers no online play.

const SOCKET := "botti"
const CODE_LETTERS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const SUCCESS := 0
const ALREADY_STARTED := 15 # EOS_AlreadyConfigured
const DUPLICATE := 24 # EOS_DuplicateNotAllowed: this phone already has its anonymous ID
const DEVICE_LOGIN := 10 # EOS_ECT_DEVICEID_ACCESS_TOKEN
const NO_OVERLAY := 2 # EOS_PF_DISABLE_OVERLAY
const KEYS := "res://scripts/epic_keys.gd"

var _ieos: Object
var _user := ""
var _lobby_id := ""
var last_error := ""


## Epic's calls read their options from an object's properties, so these are all it needs.
class Options:
	extends RefCounted
	var client_data: Variant = null


class InitOptions:
	extends Options
	var product_name := "Botti's Last Stand"
	var product_version := ""


class RtcOptions:
	extends RefCounted
	var background_mode: Variant = null


class PlatformOptions:
	extends Options
	var product_name := "Botti's Last Stand"
	var product_version := ""
	var product_id := ""
	var sandbox_id := ""
	var deployment_id := ""
	var client_id := ""
	var client_secret := ""
	var encryption_key := ""
	var cache_directory := ""
	var flags := NO_OVERLAY
	var is_server := false
	var override_country_code := ""
	var override_locale_code := ""
	var tick_budget_in_milliseconds := 2
	var task_network_timeout_seconds: Variant = null
	var rtc_options := RtcOptions.new()


class DeviceOptions:
	extends Options
	var device_model := ""


class Credentials:
	extends RefCounted
	var type := DEVICE_LOGIN
	var token := ""


class LoginInfo:
	extends RefCounted
	var display_name := ""
	var nsa_id_token := ""


class LoginOptions:
	extends Options
	var credentials := Credentials.new()
	var user_login_info := LoginInfo.new()


class RoomOptions:
	extends Options
	var local_user_id := ""
	var bucket_id := ""
	var lobby_id := ""
	var max_lobby_members := Net.MAX_PLAYERS
	var permission_level := 0 # anyone with the code can look it up
	var presence_enabled := false # that needs an Epic account, and this game asks for none
	var allow_invites := false
	var disable_host_migration := true
	var enable_rtc_room := false
	var crossplay_opt_out := false
	var rtc_room_join_action_type := 0
	var local_rtc_options: Variant = null
	var enable_join_by_id := true
	var rejoin_after_kick_requires_invite := false
	var allowed_platform_ids: Array = []


class SearchOptions:
	extends RefCounted
	var max_results := 1


class LeaveOptions:
	extends Options
	var local_user_id := ""
	var lobby_id := ""


static func available() -> bool:
	return Engine.has_singleton("IEOS") and ClassDB.class_exists("EOSGMultiplayerPeer") and ResourceLoader.exists(KEYS)


func _process(_delta: float) -> void:
	if _ieos:
		_ieos.call("tick")


func _exit_tree() -> void:
	if _ieos:
		_ieos.call("platform_interface_release")
		_ieos.call("platform_interface_shutdown")
		_ieos = null


## Starts Epic's system once, and signs this phone in. Returns false and sets last_error if it cannot.
func sign_in() -> bool:
	if _user != "":
		return true
	if not available():
		return _fail("This build has no online play.")
	if _ieos == null:
		var ieos: Object = Engine.get_singleton("IEOS")
		var version := str(ProjectSettings.get_setting("application/config/version"))
		var init := InitOptions.new()
		init.product_version = version
		var started := int(ieos.call("platform_interface_initialize", init))
		if started != SUCCESS and started != ALREADY_STARTED:
			return _fail("Could not start online play (%d)." % started)
		var keys: Script = load(KEYS)
		var platform := PlatformOptions.new()
		platform.product_version = version
		platform.product_id = keys.get("PRODUCT_ID")
		platform.sandbox_id = keys.get("SANDBOX_ID")
		platform.deployment_id = keys.get("DEPLOYMENT_ID")
		platform.client_id = keys.get("CLIENT_ID")
		platform.client_secret = keys.get("CLIENT_SECRET")
		platform.cache_directory = ProjectSettings.globalize_path("user://epic")
		DirAccess.make_dir_recursive_absolute(platform.cache_directory)
		if not bool(ieos.call("platform_interface_create", platform)):
			return _fail("Could not start online play.")
		_ieos = ieos
	var device := DeviceOptions.new()
	device.device_model = "%s %s" % [OS.get_name(), OS.get_model_name()]
	_ieos.call("connect_interface_create_device_id", device)
	var made: Dictionary = await _ieos.get("connect_interface_create_device_id_callback")
	if int(made["result_code"]) != SUCCESS and int(made["result_code"]) != DUPLICATE:
		return _fail("Epic did not accept this phone (%d)." % int(made["result_code"]))
	var login := LoginOptions.new()
	login.user_login_info.display_name = Game.player_name
	_ieos.call("connect_interface_login", login)
	var done: Dictionary = await _ieos.get("connect_interface_login_callback")
	if int(done["result_code"]) != SUCCESS:
		return _fail("Could not sign in to Epic (%d). Are you online?" % int(done["result_code"]))
	_user = str(done["local_user_id"])
	return _user != "" or _fail("Could not sign in to Epic.")


## A short code for friends to type. Returns "" if no room could be made.
func open_room() -> String:
	for attempt in 3:
		var code := ""
		for i in CODE_LENGTH:
			code += CODE_LETTERS[randi() % CODE_LETTERS.length()]
		var room := RoomOptions.new()
		room.local_user_id = _user
		room.bucket_id = "botti-%d" % Net.PROTOCOL
		room.lobby_id = code
		_ieos.call("lobby_interface_create_lobby", room)
		var made: Dictionary = await _ieos.get("lobby_interface_create_lobby_callback")
		var result := int(made["result_code"])
		if result == SUCCESS:
			_lobby_id = str(made["lobby_id"])
			return code
		last_error = "Could not open a room (%d)." % result
	return ""


## Who is hosting this code, or "" if nobody is.
func find_room(code: String) -> String:
	var made: Dictionary = _ieos.call("lobby_interface_create_lobby_search", SearchOptions.new())
	if int(made["result_code"]) != SUCCESS:
		_fail("Could not look for that room (%d)." % int(made["result_code"]))
		return ""
	var search: Object = made["lobby_search"]
	search.call("set_lobby_id", code.strip_edges().to_upper())
	search.call("find", _user)
	var found: Dictionary = await _ieos.get("lobby_search_find_callback")
	if int(found["result_code"]) != SUCCESS or int(search.call("get_search_result_count")) < 1:
		_fail("No game with that code. Check it with your host.")
		return ""
	var copy: Dictionary = search.call("copy_search_result_by_index", 0)
	if int(copy["result_code"]) != SUCCESS:
		_fail("Could not read that room (%d)." % int(copy["result_code"]))
		return ""
	return str((copy["lobby_details"] as Object).call("get_lobby_owner"))


func close_room() -> void:
	if _ieos and _lobby_id != "":
		var bye := LeaveOptions.new()
		bye.local_user_id = _user
		bye.lobby_id = _lobby_id
		_ieos.call("lobby_interface_destroy_lobby", bye)
	_lobby_id = ""


func make_peer(host_user := "") -> MultiplayerPeer:
	var peer: Object = ClassDB.instantiate("EOSGMultiplayerPeer")
	var result := int(peer.call("create_server", SOCKET)) if host_user == "" else int(peer.call("create_client", SOCKET, host_user))
	if result != OK:
		_fail("Could not open the connection (%d)." % result)
		return null
	return peer as MultiplayerPeer


func _fail(why: String) -> bool:
	last_error = why
	return false
