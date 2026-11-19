class_name Crosshair
extends Control
## Centre dot + ticks, with a hit marker that flashes on confirmed hits.

@export var color: Color = Color(1, 1, 1, 0.85)
@export var hit_color: Color = Color(1, 1, 1)
@export var weak_spot_color: Color = Color(1.0, 0.55, 0.2)
@export var kill_color: Color = Color(1.0, 0.2, 0.15)
@export var hit_marker_time: float = 0.15

var _hit_left := 0.0
var _hit_draw_color := Color.WHITE
var _kick := 0.0  # Ticks spread briefly after each shot.


func show_hit(_damage: float, is_weak_spot: bool, killed: bool) -> void:
	_hit_left = hit_marker_time * (2.0 if killed else 1.0)
	_hit_draw_color = kill_color if killed else (weak_spot_color if is_weak_spot else hit_color)
	queue_redraw()


func kick() -> void:
	_kick = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _hit_left > 0.0 or _kick > 0.0:
		_hit_left = maxf(_hit_left - delta, 0.0)
		_kick = maxf(_kick - delta * 8.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 1.5, color)
	var gap := 6.0 + _kick * 5.0
	var length := 6.0
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * gap, c + dir * (gap + length), color, 2.0, true)
	if _hit_left > 0.0:
		var a := _hit_left / hit_marker_time
		var col := Color(_hit_draw_color, minf(a, 1.0))
		for diag: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var d := diag.normalized()
			draw_line(c + d * 9.0, c + d * 17.0, col, 2.5, true)
