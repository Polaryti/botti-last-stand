class_name PhoneNet
## A phone with mobile data on will not send anything through a Wi-Fi network that has no internet,
## such as another phone's hotspot. It connects, then a few seconds later moves everything to mobile
## data and the game loses touch. So while looking for or joining a game, this phone is told to use
## its Wi-Fi. Off Android, and if any step comes back empty, this does nothing and the game carries on.

const TRANSPORT_WIFI := 1 # NetworkCapabilities.TRANSPORT_WIFI
const LOW_LATENCY := 4 # WifiManager.WIFI_MODE_FULL_LOW_LATENCY, from Android 10
const HIGH_PERF := 3 # WifiManager.WIFI_MODE_FULL_HIGH_PERF, before that

static var _bound := false
static var _lock: Variant = null


static func _activity() -> Variant:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return null
	return Engine.get_singleton("AndroidRuntime").call("getActivity")


## Everything this phone opens from now on goes over Wi-Fi, if it is on one. A phone with its hotspot
## on has no Wi-Fi network of its own, so nothing changes for it.
static func use_wifi() -> void:
	var activity: Variant = _activity()
	if activity == null:
		return
	var manager: Variant = activity.getSystemService("connectivity")
	if manager == null:
		return
	var networks: Variant = manager.getAllNetworks()
	if typeof(networks) != TYPE_ARRAY:
		return
	for network: Variant in networks:
		var caps: Variant = manager.getNetworkCapabilities(network)
		if caps and caps.hasTransport(TRANSPORT_WIFI):
			_bound = manager.bindProcessToNetwork(network) == true
			return


## Back to whatever the phone prefers, for a phone that hosts: its own hotspot needs that.
static func use_default() -> void:
	if not _bound:
		return
	_bound = false
	var activity: Variant = _activity()
	if activity:
		var manager: Variant = activity.getSystemService("connectivity")
		if manager:
			manager.bindProcessToNetwork(null)


## Keeps the Wi-Fi radio awake during a game, so packets are not held back to save power.
static func hold_wifi() -> void:
	if _lock != null:
		return
	var activity: Variant = _activity()
	if activity == null:
		return
	var wifi: Variant = activity.getApplicationContext().getSystemService("wifi")
	if wifi == null:
		return
	var version: Variant = JavaClassWrapper.wrap("android.os.Build$VERSION")
	var modern: bool = version != null and int(version.SDK_INT) >= 29
	_lock = wifi.createWifiLock(LOW_LATENCY if modern else HIGH_PERF, "botti-last-stand")
	if _lock:
		_lock.acquire()


static func release_wifi() -> void:
	if _lock:
		_lock.release()
		_lock = null
