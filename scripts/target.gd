class_name Target
extends CharacterBody3D
## Anything zombies can hunt: the player, another player, and friendly summons.

const LAYER := 2

var dead := false


func eye_position() -> Vector3:
	return global_position + Vector3.UP * 1.5


func hurt(_amount: float, _from: Vector3, _attacker: Zombie = null) -> void:
	pass


func ignite(_seconds: float) -> void:
	pass


func is_unseen() -> bool:
	return false


## How far zombies can see this target, as a fraction of their usual sight.
func sight_factor() -> float:
	return 1.0


func look_direction() -> Vector3:
	return -global_basis.z
