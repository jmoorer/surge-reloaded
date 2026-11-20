# Run: godot --headless --fixed-fps 60 --path . --script res://tests/test_full_run.gd
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


func _load_level() -> Node3D:
	var level: Node3D = load("res://scenes/levels/district.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for _i in 3:
		await physics_frame
	var player: Player = level.get_node("Player")
	player.health.max_health = 100000.0  # Cops can't end the test early; damage still counts.
	player.health.reset()
	return level


func _free_level(level: Node3D) -> void:
	paused = false
	level.free()
	await physics_frame


func _initialize() -> void:
	SaveGame.prefix = "user://test_"
	SaveGame.delete_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.profile_path()))

	# --- Samples and drops -------------------------------------------------------------
	var level: Node3D = await _load_level()
	var player: Player = level.get_node("Player")
	var run: RunDirector = level.get_node("Run")
	_check(player.samples == 0 and player.dose.pills == 0, "run starts with no samples or pills")
	var sample: Pickup = level.get_node("Pickups/Sample1")
	player.global_position = sample.global_position
	await _frames(0.2)
	_check(player.samples == 1, "walking over a sample collects it")

	var cop: DirtyCop = level.get_node("Cops/CopA")
	var cop_pos := cop.global_position
	cop.health.damage(10000.0)
	await _frames(0.2)
	var drops := get_nodes_in_group(&"pickups").filter(func(p: Node) -> bool:
		return (p as Pickup).kind == Pickup.Kind.SAMPLE and (p as Node3D).global_position.distance_to(cop_pos) < 2.0)
	_check(drops.size() == 1, "dead cop drops a sample")
	player.global_position = (drops[0] as Node3D).global_position
	await _frames(0.2)
	_check(player.samples == 2, "picked up the cop's sample (%d)" % player.samples)

	# --- Save and quit, then resume ------------------------------------------------------
	player.dose.add_pills(1)
	player.dose.take()
	await _frames(1.0)
	player.global_position = Vector3(-3, 0, 5)
	await physics_frame
	var saved_pos := player.global_position
	var saved_time := player.dose.time_left
	var saved_genome := player.dose.genome
	player.health.damage(1234.0)
	var saved_hp := player.health.current
	_check(SaveGame.save_run(run.capture()), "save written")
	_check(SaveGame.has_run(), "run save exists on disk")
	await _free_level(level)

	level = await _load_level()
	player = level.get_node("Player")
	# _load_level resets health for the test; the director had already applied the save.
	_check(not SaveGame.has_run(), "save is deleted when it loads")
	_check(player.global_position.distance_to(saved_pos) < 0.3, "position restored")
	_check(player.samples == 2, "samples restored (%d)" % player.samples)
	_check(player.dose.is_dosed and absf(player.dose.time_left - saved_time) < 0.2
		and player.dose.genome == saved_genome and player.dose.genome_revealed, "dose state restored")
	_check(not level.has_node("Cops/CopA") or level.get_node("Cops/CopA").is_queued_for_deletion(),
		"dead cop stays dead")
	_check(not level.has_node("Pickups/Sample1"), "collected sample doesn't respawn")
	var fx: ScreenFX = player.get_node("ScreenFX")
	_check(fx.saturation() > 1.0, "resumed mid-dose in colour")
	await _free_level(level)

	# A fresh start (no save) is a fresh run.
	level = await _load_level()
	player = level.get_node("Player")
	_check(player.samples == 0 and level.has_node("Pickups/Sample1"), "next start without a save is a new run")

	# --- Extraction ---------------------------------------------------------------------
	run = level.get_node("Run")
	var zone: ExtractionZone = level.get_node("Extraction")
	player.collect(Pickup.Kind.SAMPLE, 3)
	player.global_position = zone.global_position + Vector3(0, 0.1, 0)
	await _frames(1.5)
	_check(not run.ended, "extraction needs the full hold time")
	player.global_position = Vector3(0, 0, 40)
	await _frames(1.0)
	_check(zone.progress < 1.0, "leaving the zone drains progress (%.1f)" % zone.progress)
	player.global_position = zone.global_position + Vector3(0, 0.1, 0)
	await _frames(3.3)
	_check(run.ended and paused, "extracted: run over")
	var profile := SaveGame.load_profile()
	_check(int(profile["banked_samples"]) == 3, "samples banked (%s)" % profile["banked_samples"])
	_check(int(profile["extractions"]) == 1, "extraction counted")
	await _free_level(level)

	# --- Death wipes the run ------------------------------------------------------------
	level = await _load_level()
	player = level.get_node("Player")
	player.collect(Pickup.Kind.SAMPLE, 5)
	SaveGame.save_run((level.get_node("Run") as RunDirector).capture())  # A stale save, too.
	player.health.damage(1e9)
	await _frames(0.2)
	profile = SaveGame.load_profile()
	_check(player.is_dead, "player died")
	_check(int(profile["banked_samples"]) == 3, "death banks nothing (%s)" % profile["banked_samples"])
	_check(int(profile["deaths"]) == 1, "death counted (%s)" % profile["deaths"])
	_check(not SaveGame.has_run(), "death deletes any run save")
	var note: String = (player.get_node("HUD") as HUD)._death_note.text
	_check(note.begins_with("5 samples lost"), "death screen says what was lost ('%s')" % note)
	await _free_level(level)

	SaveGame.delete_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.profile_path()))
	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
