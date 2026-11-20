class_name HUD
extends CanvasLayer
## Combat HUD: crosshair/hit marker and ammo count (Pistol signals), health bar and
## damage flash (Health signals), and the death screen that restarts the level.

@export var pistol: Pistol
@export var health: Health
@export var dose: Dose
## Seconds after death before a click restarts, so a panicked click doesn't skip it.
@export var restart_delay: float = 1.0

var _restart_ready := false
var _flash_tween: Tween
var _pills: Label
var _dose_bar: ProgressBar
var _dose_label: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_desc: Label
var _banner_tween: Tween

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
	_build_dose_ui()
	if dose:
		dose.pills_changed.connect(_on_pills_changed)
		dose.dose_started.connect(_on_dose_started)
		dose.dose_ended.connect(func(_n: int) -> void: _dose_bar.hide())
		_on_pills_changed.call_deferred(dose.pills)
	if health == null:
		push_warning("HUD has no health assigned")
	else:
		health.changed.connect(_on_health_changed)
		health.died.connect(_on_died)
		_set_health_bar(health.max_health, health.max_health)


func _process(_delta: float) -> void:
	if dose and dose.is_dosed:
		_dose_bar.value = dose.time_left
		_dose_label.text = "%s  %d" % [Powers.display_name(dose.genome), ceili(dose.time_left)]


## Shows a big centred message that fades out (genome reveal, extraction, etc.).
func show_banner(title: String, desc: String, color: Color, hold: float = 2.5) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_desc.text = desc
	if _banner_tween:
		_banner_tween.kill()
	_banner.show()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)
	_banner_tween.tween_callback(_banner.hide)


func _on_pills_changed(count: int) -> void:
	_pills.text = "PILLS  %d   [Q]" % count if count > 0 else "PILLS  0"
	_pills.modulate = Color(0.6, 0.9, 1.0) if count > 0 else Color(1, 1, 1, 0.5)


func _on_dose_started(power: StringName, _n: int, revealed_now: bool) -> void:
	var c := Powers.color(power)
	_dose_bar.max_value = dose.duration
	_dose_bar.value = dose.time_left
	(_dose_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c
	_dose_bar.show()
	if revealed_now:
		show_banner("GENOME: " + Powers.display_name(power), Powers.INFO[power]["desc"], c, 3.0)
	else:
		show_banner("DOSED", Powers.display_name(power), c, 0.8)


func _build_dose_ui() -> void:
	_pills = _label(22)
	_pills.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_pills.offset_top = -150
	_pills.offset_bottom = -122
	_pills.offset_left = 32
	_pills.offset_right = 400

	_dose_bar = ProgressBar.new()
	_dose_bar.show_percentage = false
	_dose_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dose_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dose_bar.offset_left = 32
	_dose_bar.offset_right = 292
	_dose_bar.offset_top = -84
	_dose_bar.offset_bottom = -72
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	_dose_bar.add_theme_stylebox_override("background", bg)
	_dose_bar.add_theme_stylebox_override("fill", fill)
	_dose_bar.hide()
	add_child(_dose_bar)
	_dose_label = _label(16, _dose_bar)
	_dose_label.position = Vector2(0, -24)

	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 90
	_banner.offset_bottom = 200
	_banner.hide()
	add_child(_banner)
	_banner_title = _label(48, _banner)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_desc = _label(20, _banner)
	_banner_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(size: int, parent: Node = self) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	parent.add_child(l)
	return l


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
	_dose_bar.hide()
	_death_screen.show()
	_death_screen.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_death_screen, "modulate:a", 1.0, 0.5)
	tween.tween_interval(maxf(restart_delay - 0.5, 0.0))
	tween.tween_callback(func() -> void: _restart_ready = true)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.25)
