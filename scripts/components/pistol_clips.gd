class_name PistolClips
extends RefCounted
## Mixamo pistol locomotion clips (X Bot skeleton), shared by the player and enemies.
## install() loads them into an AnimationPlayer as the "pistol" library; play() picks a
## clip and scales playback to ground speed so feet don't slide.

const ANIM_DIR := "res://assets/third_party/mixamo/animations/"
## Clip file, and the ground speed (m/s) it was authored at.
const CLIPS := {
	&"idle": ["pistol-idle__e4528faaee276d7f1ce4_8d5977af883f_a74ddc14ae2e.fbx", 0.0],
	&"walk": ["pistol-walk__83fc03c0de7becb71fe8_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.6],
	&"walk_back": ["pistol-walk-backward__e6217454337d48ae5f67_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.4],
	&"strafe_left": ["pistol-strafe__c9c514be526b3ae5f592_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.5],
	&"strafe_right": ["pistol-strafe__09ce081abb7d419ad156_8d5977af883f_a74ddc14ae2e_inplace.fbx", 1.5],
	&"run": ["pistol-run__2d25c98bfe2ba8a5b2c5_8d5977af883f_a74ddc14ae2e_inplace.fbx", 4.5],
}

static var _library: AnimationLibrary


static func install(anim: AnimationPlayer) -> void:
	if anim == null:
		return
	if _library == null:
		_library = _build_library()
	anim.add_animation_library(&"pistol", _library)


static func play(anim: AnimationPlayer, clip: StringName, ground_speed: float = 0.0) -> void:
	if anim == null:
		return
	var key := StringName("pistol/" + clip)
	if not anim.has_animation(key):
		return
	var authored: float = CLIPS[clip][1]
	anim.speed_scale = clampf(ground_speed / authored, 0.6, 2.0) if authored > 0.0 else 1.0
	if anim.current_animation != key:
		anim.play(key, 0.2)


static func _build_library() -> AnimationLibrary:
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
	return lib
