# Run: godot --headless --path . --script res://tests/test_pistol.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var level: Node3D = load("res://scenes/levels/test_street.tscn").instantiate()
	root.add_child(level)
	for _i in 3:
		await physics_frame

	var player: Player = level.get_node("Player")
	var pistol: Pistol = player.get_node("%Pistol")
	var dummy: TargetDummy = level.get_node("TargetDummy1")
	player.set_physics_process(false)
	pistol.set_physics_process(false)

	# Stand 5 m in front of the dummy, facing it (model faces +Z, dummy is at -Z).
	player.global_position = dummy.global_position + Vector3(0, 0, 5)
	player.get_node("Model").rotation.y = PI
	await physics_frame

	var body: Node3D = dummy.get_node("Pivot/Body")
	var head: Node3D = dummy.get_node("Pivot/Head")

	# 1. Body shot deals base damage.
	var hit := pistol.fire_at(body.global_position)
	_check(hit.get("collider") == body, "body shot hits body hitbox")
	_check(is_equal_approx(dummy.health.current, 75.0), "body shot: 100 -> 75 (got %s)" % dummy.health.current)

	# 2. Head shot applies 2.5x.
	dummy.health.reset()
	hit = pistol.fire_at(head.global_position)
	_check(hit.get("collider") == head, "head shot hits head hitbox")
	_check(is_equal_approx(dummy.health.current, 37.5), "head shot: 100 -> 37.5 (got %s)" % dummy.health.current)

	# 3. Kill disables hitboxes; shots pass through the downed dummy.
	dummy.health.reset()
	var kills := [0]
	pistol.hit_confirmed.connect(func(_d: float, _w: bool, killed: bool) -> void:
		if killed: kills[0] += 1)
	pistol.fire_at(head.global_position)
	pistol.fire_at(head.global_position)
	_check(dummy.health.is_dead and kills[0] == 1, "two head shots kill, one kill confirmed")
	await physics_frame
	await physics_frame
	hit = pistol.fire_at(body.global_position)
	_check(hit.get("collider") != body, "dead dummy no longer blocks shots")

	# 4. Shooter's own capsule never eats the shot: wall 1 m away is hit.
	var crate: Node3D = level.get_node("Crate1")
	player.global_position = crate.global_position + Vector3(0, -0.75, 1.75 + 0.35)
	await physics_frame
	hit = pistol.fire_at(crate.global_position)
	_check(hit.get("collider") == crate, "shot with player excluded hits crate 1 m away")

	# 5. Fire rate holds at any frame rate (semi-auto, click every frame).
	for fps: float in [30.0, 60.0, 144.0]:
		var p: Pistol = load("res://scenes/weapons/pistol.tscn").instantiate()
		p.magazine_size = 100000
		level.add_child(p)
		p.set_physics_process(false)
		var shots := [0]
		p.fired.connect(func(_a: int) -> void: shots[0] += 1)
		var dt := 1.0 / fps
		for _f in roundi(10.0 * fps):
			p.pull_trigger()
			p.tick(dt)
		var expected := roundi(p.fire_rate * 10.0)
		_check(absi(shots[0] - expected) <= 1, "%d fps: %d shots in 10 s (want %d±1)" % [fps, shots[0], expected])
		p.queue_free()

	# 6. Empty mag auto-reloads; reload refills.
	var r: Pistol = load("res://scenes/weapons/pistol.tscn").instantiate()
	level.add_child(r)
	r.set_physics_process(false)
	r.ammo = 0
	r.pull_trigger()
	r.tick(0.016)
	_check(r.is_reloading, "trigger on empty mag starts reload")
	for _f in 100:
		r.tick(0.016)
	_check(r.ammo == r.magazine_size and not r.is_reloading, "reload refills magazine")

	# 7. Input actions the player relies on exist (an editor save once dropped them).
	for action in ["shoot", "reload", "move_forward", "sprint"]:
		_check(InputMap.has_action(action), "input action '%s' exists" % action)

	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
