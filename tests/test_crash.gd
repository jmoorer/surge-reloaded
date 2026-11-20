# Run: godot --headless --fixed-fps 60 --path . --script res://tests/test_crash.gd
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


func _end_dose(dose: Dose) -> void:
	dose.time_left = DT * 0.5
	await physics_frame
	await physics_frame


func _initialize() -> void:
	var level: Node3D = load("res://scenes/levels/test_street.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for _i in 3:
		await physics_frame
	var player: Player = level.get_node("Player")
	var cop: DirtyCop = level.get_node("DirtyCop")
	var dose := player.dose
	var fx: ScreenFX = player.get_node("ScreenFX")
	dose.genome = Powers.IRONSKIN

	# Out of the cop's sight, but within earshot.
	cop.patrol_path = null
	cop.global_position = Vector3(0, 0, -20)
	cop.rotation.y = PI  # Facing away (-Z).
	player.global_position = Vector3(0, 0, 0)
	await _frames(0.5)
	_check(cop.state == DirtyCop.State.PATROL, "setup: cop unaware")

	dose.add_pills(3)
	dose.take()
	_check(not dose.is_crashing, "no crash while dosed")
	await _end_dose(dose)
	_check(dose.is_crashing, "crash starts when the dose ends")
	_check(is_equal_approx(dose.crash_duration, 30.0), "first crash lasts 30 s")
	var m1 := player.mods
	_check(m1.sway_deg > 0.5, "crash: weapon sway (%.1f deg)" % m1.sway_deg)
	_check(m1.look_sensitivity < 1.0, "crash: slower aim (x%.2f)" % m1.look_sensitivity)
	_check(m1.blur > 0.2, "crash: blurred vision (%.2f)" % m1.blur)
	_check(player.health.cap < player.health.max_health, "crash: less health (cap %.0f)" % player.health.cap)
	_check(player.health.current <= player.health.cap, "health clamped to the cap")
	await physics_frame
	_check(cop.state != DirtyCop.State.PATROL, "crash alerts nearby cops (hunted: %s)" % DirtyCop.State.keys()[cop.state])
	await _frames(1.5)
	_check(fx.blur() > 0.2, "screen blurs (%.2f)" % fx.blur())

	# A pill cures the crash immediately.
	dose.take()
	_check(not dose.is_crashing and dose.is_dosed, "pill during crash ends it")
	_check(is_equal_approx(player.mods.sway_deg, 0.0) and is_equal_approx(player.health.cap, 100.0),
		"crash debuffs cleared while dosed")

	# Second crash is worse.
	await _end_dose(dose)
	var m2 := player.mods
	_check(dose.crash_duration > 30.0, "2nd crash lasts longer (%.0f s)" % dose.crash_duration)
	_check(m2.sway_deg > m1.sway_deg and m2.blur > m1.blur and m2.look_sensitivity < m1.look_sensitivity,
		"2nd crash: more sway/blur, slower aim")
	_check(player.health.cap < 75.0, "2nd crash: less health than the 1st (cap %.0f)" % player.health.cap)

	# Third crash, worse again; then it wears off completely.
	dose.take()
	await _end_dose(dose)
	_check(player.mods.blur > m2.blur, "3rd crash worse than 2nd")
	await _frames(dose.crash_duration * 0.8)
	_check(player.mods.sway_deg < m2.sway_deg, "crash eases off near its end")
	await _frames(dose.crash_duration * 0.25)
	_check(not dose.is_crashing, "crash wears off")
	_check(is_equal_approx(player.mods.sway_deg, 0.0) and is_equal_approx(player.health.cap, 100.0)
		and is_equal_approx(player.mods.look_sensitivity, 1.0), "all crash debuffs gone")

	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
