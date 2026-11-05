class_name BodyAnim
## Attacks the character files do not come with. Each one is a few poses, written as the way the arm,
## forearm and leg should point, with the character facing +Z and its right hand on the -X side.
## The poses are turned into ordinary animations once, and every character can then play them.

const RIG := "Rig/Skeleton3D:"
const GUARD_R := [Vector3(-0.35, -0.9, 0.15), Vector3(-0.15, -0.45, 0.9)]
const GUARD_L := [Vector3(0.35, -0.9, 0.1), Vector3(0.12, -0.75, 0.6)]
## Turning the wrist this way lays what the hand holds along the forearm.
const ALONG := Vector3(0.0, 0.0, -1.5)
const HALF_ALONG := Vector3(0.0, 0.0, -0.8)

## name -> [length, [time, pose], ...]. A pose has "r" and "l" for the arms (upper, fore), "leg_r",
## "chest" (pitch, yaw, roll), "wrist" (the right hand's turn) and "drop" (how far the hips sink).
const POSES := {
	"Thrust": [0.62,
		[0.0, {}],
		[0.2, {"r": [Vector3(-0.75, -0.25, -0.6), Vector3(-0.25, -0.05, 0.95)], "wrist": ALONG, "chest": Vector3(-0.05, -0.55, 0.0)}],
		[0.33, {"r": [Vector3(-0.08, 0.02, 1.0), Vector3(0.0, 0.02, 1.0)], "l": [Vector3(0.6, -0.65, -0.3), Vector3(0.3, -0.7, 0.5)], "wrist": ALONG, "chest": Vector3(0.12, 0.65, 0.0), "drop": 0.05}],
		[0.42, {"r": [Vector3(-0.1, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)], "l": [Vector3(0.6, -0.65, -0.3), Vector3(0.3, -0.7, 0.5)], "wrist": ALONG, "chest": Vector3(0.1, 0.55, 0.0), "drop": 0.05}],
		[0.62, {}]],
	"Overhead": [0.8,
		[0.0, {}],
		[0.3, {"r": [Vector3(-0.35, 0.9, -0.1), Vector3(-0.05, 0.95, -0.35)], "l": [Vector3(0.45, 0.6, 0.3), Vector3(-0.3, 0.8, 0.3)], "wrist": HALF_ALONG, "chest": Vector3(-0.25, -0.15, 0.0)}],
		[0.42, {"r": [Vector3(-0.2, 0.1, 1.0), Vector3(-0.05, -0.35, 1.0)], "l": [Vector3(0.2, 0.0, 1.0), Vector3(-0.2, -0.35, 1.0)], "wrist": HALF_ALONG, "chest": Vector3(0.4, 0.1, 0.0), "drop": 0.08}],
		[0.55, {"r": [Vector3(-0.2, -0.1, 1.0), Vector3(-0.05, -0.5, 1.0)], "l": [Vector3(0.2, -0.2, 1.0), Vector3(-0.2, -0.5, 1.0)], "wrist": HALF_ALONG, "chest": Vector3(0.45, 0.1, 0.0), "drop": 0.08}],
		[0.8, {}]],
	"Sweep": [0.7,
		[0.0, {}],
		[0.22, {"r": [Vector3(-0.95, 0.2, -0.25), Vector3(-0.85, 0.25, 0.4)], "wrist": HALF_ALONG, "chest": Vector3(0.0, -0.7, 0.0)}],
		[0.36, {"r": [Vector3(-0.1, 0.15, 1.0), Vector3(0.6, 0.12, 0.8)], "wrist": HALF_ALONG, "chest": Vector3(0.08, 0.25, 0.0), "drop": 0.04}],
		[0.48, {"r": [Vector3(0.5, 0.15, 0.85), Vector3(0.95, 0.1, 0.25)], "wrist": HALF_ALONG, "chest": Vector3(0.08, 0.8, 0.0), "drop": 0.04}],
		[0.7, {}]],
	"Throw": [0.62,
		[0.0, {}],
		[0.2, {"r": [Vector3(-0.75, 0.55, -0.4), Vector3(-0.2, 0.85, -0.5)], "l": [Vector3(0.4, 0.2, 0.9), Vector3(0.1, 0.3, 1.0)], "wrist": ALONG, "chest": Vector3(-0.15, -0.55, 0.0)}],
		[0.32, {"r": [Vector3(-0.25, 0.35, 1.0), Vector3(0.0, 0.15, 1.0)], "l": [Vector3(0.6, -0.5, -0.4), Vector3(0.2, -0.6, 0.5)], "wrist": ALONG, "chest": Vector3(0.25, 0.5, 0.0), "drop": 0.04}],
		[0.62, {}]],
	"BoSpin": [0.8,
		[0.0, {}],
		[0.14, {"r": [Vector3(-0.3, 0.05, 1.0), Vector3(0.1, 0.1, 1.0)], "l": [Vector3(0.7, -0.5, 0.3), Vector3(0.4, -0.5, 0.7)], "wrist": Vector3(0.0, 0.0, 0.0), "chest": Vector3(0.0, -0.5, 0.0)}],
		[0.3, {"r": [Vector3(-0.1, 0.05, 1.0), Vector3(0.25, 0.1, 1.0)], "l": [Vector3(0.7, -0.5, 0.3), Vector3(0.4, -0.5, 0.7)], "wrist": Vector3(0.0, 2.09, 0.0), "chest": Vector3(0.05, 0.1, 0.0)}],
		[0.46, {"r": [Vector3(0.1, 0.05, 1.0), Vector3(0.45, 0.1, 0.9)], "l": [Vector3(0.7, -0.5, 0.3), Vector3(0.4, -0.5, 0.7)], "wrist": Vector3(0.0, 4.18, 0.0), "chest": Vector3(0.05, 0.6, 0.0)}],
		[0.6, {"r": [Vector3(-0.1, 0.05, 1.0), Vector3(0.1, 0.1, 1.0)], "l": [Vector3(0.7, -0.5, 0.3), Vector3(0.4, -0.5, 0.7)], "wrist": Vector3(0.0, 6.27, 0.0), "chest": Vector3(0.0, 0.1, 0.0)}],
		[0.8, {}]],
	"Stomp": [0.78,
		[0.0, {}],
		[0.3, {"leg_r": [Vector3(-0.1, -0.3, 0.95), Vector3(-0.1, -0.95, 0.15)], "r": [Vector3(-0.8, 0.5, 0.0), Vector3(-0.4, 0.9, 0.1)], "l": [Vector3(0.8, 0.5, 0.0), Vector3(0.4, 0.9, 0.1)], "chest": Vector3(-0.2, 0.0, 0.0)}],
		[0.42, {"leg_r": [Vector3(-0.25, -0.95, 0.2), Vector3(-0.1, -0.98, 0.0)], "r": [Vector3(-0.8, -0.6, 0.0), Vector3(-0.5, -0.8, 0.3)], "l": [Vector3(0.8, -0.6, 0.0), Vector3(0.5, -0.8, 0.3)], "chest": Vector3(0.4, 0.0, 0.0), "drop": 0.14}],
		[0.56, {"leg_r": [Vector3(-0.25, -0.95, 0.2), Vector3(-0.1, -0.98, 0.0)], "r": [Vector3(-0.8, -0.6, 0.0), Vector3(-0.5, -0.8, 0.3)], "l": [Vector3(0.8, -0.6, 0.0), Vector3(0.5, -0.8, 0.3)], "chest": Vector3(0.35, 0.0, 0.0), "drop": 0.12}],
		[0.78, {}]],
	"Stance": [0.56,
		[0.0, {}],
		[0.18, {"r": [Vector3(-0.5, -0.45, 0.75), Vector3(0.65, 0.2, 0.75)], "l": [Vector3(0.5, -0.45, 0.75), Vector3(-0.65, 0.2, 0.75)], "chest": Vector3(0.12, 0.0, 0.0), "drop": 0.04}],
		[0.36, {"r": [Vector3(-0.9, -0.05, 0.45), Vector3(-0.3, 0.6, 0.75)], "l": [Vector3(0.9, -0.05, 0.45), Vector3(0.3, 0.6, 0.75)], "chest": Vector3(-0.1, 0.0, 0.0), "drop": 0.08}],
		[0.56, {}]],
	# Kneeling, hands on the knees, while the spirit is away.
	"Meditate": [1.0,
		[0.0, {"r": [Vector3(-0.3, -0.9, 0.3), Vector3(0.1, -0.3, 0.95)], "l": [Vector3(0.3, -0.9, 0.3), Vector3(-0.1, -0.3, 0.95)], "leg_r": [Vector3(-0.3, -0.25, 0.92), Vector3(0.2, -0.4, -0.9)], "leg_l": [Vector3(0.3, -0.25, 0.92), Vector3(-0.2, -0.4, -0.9)], "chest": Vector3(0.05, 0.0, 0.0), "drop": 0.24}],
		[1.0, {"r": [Vector3(-0.3, -0.9, 0.3), Vector3(0.1, -0.3, 0.95)], "l": [Vector3(0.3, -0.9, 0.3), Vector3(-0.1, -0.3, 0.95)], "leg_r": [Vector3(-0.3, -0.25, 0.92), Vector3(0.2, -0.4, -0.9)], "leg_l": [Vector3(0.3, -0.25, 0.92), Vector3(-0.2, -0.4, -0.9)], "chest": Vector3(0.05, 0.0, 0.0), "drop": 0.24}]],
	"Vault": [0.5,
		[0.0, {}],
		[0.16, {"r": [Vector3(-0.2, 0.9, 0.4), Vector3(0.0, 0.8, 0.6)], "l": [Vector3(0.2, 0.9, 0.4), Vector3(0.0, 0.8, 0.6)], "leg_r": [Vector3(-0.1, -0.5, 0.85), Vector3(-0.1, -0.9, -0.3)], "chest": Vector3(-0.3, 0.0, 0.0)}],
		[0.34, {"r": [Vector3(-0.4, -0.2, 0.9), Vector3(0.4, -0.2, 0.9)], "l": [Vector3(0.5, -0.5, 0.5), Vector3(0.2, -0.5, 0.8)], "leg_r": [Vector3(-0.1, -0.5, 0.85), Vector3(-0.1, -0.95, 0.2)], "chest": Vector3(0.4, 0.3, 0.0)}],
		[0.5, {}]],
}

static var _rest := {}


## Adds the poses to this character's animations. They are all built on the same skeleton, so the
## first character to come along does the work and the rest get them for nothing.
static func install(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	if player.has_animation("Thrust") or skeleton.find_bone("upperarm.r") < 0:
		return
	var library := player.get_animation_library(&"")
	for anim_name: String in POSES:
		library.add_animation(anim_name, _build(POSES[anim_name], skeleton))


static func _build(data: Array, skeleton: Skeleton3D) -> Animation:
	var anim := Animation.new()
	anim.length = data[0]
	var tracks := {}
	for bone: String in ["hips", "spine", "chest", "upperarm.r", "lowerarm.r", "wrist.r", "upperarm.l", "lowerarm.l", "upperleg.r", "lowerleg.r", "upperleg.l", "lowerleg.l"]:
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, RIG + bone)
		tracks[bone] = track
	var hips_at := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_at, RIG + "hips")
	var hips_rest: Vector3 = skeleton.get_bone_rest(skeleton.find_bone("hips")).origin
	for i in range(1, data.size()):
		var when: float = data[i][0]
		var pose: Dictionary = data[i][1]
		var turns := _solve(pose, skeleton)
		for bone: String in turns:
			anim.rotation_track_insert_key(tracks[bone], when, turns[bone])
		anim.position_track_insert_key(hips_at, when, hips_rest - Vector3.UP * float(pose.get("drop", 0.0)))
	return anim


## From "point this way" to the turn of each bone relative to the one it hangs from.
static func _solve(pose: Dictionary, skeleton: Skeleton3D) -> Dictionary:
	var out := {}
	var chest_e: Vector3 = pose.get("chest", Vector3.ZERO)
	var chest_turn := Basis.from_euler(Vector3(chest_e.x, chest_e.y, chest_e.z))
	var spine_g := _global(skeleton, "spine")
	var chest_g := chest_turn * _global(skeleton, "chest")
	for still: String in ["hips", "spine"]:
		out[still] = skeleton.get_bone_rest(skeleton.find_bone(still)).basis.get_rotation_quaternion()
	out["chest"] = (spine_g.inverse() * chest_g).get_rotation_quaternion()
	_limb(out, skeleton, chest_g, "upperarm.r", "lowerarm.r", pose.get("r", GUARD_R))
	_limb(out, skeleton, chest_g, "upperarm.l", "lowerarm.l", pose.get("l", GUARD_L))
	var hips_g := _global(skeleton, "hips")
	var standing := [Vector3(-0.08, -1.0, 0.0), Vector3(-0.04, -1.0, 0.0)]
	_limb(out, skeleton, hips_g, "upperleg.r", "lowerleg.r", pose.get("leg_r", standing))
	_limb(out, skeleton, hips_g, "upperleg.l", "lowerleg.l", pose.get("leg_l", [Vector3(0.08, -1.0, 0.0), Vector3(0.04, -1.0, 0.0)]))
	var rest_wrist := skeleton.get_bone_rest(skeleton.find_bone("wrist.r")).basis
	var wrist_e: Vector3 = pose.get("wrist", Vector3.ZERO)
	out["wrist.r"] = (rest_wrist * Basis.from_euler(wrist_e)).get_rotation_quaternion()
	return out


static func _limb(out: Dictionary, skeleton: Skeleton3D, parent_g: Basis, upper: String, lower: String, dirs: Array) -> void:
	var upper_g := _pointing(_global(skeleton, upper), dirs[0])
	var lower_g := _pointing(_global(skeleton, lower), dirs[1])
	out[upper] = (parent_g.inverse() * upper_g).get_rotation_quaternion()
	out[lower] = (upper_g.inverse() * lower_g).get_rotation_quaternion()


## The shortest turn that makes this bone point along dir.
static func _pointing(rest: Basis, dir: Vector3) -> Basis:
	var from := rest.y.normalized()
	var to := dir.normalized()
	var axis := from.cross(to)
	if axis.length_squared() < 0.0001:
		return rest
	return Basis(axis.normalized(), from.angle_to(to)) * rest


static func _global(skeleton: Skeleton3D, bone: String) -> Basis:
	if not _rest.has(bone):
		_rest[bone] = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).basis.orthonormalized()
	return _rest[bone]


## What a character does when it attacks with this weapon. count is how many attacks it has made,
## so that a run of blows does not repeat one move.
static func attack_for(weapon: String, count := 0) -> String:
	if weapon == "" or not WeaponDefs.ALL.has(weapon):
		return "Unarmed_Melee_Attack_Punch_A"
	var d: Dictionary = WeaponDefs.ALL[weapon]
	match d["kind"]:
		WeaponDefs.Kind.SPELL:
			return "Spellcast_Shoot"
		WeaponDefs.Kind.RANGED:
			return "Throw" if d.has("shot") or d.get("returning", false) else "2H_Ranged_Shoot"
	match str(d.get("swing", "")):
		"thrust", "stab": return "Thrust"
		"overhead", "smash": return "Overhead"
		"slash", "reap": return "Sweep" if count % 2 == 0 else "1H_Melee_Attack_Chop"
		"bo": return "BoSpin" if count % 3 == 0 else "Sweep"
	return "Unarmed_Melee_Attack_Punch_A"


## A mob's blow, close up, whatever it is carrying.
static func mob_attack(weapon: String, claws := false) -> String:
	if weapon != "" and WeaponDefs.ALL.has(weapon) and WeaponDefs.ALL[weapon]["kind"] == WeaponDefs.Kind.MELEE:
		return attack_for(weapon, randi())
	return "1H_Melee_Attack_Chop" if weapon != "" or claws else "Unarmed_Melee_Attack_Punch_A"
