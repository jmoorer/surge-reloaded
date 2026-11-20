class_name RunDirector
extends Node
## One run, start to finish: resumes a saved run, pauses (Esc / lost pointer lock) with
## Resume and Save & Quit, banks samples on extraction and wipes them on death.

@export var player: Player
@export var extraction: ExtractionZone
@export var pickups_root: Node3D
@export var cops_root: Node3D

var profile: Dictionary
var ended := false
var resumed := false

var _ui: CanvasLayer
var _pause: Control
var _end: Control
var _end_title: Label
var _end_body: Label
var _extract_label: Label
var _end_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = SaveGame.load_profile()
	_build_ui()
	player.died.connect(_on_player_died)
	extraction.extracted.connect(_on_extracted)
	var save := SaveGame.take_run()
	if not save.is_empty():
		apply(save)
		resumed = true
	_intro.call_deferred()


func _intro() -> void:
	var hud := _hud()
	if hud == null:
		return
	if resumed:
		hud.show_banner("RUN RESUMED", "Your save is gone now. Make it count.", Color(0.85, 0.85, 0.8), 2.0)
	else:
		hud.show_banner("THE DISTRICT", "Reach the extraction point.  Banked samples: %d" \
			% profile["banked_samples"], Color(0.85, 0.85, 0.8), 2.5)


# --- Snapshot ---------------------------------------------------------------------------

func capture() -> Dictionary:
	var cops := {}
	for cop in _cops():
		cops[String(cop.name)] = cop.to_dict()
	var pickups: Array = []
	for p in get_tree().get_nodes_in_group(&"pickups"):
		if not p.is_queued_for_deletion():
			pickups.append((p as Pickup).to_dict())
	return {"version": 1, "player": player.to_dict(), "cops": cops, "pickups": pickups}


func apply(d: Dictionary) -> void:
	player.from_dict(d.get("player", {}))
	var cops: Dictionary = d.get("cops", {})
	for cop in _cops():
		if cops.has(String(cop.name)):
			cop.from_dict(cops[String(cop.name)])
		else:
			cop.queue_free()  # Died and was already gone when the save was made.
	if d.has("pickups"):
		for p in get_tree().get_nodes_in_group(&"pickups"):
			p.remove_from_group(&"pickups")
			p.queue_free()
		for pd in d["pickups"]:
			pickups_root.add_child(Pickup.from_dict(pd))


func _cops() -> Array[DirtyCop]:
	var out: Array[DirtyCop] = []
	if cops_root:
		for c in cops_root.get_children():
			if c is DirtyCop and not c.is_queued_for_deletion():
				out.append(c)
	return out


# --- Pause / save -----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if extraction and not ended:
		var inside := extraction.is_player_inside() and extraction.progress > 0.0
		_extract_label.visible = inside
		if inside:
			_extract_label.text = "EXTRACTING  %.1f" % (extraction.hold_time - extraction.progress)
	# Browsers drop pointer lock on Esc without sending us the key: treat it as pause.
	if not get_tree().paused and not ended and not player.is_dead and _can_pause() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		pause()


func _can_pause() -> bool:
	return DisplayServer.get_name() != "headless" and get_window().has_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _pause.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()
	elif _end.visible and _end_ready and (event.is_action_pressed("shoot") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		new_run()


func pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause.show()
	(_pause.find_child("Resume", true, false) as Button).grab_focus()


func resume() -> void:
	_pause.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func save_and_quit() -> void:
	var ok := SaveGame.save_run(capture())
	_pause.hide()
	_show_end("RUN SAVED" if ok else "SAVE FAILED",
		"You can close the game. The run picks up where you left it\n(the save is deleted when it loads)." \
		if ok else "Couldn't write the save file.", Color(0.85, 0.85, 0.8), false)
	if ok and not OS.has_feature("web"):
		get_tree().create_timer(0.8, true).timeout.connect(get_tree().quit)


func new_run() -> void:
	_end_ready = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


# --- Run outcomes -----------------------------------------------------------------------

func _on_extracted() -> void:
	if ended or player.is_dead:
		return
	ended = true
	var banked := player.samples
	profile["banked_samples"] = int(profile["banked_samples"]) + banked
	profile["extractions"] = int(profile["extractions"]) + 1
	SaveGame.save_profile(profile)
	SaveGame.delete_run()
	get_tree().paused = true
	_show_end("EXTRACTED", "Banked %d sample%s.   Total banked: %d\n\nClick to go back in." % [
		banked, "" if banked == 1 else "s", profile["banked_samples"]], Color(0.55, 1.0, 0.75), true)


func _on_player_died() -> void:
	ended = true
	profile["deaths"] = int(profile["deaths"]) + 1
	SaveGame.save_profile(profile)
	SaveGame.delete_run()
	var lost := player.samples
	var hud := _hud()
	if hud:
		hud.set_death_note("%d sample%s lost with you." % [lost, "" if lost == 1 else "s"] \
			if lost > 0 else "Nothing lost but you.")


func _hud() -> HUD:
	return player.get_node_or_null("HUD") as HUD


# --- UI ---------------------------------------------------------------------------------

func _show_end(title: String, body: String, color: Color, can_restart: bool) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", color)
	_end_body.text = body
	_end.show()
	_extract_label.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_end_ready = false
	if can_restart:
		get_tree().create_timer(1.0, true).timeout.connect(func() -> void: _end_ready = true)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)

	_extract_label = _label(30, Color(0.55, 1.0, 0.75))
	_extract_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_extract_label.offset_top = 60
	_extract_label.offset_bottom = 100
	_extract_label.offset_left = -300
	_extract_label.offset_right = 300
	_extract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extract_label.hide()
	_ui.add_child(_extract_label)

	_pause = _overlay(Color(0, 0, 0, 0.6))
	var box := _pause.get_child(1) as VBoxContainer
	box.add_child(_label(56, Color(0.9, 0.9, 0.85), "PAUSED"))
	box.add_child(_button("Resume", resume))
	box.add_child(_button("Save & Quit", save_and_quit))
	_pause.hide()

	_end = _overlay(Color(0, 0, 0, 0.7))
	box = _end.get_child(1) as VBoxContainer
	_end_title = _label(64, Color.WHITE)
	_end_body = _label(22, Color(0.9, 0.9, 0.85))
	box.add_child(_end_title)
	box.add_child(_end_body)
	_end.hide()


func _overlay(dim: Color) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)
	var bg := ColorRect.new()
	bg.color = dim
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(box)
	return root


func _label(size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = text.replace(" ", "").replace("&", "")
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	return b
