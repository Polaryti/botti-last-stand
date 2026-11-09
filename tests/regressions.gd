extends Node
## Fast, deterministic checks for mobile rendering and boundary-data regressions.

var checks := 0
var failures := 0

class WeatherWorld extends World:
	var shown_flash := -1.0
	func weather_changed() -> void:
		pass
	func show_lightning(amount: float) -> void:
		shown_flash = amount


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", description)
	else:
		print("ok: ", description)


func _ready() -> void:
	_test_packets()
	_test_settings()
	_test_dev_channel()
	_test_meshes()
	_test_paths()
	_test_terrain_dimensions()
	_test_fort_state()
	_test_weather()
	await _test_previews()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_packets() -> void:
	var packet := PackedByteArray()
	packet.resize(39)
	check(Net.valid_pose(packet), "a complete pose with no weapon is accepted")
	packet[34] = 255
	check(not Net.valid_pose(packet), "an unknown weapon index is rejected")
	packet[34] = 0
	for offset in range(0, 32, 4):
		for bad: float in [NAN, INF, -INF]:
			packet.encode_float(offset, bad)
			check(not Net.valid_pose(packet), "non-finite pose value at byte %d is rejected" % offset)
		packet.encode_float(offset, 0.0)
	packet.resize(38)
	check(not Net.valid_pose(packet), "a truncated pose is rejected")
	packet.resize(40)
	check(not Net.valid_pose(packet), "an oversized pose is rejected")
	var old_class := Game.player_class
	Net.set_my_class("not_a_class")
	check(Game.player_class == old_class, "an invalid lobby class leaves the current class alone")


func _test_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "quality", "high")
	check(Game._saved(config, "video", "quality", 1) == 1, "a saved setting with the wrong type falls back")
	config.set_value("audio", "music", NAN)
	check(Game._saved(config, "audio", "music", 0.8) == 0.8, "NaN audio volume falls back")
	config.set_value("input", "sensitivity", 2)
	check(Game._saved(config, "input", "sensitivity", 1.0) == 2.0, "integer numbers remain valid for float settings")
	config.set_value("progress", "unlocked", [])
	check(Game._saved(config, "progress", "unlocked", {}) == {}, "a malformed progress dictionary falls back")


func _test_dev_channel() -> void:
	var key := "botti/release_channel"
	var previous: Variant = ProjectSettings.get_setting(key)
	ProjectSettings.set_setting(key, "production")
	var production_protocol := Net.protocol_version()
	ProjectSettings.set_setting(key, "dev")
	check(Game.is_dev_build(), "development build identity is detected")
	check(Net.protocol_version() != production_protocol, "development multiplayer cannot join production")
	check(EpicNet.room_card(true, true)[EpicNet.VERSION] == str(Net.protocol_version()), "online room cards use the development compatibility namespace")
	var updates := Updates.new()
	add_child(updates)
	check(Updates.endpoint() == Updates.DEV_RELEASES, "dev uses the prerelease feed")
	updates.apply_release({"tag_name": "v999.0.0", "assets": [{"name": "production.apk", "browser_download_url": "https://example.invalid/production.apk", "size": 1}]})
	check(updates.state == Updates.State.NONE and updates.apk_url == "", "dev never offers production APKs")
	var version_was: Variant = ProjectSettings.get_setting("application/config/version")
	ProjectSettings.set_setting("application/config/version", "0.20.2-dev.6+abcdef0")
	var releases: Array = []
	for number in [9, 7, 8, 6]:
		var tag := "dev-%d-abcdef0" % number
		var asset := "botti-last-stand-%s.apk" % tag
		releases.append({"tag_name": tag, "prerelease": true, "assets": [{"name": asset, "browser_download_url": Updates.DOWNLOADS + tag + "/" + asset, "size": 100, "digest": "sha256:" + "a".repeat(64)}]})
	updates.apply_dev_releases(releases)
	check(updates.latest == "dev-9-abcdef0" and updates.apk_digest == "a".repeat(64), "dev chooses newest complete build regardless of feed ordering")
	updates.apply_dev_releases([releases[-1]])
	check(updates.state == Updates.State.NONE, "installed dev APK is not offered again")
	var bad: Dictionary = releases[0].duplicate(true)
	bad["assets"][0]["browser_download_url"] = "https://example.invalid/fake.apk"
	updates.apply_dev_releases([bad, releases[1]])
	check(updates.latest == "dev-7-abcdef0", "malformed dev download cannot hide a valid update")
	bad["draft"] = true
	updates.apply_dev_releases([bad, {"tag_name": "v999.0.0", "prerelease": false}])
	check(updates.state == Updates.State.NONE, "drafts and stable releases cannot cross into dev")
	check(Updates.dev_build("dev-12-abcdef0") == 12 and Updates.dev_build("dev-12-abcdefg") == 0, "dev build identity is validated")
	ProjectSettings.set_setting(key, "production")
	check(Updates.endpoint() == Updates.LATEST, "production keeps its stable release feed")
	updates.apply_dev_releases(releases)
	check(updates.state == Updates.State.NONE, "production cannot offer dev APKs")
	ProjectSettings.set_setting("application/config/version", version_was)
	# Exercise the actual completed-download path without an HTTP server or Android installer.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Updates.FOLDER))
	var file := FileAccess.open(Updates.FILE, FileAccess.WRITE)
	file.store_string("test apk bytes")
	file.close()
	updates.apk_size = 14
	updates.apk_digest = FileAccess.get_sha256(Updates.FILE)
	updates._http = HTTPRequest.new()
	updates.add_child(updates._http)
	updates._on_downloaded(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	check(updates.state == Updates.State.READY, "a matching download reaches the installer-ready state")
	updates.apk_digest = "0".repeat(64)
	updates._http = HTTPRequest.new()
	updates.add_child(updates._http)
	updates._on_downloaded(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	check(updates.state == Updates.State.FAILED and not FileAccess.file_exists(Updates.FILE), "a corrupt download is deleted and never offered for installation")
	var stale := HTTPRequest.new()
	updates.add_child(stale)
	updates._http = HTTPRequest.new()
	updates.add_child(updates._http)
	updates.state = Updates.State.CHECKING
	updates._on_checked(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), stale)
	check(updates.state == Updates.State.CHECKING and updates._http != null, "a stale update callback cannot complete a newer request")
	updates._on_downloaded(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), stale)
	check(updates.state == Updates.State.CHECKING, "a stale download callback cannot replace the current update state")
	updates.free()
	ProjectSettings.set_setting(key, previous)


func _test_meshes() -> void:
	var l := LowPoly.new()
	l.base = Transform3D(Basis.IDENTITY.scaled(Vector3(2.0, 0.5, 3.0)), Vector3.ZERO)
	l.leaf(Vector3.ZERO, Vector3(1, 1, 0), Vector3(0, 1, 1), Color.WHITE)
	var mesh := l.commit()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(vertices.size() == 3, "two-sided foliage needs only one triangle")
	check(absf(normals[0].dot(vertices[1] - vertices[0])) < 0.001 and absf(normals[0].dot(vertices[2] - vertices[0])) < 0.001,
		"normals stay perpendicular after nonuniform scaling")
	var mirrored := LowPoly.new()
	mirrored.base = Transform3D(Basis.IDENTITY.scaled(Vector3(-1, 1, 1)), Vector3.ZERO)
	mirrored.box(Vector3.ZERO, Vector3.ONE, Color.WHITE)
	var mirrored_arrays := mirrored.commit().surface_get_arrays(0)
	var mv: PackedVector3Array = mirrored_arrays[Mesh.ARRAY_VERTEX]
	var mn: PackedVector3Array = mirrored_arrays[Mesh.ARRAY_NORMAL]
	check((mv[2] - mv[0]).cross(mv[1] - mv[0]).normalized().dot(mn[0]) > 0.99,
		"mirroring geometry preserves outward winding and lighting")
	mirrored.base = Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	check(mirrored._normal_basis.is_finite(), "zero-scale editor pieces do not invert a singular basis")
	var plant := Crops.plant(Crops.wheat(), [Transform3D.IDENTITY], PackedColorArray())
	check(plant.extra_cull_margin > 0.0, "plant culling accounts for wind displacement")
	var large_plant := Crops.plant(Crops.wheat(), [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.0), Vector3.ZERO)], PackedColorArray())
	check(is_equal_approx(large_plant.extra_cull_margin, plant.extra_cull_margin * 2.0), "plant culling includes instance scale")
	large_plant.free()
	plant.free()
	var horse := HorseModel.make()
	check(horse.extra_cull_margin > 0.0, "horse culling accounts for animated legs and tail")
	horse.free()
	print("FOLIAGE vertices: wheat=%d corn=%d beans=%d vine=%d" % [Crops.wheat().surface_get_array_len(0),
		Crops.corn().surface_get_array_len(0), Crops.beans().surface_get_array_len(0), Crops.vine().surface_get_array_len(0)])


func _test_paths() -> void:
	var grid := PathGrid.new(5)
	grid.build_far_grid()
	check(grid._far.region.size == Vector2i(2, 2), "coarse grid includes partial edge cells")
	check(not grid._far.is_point_solid(Vector2i(1, 1)), "a partially sized open edge cell stays walkable")
	grid.block_box(Vector3.ZERO, Vector3(10, 1, 10))
	check(grid.path(Vector3.ZERO, Vector3.ONE).is_empty(), "a fully blocked grid has no path")
	check(grid.flood(Vector3.ZERO).is_empty(), "a fully blocked grid has no reachable cells")


func _test_previews() -> void:
	var preview := ModelView.new(Vector2(200, 240))
	add_child(preview)
	preview.show_item("blade_flurry")
	preview.hide()
	await get_tree().process_frame
	check(preview._stage.process_mode == Node.PROCESS_MODE_DISABLED, "hidden preview stops its 3D animations")
	preview.show()
	check(preview._stage.process_mode == Node.PROCESS_MODE_INHERIT, "visible preview resumes its 3D animations")
	preview.free()
	var scroll := DragScroll.new()
	add_child(scroll)
	scroll._held = true
	scroll._touch = 2
	scroll.hide()
	check(not scroll._held and scroll._touch == -1, "hiding a list releases its captured finger")
	scroll.free()


func _test_weather() -> void:
	var world := WeatherWorld.new()
	add_child(world)
	var weather := Weather.new(world)
	world.add_child(weather)
	var ring := MeshInstance3D.new()
	weather.add_child(ring)
	weather._warnings.append({"ring": ring})
	weather.flash = 1.0
	weather.set_kind(Weather.Kind.CLEAR)
	check(weather._warnings.is_empty() and not ring.visible, "changing weather retires pending lightning and its warning")
	check(weather.flash == 0.0 and world.shown_flash == 0.0, "changing weather clears the sky flash")
	world.free()


func _test_terrain_dimensions() -> void:
	var previous := Terrain.HALF
	Terrain.use_half(4)
	var small := Terrain.new()
	small.walk.fill(3.0)
	small.visual.fill(2.0)
	Terrain.use_half(12)
	var large := Terrain.new()
	large.walk.fill(7.0)
	large.visual.fill(6.0)
	check(small.height(0, 0) == 3.0 and small.ground_height(4, 4) == 2.0, "a different map cannot change an existing terrain's sampling dimensions")
	check(large.height(12, 12) == 7.0 and large.vertices_per_side > small.vertices_per_side, "mixed-size terrain instances retain independent extents")
	Terrain.use_half(previous)


func _test_fort_state() -> void:
	var fort := Fort.new(null)
	fort.repair(-1, 1.0)
	fort.repair(0, NAN)
	check(fort.gates.is_empty(), "invalid gate repairs leave an uninitialized fort untouched")
	fort.free()
