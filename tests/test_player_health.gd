# Run: godot --headless --path . --script res://tests/test_player_health.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var level: Node3D = load("res://scenes/levels/test_street.tscn").instantiate()
	level.get_node("DirtyCop").free()  # Covered by test_dirty_cop; would shoot the player here.
	root.add_child(level)
	current_scene = level
	for _i in 3:
		await physics_frame

	var player: Player = level.get_node("Player")
	var hud: HUD = player.get_node("HUD")
	var bar: ProgressBar = hud.get_node("HealthBar")
	var death_screen: Control = hud.get_node("DeathScreen")
	var body: Hitbox = player.get_node("Hitboxes/Body")
	var head: Hitbox = player.get_node("Hitboxes/Head")
	_check(is_equal_approx(player.health.current, 100.0), "player starts at 100 hp")
	_check(is_equal_approx(bar.value, 100.0), "health bar starts full")

	# A stand-in enemy gun 6 m in front of the player.
	var enemy_gun: Pistol = load("res://scenes/weapons/pistol.tscn").instantiate()
	level.add_child(enemy_gun)
	enemy_gun.set_physics_process(false)
	enemy_gun.global_position = player.global_position + Vector3(0, 1.2, 6)
	await physics_frame

	# 1. Body shot from outside hits the player's body hitbox.
	var hit := enemy_gun.fire_at(body.global_position + Vector3(0, 0.8, 0))
	_check(hit.get("collider") == body, "enemy shot hits player body hitbox")
	_check(is_equal_approx(player.health.current, 75.0), "body shot: 100 -> 75 (got %s)" % player.health.current)
	_check(is_equal_approx(bar.value, 75.0), "health bar follows damage (got %s)" % bar.value)

	# 2. Head shot doubles.
	hit = enemy_gun.fire_at(head.global_position + Vector3(0, 1.62, 0))
	_check(hit.get("collider") == head, "enemy shot hits player head hitbox")
	_check(is_equal_approx(player.health.current, 25.0), "head shot: 75 -> 25 (got %s)" % player.health.current)

	# 3. Player's own pistol never hits the player's own hitboxes.
	var own_gun: Pistol = player.get_node("%Pistol")
	hit = own_gun.fire_at(body.global_position + Vector3(0, 0.8, 0))
	_check(hit.get("collider") != body and hit.get("collider") != head, "own shot ignores own hitboxes")
	_check(is_equal_approx(player.health.current, 25.0), "own shot deals no self damage")

	# 4. Lethal hit: dies once, hitboxes off, death screen up, movement stops.
	var deaths := [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	enemy_gun.fire_at(body.global_position + Vector3(0, 0.8, 0))
	enemy_gun.fire_at(body.global_position + Vector3(0, 0.8, 0))
	_check(player.is_dead and deaths[0] == 1, "lethal damage kills player exactly once")
	_check(death_screen.visible, "death screen shown")
	await physics_frame
	await physics_frame
	hit = enemy_gun.fire_at(body.global_position + Vector3(0, 0.8, 0))
	_check(hit.get("collider") != body, "dead player's hitboxes stop blocking shots")
	Input.action_press("move_forward")
	var before := player.global_position
	for _i in 10:
		await physics_frame
	Input.action_release("move_forward")
	var moved := Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length()
	_check(moved < 0.01, "dead player can't move (moved %.3f m)" % moved)

	# 5. Restart reloads the level with a fresh, living player.
	hud.restart()
	for _i in 4:
		await process_frame
	var new_level := current_scene
	_check(new_level != null and new_level != level, "restart reloads the level")
	if new_level:
		var p2: Player = new_level.get_node("Player")
		_check(not p2.is_dead and is_equal_approx(p2.health.current, 100.0), "restarted player at full hp")
		_check(not p2.get_node("HUD/DeathScreen").visible, "death screen hidden after restart")

	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
