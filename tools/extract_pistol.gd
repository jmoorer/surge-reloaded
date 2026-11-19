# One-off: pulls Gun_004 (pistol) + its bullet out of the Vladek pack as standalone meshes.
# Run: godot --headless --path . --script res://tools/extract_pistol.gd
extends SceneTree

const PACK := "res://assets/third_party/vladek/lp-mini-pack-modern-weapons-with-bullets-part-1/lp_mini_pack_modern_weaponswith_bullets_part_1.glb"


func _pack_xform(n: Node, root_node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != root_node:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _bake(mi: MeshInstance3D, xform: Transform3D) -> ArrayMesh:
	# Bake transform into vertices so the saved mesh is in clean local space.
	var st := SurfaceTool.new()
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		st.clear()
		st.append_from(mi.mesh, s, xform)
		st.set_material(mi.get_active_material(s))
		st.commit(out)
	return out


func _initialize() -> void:
	var pack: Node = load(PACK).instantiate()
	var gun: MeshInstance3D = pack.find_child("Gun_004_Palette_0", true, false)
	var bullet: MeshInstance3D = pack.find_child("Gun_004_Bullet_Palette_0", true, false)

	var gun_x := _pack_xform(gun, pack)
	var aabb := gun_x * gun.get_aabb()
	# Pack space: barrel points +Z, grip down. Target: barrel along -Z, 0.21 m long,
	# origin at the top-back of the grip (where the hand's palm sits).
	var s := 0.21 / aabb.size.z
	var pivot := Vector3(aabb.get_center().x, aabb.position.y + aabb.size.y * 0.62, aabb.position.z + aabb.size.z * 0.18)
	var to_local := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	var gun_mesh := _bake(gun, to_local * gun_x)
	print("gun aabb ", gun_mesh.get_aabb())
	ResourceSaver.save(gun_mesh, "res://assets/models/weapons/pistol_mesh.res")

	var b_x := _pack_xform(bullet, pack)
	var b_aabb := b_x * bullet.get_aabb()
	var b_to_local := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -b_aabb.get_center())
	var b_mesh := _bake(bullet, b_to_local * b_x)
	print("bullet aabb ", b_mesh.get_aabb())
	ResourceSaver.save(b_mesh, "res://assets/models/weapons/pistol_bullet_mesh.res")
	pack.free()
	quit()
