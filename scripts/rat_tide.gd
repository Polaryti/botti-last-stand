class_name RatTide
extends Node3D
## A Rat King's Rat Tide, as seen: the King's own rats pouring out along a line and scattering at its
## end. Only a look; PathUpgrades.rat_tide does the harm, once, on the owner's phone.

var _rats: Array[Dictionary] = []
var _clock := 0.0
var _dir := Vector3.FORWARD
var _from := Vector3.ZERO
## The scene can be replayed (the Store's stage): with `loop`, the tide comes again every `loop` seconds.
var loop := 0.0
## How far the rats run (the Store's stage is smaller than a night).
var reach := PathUpgrades.RAT_TIDE_REACH


func _init(from: Vector3, dir: Vector3) -> void:
	_from = from
	_dir = Vector3(dir.x, 0, dir.z).normalized()
	name = "RatTide"


func _ready() -> void:
	var side := _dir.cross(Vector3.UP)
	for i in PathUpgrades.RAT_TIDE_RATS:
		var root := Node3D.new()
		add_child(root)
		var parts := Ally.build_beast_model("rat", root)
		var lane := (float(i % 4) / 3.0 - 0.5) * PathUpgrades.RAT_TIDE_WIDTH * 1.4
		_rats.append({"root": root, "parts": parts, "lane": lane, "lag": (i / 4) * 0.08 + fmod(i * 0.37, 0.07), "side": side})
		root.rotation.y = atan2(_dir.x, _dir.z)
	_place(0.0)


func _process(delta: float) -> void:
	_clock += delta
	if loop > 0.0:
		_place(fmod(_clock, loop))
		return
	_place(_clock)
	if _clock > PathUpgrades.RAT_TIDE_TIME + 0.6:
		queue_free()


## Where every rat is, `t` seconds after the tide began.
func _place(t: float) -> void:
	for r: Dictionary in _rats:
		var root: Node3D = r["root"]
		var k := (t - float(r["lag"])) / PathUpgrades.RAT_TIDE_TIME
		root.visible = k >= 0.0 and k < 1.35
		if not root.visible:
			continue
		var along := minf(k, 1.0) * reach
		var scatter := maxf(0.0, k - 1.0) * 6.0 # past the end they break away to the sides
		var side: Vector3 = r["side"]
		var lane: float = r["lane"]
		var at := _from + _dir * along + side * (lane + signf(lane + 0.01) * scatter)
		if is_inside_tree() and get_parent() is World:
			at.y = (get_parent() as World).ground_at(at)
		root.position = at
		root.scale = Vector3.ONE * 0.42 * clampf((1.35 - k) / 0.35, 0.0, 1.0)
		var stride := t * 26.0 + lane * 5.0
		var legs: Array = (r["parts"] as Dictionary)["legs"]
		for j in legs.size():
			(legs[j] as Node3D).rotation.x = sin(stride + (PI if j % 2 else 0.0)) * 0.7
		root.position.y += absf(sin(stride)) * 0.06
