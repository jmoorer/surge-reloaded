class_name Pickup
extends Area3D
## Walk-over pickup. Bobs and spins; hands itself to the player on touch.

enum Kind { PILL, SAMPLE }

@export var kind: Kind = Kind.PILL
@export var amount: int = 1

var _t := 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(&"pickups")
	body_entered.connect(_on_body_entered)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_visual.position.y = 0.6 + sin(_t * 2.5) * 0.08
	_visual.rotation.y += delta * 1.8


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.is_dead:
		return
	if player.collect(kind, amount):
		queue_free()
