class_name HUD
extends CanvasLayer
## Combat HUD: crosshair/hit marker and ammo count (Pistol signals), health bar and
## damage flash (Health signals), and the death screen that restarts the level.

@export var pistol: Pistol
@export var health: Health
## Seconds after death before a click restarts, so a panicked click doesn't skip it.
@export var restart_delay: float = 1.0

var _restart_ready := false
var _flash_tween: Tween

@onready var _crosshair: Crosshair = $Crosshair
@onready var _ammo: Label = $Ammo
@onready var _health_bar: ProgressBar = $HealthBar
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _death_screen: Control = $DeathScreen
@onready var _prompt: Label = $DeathScreen/Center/Prompt


func _ready() -> void:
	_death_screen.hide()
	if pistol == null:
		push_warning("HUD has no pistol assigned")
	else:
		pistol.hit_confirmed.connect(_crosshair.show_hit)
		pistol.fired.connect(func(_ammo_left: int) -> void: _crosshair.kick())
		pistol.ammo_changed.connect(_on_ammo_changed)
		pistol.reload_started.connect(func(_t: float) -> void: _ammo.text = "RELOADING")
		_on_ammo_changed.call_deferred(pistol.magazine_size, pistol.magazine_size)
	if health == null:
		push_warning("HUD has no health assigned")
	else:
		health.changed.connect(_on_health_changed)
		health.died.connect(_on_died)
		_set_health_bar(health.max_health, health.max_health)


func _unhandled_input(event: InputEvent) -> void:
	if not _restart_ready:
		return
	if event.is_action_pressed("shoot") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		restart()


func restart() -> void:
	_restart_ready = false
	get_tree().reload_current_scene()


func _on_ammo_changed(ammo: int, magazine_size: int) -> void:
	_ammo.text = "%d / %d" % [ammo, magazine_size]
	_ammo.modulate = Color(1.0, 0.35, 0.3) if ammo * 4 <= magazine_size else Color.WHITE


func _on_health_changed(current: float, maximum: float) -> void:
	var lost := current < _health_bar.value
	_set_health_bar(current, maximum)
	if lost:
		_flash_damage()


func _set_health_bar(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_bar.modulate = Color(1.0, 0.3, 0.25) if current * 4.0 <= maximum else Color.WHITE


func _flash_damage() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_damage_flash.color.a = 0.35
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.35)


func _on_died() -> void:
	_crosshair.hide()
	_ammo.hide()
	_death_screen.show()
	_death_screen.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_death_screen, "modulate:a", 1.0, 0.5)
	tween.tween_interval(maxf(restart_delay - 0.5, 0.0))
	tween.tween_callback(func() -> void: _restart_ready = true)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.25)
