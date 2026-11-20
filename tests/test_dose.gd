# Run: godot --headless --fixed-fps 60 --path . --script res://tests/test_dose.gd
extends SceneTree

const DT := 1.0 / 60.0

var _failures := 0


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _frames(seconds: float) -> void:
	for _i in roundi(seconds / DT):
		await physics_frame


func _initialize() -> void:
	# Genome roll: random per run, every power reachable.
	var seen := {}
	var doses: Array[Dose] = []
	for s in range(1, 40):
		var d := Dose.new()
		d.rng_seed = s
		root.add_child.call_deferred(d)
		doses.append(d)
	await process_frame
	for d in doses:
		seen[d.genome] = true
		d.free()
	_check(seen.size() == Powers.ALL.size(), "all %d powers can be rolled (%s)" % [Powers.ALL.size(), seen.keys()])

	var level: Node3D = load("res://scenes/levels/test_street.tscn").instantiate()
	level.get_node("DirtyCop").free()
	root.add_child(level)
	current_scene = level
	for _i in 3:
		await physics_frame
	var player: Player = level.get_node("Player")
	var dose := player.dose
	var fx: ScreenFX = player.get_node("ScreenFX")
	var pistol: Pistol = player.get_node("%Pistol")

	_check(dose.pills == 0 and not dose.is_dosed, "run starts powerless with no pills")
	_check(not dose.take(), "can't dose with no pills")
	_check(fx.saturation() < 0.5, "world starts grey (sat %.2f)" % fx.saturation())

	# Pickup: walking into a pill collects it.
	var pill: Pickup = load("res://scenes/pickups/pill.tscn").instantiate()
	level.add_child(pill)
	pill.global_position = player.global_position + Vector3(0, 0, -3)
	await _frames(0.2)
	_check(dose.pills == 0, "pill out of reach isn't collected")
	pill.global_position = player.global_position
	await _frames(0.2)
	_check(dose.pills == 1, "walking over a pill collects it")
	_check(not is_instance_valid(pill), "collected pill is removed")

	# Force a known power to check its effect.
	dose.genome = Powers.IRONSKIN
	var revealed := [false]
	dose.dose_started.connect(func(_p: StringName, _n: int, r: bool) -> void: revealed[0] = r)
	_check(dose.take(), "Q takes a pill")
	_check(dose.is_dosed and is_equal_approx(dose.time_left, 75.0), "dose window is 75 s")
	_check(revealed[0] and dose.genome_revealed, "first pill reveals the genome")
	await _frames(0.8)
	_check(fx.saturation() > 1.0, "colour snaps back in (sat %.2f)" % fx.saturation())
	var hp := player.health.current
	player.health.damage(20.0)
	_check(is_equal_approx(hp - player.health.current, 7.0), "ironskin: 20 dmg -> 7 (got %.1f)" % (hp - player.health.current))
	_check(not dose.take(), "can't stack a second pill mid-dose")

	await _frames(75.0)
	_check(not dose.is_dosed, "dose wears off after 75 s")
	hp = player.health.current
	player.health.damage(20.0)
	_check(is_equal_approx(hp - player.health.current, 20.0), "power gone after the dose")
	await _frames(3.0)
	_check(fx.saturation() < 0.5, "world drains back to grey (sat %.2f)" % fx.saturation())

	# Each placeholder power does something.
	dose.genome = Powers.DEADEYE
	dose.add_pills(1)
	dose.take()
	_check(pistol.damage_multiplier > 1.0 and pistol.fire_rate_multiplier > 1.0, "deadeye buffs the pistol")
	dose.time_left = 0.01
	await _frames(0.1)
	_check(is_equal_approx(pistol.damage_multiplier, 1.0), "deadeye removed on wear-off")
	dose.genome = Powers.ADRENAL
	dose.add_pills(1)
	dose.take()
	_check(player.mods.speed > 1.0 and player.health.regen_per_second > 0.0, "adrenal: faster + regen")
	player.health.damage(30.0)
	hp = player.health.current
	await _frames(1.0)
	_check(player.health.current > hp, "adrenal regenerates health")
	_check(dose.doses_taken == 3, "dose count tracked (%d)" % dose.doses_taken)

	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
