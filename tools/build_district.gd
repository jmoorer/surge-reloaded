# Builds res://scenes/levels/district.tscn: the greybox street the run takes place in.
# Run: godot --headless --path . --script res://tools/build_district.gd
# Re-run after changing the layout below; the scene is regenerated from scratch (hand edits lost).
extends SceneTree

const OUT := "res://scenes/levels/district.tscn"
const PLAYER := preload("res://scenes/player/player.tscn")
const COP := preload("res://scenes/enemies/dirty_cop.tscn")

## Street runs along Z. Player starts at +Z end, extraction is at the -Z end.
const STREET_HALF_WIDTH := 9.0  # Building faces at x = ±9 (6 m road + 3 m sidewalk each side).
const Z_START := 52.0
const Z_END := -62.0

## Buildings: [x_center, z_center, size_x, height, size_z]
const BUILDINGS := [
	# Left (west) side, with an alley gap at z ∈ [-4, 2].
	[-15.0, 44.0, 12.0, 12.0, 16.0],
	[-15.0, 23.0, 12.0, 18.0, 22.0],
	[-15.0, 7.0, 12.0, 9.0, 10.0],
	[-15.0, -14.0, 12.0, 14.0, 20.0],
	[-15.0, -40.0, 12.0, 20.0, 28.0],
	# Right (east) side.
	[15.0, 38.0, 12.0, 15.0, 28.0],
	[15.0, 12.0, 12.0, 10.0, 20.0],
	[15.0, -8.0, 12.0, 22.0, 16.0],
	[15.0, -30.0, 12.0, 11.0, 24.0],
	[15.0, -54.0, 12.0, 16.0, 20.0],
	# Alley back wall and courtyard walls (behind the left gap).
	[-27.0, -1.0, 6.0, 8.0, 20.0],
	[-21.0, -10.0, 6.0, 8.0, 2.0],
	[-21.0, 8.0, 6.0, 8.0, 2.0],
	# End caps.
	[0.0, Z_START + 4.0, 30.0, 6.0, 2.0],
	[0.0, Z_END - 4.0, 30.0, 6.0, 2.0],
]

## Cover: [kind, x, z, yaw_deg]
const COVER := [
	["car", -4.2, 40.0, 0.0], ["car", 4.4, 30.0, 0.0], ["car", -4.2, 18.0, 8.0],
	["car", 1.0, 8.0, 70.0], ["car", 4.4, -6.0, 0.0], ["car", -4.0, -20.0, -5.0],
	["car", 4.3, -34.0, 0.0], ["car", -1.5, -46.0, 100.0],
	["dumpster", -7.6, 30.0, 0.0], ["dumpster", 7.6, 20.0, 0.0], ["dumpster", -20.0, 3.5, 90.0],
	["dumpster", 7.6, -22.0, 0.0], ["dumpster", -7.6, -30.0, 0.0],
	["barrier", 0.0, 24.0, 90.0], ["barrier", -2.0, -12.0, 90.0], ["barrier", 2.5, -40.0, 90.0],
	["crate", -22.5, -6.0, 15.0], ["crate", -23.5, -4.4, 0.0], ["crate", 7.4, 2.0, 30.0],
	["crate", -7.4, -50.0, 0.0], ["crate", 7.0, -46.0, 12.0],
]

const COVER_SIZE := {
	"car": Vector3(1.9, 1.4, 4.4),
	"dumpster": Vector3(1.4, 1.3, 2.2),
	"barrier": Vector3(0.6, 1.0, 3.0),
	"crate": Vector3(1.2, 1.2, 1.2),
}

## Streetlights: [x, z]
const LIGHTS := [[-8.0, 46.0], [8.0, 34.0], [-8.0, 22.0], [8.0, 6.0], [-8.0, -8.0],
	[8.0, -20.0], [-8.0, -34.0], [8.0, -48.0]]

## Cops: [name, start_x, start_z, [[x, z], ...] patrol points]
const COPS := [
	["CopA", -3.0, 26.0, [[-3.0, 26.0], [3.0, 26.0], [3.0, 14.0], [-3.0, 14.0]]],
	["CopB", -22.0, -2.0, [[-22.0, -2.0], [-22.0, 5.0], [-11.0, 0.0]]],
	["CopC", 3.0, -16.0, [[3.0, -16.0], [-5.0, -16.0], [-5.0, -28.0], [3.0, -28.0]]],
	["CopD", 0.0, -52.0, [[-5.0, -52.0], [5.0, -52.0]]],
]

## Pills: [x, z]. Few enough that dosing is a choice; one early so the genome gets revealed.
const PILLS := [[2.0, 36.0], [-22.0, -7.0], [6.5, -26.0], [-6.0, -44.0]]

const PILL := preload("res://scenes/pickups/pill.tscn")

var _mats := {}
var _scene_root: Node3D


func _initialize() -> void:
	var root_node := Node3D.new()
	root_node.name = "District"
	_scene_root = root_node
	_add_environment(root_node)

	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 1.75
	navmesh.agent_max_climb = 0.25
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	nav.navigation_mesh = navmesh
	_add(root_node, nav)

	var geo := Node3D.new()
	geo.name = "Geometry"
	_add(nav, geo)

	var length := Z_START - Z_END + 12.0
	var mid_z := (Z_START + Z_END) * 0.5
	_box(geo, "Ground", Vector3(0, -0.5, mid_z), Vector3(70, 1, length), "asphalt")
	# Sidewalks/markings are paint only (no collision) so nothing trips on a curb.
	for side in [-1.0, 1.0]:
		_decal(geo, "Sidewalk", Vector3(side * 7.5, 0.005, mid_z), Vector3(3, 0.01, length), "sidewalk")
	for z in range(int(Z_END), int(Z_START), 6):
		_decal(geo, "Lane", Vector3(0, 0.006, z + 1.5), Vector3(0.15, 0.01, 2.5), "paint")

	var i := 0
	for b in BUILDINGS:
		i += 1
		var size := Vector3(b[2], b[3], b[4])
		_box(geo, "Building%d" % i, Vector3(b[0], size.y * 0.5, b[1]), size, "building")

	var counts := {}
	for c in COVER:
		var kind: String = c[0]
		counts[kind] = counts.get(kind, 0) + 1
		var size: Vector3 = COVER_SIZE[kind]
		var body := _box(geo, "%s%d" % [kind.capitalize(), counts[kind]],
			Vector3(c[1], size.y * 0.5, c[2]), size, kind)
		body.rotation_degrees.y = c[3]

	var lights := Node3D.new()
	lights.name = "Streetlights"
	_add(root_node, lights)
	i = 0
	for l in LIGHTS:
		i += 1
		_streetlight(lights, "Light%d" % i, Vector3(l[0], 0, l[1]))

	# Bake once here so the scene ships with a navmesh (no runtime bake on web). Done before
	# actors are added so their _ready() never runs inside the scene we pack.
	root.add_child.call_deferred(root_node)
	await process_frame
	await physics_frame
	nav.bake_navigation_mesh(false)
	var polys := navmesh.get_polygon_count()
	root.remove_child(root_node)

	var player: Node3D = PLAYER.instantiate()
	player.name = "Player"
	_add(root_node, player)
	player.position = Vector3(0, 0, Z_START - 4.0)

	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	_add(root_node, spawn)
	spawn.position = player.position

	var pickups := Node3D.new()
	pickups.name = "Pickups"
	_add(root_node, pickups)
	i = 0
	for p in PILLS:
		i += 1
		var pill: Node3D = PILL.instantiate()
		pill.name = "Pill%d" % i
		_add(pickups, pill)
		pill.position = Vector3(p[0], 0, p[1])

	var cops := Node3D.new()
	cops.name = "Cops"
	_add(root_node, cops)
	for c in COPS:
		var path := Node3D.new()
		path.name = "%sPatrol" % c[0]
		_add(cops, path)
		var n := 0
		for p in c[3]:
			n += 1
			var m := Marker3D.new()
			m.name = "P%d" % n
			_add(path, m)
			m.position = Vector3(p[0], 0, p[1])
		var cop: DirtyCop = COP.instantiate()
		cop.name = c[0]
		_add(cops, cop)
		cop.position = Vector3(c[1], 0, c[2])
		cop.rotation_degrees.y = 0.0  # Face +Z, toward where the player comes from.
		cop.patrol_path = path


	var packed := PackedScene.new()
	var err := packed.pack(root_node)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("district: %d nav polygons, save -> %s" % [polys, error_string(err)])
	root_node.free()
	quit(0 if err == OK and polys > 0 else 1)


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _scene_root  # Only nodes owned by the root get saved.


func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.roughness = 0.8
	match kind:
		"asphalt": m.albedo_color = Color(0.16, 0.16, 0.17); m.roughness = 0.45
		"sidewalk": m.albedo_color = Color(0.3, 0.3, 0.3)
		"paint": m.albedo_color = Color(0.55, 0.5, 0.35)
		"building": m.albedo_color = Color(0.26, 0.25, 0.27)
		"car": m.albedo_color = Color(0.2, 0.22, 0.26); m.roughness = 0.3; m.metallic = 0.4
		"dumpster": m.albedo_color = Color(0.17, 0.24, 0.18)
		"barrier": m.albedo_color = Color(0.45, 0.44, 0.42)
		"crate": m.albedo_color = Color(0.33, 0.27, 0.2)
		"pole": m.albedo_color = Color(0.12, 0.12, 0.12)
		"lamp":
			m.albedo_color = Color(1, 0.7, 0.4)
			m.emission_enabled = true
			m.emission = Color(1, 0.6, 0.3)
			m.emission_energy_multiplier = 3.0
	_mats[kind] = m
	return m


func _box(parent: Node, n: String, pos: Vector3, size: Vector3, kind: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = n
	_add(parent, body)
	body.position = pos
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat(kind)
	mesh.mesh = box
	_add(body, mesh)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	_add(body, col)
	return body


func _decal(parent: Node, n: String, pos: Vector3, size: Vector3, kind: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = n
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat(kind)
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mesh)
	mesh.position = pos


func _streetlight(parent: Node, n: String, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = n
	_add(parent, holder)
	holder.position = pos
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.1
	cyl.height = 5.5
	cyl.material = _mat("pole")
	pole.mesh = cyl
	_add(holder, pole)
	pole.position = Vector3(0, 2.75, 0)
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var lamp_box := BoxMesh.new()
	lamp_box.size = Vector3(0.5, 0.15, 0.3)
	lamp_box.material = _mat("lamp")
	lamp.mesh = lamp_box
	_add(holder, lamp)
	var inward := -signf(pos.x)
	lamp.position = Vector3(inward * 0.6, 5.5, 0)
	var light := OmniLight3D.new()
	light.name = "Omni"
	light.light_color = Color(1, 0.62, 0.3)
	light.light_energy = 2.5
	light.omni_range = 13.0
	light.omni_attenuation = 1.4
	_add(holder, light)
	light.position = Vector3(inward * 0.6, 5.2, 0)


func _add_environment(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.16, 0.19)
	env.fog_density = 0.025
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(parent, we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.65, 0.7, 0.9)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	_add(parent, moon)
	moon.rotation_degrees = Vector3(-55, 30, 0)
