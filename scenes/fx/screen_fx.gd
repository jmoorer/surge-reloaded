class_name ScreenFX
extends CanvasLayer
## Full-screen grade driven by the Dose: grey while sober, a snap to full colour on a pill,
## a slow drain back to grey when it wears off, blur/double vision while crashing.

const SOBER_SATURATION := 0.18
const DOSED_SATURATION := 1.25

@export var dose: Dose

var _mat: ShaderMaterial
var _sat_tween: Tween

@onready var _rect: ColorRect = $Grade


func _ready() -> void:
	_mat = _rect.material as ShaderMaterial
	_mat.set_shader_parameter("saturation", SOBER_SATURATION)
	if dose:
		dose.dose_started.connect(_on_dose_started)
		dose.dose_ended.connect(_on_dose_ended)
		dose.modifiers_changed.connect(_on_modifiers_changed)


func saturation() -> float:
	return _mat.get_shader_parameter("saturation")


func _on_dose_started(power: StringName, _n: int, _revealed: bool) -> void:
	# The snap: overshoot past full colour with a power-tinted flash, then settle.
	if _sat_tween:
		_sat_tween.kill()
	_mat.set_shader_parameter("saturation", 2.0)
	var flash := Powers.color(power).lerp(Color.WHITE, 0.5)
	_mat.set_shader_parameter("tint", Color(flash.r * 1.6, flash.g * 1.6, flash.b * 1.6))
	_sat_tween = create_tween().set_parallel()
	_sat_tween.tween_method(_set_sat, 2.0, DOSED_SATURATION, 0.6).set_ease(Tween.EASE_OUT)
	_sat_tween.tween_method(_set_tint, _mat.get_shader_parameter("tint"), Color.WHITE, 0.4)


func _on_dose_ended(_n: int) -> void:
	if _sat_tween:
		_sat_tween.kill()
	_sat_tween = create_tween()
	_sat_tween.tween_method(_set_sat, saturation(), SOBER_SATURATION, 2.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_modifiers_changed(mods: PlayerModifiers) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter("blur", v),
		float(_mat.get_shader_parameter("blur")), mods.blur, 1.5)
	_mat.set_shader_parameter("vignette", 0.35 + mods.blur * 0.4)


func _set_sat(v: float) -> void:
	_mat.set_shader_parameter("saturation", v)


func _set_tint(c: Color) -> void:
	_mat.set_shader_parameter("tint", c)
