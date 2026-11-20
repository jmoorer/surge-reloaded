class_name Pistol
extends Node3D
## Semi-auto hitscan pistol for a third-person camera.
## Shot model: ray from the camera finds what the crosshair is on, then a ray from the
## muzzle to that point decides the hit, so cover right in front of the gun still blocks.

signal fired(ammo: int)
signal hit_confirmed(damage: float, is_weak_spot: bool, killed: bool)
signal ammo_changed(ammo: int, magazine_size: int)
signal reload_started(duration: float)
signal reload_finished

const LAYER_WORLD := 1 << 0
const LAYER_HITBOX := 1 << 2

@export var damage: float = 25.0
@export var fire_rate: float = 6.0  ## Max shots per second.
@export var magazine_size: int = 12
@export var reload_time: float = 1.4
@export var max_range: float = 100.0
@export var trigger_buffer: float = 0.12  ## A click this early still fires when ready.
@export var tracer_color: Color = Color(1.0, 0.8, 0.45)
## Visual only: damage is hitscan and lands instantly; the bullet just sells the shot.
@export var bullet_mesh: Mesh
@export var bullet_visual_speed: float = 220.0
@export var bullet_visual_scale: float = 2.5

## Set by the owner (power/crash modifiers). 1 = base stats.
var damage_multiplier := 1.0
var fire_rate_multiplier := 1.0
var reload_speed_multiplier := 1.0

## Set by the owner: camera that defines the aim, and RIDs the shot must ignore.
var camera: Camera3D
var exclude: Array[RID] = []

var ammo: int
var is_reloading: bool:
	get:
		return _reload_left > 0.0

var _cooldown := 0.0
var _buffered := 0.0
var _reload_left := 0.0

@onready var _muzzle: Marker3D = $Muzzle
@onready var _flash: OmniLight3D = $Muzzle/Flash


func _ready() -> void:
	ammo = magazine_size
	_flash.light_energy = 0.0


func pull_trigger() -> void:
	_buffered = trigger_buffer


func reload() -> void:
	if is_reloading or ammo == magazine_size:
		return
	_reload_left = reload_time / reload_speed_multiplier
	_buffered = 0.0
	reload_started.emit(_reload_left)


func _physics_process(delta: float) -> void:
	tick(delta)


## Advances timers and fires a buffered shot. Split out so tests can drive it.
func tick(delta: float) -> void:
	if is_reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			ammo = magazine_size
			ammo_changed.emit(ammo, magazine_size)
			reload_finished.emit()

	# Keep the remainder while the trigger is being worked so the rate holds at any FPS,
	# but never bank shots across an idle gap.
	_cooldown -= delta
	if _buffered <= 0.0:
		_cooldown = maxf(_cooldown, 0.0)
	_buffered = maxf(_buffered - delta, 0.0)

	if _buffered > 0.0 and _cooldown <= 0.0 and not is_reloading:
		_buffered = 0.0
		if ammo <= 0:
			reload()
			return
		_cooldown += 1.0 / (fire_rate * fire_rate_multiplier)
		fire_at(_find_aim_point())


## Fires one round from the muzzle toward a world point. Returns the ray result ({} on miss).
func fire_at(aim_point: Vector3) -> Dictionary:
	ammo -= 1
	var origin := _muzzle.global_position
	var dir := (aim_point - origin).normalized()
	if dir == Vector3.ZERO:
		dir = -_muzzle.global_basis.z
	var end := origin + dir * max_range

	var query := PhysicsRayQueryParameters3D.create(origin, end, LAYER_WORLD | LAYER_HITBOX, exclude)
	query.hit_from_inside = true  # Muzzle poking into a wall must not shoot through it.
	var result := get_world_3d().direct_space_state.intersect_ray(query)

	var hit_point := end
	if not result.is_empty():
		hit_point = result.position
		var hitbox := result.collider as Hitbox
		if hitbox:
			var dealt := hitbox.receive_hit(damage * damage_multiplier, hit_point)
			if dealt > 0.0:
				var killed := hitbox.health != null and hitbox.health.is_dead
				hit_confirmed.emit(dealt, hitbox.is_weak_spot, killed)
		_spawn_impact(hit_point, hitbox != null)

	_spawn_tracer(origin, hit_point)
	_muzzle_flash()
	fired.emit(ammo)
	ammo_changed.emit(ammo, magazine_size)
	return result


func _find_aim_point() -> Vector3:
	if camera == null:
		return _muzzle.global_position - _muzzle.global_basis.z * max_range
	var cam_pos := camera.global_position
	var forward := -camera.global_basis.z
	# Start the aim ray level with the gun so nothing between camera and player counts.
	var skip := maxf((global_position - cam_pos).dot(forward), 0.0)
	var start := cam_pos + forward * skip
	var end := cam_pos + forward * max_range
	var query := PhysicsRayQueryParameters3D.create(start, end, LAYER_WORLD | LAYER_HITBOX, exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.position if not result.is_empty() else end


func _muzzle_flash() -> void:
	_flash.light_energy = 6.0
	var tween := create_tween()
	tween.tween_property(_flash, "light_energy", 0.0, 0.06)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = tracer_color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.015, length)
	mesh.material = mat
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.top_level = true
	add_child(tracer)
	tracer.global_position = from.lerp(to, 0.5)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD
	tracer.look_at(to, up)
	mat.albedo_color.a = 0.35
	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.07)
	tween.tween_callback(tracer.queue_free)

	if bullet_mesh:
		var bullet := MeshInstance3D.new()
		bullet.mesh = bullet_mesh
		bullet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bullet.top_level = true
		add_child(bullet)
		bullet.global_position = from
		bullet.look_at(to, up)  # Bullet mesh points down -Z, like look_at.
		bullet.scale = Vector3.ONE * bullet_visual_scale
		var fly := bullet.create_tween()
		fly.tween_property(bullet, "global_position", to, length / bullet_visual_speed)
		fly.tween_callback(bullet.queue_free)


func _spawn_impact(at: Vector3, on_target: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.2) if on_target else Color(1.0, 0.85, 0.6)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = mat
	var spark := MeshInstance3D.new()
	spark.mesh = mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark.top_level = true
	add_child(spark)
	spark.global_position = at
	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3.ZERO, 0.15).from(Vector3.ONE * 1.6)
	tween.tween_callback(spark.queue_free)
