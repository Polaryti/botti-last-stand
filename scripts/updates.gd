class_name Updates
extends Node
## Looks for a newer version on the game's GitHub page, where every version is published with its
## Android app: when the game starts, and again each time a match ends and the menu comes back. On
## Android it can fetch the new app and hand it to Android's own installer, which asks before it changes
## anything. An iPhone app cannot install another, so there it only says a new version is out and
## where to find it. With no connection it says nothing.

signal changed

const LATEST := "https://api.github.com/repos/Polaryti/botti-last-stand/releases/latest"
const DEV_RELEASES := "https://api.github.com/repos/Polaryti/botti-last-stand/releases?per_page=100"
const DOWNLOADS := "https://github.com/Polaryti/botti-last-stand/releases/download/"
const PAGE := "https://github.com/Polaryti/botti-last-stand/releases/latest"
const FOLDER := "user://update"
const FILE := "user://update/botti-last-stand.apk"

enum State { IDLE, CHECKING, NONE, AVAILABLE, DOWNLOADING, READY, FAILED }

var state: int = State.IDLE
var latest := "" # the newer version, as "0.20.2"
var apk_url := ""
var apk_size := 0
var apk_digest := ""
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
	return OS.has_feature("android")


func _headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: BottisLastStand/%s" % current(), "Accept: application/vnd.github+json"])


func check() -> void:
	if state == State.CHECKING or state == State.DOWNLOADING or state == State.READY:
		return
	# Whatever was fetched last time has been installed or given up on.
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	state = State.CHECKING
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_checked.bind(_http))
	if _http.request(endpoint(), _headers()) != OK:
		_http.queue_free()
		_http = null
		state = State.NONE
		changed.emit()


func _on_checked(result: int, code: int, _headers_got: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	if request != _http or not is_instance_valid(_http):
		return
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		state = State.NONE
		changed.emit()
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if Game.is_dev_build():
		apply_dev_releases(data)
	else:
		apply_release(data)


## Production uses GitHub's stable release; dev scans prereleases because /latest excludes them.
static func endpoint() -> String:
	return DEV_RELEASES if Game.is_dev_build() else LATEST


static func dev_build(tag: String) -> int:
	var bits := tag.split("-")
	if bits.size() != 3 or bits[0] != "dev" or not bits[1].is_valid_int() or bits[2].length() != 7:
		return 0
	for ch in bits[2]:
		if not ch in "0123456789abcdef":
			return 0
	return maxi(0, bits[1].to_int())


static func _stable_tag(tag: String) -> bool:
	var parts := tag.trim_prefix("v").split(".")
	if parts.size() != 3:
		return false
	for part: String in parts:
		if part.is_empty() or not part.is_valid_int() or part.to_int() < 0:
			return false
	return true


static func installed_dev_build() -> int:
	return current().split("-dev.")[-1].split("+")[0].to_int() if "-dev." in current() else 0


func _reset_offer() -> void:
	state = State.NONE
	latest = ""
	apk_url = ""
	apk_size = 0
	apk_digest = ""
	page = PAGE


## Ignore drafts, stable builds and incomplete uploads; compare Android's monotonic dev run number.
func apply_dev_releases(data: Variant) -> void:
	_reset_offer()
	var best := installed_dev_build()
	if Game.is_dev_build() and typeof(data) == TYPE_ARRAY:
		for release: Variant in data:
			if typeof(release) != TYPE_DICTIONARY or release.get("draft", false) or not release.get("prerelease", false):
				continue
			var tag := str(release.get("tag_name", ""))
			var number := dev_build(tag)
			if number > best and _select_asset(release, tag, "botti-last-stand-%s.apk" % tag):
				best = number
	changed.emit()


## A version is offered only once the correct channel's Android app is published.
func apply_release(data: Variant) -> void:
	_reset_offer()
	if not Game.is_dev_build() and typeof(data) == TYPE_DICTIONARY and not data.get("draft", false) and not data.get("prerelease", false):
		var tag := str(data.get("tag_name", ""))
		if _stable_tag(tag) and is_newer(tag, current()):
			_select_asset(data, tag)
	changed.emit()


func _select_asset(release: Dictionary, tag: String, exact_name := "") -> bool:
	var assets: Variant = release.get("assets", [])
	if typeof(assets) != TYPE_ARRAY:
		return false
	var wanted := ".ipa" if OS.has_feature("ios") and not Game.is_dev_build() else ".apk"
	if exact_name == "":
		exact_name = "botti-last-stand-" + tag.trim_prefix("v") + ("-ios" if wanted == ".ipa" else "") + wanted
	for asset: Variant in assets:
		if typeof(asset) != TYPE_DICTIONARY:
			continue
		var asset_name := str(asset.get("name", ""))
		var url := str(asset.get("browser_download_url", ""))
		if asset_name != exact_name:
			continue
		if not url.begins_with(DOWNLOADS + tag + "/") or url.get_file() != asset_name or int(asset.get("size", 0)) <= 0:
			continue
		var digest: Variant = asset.get("digest")
		var checksum := ""
		if digest != null and digest != "":
			if typeof(digest) != TYPE_STRING or not digest.begins_with("sha256:"):
				continue
			checksum = digest.trim_prefix("sha256:")
			if checksum.length() != 64 or not checksum.is_valid_hex_number():
				continue
		apk_url = url
		apk_size = int(asset["size"])
		apk_digest = checksum
		latest = tag if Game.is_dev_build() else tag.trim_prefix("v")
		page = "https://github.com/Polaryti/botti-last-stand/releases/tag/" + tag
		state = State.AVAILABLE
		return true
	return false


## Android: fetch the new app, then open it. Android asks the player before it installs anything.
func download() -> void:
	if not (state == State.AVAILABLE or state == State.FAILED) or apk_url == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	_http = HTTPRequest.new()
	_http.download_file = ProjectSettings.globalize_path(FILE)
	_http.timeout = 900.0
	add_child(_http)
	_http.request_completed.connect(_on_downloaded.bind(_http))
	problem = ""
	var download_url := apk_url + "?download=1&check=%d" % int(Time.get_unix_time_from_system())
	if _http.request(download_url, _headers()) != OK:
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


func _on_downloaded(result: int, code: int, _headers_got: PackedStringArray, _body: PackedByteArray, request: HTTPRequest = null) -> void:
	if (request != null and request != _http) or not is_instance_valid(_http):
		return
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
	if apk_digest != "" and FileAccess.get_sha256(FILE) != apk_digest:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
		_failed("The download failed verification. Try again.")
		return
	state = State.READY
	changed.emit()
	install()


## Opens the new app with Android's installer. The first time, Android asks to allow this game to
## install apps; after allowing it, tap Install again.
func install() -> void:
	if state == State.READY and can_install():
		OS.shell_open(ProjectSettings.globalize_path(FILE))


func _failed(why: String) -> void:
	problem = why
	state = State.FAILED
	changed.emit()
