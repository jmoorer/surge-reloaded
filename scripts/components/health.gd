class_name Health
extends Node
## Hit points for anything that can be damaged. Hitboxes forward damage here.

signal changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
## Incoming damage is scaled by this (powers lower it).
var damage_taken_multiplier := 1.0
## Health regained per second while alive (powers raise it).
var regen_per_second := 0.0
## Fraction of max_health currently allowed (below 1 while crashing).
var cap_fraction := 1.0:
	set(value):
		cap_fraction = clampf(value, 0.0, 1.0)
		if current > cap:
			current = cap
			changed.emit(current, max_health)
var cap: float:
	get:
		return max_health * cap_fraction

var current: float
var is_dead: bool:
	get:
		return current <= 0.0


func _ready() -> void:
	current = max_health


func damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = maxf(current - amount * damage_taken_multiplier, 0.0)
	changed.emit(current, max_health)
	if is_dead:
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0 or current >= cap:
		return
	current = minf(current + amount, cap)
	changed.emit(current, max_health)


func _physics_process(delta: float) -> void:
	if regen_per_second > 0.0:
		heal(regen_per_second * delta)


func reset() -> void:
	current = cap
	changed.emit(current, max_health)
