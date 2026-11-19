class_name TargetDummy
extends Node3D
## Shootable practice target. Flashes and shows damage numbers on hit,
## topples when Health runs out, then stands back up.

@export var respawn_delay: float = 2.5
@export var flash_color: Color = Color(1.0, 1.0, 1.0)
@export var weak_spot_flash_color: Color = Color(1.0, 0.45, 0.15)

var _flash_mat: StandardMaterial3D
var _flash_tween: Tween
var _wobble_tween: Tween

@onready var health: Health = $Health
@onready var _pivot: Node3D = $Pivot
@onready var _hitboxes: Array[Hitbox] = [$Pivot/Body, $Pivot/Head]


func _ready() -> void:
	# Per-instance material so one dummy's flash doesn't light up every dummy.
	var body_mesh: MeshInstance3D = $Pivot/Body/Mesh
	_flash_mat = (body_mesh.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_flash_mat.emission_enabled = true
	_flash_mat.emission_energy_multiplier = 0.0
	for mesh: MeshInstance3D in [$Pivot/Body/Mesh, $Pivot/Head/Mesh]:
		mesh.material_override = _flash_mat
	for hitbox in _hitboxes:
		hitbox.hit.connect(_on_hit)
	health.died.connect(_on_died)


func _on_hit(damage: float, hit_position: Vector3, is_weak_spot: bool) -> void:
	_flash(weak_spot_flash_color if is_weak_spot else flash_color)
	_spawn_damage_number(damage, hit_position, is_weak_spot)
	if not health.is_dead:
		_wobble()


func _flash(color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_mat.emission = color
	_flash_mat.emission_energy_multiplier = 3.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_mat, "emission_energy_multiplier", 0.0, 0.12)


func _wobble() -> void:
	if _wobble_tween:
		_wobble_tween.kill()
	_pivot.rotation = Vector3.ZERO
	_wobble_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_wobble_tween.tween_property(_pivot, "rotation:x", deg_to_rad(-9.0), 0.05)
	_wobble_tween.tween_property(_pivot, "rotation:x", deg_to_rad(4.0), 0.12)
	_wobble_tween.tween_property(_pivot, "rotation:x", 0.0, 0.15)


func _on_died() -> void:
	_set_hitboxes_enabled(false)
	if _wobble_tween:
		_wobble_tween.kill()
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(_pivot, "rotation:x", deg_to_rad(-88.0), 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_wobble_tween.tween_interval(respawn_delay)
	_wobble_tween.tween_property(_pivot, "rotation:x", 0.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wobble_tween.tween_callback(_respawn)


func _respawn() -> void:
	health.reset()
	_set_hitboxes_enabled(true)


func _set_hitboxes_enabled(enabled: bool) -> void:
	for hitbox in _hitboxes:
		hitbox.set_deferred("collision_layer", Pistol.LAYER_HITBOX if enabled else 0)


func _spawn_damage_number(damage: float, at: Vector3, is_weak_spot: bool) -> void:
	var label := Label3D.new()
	label.text = str(roundi(damage))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0015
	label.font_size = 28 if is_weak_spot else 22
	label.outline_size = 8
	label.modulate = weak_spot_flash_color if is_weak_spot else Color(1, 1, 1)
	label.top_level = true
	add_child(label)
	label.global_position = at + Vector3(randf_range(-0.15, 0.15), 0.15, 0.0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", label.global_position.y + 0.7, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
