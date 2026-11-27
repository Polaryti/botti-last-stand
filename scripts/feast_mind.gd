class_name FeastMind
extends MesenllaMind
## Pelagros fights from the centre of the court. The host resolves the offering, and MistSeal
## replicates attack tells and lets each phone resolve hits against its own players.

const ID := "pelagros"
const ARRIVAL := 450.0
const CHEST_TELL := 3.2
const TRIBUTE_DAMAGE := 210.0
const BREAK_DAMAGE := 135.0
const HEARTHFIRE := 1.15
const FLOURISH := 1.0

var _entered := false
var _enraged := false
var _offering := 7.0
var _hp_at_tell := 0.0
var _origin := Vector3.ZERO
var _pace := 0.0


func _init(id: String) -> void:
	super(id)
	cooldown = 3.5


func tick(z: Zombie, target: Target, _to: Vector3, _dist: float, delta: float) -> bool:
	z.velocity = Vector3.ZERO
	if not _entered:
		_entered = true
		_origin = z.position
		left = 1.8
		phase = "arrival"
		_show(z, "m_rise")
	if phase == "tribute" and _hp_at_tell - z.hp >= BREAK_DAMAGE * (1.0 + 0.35 * (z.world.players.size() - 1)):
		interrupt(z)
		return true
	if phase != "":
		left -= delta
		if left > 0.0:
			return true
		match phase:
			"tribute":
				z.world.fort.hit_heart(TRIBUTE_DAMAGE)
				z.world.sfx_at("pelagros_crash", z.world.fort.heart_at, 2.0)
				_recover(z, "m_cast")
				return true
			"flourish", "hearthfire":
				_recover(z, z._current_anim)
				return true
		phase = ""
		_show(z, "")
	if not _enraged and z.hp < z.max_hp * 0.5:
		_enraged = true
		phase = "call"
		left = 1.3
		_show(z, "m_roar", true)
		z.world.banner("Pelagros calls the last guests to the gates.", 4.0)
		z.world.sfx_at("pelagros_arrive", z.position, 3.0)
		for kind in ["cult_guardian", "cult_worshipper", "thornback"]:
			z.world.spawn_zombie(kind)
		return true
	if target == null:
		return true
	_pace += delta
	var x := _origin.x + 4.4 * sin(_pace * (0.65 if _enraged else 0.43))
	z.position.x = move_toward(z.position.x, x, delta * (2.9 if _enraged else 1.7))
	var direction := target.global_position - z.position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		z.rotation.y = lerp_angle(z.rotation.y, atan2(direction.x, direction.z), minf(delta * 2.1, 1.0))
	_offering -= delta
	cooldown -= delta
	if _offering <= 0.0 and z.world.fort and z.world.map_id == "thalys":
		_offering = 12.0 if _enraged else 17.0
		_hp_at_tell = z.hp
		phase = "tribute"
		left = CHEST_TELL
		_show(z, "m_cast", true)
		var heart := z.world.fort.heart_at
		MistSeal.cast(z, heart + Vector3.UP * 1.05, 6.1, CHEST_TELL, z._damage, 0.0, MistSeal.Style.FEAST)
		z.world.sfx_at("pelagros_charge", z.position, 3.0)
		z.world.banner("Pelagros is draining the cornucopia! Strike him to break the offering.", CHEST_TELL)
	elif cooldown <= 0.0 and direction.length() < 30.0:
		cooldown = 2.5 if _enraged else 4.0
		if direction.length() < 7.5:
			phase = "hearthfire"
			left = HEARTHFIRE
			_show(z, "m_slam", true)
			MistSeal.cast(z, z.position, 7.5, HEARTHFIRE, z._damage * 1.2, 0.0, MistSeal.Style.FEAST)
		else:
			phase = "flourish"
			left = FLOURISH + 0.48
			_show(z, "m_sweep", true)
			var forward := direction.normalized()
			for i in 5:
				var at := z.position + forward * (5.0 + i * 4.3)
				var reach := 3.7 if _enraged else 3.15
				MistSeal.cast(z, at, reach, FLOURISH + i * 0.12, z._damage * 0.75, 0.0, MistSeal.Style.FEAST)
		z.world.sfx_at("pelagros_charge", z.position, -1.0)
	return true


func _recover(z: Zombie, anim: String) -> void:
	phase = "recover"
	left = 0.65
	_show(z, anim)


func interrupt(z: Zombie) -> void:
	if phase == "tribute":
		z.world.banner("The offering breaks. The cornucopia is safe.", 2.8)
	MistSeal.break_from(z.world, z.net_id)
	_recover(z, z._current_anim)
