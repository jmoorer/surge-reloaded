class_name DirtyCop
extends CharacterBody3D
## Dirty cop: patrols, spots the player, shoots back, searches when it loses them.
##
## Layers: perception (_sense, 10 Hz) writes facts -> the FSM (_tick_*) picks a move and
## facing -> movement/animation. States never raycast; only _sense does.
## Fairness: a reaction delay before the first shot, a deliberate first miss, and spread
## that tightens the longer the cop keeps the player in sight.

signal state_changed(from: State, to: State)
signal died

enum State { PATROL, ALERT, COMBAT, SEARCH, DEAD }

const EYE_HEIGHT := 1.6
## Points on the player the sight ray tries (head, chest); any clear one counts.
const SIGHT_POINTS: Array[float] = [1.6, 1.1]
const AIM_HEIGHT := 1.1

## Marker3D children are visited in order, looping. Empty/unset: stand guard.
@export var patrol_path: Node3D
@export var walk_speed: float = 1.6
@export var run_speed: float = 3.2
@export var acceleration: float = 8.0
@export var turn_speed: float = 6.0
@export var waypoint_wait: float = 1.5

@export_group("Perception")
@export var sight_range: float = 20.0
## Once engaged the cop keeps tracking out to this range (hysteresis, no flicker at the edge).
@export var sight_range_engaged: float = 28.0
@export var view_angle_deg: float = 110.0
@export var sense_rate: float = 10.0

@export_group("Combat")
## Seconds between spotting and the first shot, so the player can react.
@export var reaction_time: float = 0.5
@export var shot_interval_min: float = 0.55
@export var shot_interval_max: float = 0.9
## First shot of an engagement lands this far (m) to the side of the player.
@export var first_shot_miss_offset: float = 0.8
@export var spread_start_deg: float = 5.0
@export var spread_min_deg: float = 0.8
## Seconds of continuous sight to go from start to min spread.
@export var spread_settle_time: float = 3.0
## Seconds out of sight before giving up on combat and going to search.
@export var lose_sight_grace: float = 1.5
## Seconds spent looking around at the last known position.
@export var search_time: float = 4.0
## 0 = random each run.
@export var rng_seed: int = 0

var state: State = State.PATROL
var can_see_target := false
var last_known_position := Vector3.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()
var _target: Player
var _state_time := 0.0
var _sense_left := 0.0
var _sight_time := 0.0  # Continuous seconds the target has been visible.
var _unseen_time := 0.0
var _shot_left := 0.0
var _missed_first := false  # Reset each engagement that starts from patrol.
var _waypoint := 0
var _wait_left := 0.0
var _arrived := false
var _stuck_time := 0.0
var _stuck_best := INF
var _own_rids: Array[RID] = []

@onready var health: Health = $Health
@onready var _hitboxes: Array[Hitbox] = [$Hitboxes/Body, $Hitboxes/Head]
@onready var _model: Node3D = $Model
@onready var _pistol: Pistol = %Pistol
@onready var _label: Label3D = $StateLabel
@onready var _nav: NavigationAgent3D = $NavAgent
@onready var _anim: AnimationPlayer = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	_own_rids = [get_rid()]
	for hitbox in _hitboxes:
		_own_rids.append(hitbox.get_rid())
		hitbox.hit.connect(_on_hit)
	_pistol.exclude = _own_rids
	health.died.connect(_die)
	_label.visible = OS.is_debug_build()
	_tint_model()
	PistolClips.install(_anim)
	add_to_group(&"enemies")
	_sense_left = _rng.randf() / sense_rate  # Stagger cops so they don't all raycast on one tick.
	_change_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_sense_left -= delta
	if _sense_left <= 0.0:
		_sense_left += 1.0 / sense_rate
		_sense()
	_sight_time = _sight_time + delta if can_see_target else 0.0
	_unseen_time = 0.0 if can_see_target else _unseen_time + delta
	_state_time += delta

	var move_to: Variant = null  # Vector3 to walk toward, or null to stand.
	var speed := walk_speed
	var face: Variant = null  # Vector3 point to turn toward.
	match state:
		State.PATROL:
			move_to = _tick_patrol(delta)
			face = _steer_point(move_to) if move_to != null else null
		State.ALERT:
			face = last_known_position
			if _state_time >= reaction_time:
				_change_state(State.COMBAT if can_see_target else State.SEARCH)
		State.COMBAT:
			face = last_known_position
			_tick_combat(delta)
		State.SEARCH:
			move_to = _tick_search(delta)
			speed = run_speed
			face = _steer_point(move_to) if move_to != null else null

	_move(move_to, speed, delta)
	if face != null:
		_turn_toward(face, delta)
	elif state == State.SEARCH:
		rotate_y(1.2 * delta)  # Look around.
	_animate()


# --- Perception -------------------------------------------------------------------------

func _sense() -> void:
	_target = get_tree().get_first_node_in_group(&"player") as Player
	can_see_target = _target != null and not _target.is_dead and _sees(_target)
	if can_see_target:
		last_known_position = _target.global_position


func _sees(target: Node3D) -> bool:
	var engaged := state == State.ALERT or state == State.COMBAT or state == State.SEARCH
	var to := target.global_position - global_position
	to.y = 0.0
	var max_range := sight_range_engaged if engaged else sight_range
	if to.length_squared() > max_range * max_range:
		return false
	# Engaged cops track the player all round; relaxed ones only see their cone.
	if not engaged and to.length_squared() > 0.01:
		var forward := global_basis.z  # X Bot faces +Z.
		forward.y = 0.0
		if forward.normalized().dot(to.normalized()) < cos(deg_to_rad(view_angle_deg * 0.5)):
			return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var space := get_world_3d().direct_space_state
	for height in SIGHT_POINTS:
		var query := PhysicsRayQueryParameters3D.create(
			eye, target.global_position + Vector3.UP * height, Pistol.LAYER_WORLD, _own_rids)
		if space.intersect_ray(query).is_empty():
			return true
	return false


## Someone tipped this cop off: go check the spot (does nothing if already fighting).
func alert_to(point: Vector3) -> void:
	if state == State.PATROL or state == State.SEARCH:
		last_known_position = point
		_change_state(State.SEARCH)


func _on_hit(_damage: float, _hit_position: Vector3, _is_weak_spot: bool) -> void:
	# Getting shot gives away roughly where the shooter is.
	if state == State.PATROL or state == State.SEARCH:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		if player:
			last_known_position = player.global_position
		_change_state(State.ALERT)


# --- States -----------------------------------------------------------------------------

func _change_state(to: State) -> void:
	var from := state
	state = to
	_state_time = 0.0
	match to:
		State.PATROL:
			_missed_first = false
			_wait_left = 0.0
			_reset_stuck()
		State.COMBAT:
			_shot_left = 0.0  # Reaction delay already paid in ALERT.
		State.SEARCH:
			_arrived = false
			_reset_stuck()
	_label.text = State.keys()[to]
	if from != to:
		state_changed.emit(from, to)


func _tick_patrol(delta: float) -> Variant:
	if can_see_target:
		_change_state(State.ALERT)
		return null
	var points := _patrol_points()
	if points.is_empty():
		return null
	if _wait_left > 0.0:
		_wait_left -= delta
		return null
	var goal: Vector3 = points[_waypoint % points.size()]
	if _reached(goal, walk_speed, delta) or _is_stuck(goal, delta):
		_waypoint = (_waypoint + 1) % points.size()
		_wait_left = waypoint_wait
		_reset_stuck()
		return null
	return goal


func _tick_combat(delta: float) -> void:
	if _target == null or _target.is_dead:
		_change_state(State.PATROL)
		return
	if not can_see_target:
		if _unseen_time >= lose_sight_grace:
			_change_state(State.SEARCH)
		return
	_shot_left -= delta
	if _shot_left <= 0.0:
		_shot_left = _rng.randf_range(shot_interval_min, shot_interval_max)
		_shoot()


func _tick_search(delta: float) -> Variant:
	if can_see_target:
		_change_state(State.ALERT)
		return null
	if not _arrived:
		if _reached(last_known_position, run_speed, delta) or _is_stuck(last_known_position, delta):
			_arrived = true
			_state_time = 0.0
		else:
			return last_known_position
	if _state_time >= search_time:
		_change_state(State.PATROL)
	return null


func _shoot() -> void:
	if _pistol.is_reloading:
		return
	if _pistol.ammo <= 0:
		_pistol.reload()
		return
	var aim := _target.global_position + Vector3.UP * AIM_HEIGHT
	var muzzle := _pistol.global_position
	var dir := (aim - muzzle).normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var up := right.cross(dir).normalized()
	if not _missed_first:
		_missed_first = true
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		aim += right * first_shot_miss_offset * side + up * 0.3
	else:
		var settle := clampf(_sight_time / spread_settle_time, 0.0, 1.0)
		var spread := deg_to_rad(lerpf(spread_start_deg, spread_min_deg, settle))
		var radius := tan(spread) * muzzle.distance_to(aim) * sqrt(_rng.randf())
		var angle := _rng.randf() * TAU
		aim += (right * cos(angle) + up * sin(angle)) * radius
	_pistol.fire_at(aim)


func _die() -> void:
	_change_state(State.DEAD)
	collision_layer = 0
	for hitbox in _hitboxes:
		hitbox.set_deferred("collision_layer", 0)
	if _anim:
		_anim.pause()
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", deg_to_rad(-85.0), 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	died.emit()


# --- Movement ---------------------------------------------------------------------------

func _move(goal: Variant, speed: float, delta: float) -> void:
	var target_velocity := Vector3.ZERO
	if goal != null:
		var to: Vector3 = _steer_point(goal) - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			target_velocity = to.normalized() * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * speed * delta)
	move_and_slide()


## Next corner on the navmesh path to goal; goal itself when the level has no navmesh.
func _steer_point(goal: Vector3) -> Vector3:
	var map := _nav.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0 \
			or NavigationServer3D.map_get_regions(map).is_empty():
		return goal
	if _nav.target_position.distance_squared_to(goal) > 0.25:
		_nav.target_position = goal
	if _nav.is_navigation_finished():
		return goal
	var next := _nav.get_next_path_position()
	if Vector2(next.x - global_position.x, next.z - global_position.z).length_squared() < 0.0001:
		return goal
	return next


func _turn_toward(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), turn_speed * delta)


func _reached(goal: Vector3, speed: float, delta: float) -> bool:
	var flat := Vector2(goal.x - global_position.x, goal.z - global_position.z)
	return flat.length() <= maxf(0.4, speed * delta)


## True when no progress toward goal for 2 s (blocked, or goal off the navmesh).
func _is_stuck(goal: Vector3, delta: float) -> bool:
	var dist := Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
	if dist < _stuck_best - 0.25:
		_stuck_best = dist
		_stuck_time = 0.0
		return false
	_stuck_time += delta
	return _stuck_time >= 2.0


func _reset_stuck() -> void:
	_stuck_best = INF
	_stuck_time = 0.0


func _patrol_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if patrol_path:
		for child in patrol_path.get_children():
			if child is Node3D:
				points.append((child as Node3D).global_position)
	return points


func _animate() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.3:
		PistolClips.play(_anim, &"idle")
	else:
		PistolClips.play(_anim, &"walk", speed)


func _tint_model() -> void:
	# Greybox read: navy uniform so the cop never reads as the player.
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.7
		mat.albedo_color = Color(0.1, 0.1, 0.12) if "Joint" in mesh.name else Color(0.12, 0.17, 0.32)
		mesh.material_override = mat
