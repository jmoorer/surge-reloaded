extends CanvasLayer
## Combat HUD: crosshair/hit marker and ammo count, driven by Pistol signals.

@export var pistol: Pistol

@onready var _crosshair: Crosshair = $Crosshair
@onready var _ammo: Label = $Ammo


func _ready() -> void:
	if pistol == null:
		push_warning("HUD has no pistol assigned")
		return
	pistol.hit_confirmed.connect(_crosshair.show_hit)
	pistol.fired.connect(func(_ammo_left: int) -> void: _crosshair.kick())
	pistol.ammo_changed.connect(_on_ammo_changed)
	pistol.reload_started.connect(func(_t: float) -> void: _ammo.text = "RELOADING")
	_on_ammo_changed.call_deferred(pistol.magazine_size, pistol.magazine_size)


func _on_ammo_changed(ammo: int, magazine_size: int) -> void:
	_ammo.text = "%d / %d" % [ammo, magazine_size]
	_ammo.modulate = Color(1.0, 0.35, 0.3) if ammo * 4 <= magazine_size else Color.WHITE
