class_name Hitbox
extends StaticBody3D
## A shootable body part. Lives on the "hitbox" physics layer (3) so hitscan rays
## hit it without needing collide_with_areas. Scales damage, then forwards it to Health.

signal hit(damage: float, hit_position: Vector3, is_weak_spot: bool)

@export var health: Health
@export var damage_multiplier: float = 1.0
@export var is_weak_spot: bool = false


## Returns the damage actually dealt (0 if already dead).
func receive_hit(base_damage: float, hit_position: Vector3) -> float:
	if health and health.is_dead:
		return 0.0
	var dealt := base_damage * damage_multiplier
	if health:
		health.damage(dealt)
	hit.emit(dealt, hit_position, is_weak_spot)
	return dealt
