class_name VaelVault
extends RefCounted
## A short jump over an obstacle in Port Vael, with room for the whole body throughout.

const TIME := 0.72
const RISE := 1.85
const REACH := 1.8
const SWEEPS := 8


static func point(from: Vector3, to: Vector3, progress: float) -> Vector3:
	# Get the feet up before moving across a wall, then touch down clear of it.
	var along := smoothstep(0.17, 0.85, progress)
	return from.lerp(to, along) + Vector3.UP * sin(progress * PI) * RISE


static func landing(body: CharacterBody3D, world: World, heading: Vector3) -> Vector3:
	var dir := Vector3(heading.x, 0.0, heading.z).normalized()
	if dir == Vector3.ZERO:
		return Vector3.INF
	var from := body.global_position
	var space := body.get_world_3d().direct_space_state
	var low := from + Vector3.UP * 0.32
	var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + dir * REACH, 1))
	if face.is_empty() or (face["normal"] as Vector3).y > 0.45:
		return Vector3.INF
	# A wall, rail above waist height or window is something to go round.
	var high := from + Vector3.UP * (RISE - 0.05)
	var mask := 1 | Terrain.BARRIER | Terrain.ENEMY_ONLY
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(high, high + dir * REACH, mask)).is_empty():
		return Vector3.INF
	var min_run := low.distance_to(face["position"]) + 0.83
	for reach: float in [2.0, 2.5, 3.0, 3.6, 4.2]:
		if reach < min_run:
			continue
		var to := from + dir * reach
		if not world.vael_sites.accessible(to):
			continue
		to.y = world.ground_at(to) + 0.055
		if absf(to.y - from.y) > 0.85:
			continue
		if _clear_arc(body, world, from, to):
			return to
	return Vector3.INF


static func _clear_arc(body: CharacterBody3D, world: World, from: Vector3, to: Vector3) -> bool:
	var pose := body.global_transform
	for i in range(1, SWEEPS + 1):
		var there := point(from, to, float(i) / SWEEPS)
		if there.y + 0.05 < world.ground_at(there) or body.test_move(pose, there - pose.origin):
			return false
		pose.origin = there
	return true
