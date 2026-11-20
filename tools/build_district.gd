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
const SAMPLE := preload("res://scenes/pickups/sample.tscn")
const EXTRACTION := preload("res://scenes/props/extraction_zone.tscn")
const RUN_DIRECTOR := preload("res://scripts/run/run_director.gd")
const RAIN := preload("res://scenes/fx/rain.tscn")

## Samples: [x, z]. Riskier spots hold more of them (alley, courtyard, near cops).
const SAMPLES := [[-7.2, 44.0], [7.0, 28.0], [-20.5, -8.0], [-24.0, 6.0], [-1.0, 10.5],
	[6.8, -8.0], [-7.0, -24.0], [0.5, -38.0], [-6.5, -56.0]]
const EXTRACTION_AT := Vector3(4.0, 0.0, -57.0)

const KIT := "res://assets/third_party/kaykit/city-builder-bits/"
## Facade modules: [file, width in kit units]. Front faces +Z in the kit.
const FACADES := [["building_A_withoutBase", 1.21], ["building_B_withoutBase", 1.61],
	["building_C_withoutBase", 1.21], ["building_D_withoutBase", 1.61],
	["building_E_withoutBase", 2.01], ["building_F_withoutBase", 2.01],
	["building_G_withoutBase", 2.01], ["building_H_withoutBase", 2.01]]
const FACADE_SCALE := 5.0
## Prop models per cover kind: [files], uniform scale, extra yaw (deg), y offset.
const PROP_MODELS := {
	"car": [["car_sedan", "car_taxi", "car_hatchback", "car_stationwagon", "car_police"], 4.7, 0.0, 0.33],
	"dumpster": [["dumpster"], 3.9, 90.0, 0.0],
	"crate": [["box_A"], 6.0, 0.0, 0.0],
}

var _mats := {}
var _scene_root: Node3D
var _rng := RandomNumberGenerator.new()


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

	_rng.seed = 1977  # Same facades every rebuild.
	var i := 0
	for b in BUILDINGS:
		i += 1
		var size := Vector3(b[2], b[3], b[4])
		var body := _box(geo, "Building%d" % i, Vector3(b[0], size.y * 0.5, b[1]), size, "building")
		if absf(b[0]) == STREET_HALF_WIDTH + 6.0:
			_facades(body, size, -signf(b[0]))

	var counts := {}
	for c in COVER:
		var kind: String = c[0]
		counts[kind] = counts.get(kind, 0) + 1
		var size: Vector3 = COVER_SIZE[kind]
		var body := _box(geo, "%s%d" % [kind.capitalize(), counts[kind]],
			Vector3(c[1], size.y * 0.5, c[2]), size, kind)
		body.rotation_degrees.y = c[3]
		if PROP_MODELS.has(kind):
			_swap_for_model(body, kind, size, counts[kind])

	var rain: Node3D = RAIN.instantiate()
	rain.name = "Rain"
	_add(root_node, rain)

	var lights := Node3D.new()
	lights.name = "Streetlights"
	_add(root_node, lights)
	i = 0
	for l in LIGHTS:
		i += 1
		_streetlight(lights, "Light%d" % i, Vector3(l[0], 0, l[1]), i % 2 == 1)

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

	i = 0
	for p in SAMPLES:
		i += 1
		var sample: Node3D = SAMPLE.instantiate()
		sample.name = "Sample%d" % i
		_add(pickups, sample)
		sample.position = Vector3(p[0], 0, p[1])

	var zone: Node3D = EXTRACTION.instantiate()
	zone.name = "Extraction"
	_add(root_node, zone)
	zone.position = EXTRACTION_AT

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


	# Last child: every sibling is ready before it resumes a saved run.
	var director := Node.new()
	director.name = "Run"
	director.set_script(RUN_DIRECTOR)
	_add(root_node, director)
	director.set("player", player)
	director.set("extraction", zone)
	director.set("pickups_root", pickups)
	director.set("cops_root", cops)

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
		"asphalt":
			# Rain-soaked: puddle noise drives roughness so lamps smear across wet patches.
			m.albedo_color = Color(0.13, 0.13, 0.14)
			m.roughness = 1.0
			var noise := FastNoiseLite.new()
			noise.frequency = 0.012
			noise.fractal_octaves = 3
			var tex := NoiseTexture2D.new()
			tex.width = 512
			tex.height = 512
			tex.seamless = true
			tex.noise = noise
			var ramp := Gradient.new()
			ramp.set_color(0, Color(0.05, 0.05, 0.05))
			ramp.set_color(1, Color(0.6, 0.6, 0.6))
			ramp.set_offset(0, 0.45)
			ramp.set_offset(1, 0.62)
			tex.color_ramp = ramp
			m.roughness_texture = tex
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * 0.04
		"sidewalk": m.albedo_color = Color(0.22, 0.22, 0.23); m.roughness = 0.35
		"paint": m.albedo_color = Color(0.55, 0.5, 0.35)
		"building": m.albedo_color = Color(0.11, 0.1, 0.11); m.roughness = 0.9
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


## Lines the street face of a block with kit buildings. `facing` is +1 (front toward +X)
## or -1. The block's box stays as collision and as the dark mass behind/above them.
func _facades(body: StaticBody3D, size: Vector3, facing: float) -> void:
	var holder := Node3D.new()
	holder.name = "Facades"
	_add(body, holder)
	# Pick modules until the block length is covered, then stretch them to fit exactly.
	var picks: Array = []
	var total := 0.0
	while total < size.z - 2.0:
		var f: Array = FACADES[_rng.randi_range(0, FACADES.size() - 1)]
		picks.append(f)
		total += f[1] * FACADE_SCALE
	var stretch := size.z / total
	var z := -size.z * 0.5
	# Kit walls sit ~0.5 m behind the front of their bounds (awnings/ledges stick out), so
	# shift them forward until the wall lines up with the collision face.
	var face_x := facing * (size.x * 0.5 + 0.5)
	var depth := 1.3 * FACADE_SCALE
	for f in picks:
		var w: float = f[1] * FACADE_SCALE * stretch
		var model: Node3D = (load(KIT + f[0] + ".gltf") as PackedScene).instantiate()
		_add(holder, model)
		model.rotation_degrees.y = 90.0 * facing  # Kit front +Z -> street.
		model.scale = Vector3(FACADE_SCALE * stretch, FACADE_SCALE, FACADE_SCALE)
		model.position = Vector3(face_x - facing * depth * 0.5, -size.y * 0.5 - 0.5, z + w * 0.5)
		# Some windows are lit: a small glow just off the wall picks the facade out of the dark.
		if _rng.randf() < 0.6:
			var glow := OmniLight3D.new()
			glow.name = "WindowGlow"
			var neon := _rng.randf() < 0.2
			glow.light_color = Color(0.3, 0.9, 1.0) if neon and _rng.randf() < 0.5 \
				else (Color(1.0, 0.25, 0.6) if neon else Color(1.0, 0.78, 0.45))
			glow.light_energy = 2.2 if neon else 1.4
			glow.light_volumetric_fog_energy = 0.5
			glow.omni_range = 7.0
			glow.omni_attenuation = 1.2
			_add(holder, glow)
			var storey := float(_rng.randi_range(1, 2))
			glow.position = Vector3(face_x + facing * 1.2, -size.y * 0.5 + 1.0 + storey * 3.4,
				z + w * _rng.randf_range(0.3, 0.7))
		z += w
	# The block's own box becomes a darker mass set back from the street, so it reads as the
	# taller building behind the facades instead of hiding them.
	var mass := body.get_node("Mesh") as MeshInstance3D
	var setback := 4.0
	(mass.mesh as BoxMesh).size = Vector3(size.x - setback, size.y, size.z)
	mass.position.x = -facing * setback * 0.5


## Replaces a cover box's greybox mesh with a kit model (collision box stays).
func _swap_for_model(body: StaticBody3D, kind: String, size: Vector3, index: int) -> void:
	var spec: Array = PROP_MODELS[kind]
	var files: Array = spec[0]
	var file: String = files[(index - 1) % files.size()]
	var model: Node3D = (load(KIT + file + ".gltf") as PackedScene).instantiate()
	model.name = "Model"
	_add(body, model)
	model.scale = Vector3.ONE * spec[1]
	model.rotation_degrees.y = spec[2]
	model.position = Vector3(0, -size.y * 0.5 + spec[3], 0)
	body.get_node("Mesh").free()


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


func _streetlight(parent: Node, n: String, pos: Vector3, shadows: bool) -> void:
	var holder := Node3D.new()
	holder.name = n
	_add(parent, holder)
	holder.position = pos
	var model: Node3D = (load(KIT + "streetlight.gltf") as PackedScene).instantiate()
	model.name = "Model"
	_add(holder, model)
	model.scale = Vector3.ONE * 6.0
	# Kit arm reaches toward -X; turn it over the road.
	var inward := -signf(pos.x)
	model.rotation_degrees.y = 180.0 if inward > 0.0 else 0.0
	var light := OmniLight3D.new()
	light.name = "Omni"
	light.light_color = Color(1, 0.6, 0.28)
	light.light_energy = 5.5
	light.light_volumetric_fog_energy = 2.5
	light.omni_range = 17.0
	light.omni_attenuation = 1.1
	light.shadow_enabled = shadows
	_add(holder, light)
	light.position = Vector3(inward * 1.2, 5.3, 0)


func _add_environment(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.ambient_light_energy = 0.6
	env.ambient_light_color = Color(0.22, 0.25, 0.34)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.11, 0.14)
	env.fog_density = 0.012
	# Volumetric fog makes the sodium lamps throw visible cones through the rain haze.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.75, 0.75, 0.8)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.15
	# Wet street reflections.
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.5
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(parent, we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.65, 0.7, 0.9)
	moon.light_energy = 0.25
	moon.shadow_enabled = true
	_add(parent, moon)
	moon.rotation_degrees = Vector3(-55, 30, 0)
