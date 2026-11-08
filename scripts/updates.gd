class_name Updates
extends Node
## Looks once per launch for a newer version on the game's GitHub page, where every version is
## published with its Android app. On Android it can fetch the new app and hand it to Android's own
## installer, which asks before it changes anything. An iPhone app cannot install another, so there it
## only says a new version is out and where to find it. With no connection it says nothing.

signal changed

const LATEST := "https://api.github.com/repos/Polaryti/botti-last-stand/releases/latest"
const PAGE := "https://github.com/Polaryti/botti-last-stand/releases/latest"
const FOLDER := "user://update"
const FILE := "user://update/botti-last-stand.apk"

enum State { IDLE, CHECKING, NONE, AVAILABLE, DOWNLOADING, READY, FAILED }

var state: int = State.IDLE
var latest := "" # the newer version, as "0.20.2"
var apk_url := ""
var apk_size := 0
var page := PAGE
var problem := ""
var _http: HTTPRequest


## Is the version they published newer than this one? Both like "0.20.1", with or without a "v".
static func is_newer(theirs: String, mine: String) -> bool:
	var a := _parts(theirs)
	var b := _parts(mine)
	for i in 3:
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


static func _parts(v: String) -> Array[int]:
	var bits := v.strip_edges().trim_prefix("v").split(".")
	var out: Array[int] = [0, 0, 0]
	for i in mini(3, bits.size()):
		out[i] = bits[i].to_int()
	return out


static func current() -> String:
	return str(ProjectSettings.get_setting("application/config/version"))


## Whether this phone can put the new version on by itself, with one more tap on Android's screen.
static func can_install() -> bool:
	return OS.has_feature("android") and not Game.is_dev_build()


func _headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: BottisLastStand/%s" % current(), "Accept: application/vnd.github+json"])


func check() -> void:
	if Game.is_dev_build():
		state = State.NONE
		changed.emit()
		return
	if state == State.CHECKING or state == State.DOWNLOADING or state == State.READY:
		return
	# Whatever was fetched last time has been installed or given up on.
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	state = State.CHECKING
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_checked)
	if _http.request(LATEST, _headers()) != OK:
		_http.queue_free()
		state = State.NONE
		changed.emit()


func _on_checked(result: int, code: int, _headers_got: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		state = State.NONE
		changed.emit()
		return
	apply_release(JSON.parse_string(body.get_string_from_utf8()))


## What GitHub says about the latest version. A version is only offered once its app is there.
func apply_release(data: Variant) -> void:
	state = State.NONE
	latest = ""
	apk_url = ""
	apk_size = 0
	if Game.is_dev_build() or typeof(data) != TYPE_DICTIONARY or data.get("draft", false) or data.get("prerelease", false):
		changed.emit()
		return
	var tag := str(data.get("tag_name", ""))
	if not is_newer(tag, current()):
		changed.emit()
		return
	# The app for this phone: the Android one, or on an iPhone the one to install with Sideloadly.
	var wanted := ".ipa" if OS.has_feature("ios") else ".apk"
	for asset: Variant in data.get("assets", []):
		if typeof(asset) == TYPE_DICTIONARY and str(asset.get("name", "")).ends_with(wanted):
			apk_url = str(asset.get("browser_download_url", ""))
			apk_size = int(asset.get("size", 0))
	if apk_url == "":
		changed.emit()
		return
	latest = tag.trim_prefix("v")
	page = str(data.get("html_url", PAGE))
	state = State.AVAILABLE
	changed.emit()


## Android: fetch the new app, then open it. Android asks the player before it installs anything.
func download() -> void:
	if Game.is_dev_build():
		return
	if not (state == State.AVAILABLE or state == State.FAILED) or apk_url == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	_http = HTTPRequest.new()
	_http.download_file = ProjectSettings.globalize_path(FILE)
	_http.timeout = 900.0
	add_child(_http)
	_http.request_completed.connect(_on_downloaded)
	problem = ""
	if _http.request(apk_url, _headers()) != OK:
		_http.queue_free()
		_http = null
		_failed("Could not start the download.")
		return
	state = State.DOWNLOADING
	changed.emit()


## How much has come so far, from 0 to 1, while downloading.
func progress() -> float:
	if _http == null or apk_size <= 0:
		return 0.0
	return clampf(float(_http.get_downloaded_bytes()) / float(apk_size), 0.0, 1.0)


func _on_downloaded(result: int, code: int, _headers_got: PackedStringArray, _body: PackedByteArray) -> void:
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_failed("The download stopped. Check your connection and try again.")
		return
	var f := FileAccess.open(FILE, FileAccess.READ)
	var got := f.get_length() if f else 0
	if apk_size > 0 and got != apk_size:
		_failed("The download came out wrong. Try again.")
		return
	state = State.READY
	changed.emit()
	install()


## Opens the new app with Android's installer. The first time, Android asks to allow this game to
## install apps; after allowing it, tap Install again.
func install() -> void:
	if state == State.READY and not Game.is_dev_build():
		OS.shell_open(ProjectSettings.globalize_path(FILE))


func _failed(why: String) -> void:
	problem = why
	state = State.FAILED
	changed.emit()
