# Run: godot --headless --fixed-fps 60 --path . --script res://tests/test_dirty_cop.gd
# (--fixed-fps makes every frame exactly 1/60 s, so simulated seconds run instantly.)
extends SceneTree

const DT := 1.0 / 60.0

var _failures := 0
var _transitions: Array[String] = []


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _frames(seconds: float) -> void:
	for _i in roundi(seconds / DT):
		await physics_frame


## Steps until cond() is true or timeout; returns seconds waited (or -1 on timeout).
func _wait_for(cond: Callable, timeout: float) -> float:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return t
		await physics_frame
		t += DT
	return -1.0


func _wall(level: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	level.add_child(body)
	body.global_position = at
	return body


func _initialize() -> void:
	var level: Node3D = load("res://scenes/levels/test_street.tscn").instantiate()
	root.add_child(level)
	await physics_frame

	var player: Player = level.get_node("Player")
	var cop: DirtyCop = level.get_node("DirtyCop")
	cop._rng.seed = 7
	cop.state_changed.connect(func(from: DirtyCop.State, to: DirtyCop.State) -> void:
		_transitions.append("%s->%s" % [DirtyCop.State.keys()[from], DirtyCop.State.keys()[to]]))
	player.health.max_health = 10000.0  # Survive long enough to observe; damage still counts.
	player.health.reset()

	# 1. Patrols when the player is far away.
	player.global_position = Vector3(25, 0, 25)
	var start := cop.global_position
	await _frames(3.0)
	_check(cop.state == DirtyCop.State.PATROL, "far player: cop stays on patrol")
	_check(cop.global_position.distance_to(start) > 2.0,
		"cop walks its patrol (%.1f m in 3 s)" % cop.global_position.distance_to(start))

	# From here: stand guard at a fixed spot facing +Z (toward the player side).
	cop.patrol_path = null
	cop.global_position = Vector3(0, 0, -15)
	cop.rotation.y = 0.0
	cop.velocity = Vector3.ZERO
	await _frames(0.2)

	# 2. Player behind the cop (outside the view cone) is not seen.
	player.global_position = Vector3(0, 0, -25)
	await _frames(1.0)
	_check(cop.state == DirtyCop.State.PATROL, "player behind cop is not spotted")

	# 3. Player in front but behind a tall wall is not seen.
	var wall := _wall(level, Vector3(0, 1.5, -10), Vector3(4, 3, 0.5))
	await physics_frame  # Let the wall enter the physics space before the player is exposed.
	player.global_position = Vector3(0, 0, -6)
	await _frames(1.0)
	_check(cop.state == DirtyCop.State.PATROL, "player behind cover is not spotted")

	# 4. Clear line of sight: ALERT quickly, COMBAT only after the reaction delay.
	wall.free()
	var hp_before := player.health.current
	var first_shot_hp := [-1.0]
	var pistol: Pistol = cop.get_node("%Pistol")
	pistol.fired.connect(func(_a: int) -> void:
		if first_shot_hp[0] < 0.0:
			first_shot_hp[0] = player.health.current)
	var t_alert := await _wait_for(func() -> bool: return cop.state == DirtyCop.State.ALERT, 1.0)
	_check(t_alert >= 0.0 and t_alert <= 0.2, "spots player in the open within 0.2 s (%.2f)" % t_alert)
	var t_combat := await _wait_for(func() -> bool: return cop.state == DirtyCop.State.COMBAT, 2.0)
	_check(t_combat >= cop.reaction_time - 0.05,
		"waits the reaction delay before combat (%.2f s, want >= %.2f)" % [t_combat, cop.reaction_time])

	# 5. Shoots back: first shot misses on purpose, later shots land.
	await _frames(6.0)
	_check(is_equal_approx(first_shot_hp[0], hp_before), "first shot of the engagement misses")
	_check(player.health.current < hp_before,
		"cop's shots hurt the player (%.0f -> %.0f)" % [hp_before, player.health.current])

	# 6. Loses sight: holds combat through the grace period, then searches, then patrols.
	wall = _wall(level, Vector3(0, 1.5, -10), Vector3(4, 3, 0.5))
	await _frames(1.0)
	_check(cop.state == DirtyCop.State.COMBAT, "keeps combat for the lose-sight grace period")
	var t_search := await _wait_for(func() -> bool: return cop.state == DirtyCop.State.SEARCH, 2.0)
	_check(t_search >= 0.0, "goes to search after losing the player")
	var t_patrol := await _wait_for(func() -> bool: return cop.state == DirtyCop.State.PATROL, 12.0)
	_check(t_patrol >= 0.0, "gives up the search and returns to patrol (%.1f s)" % t_patrol)

	# 7. Shot from out of sight: turns alert toward the shooter.
	player.global_position = Vector3(0, 0, -25)  # Behind the cop again.
	cop.rotation.y = 0.0
	await _frames(0.3)
	(cop.get_node("Hitboxes/Body") as Hitbox).receive_hit(5.0, cop.global_position)
	await physics_frame
	_check(cop.state == DirtyCop.State.ALERT, "getting shot alerts the cop")

	# 8. No state flicker over the whole run.
	var per_sec := _transitions.size() / 35.0
	_check(per_sec < 2.0, "transitions/s %.2f < 2 (%s)" % [per_sec, ", ".join(_transitions)])

	# 9. Killable: two head shots, then it stops shooting.
	wall.free()
	var gun: Pistol = player.get_node("%Pistol")
	var head: Node3D = cop.get_node("Hitboxes/Head")
	player.global_position = cop.global_position + Vector3(0, 0, 5)
	await physics_frame
	gun.fire_at(head.global_position)
	gun.fire_at(head.global_position)
	_check(cop.state == DirtyCop.State.DEAD and cop.health.is_dead, "two head shots kill the cop")
	var shots_after := [0]
	pistol.fired.connect(func(_a: int) -> void: shots_after[0] += 1)
	await _frames(2.0)
	_check(shots_after[0] == 0, "dead cop stops shooting")
	var hit := gun.fire_at(head.global_position)
	_check(hit.get("collider") != head, "dead cop's hitboxes are off")

	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
