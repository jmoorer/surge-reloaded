class_name Player
extends CharacterBody3D
## Third-person player: WASD moves relative to the camera, mouse orbits the camera.

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var acceleration: float = 12.0
@export var turn_speed: float = 12.0
@export var mouse_sensitivity: float = 0.0025
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 30.0

@onready var _camera_yaw: Node3D = $CameraYaw
@onready var _camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var _spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var _model: Node3D = $Model
@onready var _anim: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_pitch.rotation.x = deg_to_rad(-15.0)
	_spring_arm.add_excluded_object(get_rid())
	if _anim:
		for anim_name: StringName in [&"idle", &"walk", &"sprint"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_camera_yaw.rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera_pitch.rotation.x = clampf(
			_camera_pitch.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg)
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		# Browsers only grant pointer lock from a user click.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Rotate input by camera yaw so W always means "away from camera".
	var direction := (_camera_yaw.global_basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	direction = direction.normalized()

	var sprinting := Input.is_action_pressed("sprint")
	var target_speed := sprint_speed if sprinting else walk_speed
	var target := direction * target_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * target_speed * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * target_speed * delta)

	move_and_slide()

	if direction != Vector3.ZERO:
		# Kenney models face +Z.
		var target_yaw := atan2(direction.x, direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, turn_speed * delta)
		_play("sprint" if sprinting else "walk")
	else:
		_play("idle")


func _play(anim_name: StringName) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15)
