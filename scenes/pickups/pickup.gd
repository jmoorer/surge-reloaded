class_name Pickup
extends Area3D
## Walk-over pickup. Bobs and spins; hands itself to the player on touch.

enum Kind { PILL, SAMPLE }

const SCENES := {
	Kind.PILL: "res://scenes/pickups/pill.tscn",
	Kind.SAMPLE: "res://scenes/pickups/sample.tscn",
}

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


func to_dict() -> Dictionary:
	return {"kind": kind, "amount": amount, "position": SaveGame.vec3(global_position)}


static func from_dict(d: Dictionary) -> Pickup:
	var scene: PackedScene = load(SCENES.get(int(d.get("kind", 0)), SCENES[Kind.PILL]))
	var p: Pickup = scene.instantiate()
	p.amount = int(d.get("amount", 1))
	p.position = SaveGame.to_vec3(d.get("position"))
	return p
