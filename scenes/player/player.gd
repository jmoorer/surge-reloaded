class_name Player
extends CharacterBody3D
## Third-person player: WASD moves relative to the camera, mouse orbits the camera,
## left click fires the pistol, R reloads.

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var acceleration: float = 12.0
@export var turn_speed: float = 12.0
@export var mouse_sensitivity: float = 0.0025
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 30.0

@export_group("Combat")
## Seconds the character keeps facing the aim direction after a shot.
@export var combat_stance_time: float = 1.5
@export var recoil_kick_deg: float = 1.6
@export var recoil_yaw_jitter_deg: float = 0.4
@export var recoil_recovery: float = 14.0

@onready var _camera_yaw: Node3D = $CameraYaw
@onready var _camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var _spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var _camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var _model: Node3D = $Model
@onready var _pistol: Pistol = %Pistol
@onready var _anim: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

const ANIM_DIR := "res://assets/third_party/mixamo/animations/"
## Mixamo clips (X Bot skeleton), and the ground speed each was authored at so
## playback can be scaled to match movement and keep feet from sliding.
const CLIPS := {
	&"idle": ["pistol-idle__e4528faaee276d7f1ce4_8d5977af883f_a74ddc14ae2e.fbx", 0.0],
	&"walk": ["pistol-walk__83fc03c0de7becb71fe8_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.6],
	&"walk_back": ["pistol-walk-backward__e6217454337d48ae5f67_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.4],
	&"strafe_left": ["pistol-strafe__c9c514be526b3ae5f592_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.5],
	&"strafe_right": ["pistol-strafe__09ce081abb7d419ad156_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.5],
	&"run": ["pistol-run__2d25c98bfe2ba8a5b2c5_8d5977af883f_a74ddc14ae2e_inplace.fbx", 4.5],
}

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _combat_left := 0.0
# Recoil lives on the camera as an offset that decays, never written into the look angle.
var _recoil := Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_pitch.rotation.x = deg_to_rad(-15.0)
	_spring_arm.add_excluded_object(get_rid())
	_pistol.camera = _camera
	_pistol.exclude = [get_rid()]
	_pistol.fired.connect(_on_pistol_fired)
	_load_clips()
	_play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		var motion := event as InputEventMouseMotion
		_camera_yaw.rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera_pitch.rotation.x = clampf(
			_camera_pitch.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg)
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not captured:
		# Browsers only grant pointer lock from a user click. This click doesn't shoot.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("shoot"):
		_shoot()
	elif event.is_action_pressed("reload"):
		_pistol.reload()


func _shoot() -> void:
	# Snap to the aim so the gun visibly points where the crosshair is.
	_combat_left = combat_stance_time
	_model.rotation.y = _aim_yaw()
	_pistol.pull_trigger()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	_combat_left = maxf(_combat_left - delta, 0.0)
	var in_combat := _combat_left > 0.0

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Rotate input by camera yaw so W always means "away from camera".
	var direction := (_camera_yaw.global_basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	direction = direction.normalized()

	var sprinting := Input.is_action_pressed("sprint") and not in_combat
	var target_speed := sprint_speed if sprinting else walk_speed
	var target := direction * target_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * target_speed * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * target_speed * delta)

	move_and_slide()

	if in_combat:
		# Strafe while aiming: keep facing where the camera looks.
		_model.rotation.y = lerp_angle(_model.rotation.y, _aim_yaw(), turn_speed * 2.0 * delta)
	elif direction != Vector3.ZERO:
		# Mixamo models face +Z.
		var target_yaw := atan2(direction.x, direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, turn_speed * delta)
	_update_animation(in_combat, sprinting)


func _process(delta: float) -> void:
	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-recoil_recovery * delta))
	# On the arm, not the Camera3D: SpringArm3D resets its child's transform every tick.
	_spring_arm.rotation = Vector3(_recoil.x, _recoil.y, 0.0)


func _on_pistol_fired(_ammo: int) -> void:
	_recoil.x += deg_to_rad(recoil_kick_deg)
	_recoil.y += deg_to_rad(randf_range(-recoil_yaw_jitter_deg, recoil_yaw_jitter_deg))


func _aim_yaw() -> float:
	# Camera looks down its -Z; the model faces +Z, hence the half turn.
	return _camera_yaw.rotation.y + PI


func _update_animation(in_combat: bool, sprinting: bool) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < 0.3:
		_play(&"idle")
		return
	var clip := &"walk"
	if sprinting:
		clip = &"run"
	elif in_combat:
		# Pick the clip from movement relative to where the body faces (+Z fwd, +X = its left).
		var local := _model.global_basis.inverse() * flat
		if absf(local.z) >= absf(local.x):
			clip = &"walk" if local.z > 0.0 else &"walk_back"
		else:
			clip = &"strafe_left" if local.x > 0.0 else &"strafe_right"
	_play(clip, speed)


func _play(clip: StringName, ground_speed: float = 0.0) -> void:
	if _anim == null:
		return
	var key := StringName("pistol/" + clip)
	if not _anim.has_animation(key):
		return
	var authored: float = CLIPS[clip][1]
	_anim.speed_scale = clampf(ground_speed / authored, 0.6, 2.0) if authored > 0.0 else 1.0
	if _anim.current_animation != key:
		_anim.play(key, 0.2)


func _load_clips() -> void:
	if _anim == null:
		return
	var lib := AnimationLibrary.new()
	for clip: StringName in CLIPS:
		var path: String = ANIM_DIR + CLIPS[clip][0]
		if not ResourceLoader.exists(path):
			push_warning("Missing animation clip: " + path)
			continue
		var scene: Node = (load(path) as PackedScene).instantiate()
		var src: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		var anim: Animation = src.get_animation(src.get_animation_list()[0]).duplicate()
		anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(clip, anim)
		scene.free()
	_anim.add_animation_library(&"pistol", lib)
