# Run: godot --headless --fixed-fps 60 --path . --script res://tests/test_district.gd
extends SceneTree

const DT := 1.0 / 60.0

var _failures := 0


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var level: Node3D = load("res://scenes/levels/district.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for _i in 5:
		await physics_frame

	var nav: NavigationRegion3D = level.get_node("Navigation")
	_check(nav.navigation_mesh.get_polygon_count() > 50, "district ships a baked navmesh")
	var cops := level.get_node("Cops").get_children().filter(func(n: Node) -> bool: return n is DirtyCop)
	_check(cops.size() >= 3, "district has %d cops" % cops.size())
	var player: Player = level.get_node("Player")
	_check(player.global_position.distance_to(level.get_node("PlayerSpawn").global_position) < 0.5,
		"player starts at spawn")

	# Nobody can see the player at spawn (no instant fire on load).
	for _i in 60:
		await physics_frame
	var alerted := cops.filter(func(c: DirtyCop) -> bool: return c.state != DirtyCop.State.PATROL)
	_check(alerted.is_empty(), "no cop engages the player at spawn")

	# Pathfinding: send a cop to a point behind a building; direct line is blocked.
	player.global_position = Vector3(0, 0, 200)  # Out of the way.
	player.health.max_health = 100000.0
	player.health.reset()
	var cop: DirtyCop = level.get_node("Cops/CopB")  # Alley cop.
	cop.patrol_path = null
	cop.global_position = Vector3(-22.0, 0.1, 2.0)  # In the courtyard behind the alley.
	cop.velocity = Vector3.ZERO
	var goal := Vector3(4.0, 0, 16.0)  # Out on the street, other side of Building3.
	var space := cop.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cop.global_position + Vector3.UP, goal + Vector3.UP, 1)
	_check(not space.intersect_ray(q).is_empty(), "test setup: direct line to goal is blocked")
	cop.last_known_position = goal
	cop._change_state(DirtyCop.State.SEARCH)
	var reached := false
	for _i in roundi(20.0 / DT):
		await physics_frame
		if Vector2(cop.global_position.x - goal.x, cop.global_position.z - goal.z).length() < 1.0:
			reached = true
			break
		if cop.state != DirtyCop.State.SEARCH:
			cop.last_known_position = goal
			cop._change_state(DirtyCop.State.SEARCH)
	_check(reached, "cop paths around the building to the goal (ended at %s)" % cop.global_position)

	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
