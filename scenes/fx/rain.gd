extends GPUParticles3D
## Rain that follows the active camera, so a small emitter box covers wherever you look.


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = Vector3(cam.global_position.x, cam.global_position.y + 12.0, cam.global_position.z)
