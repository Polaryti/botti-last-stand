class_name DamageNumbers
extends Node3D
## The numbers that float up from an enemy when your side hurts it: how much the blow took, bigger
## and amber when it was a heavy one. Drawn from a small pool of labels, so a crowd being hit costs
## no more than MAX of them; blows landing on the same enemy within a moment are added together.

const MAX := 14
const LIFE := 0.75
const RISE := 1.1 # metres climbed in its life
const MERGE := 0.14 # seconds within which blows on one enemy join one number
const HEAVY := 0.3 # of the enemy's full health in one blow makes it a heavy one

var _labels: Array[Label3D] = []
var _age: PackedFloat32Array = []
var _sum: PackedFloat32Array = []
var _from: Array[Vector3] = []
var _owner: PackedInt64Array = [] # the enemy each number belongs to
var _next := 0


func _ready() -> void:
	name = "DamageNumbers"
	var font := UiTheme.bold_font()
	for i in MAX:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.font = font
		l.font_size = 40
		l.outline_size = 10
		l.outline_modulate = Color(0.06, 0.04, 0.08, 0.9)
		l.render_priority = 4
		l.visible = false
		add_child(l)
		_labels.append(l)
		_age.append(LIFE)
		_sum.append(0.0)
		_from.append(Vector3.ZERO)
		_owner.append(0)
	set_process(false)


## Damage over time, in its status's colour, and healing, green with a plus: these join numbers of
## their own kind on the same one for a little longer, so a poison shows as a steady few numbers.
const DOT_COLORS := {"poison": Color(0.5, 0.95, 0.32), "bleed": Color(0.95, 0.22, 0.18), "fire": Color(1.0, 0.56, 0.16)}
const HEAL_COLOR := Color(0.42, 1.0, 0.55)
const SLOW_MERGE := 0.45
const KINDS := ["", "poison", "bleed", "fire", "heal"]


## amount taken from `who` (its instance id) at `at`; full is its whole health.
func show_hit(who: int, at: Vector3, amount: float, full: float) -> void:
	var slot := _slot(who * 8, at, amount, MERGE)
	if slot < 0:
		return
	var l := _labels[slot]
	var heavy := _sum[slot] >= full * HEAVY
	l.text = str(roundi(_sum[slot]))
	l.modulate = Color(1.0, 0.72, 0.25) if heavy else Color(1, 1, 1)
	l.font_size = 54 if heavy else 40
	set_process(true)


## Damage over time on `who`: "poison", "bleed" or "fire", tinted, smaller than a blow's.
func show_dot(who: int, at: Vector3, amount: float, kind: String) -> void:
	var slot := _slot(who * 8 + KINDS.find(kind), at + Vector3.UP * 0.15, amount, SLOW_MERGE)
	if slot < 0:
		return
	var l := _labels[slot]
	l.text = str(maxi(1, roundi(_sum[slot])))
	l.modulate = DOT_COLORS.get(kind, Color.WHITE)
	l.font_size = 34
	set_process(true)


## Healing given to `who` (a friend, one of your summons): green, "+12".
func show_heal(who: int, at: Vector3, amount: float) -> void:
	var slot := _slot(who * 8 + KINDS.find("heal"), at, amount, SLOW_MERGE)
	if slot < 0:
		return
	var l := _labels[slot]
	l.text = "+%d" % maxi(1, roundi(_sum[slot]))
	l.modulate = HEAL_COLOR
	l.font_size = 40
	set_process(true)


## The label for `key` (an owner and a kind): the one still joining it within `merge`, else the next
## of the pool. -1 when nothing should show.
func _slot(key: int, at: Vector3, amount: float, merge: float) -> int:
	if amount < 0.5 or amount >= 5000.0 or not Game.damage_numbers:
		return -1
	var slot := -1
	for i in MAX:
		if _owner[i] == key and _age[i] < merge:
			slot = i
			break
	if slot < 0:
		slot = _next
		_next = (_next + 1) % MAX
		_sum[slot] = 0.0
		_age[slot] = 0.0
		# A little to one side or the other, so numbers in a row do not sit on top of each other.
		_from[slot] = at + Vector3(randf_range(-0.25, 0.25), 0.25, randf_range(-0.25, 0.25))
		_owner[slot] = key
	_sum[slot] += amount
	_labels[slot].position = _from[slot]
	_labels[slot].visible = true
	return slot


func _process(delta: float) -> void:
	var live := false
	for i in MAX:
		if _age[i] >= LIFE:
			continue
		_age[i] += delta
		var l := _labels[i]
		if _age[i] >= LIFE:
			l.visible = false
			continue
		live = true
		var t := _age[i] / LIFE
		# Quick up, then easing; fading over the last third.
		l.position = _from[i] + Vector3.UP * RISE * (1.0 - (1.0 - t) * (1.0 - t))
		l.modulate.a = clampf((1.0 - t) * 3.0, 0.0, 1.0)
		l.outline_modulate.a = 0.9 * l.modulate.a
	if not live:
		set_process(false)
