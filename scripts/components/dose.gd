class_name Dose
extends Node
## The Surge cycle for one run: pills in the pocket, the 75 s power window, the genome
## (which power this run gives, rolled at run start, revealed by the first pill).
## Owns the PlayerModifiers; the player applies whatever this emits.

signal pills_changed(count: int)
signal dose_started(power: StringName, dose_number: int, revealed_now: bool)
signal dose_ended(dose_number: int)
signal modifiers_changed(mods: PlayerModifiers)

@export var duration: float = 75.0
@export var starting_pills: int = 0
## 0 = random genome each run.
@export var rng_seed: int = 0

var genome: StringName = &""
var genome_revealed := false
var pills := 0
var doses_taken := 0
var time_left := 0.0
var modifiers := PlayerModifiers.new()
var is_dosed: bool:
	get:
		return time_left > 0.0

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
	if not is_dosed:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_on_dose_ended()
		dose_ended.emit(doses_taken)
		_recompute()


## Hooks for the crash (M4).
func _on_dose_started() -> void:
	pass


func _on_dose_ended() -> void:
	pass


func _recompute() -> void:
	var m := PlayerModifiers.new()
	if is_dosed:
		Powers.modify(genome, m)
	_modify_extra(m)
	modifiers = m
	modifiers_changed.emit(m)


func _modify_extra(_m: PlayerModifiers) -> void:
	pass
