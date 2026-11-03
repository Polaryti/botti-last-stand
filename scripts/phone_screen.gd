class_name PhoneScreen
## Two things about the screen that the engine does not offer, so they are asked of Android directly.
## Off Android, and if any step comes back empty, these do nothing and the game carries on.

const SENSOR_LANDSCAPE := 6 # ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
const PHONE_DECIDES := -1.0 # WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE


static func _android() -> Object:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return null
	return Engine.get_singleton("AndroidRuntime")


static func _on_ui_thread(action: Callable) -> void:
	var runtime := _android()
	if runtime == null:
		return
	var activity: Variant = runtime.call("getActivity")
	if activity:
		activity.runOnUiThread(runtime.call("createRunnableFromGodotCallable", action))


## The game is always landscape, and turns over with the phone, even with the phone's own
## auto-rotate switched off. The engine's own setting would obey that switch.
static func apply_orientation() -> void:
	_on_ui_thread(func() -> void:
		var activity: Variant = _android().call("getActivity")
		if activity:
			activity.setRequestedOrientation(SENSOR_LANDSCAPE))


## A level set by this window takes over from automatic brightness, which is what dims the screen
## when a thumb covers the light sensor. Leaving the game gives the phone its own control back.
static func apply_brightness() -> void:
	var level := PHONE_DECIDES
	if Game.steady_brightness:
		level = Game.brightness if Game.brightness > 0.0 else _phone_level()
	_on_ui_thread(func() -> void:
		var activity: Variant = _android().call("getActivity")
		if activity == null:
			return
		var window: Variant = activity.getWindow()
		var attributes: Variant = window.getAttributes() if window else null
		if attributes == null:
			return
		# The value is a public field, and the bridge to Java only calls methods.
		var field: Variant = attributes.getClass().getField("screenBrightness")
		if field:
			field.setFloat(attributes, level)
			window.setAttributes(attributes))


static func current_level() -> float:
	return _phone_level()


## How bright the phone is right now, from 0 to 1.
static func _phone_level() -> float:
	var runtime := _android()
	if runtime == null:
		return 0.6
	var activity: Variant = runtime.call("getActivity")
	var settings: Variant = JavaClassWrapper.wrap("android.provider.Settings$System")
	if activity == null or settings == null:
		return 0.6
	var value: Variant = settings.getInt(activity.getContentResolver(), "screen_brightness", 150)
	return clampf(float(value) / 255.0, 0.25, 1.0) if typeof(value) == TYPE_INT else 0.6
