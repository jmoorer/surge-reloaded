class_name Dose
extends Node
## The Surge cycle for one run: pills in the pocket, the 75 s power window, the genome
## (which power this run gives, rolled at run start, revealed by the first pill).
## Owns the PlayerModifiers; the player applies whatever this emits.

signal pills_changed(count: int)
signal dose_started(power: StringName, dose_number: int, revealed_now: bool)
signal dose_ended(dose_number: int)
signal modifiers_changed(mods: PlayerModifiers)
signal crash_started(severity: int, duration: float)
signal crash_ended

@export var duration: float = 75.0
@export var starting_pills: int = 0
@export_group("Crash")
## Crash length after the first dose; each later dose adds crash_extra_per_dose.
@export var crash_base_time: float = 30.0
@export var crash_extra_per_dose: float = 15.0
## Debuffs ease off over this last fraction of the crash.
@export var crash_recovery_fraction: float = 0.3
## Cops within this range hear about you when you crash.
@export var crash_alert_radius: float = 40.0

## 0 = random genome each run.
@export var rng_seed: int = 0

var genome: StringName = &""
var genome_revealed := false
var pills := 0
var doses_taken := 0
var time_left := 0.0
var modifiers := PlayerModifiers.new()
var crash_left := 0.0
var crash_duration := 0.0
var is_dosed: bool:
	get:
		return time_left > 0.0
var is_crashing: bool:
	get:
		return crash_left > 0.0
## Crash severity is the number of doses taken this run (1 = first crash).
var severity: int:
	get:
		return doses_taken

var _crash_step := 0.0  # Recompute the easing debuffs a few times a second, not every tick.

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	pills = starting_pills
	if genome == &"":
		genome = Powers.ALL[_rng.randi_range(0, Powers.ALL.size() - 1)]
	_recompute.call_deferred()


func add_pills(count: int = 1) -> void:
	pills += count
	pills_changed.emit(pills)


## Swallow a pill. Fails with no pills or while already dosed (no stacking).
func take() -> bool:
	if pills <= 0 or is_dosed:
		return false
	pills -= 1
	doses_taken += 1
	time_left = duration
	var revealed_now := not genome_revealed
	genome_revealed = true
	pills_changed.emit(pills)
	_on_dose_started()
	dose_started.emit(genome, doses_taken, revealed_now)
	_recompute()
	return true


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_dosed:
		time_left = maxf(time_left - delta, 0.0)
		if time_left <= 0.0:
			dose_ended.emit(doses_taken)
			_start_crash()
		return
	if is_crashing:
		crash_left = maxf(crash_left - delta, 0.0)
		_crash_step -= delta
		if crash_left <= 0.0:
			crash_ended.emit()
			_recompute()
		elif _crash_step <= 0.0:
			_crash_step = 0.25
			_recompute()


## A pill cures a crash on the spot (and makes the next one worse).
func _on_dose_started() -> void:
	if is_crashing:
		crash_left = 0.0
		crash_ended.emit()


func _start_crash() -> void:
	crash_duration = crash_base_time + crash_extra_per_dose * (severity - 1)
	crash_left = crash_duration
	_crash_step = 0.0
	crash_started.emit(severity, crash_duration)
	_recompute()


## 1 while the crash is at full strength, easing to 0 over the recovery fraction.
func crash_strength() -> float:
	if not is_crashing:
		return 0.0
	var recovery := crash_duration * crash_recovery_fraction
	return clampf(crash_left / recovery, 0.0, 1.0) if recovery > 0.0 else 1.0


func _recompute() -> void:
	var m := PlayerModifiers.new()
	if is_dosed:
		Powers.modify(genome, m)
	_modify_extra(m)
	modifiers = m
	modifiers_changed.emit(m)


func _modify_extra(m: PlayerModifiers) -> void:
	var k := crash_strength()
	if k <= 0.0:
		return
	var s := float(severity - 1)  # 0 on the first crash.
	m.sway_deg += minf(1.4 + 0.9 * s, 5.0) * k
	m.look_sensitivity *= lerpf(1.0, 1.0 / (1.3 + 0.25 * s), k)
	m.blur = maxf(m.blur, minf(0.35 + 0.2 * s, 0.95) * k)
	m.max_health_penalty = maxf(m.max_health_penalty, minf(0.25 + 0.1 * s, 0.6) * k)
	m.speed *= lerpf(1.0, maxf(0.85 - 0.05 * s, 0.65), k)
	m.reload_speed *= lerpf(1.0, 0.75, k)
