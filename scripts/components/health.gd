class_name Health
extends Node
## Hit points for anything that can be damaged. Hitboxes forward damage here.

signal changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var current: float
var is_dead: bool:
	get:
		return current <= 0.0


func _ready() -> void:
	current = max_health


func damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	changed.emit(current, max_health)
	if is_dead:
		died.emit()


func reset() -> void:
	current = max_health
	changed.emit(current, max_health)
