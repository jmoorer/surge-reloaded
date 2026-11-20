class_name ExtractionZone
extends Area3D
## The way out. Stand inside for hold_time seconds (alive) to extract.
## Leaving drains the progress, so getting chased off it costs you.

signal extracted

@export var hold_time: float = 3.0

var progress := 0.0
var is_done := false
var _player: Player


func _ready() -> void:
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			_player = b)
	body_exited.connect(func(b: Node3D) -> void:
		if b == _player:
			_player = null)


func is_player_inside() -> bool:
	return _player != null and not _player.is_dead


func _physics_process(delta: float) -> void:
	if is_done:
		return
	if is_player_inside():
		progress += delta
		if progress >= hold_time:
			progress = hold_time
			is_done = true
			extracted.emit()
	else:
		progress = maxf(progress - delta * 2.0, 0.0)
